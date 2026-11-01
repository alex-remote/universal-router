// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {V3Path} from './V3Path.sol';
import {BytesLib} from './BytesLib.sol';
import {SafeCast} from '@uniswap/v3-core/contracts/libraries/SafeCast.sol';
import {IUniswapV3Pool} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {IUniswapV3SwapCallback} from '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {Constants} from '../../../libraries/Constants.sol';
import {CalldataDecoder} from '@uniswap/v4-periphery/src/libraries/CalldataDecoder.sol';
import {Permit2Payments} from '../../Permit2Payments.sol';
import {UniswapImmutables} from '../UniswapImmutables.sol';
import {MaxInputAmount} from '../../../libraries/MaxInputAmount.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';

/// @title Uniswap v3 交易路由器
abstract contract V3SwapRouter is UniswapImmutables, Permit2Payments, IUniswapV3SwapCallback {
    using V3Path for bytes;
    using BytesLib for bytes;
    using CalldataDecoder for bytes;
    using SafeCast for uint256;

    error V3InvalidSwap();
    error V3TooLittleReceived();
    error V3TooMuchRequested();
    error V3InvalidAmountOut();
    error V3InvalidCaller();
    error V3TooLittleReceivedPerHop(uint256 hopIndex, uint256 minPrice, uint256 price);
    error V3TooMuchRequestedPerHop(uint256 hopIndex, uint256 minPrice, uint256 price);
    error V3HopPriceAndPathLengthMismatch();

    /// @dev #getSqrtRatioAtTick 可返回的最小值。等价于 getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;

    /// @dev #getSqrtRatioAtTick 可返回的最大值。等价于 getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (amount0Delta <= 0 && amount1Delta <= 0) revert V3InvalidSwap(); // 不支持完全处于零流动性区间内的兑换
        (, address payer, uint256[] memory minHopPriceX36, uint256 hopIndex) =
            abi.decode(data, (bytes, address, uint256[], uint256));
        bytes calldata path = data.toBytes(0);

        // 由于精确输出兑换按逆序执行，此时 tokenOut 实际上是 tokenIn
        (address tokenIn, uint24 fee, address tokenOut) = path.decodeFirstPool();

        if (computePoolAddress(tokenIn, tokenOut, fee) != msg.sender) revert V3InvalidCaller();

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0 ? (tokenIn < tokenOut, uint256(amount0Delta)) : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            // 向池（msg.sender）付款
            payOrPermit2Transfer(tokenIn, payer, msg.sender, amountToPay);
        } else {
            // 要么发起下一次兑换，要么付款
            if (path.hasMultiplePools()) {
                // 对精确输出的中间跳进行逐跳价格检查
                if (minHopPriceX36.length != 0) {
                    uint256 amountOut = uint256(-(amount0Delta > 0 ? amount1Delta : amount0Delta));
                    uint256 price = amountOut * Constants.PRICE_PRECISION / amountToPay;
                    uint256 minPrice = minHopPriceX36[hopIndex];
                    if (price < minPrice) revert V3TooMuchRequestedPerHop(hopIndex, minPrice, price);
                }
                // 这是中间步骤，因此付款方实际上是本合约
                path = path.skipToken();
                _swap(
                    -amountToPay.toInt256(),
                    msg.sender,
                    path,
                    payer,
                    false,
                    minHopPriceX36,
                    hopIndex > 0 ? hopIndex - 1 : 0
                );
            } else {
                if (amountToPay > MaxInputAmount.get()) revert V3TooMuchRequested();
                // 对第一个交易跳进行逐跳价格检查（在精确输出中最后执行）
                if (minHopPriceX36.length != 0) {
                    uint256 amountOut = uint256(-(amount0Delta > 0 ? amount1Delta : amount0Delta));
                    uint256 price = amountOut * Constants.PRICE_PRECISION / amountToPay;
                    uint256 minPrice = minHopPriceX36[hopIndex];
                    if (price < minPrice) revert V3TooMuchRequestedPerHop(hopIndex, minPrice, price);
                }
                // 注意：由于精确输出兑换按逆序执行，tokenOut 实际上是 tokenIn
                payOrPermit2Transfer(tokenOut, payer, msg.sender, amountToPay);
            }
        }
    }

    /// @notice 执行 Uniswap v3 精确输入兑换
    /// @param recipient 输出代币的接收方
    /// @param amountIn 本次交易的输入代币数量
    /// @param amountOutMinimum 期望获得的最小输出代币数量
    /// @param path 以字节串表示的交易路径
    /// @param payer 将支付输入代币的地址
    /// @param minHopPriceX36 以 1e36 精度表示的逐跳最低价格数组（为空则禁用）
    function v3SwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path,
        address payer,
        uint256[] calldata minHopPriceX36
    ) internal {
        // 校验逐跳价格数组的长度
        // V3 路径：token(20) + [fee(3) + token(20)] * numHops => path.length = (minHopPriceX36.length * 23) + 20
        if (
            minHopPriceX36.length != 0
                && path.length != (minHopPriceX36.length * Constants.NEXT_V3_POOL_OFFSET) + Constants.ADDR_SIZE
        ) revert V3HopPriceAndPathLengthMismatch();

        // 以 amountIn == ActionConstants.CONTRACT_BALANCE 作为标志，表示兑换本合约的全部余额
        if (amountIn == ActionConstants.CONTRACT_BALANCE) {
            address tokenIn = path.decodeFirstToken();
            amountIn = ERC20(tokenIn).balanceOf(address(this));
        }

        uint256 amountOut;
        uint256 hopIndex;
        uint256 previousAmountIn = amountIn;
        uint256[] memory emptyHopPrice = new uint256[](0);
        while (true) {
            bool hasMultiplePools = path.hasMultiplePools();

            // 前一次兑换的输出成为后续兑换的输入
            (int256 amount0Delta, int256 amount1Delta, bool zeroForOne) = _swap(
                amountIn.toInt256(),
                hasMultiplePools ? address(this) : recipient, // 对于中间兑换，由本合约托管
                path.getFirstPool(), // 只需要第一个池
                payer, // 对于中间兑换，由本合约托管
                true,
                emptyHopPrice, // 精确输入的回调无需价格检查
                0
            );

            amountIn = uint256(-(zeroForOne ? amount1Delta : amount0Delta));

            // 精确输入的逐跳价格检查
            if (minHopPriceX36.length != 0) {
                uint256 price = amountIn * Constants.PRICE_PRECISION / previousAmountIn;
                uint256 minPrice = minHopPriceX36[hopIndex];
                if (price < minPrice) revert V3TooLittleReceivedPerHop(hopIndex, minPrice, price);
            }

            // 决定继续还是终止
            if (hasMultiplePools) {
                payer = address(this);
                path = path.skipToken();
                previousAmountIn = amountIn;
                hopIndex++;
            } else {
                amountOut = amountIn;
                break;
            }
        }

        if (amountOut < amountOutMinimum) revert V3TooLittleReceived();
    }

    /// @notice 执行 Uniswap v3 精确输出兑换
    /// @param recipient 输出代币的接收方
    /// @param amountOut 本次交易要获得的输出代币数量
    /// @param amountInMaximum 期望支付的最大输入代币数量
    /// @param path 以字节串表示的交易路径
    /// @param payer 将支付输入代币的地址
    /// @param minHopPriceX36 以 1e36 精度表示的逐跳最低价格数组（为空则禁用）
    function v3SwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        bytes calldata path,
        address payer,
        uint256[] calldata minHopPriceX36
    ) internal {
        // 校验逐跳价格数组的长度
        // V3 路径：token(20) + [fee(3) + token(20)] * numHops => path.length = (minHopPriceX36.length * 23) + 20
        if (
            minHopPriceX36.length != 0
                && path.length != (minHopPriceX36.length * Constants.NEXT_V3_POOL_OFFSET) + Constants.ADDR_SIZE
        ) revert V3HopPriceAndPathLengthMismatch();

        // 将 calldata 转为 memory，以便在 _swap 中进行 abi.encode
        uint256[] memory minHopPriceX36Memory = minHopPriceX36;

        MaxInputAmount.set(amountInMaximum);

        // 对于精确输出，第一次 _swap 处理的是“最后一个”交易跳。
        // 交易方向：跳 0（A->B），跳 1（B->C），...
        // 执行顺序：先执行最后一跳，再由回调处理更早的跳。
        // 因此 hopIndex 从 minHopPriceX36Memory.length - 1 开始，并在回调中递减。
        uint256 startHopIndex = minHopPriceX36Memory.length > 0 ? minHopPriceX36Memory.length - 1 : 0;

        (int256 amount0Delta, int256 amount1Delta, bool zeroForOne) =
            _swap(-amountOut.toInt256(), recipient, path, payer, false, minHopPriceX36Memory, startHopIndex);

        uint256 amountOutReceived = zeroForOne ? uint256(-amount1Delta) : uint256(-amount0Delta);

        if (amountOutReceived != amountOut) revert V3InvalidAmountOut();

        MaxInputAmount.set(0);
    }

    /// @dev 为 exactIn 和 exactOut 两种情况执行单次兑换
    /// 对于 exactIn，`amount` 为 `amountIn`；对于 exactOut，`amount` 为 `-amountOut`
    function _swap(
        int256 amount,
        address recipient,
        bytes calldata path,
        address payer,
        bool isExactIn,
        uint256[] memory minHopPriceX36,
        uint256 hopIndex
    ) private returns (int256 amount0Delta, int256 amount1Delta, bool zeroForOne) {
        (address tokenIn, uint24 fee, address tokenOut) = path.decodeFirstPool();

        zeroForOne = isExactIn ? tokenIn < tokenOut : tokenOut < tokenIn;

        (amount0Delta, amount1Delta) = IUniswapV3Pool(computePoolAddress(tokenIn, tokenOut, fee))
            .swap(
                recipient,
                zeroForOne,
                amount,
                (zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1),
                abi.encode(path, payer, minHopPriceX36, hopIndex)
            );
    }

    function computePoolAddress(address tokenA, address tokenB, uint24 fee) private view returns (address pool) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            UNISWAP_V3_FACTORY,
                            keccak256(abi.encode(tokenA, tokenB, fee)),
                            UNISWAP_V3_POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
