// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {PositionManager} from '@uniswap/v4-periphery/src/PositionManager.sol';
import {PoolManager} from '@uniswap/v4-core/src/PoolManager.sol';
import {ERC721} from 'solmate/src/tokens/ERC721.sol';
import {ERC6909} from '@uniswap/v4-core/src/ERC6909.sol';

// 此合约仅用于将 PositionManager 和 PoolManager 引入 hardhat 构建流程
// 以便为其生成 typechain 产物
abstract contract ImportsForTypechain is PositionManager, PoolManager {
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC6909, ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
