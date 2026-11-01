// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {MigratorImmutables} from '../modules/MigratorImmutables.sol';
import {INonfungiblePositionManager} from '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import {Actions} from '@uniswap/v4-periphery/src/libraries/Actions.sol';
import {IERC721Permit} from '@uniswap/v3-periphery/contracts/interfaces/IERC721Permit.sol';
import {CalldataDecoder} from '@uniswap/v4-periphery/src/libraries/CalldataDecoder.sol';

/// @title V3 到 V4 迁移器
/// @notice 将流动性从 Uniswap V3 迁移到 V4 的合约
abstract contract V3ToV4Migrator is MigratorImmutables {
    using CalldataDecoder for bytes;

    error InvalidAction(bytes4 action);
    error OnlyMintAllowed();
    error NotAuthorizedForToken(uint256 tokenId);

    /// @dev 校验某个操作是否为 decreaseLiquidity、collect 或 burn
    function _isValidAction(bytes4 selector) private pure returns (bool) {
        return selector == INonfungiblePositionManager.decreaseLiquidity.selector
            || selector == INonfungiblePositionManager.collect.selector
            || selector == INonfungiblePositionManager.burn.selector;
    }

    /// @dev 若调用者是该代币的所有者、被授权方（spender）或操作员（operator），则其对该代币有权限
    function _isAuthorizedForToken(address caller, uint256 tokenId) private view returns (bool) {
        address owner = V3_POSITION_MANAGER.ownerOf(tokenId);
        return caller == owner || V3_POSITION_MANAGER.getApproved(tokenId) == caller
            || V3_POSITION_MANAGER.isApprovedForAll(owner, caller);
    }

    /// @dev 检查调用是否指向 ERC721 的 permit 函数
    function _checkV3PermitCall(bytes calldata inputs) internal pure {
        bytes4 selector;
        assembly {
            selector := calldataload(inputs.offset)
        }

        if (selector != IERC721Permit.permit.selector) {
            revert InvalidAction(selector);
        }
    }

    /// @dev 检查对 v3 position manager 的调用是否为安全调用
    function _checkV3PositionManagerCall(bytes calldata inputs, address caller) internal view {
        bytes4 selector;
        assembly {
            selector := calldataload(inputs.offset)
        }

        if (!_isValidAction(selector)) {
            revert InvalidAction(selector);
        }

        uint256 tokenId;
        assembly {
            // 在各有效操作中，tokenId 始终是第一个参数
            tokenId := calldataload(add(inputs.offset, 0x04))
        }
        // 若所有者以外的其他地址想调用此函数，除本合约需获得授权外，该地址自身也需要获得授权
        // 可通过以下 2 种方式实现：
        //    1. 本合约获得该特定代币的许可，且调用者获得所有者全部（ALL）代币的授权
        //    2. 本合约获得所有者全部（ALL）代币的许可，且调用者获得该特定代币的许可
        if (!_isAuthorizedForToken(caller, tokenId)) {
            revert NotAuthorizedForToken(tokenId);
        }
    }

    /// @dev 检查对 v4 position manager 的调用是否为安全调用
    /// 在会改变头寸的 Actions 中，我们只允许 Actions.MINT
    /// 这是因为，如果用户可能被诱骗将其头寸授权给 UniversalRouter，
    /// 攻击者就可能拿走其手续费，或掏空其整个头寸
    function _checkV4PositionManagerCall(bytes calldata inputs) internal view {
        bytes4 selector;
        assembly {
            selector := calldataload(inputs.offset)
        }
        if (selector != V4_POSITION_MANAGER.modifyLiquidities.selector) {
            revert InvalidAction(selector);
        }

        // slice 为 `abi.encode(bytes unlockData, uint256 deadline)`
        bytes calldata slice = inputs[4:];
        // 第一个 bytes(0) 从 modifyLiquidities 中提取 unlockData 参数
        // unlockData = `abi.encode(bytes actions, bytes[] params)`
        // 第二个 bytes(0) 从 unlockData 中提取 actions 参数
        bytes calldata actions = slice.toBytes(0).toBytes(0);

        uint256 numActions = actions.length;

        for (uint256 actionIndex = 0; actionIndex < numActions; actionIndex++) {
            uint256 action = uint8(actions[actionIndex]);

            if (
                action == Actions.INCREASE_LIQUIDITY || action == Actions.INCREASE_LIQUIDITY_FROM_DELTAS
                    || action == Actions.DECREASE_LIQUIDITY || action == Actions.BURN_POSITION
            ) {
                revert OnlyMintAllowed();
            }
        }
    }
}
