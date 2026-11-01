// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IUniversalRouter} from './IUniversalRouter.sol';

/// @title ISwapProxy
/// @notice SwapProxy 合约的接口，该合约支持无需 Permit2 的两笔交易兑换流程
interface ISwapProxy {
    /// @notice 从 msg.sender 拉取 ERC20 代币到 Universal Router，然后执行命令
    /// @param router 用于执行命令的 Universal Router
    /// @param token 从调用者处拉取的 ERC20 代币
    /// @param amount 转入 UR 的代币数量
    /// @param commands 待执行的已编码 UR 命令
    /// @param inputs 每条命令对应的已编码输入参数
    /// @param deadline 交易截止时间
    function execute(
        IUniversalRouter router,
        address token,
        uint256 amount,
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external;
}
