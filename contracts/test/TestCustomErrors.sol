// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

contract TestCustomErrors {
    // 添加于此，以便 hardhat 识别外部合约的该自定义签名选择器
    error InvalidSignature();
    error UnsafeCast();
}
