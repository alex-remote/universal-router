// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ERC20} from 'solmate/src/tokens/ERC20.sol';
import {SafeTransferLib} from 'solmate/src/utils/SafeTransferLib.sol';
import {IUniversalRouter} from './interfaces/IUniversalRouter.sol';
import {ISwapProxy} from './interfaces/ISwapProxy.sol';

/// @title SwapProxy
/// @notice 支持无需 Permit2 签名消息的两笔交易兑换流程（授权 + 兑换）
/// @dev 将代币从用户直接转账到 Universal Router（UR），然后
///      以 payerIsUser=false 执行 UR 命令，使路由器使用其自身余额。
///      本合约用于辅助以代币为输入的操作；以 ETH 为输入的操作应直接发送到 UR。
///      IMPORTANT: 所有兑换命令必须使用 payerIsUser=false。
///      所有接收方地址必须是用户的明确地址，而不能是 MSG_SENDER，
///      因为在 UR 执行上下文中，MSG_SENDER 会被解析为本代理合约。
contract SwapProxy is ISwapProxy {
    using SafeTransferLib for ERC20;

    /// @inheritdoc ISwapProxy
    function execute(
        IUniversalRouter router,
        address token,
        uint256 amount,
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external {
        // Note: Solmate 的 SafeTransferLib 不会检查代币地址是否包含代码。
        // 对空地址的转账调用会静默成功。
        ERC20(token).safeTransferFrom(msg.sender, address(router), amount);
        router.execute(commands, inputs, deadline);
    }
}
