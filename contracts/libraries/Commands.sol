// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/// @title Commands
/// @notice 用于解码命令的命令标志位
library Commands {
    // 用于提取命令中特定位的掩码
    bytes1 internal constant FLAG_ALLOW_REVERT = 0x80;
    bytes1 internal constant COMMAND_TYPE_MASK = 0x7f;

    // 命令类型。目前支持的最大命令为 0x3f。
    // 命令在嵌套的 if 块中执行，以尽量减少 gas 消耗

    // value<=0x07 的命令类型，在第一个嵌套 if 块中执行
    uint256 constant V3_SWAP_EXACT_IN = 0x00;
    uint256 constant V3_SWAP_EXACT_OUT = 0x01;
    uint256 constant PERMIT2_TRANSFER_FROM = 0x02;
    uint256 constant PERMIT2_PERMIT_BATCH = 0x03;
    uint256 constant SWEEP = 0x04;
    uint256 constant TRANSFER = 0x05;
    uint256 constant PAY_PORTION = 0x06;
    uint256 constant PAY_PORTION_FULL_PRECISION = 0x07;

    // 0x08<=value<=0x0f 的命令类型，在第二个嵌套 if 块中执行
    uint256 constant V2_SWAP_EXACT_IN = 0x08;
    uint256 constant V2_SWAP_EXACT_OUT = 0x09;
    uint256 constant PERMIT2_PERMIT = 0x0a;
    uint256 constant WRAP_ETH = 0x0b;
    uint256 constant UNWRAP_WETH = 0x0c;
    uint256 constant PERMIT2_TRANSFER_FROM_BATCH = 0x0d;
    uint256 constant BALANCE_CHECK_ERC20 = 0x0e;
    // COMMAND_PLACEHOLDER = 0x0f;

    // 0x10<=value<=0x20 的命令类型，在第三个嵌套 if 块中执行
    uint256 constant V4_SWAP = 0x10;
    uint256 constant V3_POSITION_MANAGER_PERMIT = 0x11;
    uint256 constant V3_POSITION_MANAGER_CALL = 0x12;
    uint256 constant V4_INITIALIZE_POOL = 0x13;
    uint256 constant V4_POSITION_MANAGER_CALL = 0x14;
    // COMMAND_PLACEHOLDER = 0x15 -> 0x20

    // 0x21<=value<=0x3f 的命令类型
    uint256 constant EXECUTE_SUB_PLAN = 0x21;
    // COMMAND_PLACEHOLDER，用于 0x22 至 0x3f

    // 0x40<=value<=0x5f 的命令类型
    // 预留给第三方集成
    uint256 constant ACROSS_V4_DEPOSIT_V3 = 0x40;
}
