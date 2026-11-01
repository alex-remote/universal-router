// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {IUniswapV2Pair} from '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

/// @title Uniswap v2 辅助库
/// @notice 计算某个命令的接收方地址
library UniswapV2Library {
    error InvalidReserves();
    error InvalidPath();

    /// @notice 在不进行任何外部调用的情况下计算交易对的 v2 地址
    /// @param factory v2 工厂合约的地址
    /// @param initCodeHash 交易对初始化代码（initcode）的哈希
    /// @param tokenA 交易对中的一个代币
    /// @param tokenB 交易对中的另一个代币
    /// @return pair 计算得到的 v2 交易对地址
    function pairFor(address factory, bytes32 initCodeHash, address tokenA, address tokenB)
        internal
        pure
        returns (address pair)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = pairForPreSorted(factory, initCodeHash, token0, token1);
    }

    /// @notice 计算交易对的 v2 地址以及该交易对的 token0
    /// @param factory v2 工厂合约的地址
    /// @param initCodeHash 交易对初始化代码（initcode）的哈希
    /// @param tokenA 交易对中的一个代币
    /// @param tokenB 交易对中的另一个代币
    /// @return pair 计算得到的 v2 交易对地址
    /// @return token0 在该交易对中被视为 token0 的代币
    function pairAndToken0For(address factory, bytes32 initCodeHash, address tokenA, address tokenB)
        internal
        pure
        returns (address pair, address token0)
    {
        address token1;
        (token0, token1) = sortTokens(tokenA, tokenB);
        pair = pairForPreSorted(factory, initCodeHash, token0, token1);
    }

    /// @notice 在假定输入代币已预先排序的前提下计算交易对的 v2 地址
    /// @param factory v2 工厂合约的地址
    /// @param initCodeHash 交易对初始化代码（initcode）的哈希
    /// @param token0 交易对的 token0
    /// @param token1 交易对的 token1
    /// @return pair 计算得到的 v2 交易对地址
    function pairForPreSorted(address factory, bytes32 initCodeHash, address token0, address token1)
        private
        pure
        returns (address pair)
    {
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex'ff', factory, keccak256(abi.encodePacked(token0, token1)), initCodeHash)
                    )
                )
            )
        );
    }

    /// @notice 计算交易对的 v2 地址，并获取每个代币的储备量
    /// @param factory v2 工厂合约的地址
    /// @param initCodeHash 交易对初始化代码（initcode）的哈希
    /// @param tokenA 交易对中的一个代币
    /// @param tokenB 交易对中的另一个代币
    /// @return pair 计算得到的 v2 交易对地址
    /// @return reserveA tokenA 的储备量
    /// @return reserveB tokenB 的储备量
    function pairAndReservesFor(address factory, bytes32 initCodeHash, address tokenA, address tokenB)
        private
        view
        returns (address pair, uint256 reserveA, uint256 reserveB)
    {
        address token0;
        (pair, token0) = pairAndToken0For(factory, initCodeHash, tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /// @notice 给定一种资产的输入数量，返回另一种资产的最大输出数量
    /// @param amountIn 代币的输入数量
    /// @param reserveIn 输入代币的可用储备量
    /// @param reserveOut 输出代币的可用储备量
    /// @return amountOut 输出代币的输出数量
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /// @notice 返回单跳交易中获得期望输出数量所需的输入数量
    /// @param amountOut 期望的输出数量
    /// @param reserveIn 输入代币的可用储备量
    /// @param reserveOut 输出代币的可用储备量
    /// @return amountIn 输入代币的输入数量
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    /// @notice 返回多跳交易中获得期望输出数量所需的输入数量
    /// @param factory v2 工厂合约的地址
    /// @param initCodeHash 交易对初始化代码（initcode）的哈希
    /// @param amountOut 期望的输出数量
    /// @param path 多跳交易的路径
    /// @return amount 输入代币的输入数量
    /// @return pair 交易中的第一个交易对
    function getAmountInMultihop(address factory, bytes32 initCodeHash, uint256 amountOut, address[] calldata path)
        internal
        view
        returns (uint256 amount, address pair)
    {
        if (path.length < 2) revert InvalidPath();
        amount = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            uint256 reserveIn;
            uint256 reserveOut;

            (pair, reserveIn, reserveOut) = pairAndReservesFor(factory, initCodeHash, path[i - 1], path[i]);
            amount = getAmountIn(amount, reserveIn, reserveOut);
        }
    }

    /// @notice 对两个代币排序，返回 token0 和 token1
    /// @param tokenA 待排序的第一个代币
    /// @param tokenB 待排序的另一个代币
    /// @return token0 按地址值较小的代币
    /// @return token1 按地址值较大的代币
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
