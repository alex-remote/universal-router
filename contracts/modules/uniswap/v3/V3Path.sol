// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.0;

import {BytesLib} from './BytesLib.sol';
import {Constants} from '../../../libraries/Constants.sol';

/// @title 用于处理多跳兑换路径数据的函数
library V3Path {
    using BytesLib for bytes;

    /// @notice 当且仅当路径包含两个或以上池时返回 true
    /// @param path 编码后的兑换路径
    /// @return 若路径包含两个或以上池则为 true，否则为 false
    function hasMultiplePools(bytes calldata path) internal pure returns (bool) {
        return path.length >= Constants.MULTIPLE_V3_POOLS_MIN_LENGTH;
    }

    /// @notice 解码路径中的第一个池
    /// @param path 以字节编码的兑换路径
    /// @return tokenA 给定池的第一个代币
    /// @return fee 该池的手续费等级
    /// @return tokenB 给定池的第二个代币
    function decodeFirstPool(bytes calldata path) internal pure returns (address, uint24, address) {
        return path.toPool();
    }

    /// @notice 获取路径中第一个池对应的片段
    /// @param path 以字节编码的兑换路径
    /// @return 包含定位路径中第一个池所需全部数据的片段
    function getFirstPool(bytes calldata path) internal pure returns (bytes calldata) {
        return path[:Constants.V3_POP_OFFSET];
    }

    function decodeFirstToken(bytes calldata path) internal pure returns (address tokenA) {
        tokenA = path.toAddress();
    }

    /// @notice 跳过一个“代币 + 手续费”元素
    /// @param path 兑换路径
    function skipToken(bytes calldata path) internal pure returns (bytes calldata) {
        return path[Constants.NEXT_V3_POOL_OFFSET:];
    }
}
