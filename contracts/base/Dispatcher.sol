// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {V2SwapRouter} from '../modules/uniswap/v2/V2SwapRouter.sol';
import {V3SwapRouter} from '../modules/uniswap/v3/V3SwapRouter.sol';
import {V4SwapRouter} from '../modules/uniswap/v4/V4SwapRouter.sol';
import {BytesLib} from '../modules/uniswap/v3/BytesLib.sol';
import {Payments} from '../modules/Payments.sol';
import {Constants} from '../libraries/Constants.sol';
import {PaymentsImmutables} from '../modules/PaymentsImmutables.sol';
import {V3ToV4Migrator} from '../modules/V3ToV4Migrator.sol';
import {Commands} from '../libraries/Commands.sol';
import {Lock} from './Lock.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {CalldataDecoder} from '@uniswap/v4-periphery/src/libraries/CalldataDecoder.sol';
import {PoolKey} from '@uniswap/v4-core/src/types/PoolKey.sol';
import {IPoolManager} from '@uniswap/v4-core/src/interfaces/IPoolManager.sol';
import {ChainedActions} from '../modules/ChainedActions.sol';

/// @title 解码并执行命令
/// @notice 由 UniversalRouter 合约调用，用于高效地解码并执行单条命令
abstract contract Dispatcher is
    Payments,
    V2SwapRouter,
    V3SwapRouter,
    V4SwapRouter,
    V3ToV4Migrator,
    Lock,
    ChainedActions
{
    using BytesLib for bytes;
    using CalldataDecoder for bytes;

    error InvalidCommandType(uint256 commandType);
    error BalanceTooLow();

    /// @notice 使用提供的输入参数执行已编码的命令。
    /// @param commands 一组拼接在一起的命令，每条命令长 1 字节
    /// @param inputs 字节串数组，包含每条命令经 abi 编码的输入参数
    function execute(bytes calldata commands, bytes[] calldata inputs) external payable virtual;

    /// @notice 用于替代 msg.sender 的公开 view 函数，因为合约会进行自重入，
    /// 有时会出现 msg.sender == address(this)。msgSender() 则返回加锁的发起者
    /// @dev 覆盖 V4Router 中的 BaseActionsRouter.msgSender
    function msgSender() public view override returns (address) {
        return _getLocker();
    }

    /// @notice 使用给定的输入参数解码并执行给定的命令
    /// @param commandType 要执行的命令类型
    /// @param inputs 执行该命令所用的输入参数
    /// @dev 出于效率考虑使用 2 个掩码，以便在执行中使用嵌套 if 语句
    /// @return success 命令成功时为 true，失败时为 false
    /// @return output 命令的输出或错误信息（如有）
    function dispatch(bytes1 commandType, bytes calldata inputs) internal returns (bool success, bytes memory output) {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);

        success = true;

        // 0x00 <= command < 0x21
        if (command < Commands.EXECUTE_SUB_PLAN) {
            // 0x00 <= command < 0x10
            if (command < Commands.V4_SWAP) {
                // 0x00 <= command < 0x08
                if (command < Commands.V2_SWAP_EXACT_IN) {
                    if (command == Commands.V3_SWAP_EXACT_IN) {
                        // 等价于：abi.decode(inputs, (address, uint256, uint256, bytes, bool, uint256[]))
                        address recipient;
                        uint256 amountIn;
                        uint256 amountOutMin;
                        bool payerIsUser;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountIn := calldataload(add(inputs.offset, 0x20))
                            amountOutMin := calldataload(add(inputs.offset, 0x40))
                            // 0x60 偏移处为路径，在下方解码
                            payerIsUser := calldataload(add(inputs.offset, 0x80))
                        }
                        bytes calldata path = inputs.toBytes(3);
                        uint256[] calldata minHopPriceX36 = inputs.toUint256Array(5);
                        address payer = payerIsUser ? msgSender() : address(this);
                        v3SwapExactInput(map(recipient), amountIn, amountOutMin, path, payer, minHopPriceX36);
                    } else if (command == Commands.V3_SWAP_EXACT_OUT) {
                        // 等价于：abi.decode(inputs, (address, uint256, uint256, bytes, bool, uint256[]))
                        address recipient;
                        uint256 amountOut;
                        uint256 amountInMax;
                        bool payerIsUser;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountOut := calldataload(add(inputs.offset, 0x20))
                            amountInMax := calldataload(add(inputs.offset, 0x40))
                            // 0x60 偏移处为路径，在下方解码
                            payerIsUser := calldataload(add(inputs.offset, 0x80))
                        }
                        bytes calldata path = inputs.toBytes(3);
                        uint256[] calldata minHopPriceX36 = inputs.toUint256Array(5);
                        address payer = payerIsUser ? msgSender() : address(this);
                        v3SwapExactOutput(map(recipient), amountOut, amountInMax, path, payer, minHopPriceX36);
                    } else if (command == Commands.PERMIT2_TRANSFER_FROM) {
                        // 等价于：abi.decode(inputs, (address, address, uint160))
                        address token;
                        address recipient;
                        uint160 amount;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            amount := calldataload(add(inputs.offset, 0x40))
                        }
                        permit2TransferFrom(token, msgSender(), map(recipient), amount);
                    } else if (command == Commands.PERMIT2_PERMIT_BATCH) {
                        IAllowanceTransfer.PermitBatch calldata permitBatch;
                        assembly {
                            // 这是一个变长结构体，因此 calldataload(inputs.offset) 存放的是
                            // 结构体起始位置相对于 inputs.offset 的偏移量
                            permitBatch := add(inputs.offset, calldataload(inputs.offset))
                        }
                        bytes calldata data = inputs.toBytes(1);
                        (success, output) = address(PERMIT2)
                            .call(
                                abi.encodeWithSignature(
                                    'permit(address,((address,uint160,uint48,uint48)[],address,uint256),bytes)',
                                    msgSender(),
                                    permitBatch,
                                    data
                                )
                            );
                    } else if (command == Commands.SWEEP) {
                        // 等价于：abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint160 amountMin;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            amountMin := calldataload(add(inputs.offset, 0x40))
                        }
                        // adapter 代币在到达时即被解包，因此路由器只会持有底层代币。
                        // 若清扫 adapter 代币，读到的余额将始终为零，底层代币会滞留在路由器中。
                        // ETH 直接短路：Constants.ETH 为 address(0)，它永远不会是 adapter，因此
                        // 对其查询既是浪费，又要依赖 factory 对其返回零。
                        if (token != Constants.ETH && address(PERMISSIONS_ADAPTER_FACTORY) != address(0)) {
                            address underlying = PERMISSIONS_ADAPTER_FACTORY.verifiedPermissionsAdapterOf(token);
                            if (underlying != address(0)) token = underlying;
                        }
                        Payments.sweep(token, map(recipient), amountMin);
                    } else if (command == Commands.TRANSFER) {
                        // 等价于：abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint256 value;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            value := calldataload(add(inputs.offset, 0x40))
                        }
                        Payments.pay(token, map(recipient), value);
                    } else if (command == Commands.PAY_PORTION) {
                        // 等价于：abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint256 bips;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            bips := calldataload(add(inputs.offset, 0x40))
                        }
                        Payments.payPortion(token, map(recipient), bips);
                    } else if (command == Commands.PAY_PORTION_FULL_PRECISION) {
                        // 等价于：abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint256 portion;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            portion := calldataload(add(inputs.offset, 0x40))
                        }
                        Payments.payPortionFullPrecision(token, map(recipient), portion);
                    } else {
                        revert InvalidCommandType(command);
                    }
                } else {
                    // 0x08 <= command < 0x10
                    if (command == Commands.V2_SWAP_EXACT_IN) {
                        // 等价于：abi.decode(inputs, (address, uint256, uint256, address[], bool, uint256[]))
                        address recipient;
                        uint256 amountIn;
                        uint256 amountOutMin;
                        bool payerIsUser;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountIn := calldataload(add(inputs.offset, 0x20))
                            amountOutMin := calldataload(add(inputs.offset, 0x40))
                            // 0x60 偏移处为路径，在下方解码
                            payerIsUser := calldataload(add(inputs.offset, 0x80))
                        }
                        address[] calldata path = inputs.toAddressArray(3);
                        uint256[] calldata minHopPriceX36 = inputs.toUint256Array(5);
                        address payer = payerIsUser ? msgSender() : address(this);
                        v2SwapExactInput(map(recipient), amountIn, amountOutMin, path, payer, minHopPriceX36);
                    } else if (command == Commands.V2_SWAP_EXACT_OUT) {
                        // 等价于：abi.decode(inputs, (address, uint256, uint256, address[], bool, uint256[]))
                        address recipient;
                        uint256 amountOut;
                        uint256 amountInMax;
                        bool payerIsUser;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountOut := calldataload(add(inputs.offset, 0x20))
                            amountInMax := calldataload(add(inputs.offset, 0x40))
                            // 0x60 偏移处为路径，在下方解码
                            payerIsUser := calldataload(add(inputs.offset, 0x80))
                        }
                        address[] calldata path = inputs.toAddressArray(3);
                        uint256[] calldata minHopPriceX36 = inputs.toUint256Array(5);
                        address payer = payerIsUser ? msgSender() : address(this);
                        v2SwapExactOutput(map(recipient), amountOut, amountInMax, path, payer, minHopPriceX36);
                    } else if (command == Commands.PERMIT2_PERMIT) {
                        // 等价于：abi.decode(inputs, (IAllowanceTransfer.PermitSingle, bytes))
                        IAllowanceTransfer.PermitSingle calldata permitSingle;
                        assembly {
                            permitSingle := inputs.offset
                        }
                        bytes calldata data = inputs.toBytes(6); // PermitSingle 占用前 6 个槽位（0..5）
                        (success, output) = address(PERMIT2)
                            .call(
                                abi.encodeWithSignature(
                                    'permit(address,((address,uint160,uint48,uint48),address,uint256),bytes)',
                                    msgSender(),
                                    permitSingle,
                                    data
                                )
                            );
                    } else if (command == Commands.WRAP_ETH) {
                        // 等价于：abi.decode(inputs, (address, uint256))
                        address recipient;
                        uint256 amount;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amount := calldataload(add(inputs.offset, 0x20))
                        }
                        Payments.wrapETH(map(recipient), amount);
                    } else if (command == Commands.UNWRAP_WETH) {
                        // 等价于：abi.decode(inputs, (address, uint256))
                        address recipient;
                        uint256 amountMin;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountMin := calldataload(add(inputs.offset, 0x20))
                        }
                        Payments.unwrapWETH9(map(recipient), amountMin);
                    } else if (command == Commands.PERMIT2_TRANSFER_FROM_BATCH) {
                        IAllowanceTransfer.AllowanceTransferDetails[] calldata batchDetails;
                        (uint256 length, uint256 offset) = inputs.toLengthOffset(0);
                        assembly {
                            batchDetails.length := length
                            batchDetails.offset := offset
                        }
                        permit2TransferFrom(batchDetails, msgSender());
                    } else if (command == Commands.BALANCE_CHECK_ERC20) {
                        // 等价于：abi.decode(inputs, (address, address, uint256))
                        address owner;
                        address token;
                        uint256 minBalance;
                        assembly {
                            owner := calldataload(inputs.offset)
                            token := calldataload(add(inputs.offset, 0x20))
                            minBalance := calldataload(add(inputs.offset, 0x40))
                        }
                        success = (ERC20(token).balanceOf(owner) >= minBalance);
                        if (!success) output = abi.encodePacked(BalanceTooLow.selector);
                    } else {
                        // 命令 0x0f 的预留区域
                        revert InvalidCommandType(command);
                    }
                }
            } else {
                // 0x10 <= command < 0x21
                if (command == Commands.V4_SWAP) {
                    // 将提供的 calldata 传给 V4SwapRouter._executeActions（定义于 BaseActionsRouter）
                    _executeActions(inputs);
                    // 本合约必须获得花费该代币的授权，因为将由它对 position manager 发起调用
                } else if (command == Commands.V3_POSITION_MANAGER_PERMIT) {
                    _checkV3PermitCall(inputs);
                    (success, output) = address(V3_POSITION_MANAGER).call(inputs);
                } else if (command == Commands.V3_POSITION_MANAGER_CALL) {
                    _checkV3PositionManagerCall(inputs, msgSender());
                    (success, output) = address(V3_POSITION_MANAGER).call(inputs);
                } else if (command == Commands.V4_INITIALIZE_POOL) {
                    PoolKey calldata poolKey;
                    uint160 sqrtPriceX96;
                    assembly {
                        poolKey := inputs.offset
                        sqrtPriceX96 := calldataload(add(inputs.offset, 0xa0))
                    }
                    (success, output) =
                        address(poolManager).call(abi.encodeCall(IPoolManager.initialize, (poolKey, sqrtPriceX96)));
                } else if (command == Commands.V4_POSITION_MANAGER_CALL) {
                    // 应仅调用 modifyLiquidities() 进行铸造
                    _checkV4PositionManagerCall(inputs);
                    (success, output) = address(V4_POSITION_MANAGER).call{value: address(this).balance}(inputs);
                } else {
                    // 命令 0x15-0x20 的预留区域
                    revert InvalidCommandType(command);
                }
            }
        } else if (command < Commands.ACROSS_V4_DEPOSIT_V3) {
            // 0x21 <= command
            if (command == Commands.EXECUTE_SUB_PLAN) {
                (bytes calldata _commands, bytes[] calldata _inputs) = inputs.decodeCommandsAndInputs();
                (success, output) = (address(this)).call(abi.encodeCall(Dispatcher.execute, (_commands, _inputs)));
            } else {
                // 命令 0x22-0x3f 的预留区域
                revert InvalidCommandType(command);
            }
        } else {
            if (command == Commands.ACROSS_V4_DEPOSIT_V3) {
                _acrossV4DepositV3(inputs);
            } else {
                // 命令 0x41-0x5f 的预留区域
                revert InvalidCommandType(command);
            }
        }
    }

    /// @notice 计算命令的接收方地址
    /// @param recipient 命令的接收方或接收方标志
    /// @return output 命令最终的接收方
    function map(address recipient) internal view returns (address) {
        if (recipient == ActionConstants.MSG_SENDER) {
            return msgSender();
        } else if (recipient == ActionConstants.ADDRESS_THIS) {
            return address(this);
        } else {
            return recipient;
        }
    }
}
