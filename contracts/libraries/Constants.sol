// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/// @title 常量状态
/// @notice Universal Router 使用的常量状态
library Constants {
    /// @dev 用于识别 v2 交易对已收到输入代币的情况
    uint256 internal constant ALREADY_PAID = 0;

    /// @dev 用作标志，标识转账的是 ETH 而非代币
    address internal constant ETH = address(0);

    /// @dev 字节编码地址的长度
    uint256 internal constant ADDR_SIZE = 20;

    /// @dev 字节编码手续费的长度
    uint256 internal constant V3_FEE_SIZE = 3;

    /// @dev 单个代币地址（20）与池手续费（3）的偏移量
    uint256 internal constant NEXT_V3_POOL_OFFSET = ADDR_SIZE + V3_FEE_SIZE;

    /// @dev 一个已编码池键（pool key）的偏移量
    /// 代币 (20) + 手续费 (3) + 代币 (20) = 43
    uint256 internal constant V3_POP_OFFSET = NEXT_V3_POOL_OFFSET + ADDR_SIZE;

    /// @dev 包含 2 个或更多池的编码的最小长度
    uint256 internal constant MULTIPLE_V3_POOLS_MIN_LENGTH = V3_POP_OFFSET + NEXT_V3_POOL_OFFSET;

    /// @dev 用于每跳价格计算的精度乘数
    uint256 internal constant PRICE_PRECISION = 1e36;
}
