// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/// @title 始终回滚（revert）的哑合约
/// @notice 用作占位，确保在给定链上尝试调用不受支持的协议时回滚
contract UnsupportedProtocol {
    error UnsupportedProtocolError();

    fallback() external {
        revert UnsupportedProtocolError();
    }
}
