// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

struct RouterParameters {
    // 支付参数
    address permit2;
    address weth9;
    // Uniswap 兑换参数
    address v2Factory;
    address v3Factory;
    bytes32 pairInitCodeHash;
    bytes32 poolInitCodeHash;
    address v4PoolManager;
    address permissionsAdapterFactory;
    // Uniswap v3->v4 迁移参数
    address v3NFTPositionManager;
    address v4PositionManager;
    // Across 参数
    address spokePool;
}
