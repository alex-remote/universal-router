// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

/// @title RouteSigner
/// @notice 使用瞬态存储（transient storage）管理签名执行上下文的合约
abstract contract RouteSigner is EIP712 {
    /// @notice 存放路由签名者地址的瞬态存储槽
    /// @dev bytes32(uint256(keccak256("RouteSigner")) - 1)
    bytes32 private constant ROUTE_SIGNER_SLOT = 0xd317c76a4357223a1868125ee857a1f31cabfcec288f6cdd0ea8c52b6a71ee31;

    /// @notice 存放路由 intent 的瞬态存储槽
    /// @dev bytes32(uint256(keccak256("RouteIntent")) - 1)
    bytes32 private constant ROUTE_INTENT_SLOT = 0xa42de8dec63499ed8713dc6815ea14006a1f8e80e1664c66e3beb461bb65b0da;

    /// @notice 存放路由 data 的瞬态存储槽
    /// @dev bytes32(uint256(keccak256("RouteData")) - 1)
    bytes32 private constant ROUTE_DATA_SLOT = 0x17350132762f24cc4b86e10621ea1e0b5c33483a51cca86a1b11e7ed029b6eb6;

    /// @notice 签名执行所用的 EIP712 typehash
    bytes32 internal constant EXECUTE_SIGNED_TYPEHASH = keccak256(
        'ExecuteSigned(bytes commands,bytes[] inputs,bytes32 intent,bytes32 data,address sender,bytes32 nonce,uint256 deadline)'
    );

    /// @notice 已使用 nonce 的映射，用于防重放
    /// @dev 无序 nonce 允许并行执行多个签名路由
    mapping(address user => mapping(bytes32 nonce => bool used)) public noncesUsed;

    /// @notice 当 nonce 已被使用时抛出
    error NonceAlreadyUsed();

    /// @dev 将签名上下文（signer、intent、data）存入瞬态存储
    function _setSignatureContext(
        bytes calldata commands,
        bytes[] calldata inputs,
        bytes32 intent,
        bytes32 data,
        bool verifySender,
        bytes32 nonce,
        bytes calldata signature,
        uint256 deadline
    ) internal returns (address signer) {
        // 按 EIP712 规则对 inputs 数组求哈希：先对每个元素求哈希，拼接后再整体求哈希
        uint256 inputsLength = inputs.length;
        bytes32[] memory inputHashes = new bytes32[](inputsLength);
        for (uint256 i = 0; i < inputsLength; ++i) {
            inputHashes[i] = keccak256(inputs[i]);
        }
        bytes32 inputsHash = keccak256(abi.encodePacked(inputHashes));

        // 确定用于签名验证的 sender
        address sender = verifySender ? msg.sender : address(0);

        // 构造 EIP712 哈希
        bytes32 structHash = keccak256(
            abi.encode(EXECUTE_SIGNED_TYPEHASH, keccak256(commands), inputsHash, intent, data, sender, nonce, deadline)
        );
        bytes32 digest = _hashTypedDataV4(structHash);

        // 恢复签名者
        signer = ECDSA.recover(digest, signature);

        // 检查 nonce 并将其标记为已使用（若 nonce == bytes32(type(uint256).max) 则跳过）
        if (nonce != bytes32(type(uint256).max)) {
            if (noncesUsed[signer][nonce]) revert NonceAlreadyUsed();
            noncesUsed[signer][nonce] = true;
        }

        // 将 signer、intent 和 data 存入瞬态存储
        assembly ('memory-safe') {
            tstore(ROUTE_SIGNER_SLOT, signer)
            tstore(ROUTE_INTENT_SLOT, intent)
            tstore(ROUTE_DATA_SLOT, data)
        }
    }

    /// @dev 从瞬态存储中清除签名上下文
    function _resetSignatureContext() internal {
        assembly ('memory-safe') {
            tstore(ROUTE_SIGNER_SLOT, 0)
            tstore(ROUTE_INTENT_SLOT, 0)
            tstore(ROUTE_DATA_SLOT, 0)
        }
    }

    /// @dev 从瞬态存储读取签名路由上下文的内部函数
    function _signedRouteContext() internal view returns (address signer, bytes32 intent, bytes32 data) {
        assembly ('memory-safe') {
            signer := tload(ROUTE_SIGNER_SLOT)
            intent := tload(ROUTE_INTENT_SLOT)
            data := tload(ROUTE_DATA_SLOT)
        }
    }
}
