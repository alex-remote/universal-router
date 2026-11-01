// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

struct UniswapParameters {
    address v2Factory;
    address v3Factory;
    bytes32 pairInitCodeHash;
    bytes32 poolInitCodeHash;
}

contract UniswapImmutables {
    /// @notice UniswapV2Factory 的地址
    address internal immutable UNISWAP_V2_FACTORY;

    /// @notice UniswapV2Pair 的初始化代码哈希（initcodehash）
    bytes32 internal immutable UNISWAP_V2_PAIR_INIT_CODE_HASH;

    /// @notice UniswapV3Factory 的地址
    address internal immutable UNISWAP_V3_FACTORY;

    /// @notice UniswapV3Pool 的初始化代码哈希（initcodehash）
    bytes32 internal immutable UNISWAP_V3_POOL_INIT_CODE_HASH;

    constructor(UniswapParameters memory params) {
        UNISWAP_V2_FACTORY = params.v2Factory;
        UNISWAP_V2_PAIR_INIT_CODE_HASH = params.pairInitCodeHash;
        UNISWAP_V3_FACTORY = params.v3Factory;
        UNISWAP_V3_POOL_INIT_CODE_HASH = params.poolInitCodeHash;
    }
}
