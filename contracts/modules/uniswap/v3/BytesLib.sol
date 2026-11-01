// SPDX-License-Identifier: GPL-3.0-or-later

/// @title 字节操作库
pragma solidity ^0.8.0;

import {Constants} from '../../../libraries/Constants.sol';
import {CalldataDecoder} from '@uniswap/v4-periphery/src/libraries/CalldataDecoder.sol';

library BytesLib {
    using CalldataDecoder for bytes;

    error SliceOutOfBounds();

    /// @notice 返回从第 0 字节开始的地址
    /// @dev 调用前必须先完成长度与溢出检查
    /// @param _bytes 待切片的输入字节串
    /// @return _address 从第 0 字节开始的地址
    function toAddress(bytes calldata _bytes) internal pure returns (address _address) {
        if (_bytes.length < Constants.ADDR_SIZE) revert SliceOutOfBounds();
        assembly {
            _address := shr(96, calldataload(_bytes.offset))
        }
    }

    /// @notice 返回从第 0 字节开始的池信息
    /// @dev 调用前必须先完成长度与溢出检查
    /// @param _bytes 待切片的输入字节串
    /// @return token0 位于第 0 字节的地址
    /// @return fee 从第 20 字节开始的 uint24
    /// @return token1 位于第 23 字节的地址
    function toPool(bytes calldata _bytes) internal pure returns (address token0, uint24 fee, address token1) {
        if (_bytes.length < Constants.V3_POP_OFFSET) revert SliceOutOfBounds();
        assembly {
            let firstWord := calldataload(_bytes.offset)
            token0 := shr(96, firstWord)
            fee := and(shr(72, firstWord), 0xffffff)
            token1 := shr(96, calldataload(add(_bytes.offset, 23)))
        }
    }

    /// @notice 将 `_bytes` 中第 `_arg` 个元素解码为动态数组
    /// @dev `length` 与 `offset` 的解码方式是通用的，
    /// 而 `res` 的类型声明则告诉编译器如何读取它。
    /// @param _bytes 待切片的输入字节串
    /// @param _arg 要提取的参数的索引
    /// @return length 数组的长度
    /// @return offset 指向数组数据部分的指针
    function toLengthOffset(bytes calldata _bytes, uint256 _arg)
        internal
        pure
        returns (uint256 length, uint256 offset)
    {
        assembly {
            // 第 `_arg` 个元素的偏移量为 `32 * arg`，该位置存储的是长度指针的偏移量。
            // shl(5, x) 等价于 mul(32, x)
            let lengthPtr := add(_bytes.offset, calldataload(add(_bytes.offset, shl(5, _arg))))
            length := calldataload(lengthPtr)
            offset := add(lengthPtr, 0x20)
            let relativeOffset := sub(offset, _bytes.offset)
            if lt(_bytes.length, add(shl(5, length), relativeOffset)) {
                mstore(0, 0x3b99b53d) // SliceOutOfBounds()
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice 将 `_bytes` 中第 `_arg` 个元素解码为 `address[]`
    /// @param _bytes 要从中提取地址数组的输入字节串
    /// @param _arg 要提取的参数的索引
    function toAddressArray(bytes calldata _bytes, uint256 _arg) internal pure returns (address[] calldata res) {
        (uint256 length, uint256 offset) = toLengthOffset(_bytes, _arg);
        assembly {
            res.length := length
            res.offset := offset
        }
    }

    /// @notice 将 `_bytes` 中第 `_arg` 个元素解码为 `uint256[]`
    /// @param _bytes 要从中提取 uint256 数组的输入字节串
    /// @param _arg 要提取的参数的索引
    function toUint256Array(bytes calldata _bytes, uint256 _arg) internal pure returns (uint256[] calldata res) {
        (uint256 length, uint256 offset) = toLengthOffset(_bytes, _arg);
        assembly {
            res.length := length
            res.offset := offset
        }
    }

    /// @notice 等价于 abi.decode(bytes, bytes[])
    /// @param _bytes 要从中提取参数的输入字节串
    function decodeCommandsAndInputs(bytes calldata _bytes) internal pure returns (bytes calldata, bytes[] calldata) {
        return _bytes.decodeActionsRouterParams();
    }
}
