// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IUniswapV2Pair} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import {UniswapV2Library} from './UniswapV2Library.sol';
import {UniswapImmutables} from '../UniswapImmutables.sol';
import {Permit2Payments} from '../../Permit2Payments.sol';
import {Constants} from '../../../libraries/Constants.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';

/// @title Uniswap v2 交易的路由器
abstract contract V2SwapRouter is UniswapImmutables, Permit2Payments {
    error V2TooLittleReceived();
    error V2TooMuchRequested();
    error V2InvalidPath();
    error V2TooLittleReceivedPerHop(uint256 hopIndex, uint256 minPrice, uint256 price);
    error V2InvalidHopPriceLength();

    function _v2Swap(address[] calldata path, address recipient, address pair, uint256[] calldata minHopPriceX36)
        private
    {
        unchecked {
            // 缓存起来以避免重复运算
            (address token0,) = UniswapV2Library.sortTokens(path[0], path[1]);
            uint256 finalPairIndex = path.length - 1;
            uint256 penultimatePairIndex = finalPairIndex - 1;
            bool minHopPriceEnabled = minHopPriceX36.length != 0;
            for (uint256 i; i < finalPairIndex; i++) {
                (address input, address output) = (path[i], path[i + 1]);
                (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                uint256 amountInput = ERC20(input).balanceOf(pair) - reserveInput;
                uint256 amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
                (uint256 amount0Out, uint256 amount1Out) =
                    input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
                address nextPair;
                (nextPair, token0) = i < penultimatePairIndex
                    ? UniswapV2Library.pairAndToken0For(
                        UNISWAP_V2_FACTORY, UNISWAP_V2_PAIR_INIT_CODE_HASH, output, path[i + 2]
                    )
                    : (recipient, address(0));

                // 如果启用了 minHopPrice，需要检查输出余额的变化
                if (minHopPriceEnabled && minHopPriceX36[i] != 0) {
                    uint256 recipientBalance = ERC20(output).balanceOf(nextPair);
                    IUniswapV2Pair(pair).swap(amount0Out, amount1Out, nextPair, new bytes(0));
                    amountOutput = ERC20(output).balanceOf(nextPair) - recipientBalance;
                    uint256 price = amountOutput * Constants.PRICE_PRECISION / amountInput;
                    uint256 minPrice = minHopPriceX36[i];
                    if (price < minPrice) revert V2TooLittleReceivedPerHop(i, minPrice, price);
                } else {
                    IUniswapV2Pair(pair).swap(amount0Out, amount1Out, nextPair, new bytes(0));
                }
                pair = nextPair;
            }
        }
    }

    /// @notice 执行 Uniswap v2 精确输入兑换
    /// @param recipient 输出代币的接收方
    /// @param amountIn 本次交易的输入代币数量
    /// @param amountOutMinimum 期望获得的输出代币最小数量
    /// @param path 交易路径，以代币地址数组表示
    /// @param payer 将支付输入代币的地址
    /// @param minHopPriceX36 每跳最低价格数组，精度为 1e36（为空则禁用）
    function v2SwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        address payer,
        uint256[] calldata minHopPriceX36
    ) internal {
        if (path.length < 2) revert V2InvalidPath();
        if (minHopPriceX36.length != 0 && minHopPriceX36.length != path.length - 1) {
            revert V2InvalidHopPriceLength();
        }

        address firstPair =
            UniswapV2Library.pairFor(UNISWAP_V2_FACTORY, UNISWAP_V2_PAIR_INIT_CODE_HASH, path[0], path[1]);
        if (
            amountIn != Constants.ALREADY_PAID // amountIn 为 0 表示交易对中已经持有这些代币
        ) {
            payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        }

        ERC20 tokenOut = ERC20(path[path.length - 1]);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        _v2Swap(path, recipient, firstPair, minHopPriceX36);

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut < amountOutMinimum) revert V2TooLittleReceived();
    }

    /// @notice 执行 Uniswap v2 精确输出兑换
    /// @param recipient 输出代币的接收方
    /// @param amountOut 本次交易要获得的输出代币数量
    /// @param amountInMaximum 愿意支付的输入代币最大数量
    /// @param path 交易路径，以代币地址数组表示
    /// @param payer 将支付输入代币的地址
    /// @param minHopPriceX36 每跳最低价格数组，精度为 1e36（为空则禁用）
    function v2SwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        address[] calldata path,
        address payer,
        uint256[] calldata minHopPriceX36
    ) internal {
        if (path.length < 2) revert V2InvalidPath();
        if (minHopPriceX36.length != 0 && minHopPriceX36.length != path.length - 1) {
            revert V2InvalidHopPriceLength();
        }

        (uint256 amountIn, address firstPair) =
            UniswapV2Library.getAmountInMultihop(UNISWAP_V2_FACTORY, UNISWAP_V2_PAIR_INIT_CODE_HASH, amountOut, path);
        if (amountIn > amountInMaximum) revert V2TooMuchRequested();

        payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        _v2Swap(path, recipient, firstPair, minHopPriceX36);
    }
}
