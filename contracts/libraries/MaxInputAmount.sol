// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/// @notice 用于存储精确输出兑换中期望的最大输入代币数量的库；用于检查滑点
library MaxInputAmount {
    // 以瞬态方式保存期望的最大输入代币数量的存储槽。bytes32(uint256(keccak256("MaxAmountIn")) - 1)
    bytes32 constant MAX_AMOUNT_IN_SLOT = 0xaf28d9864a81dfdf71cab65f4e5d79a0cf9b083905fb8971425e6cb581b3f692;

    function set(uint256 maxAmountIn) internal {
        assembly ('memory-safe') {
            tstore(MAX_AMOUNT_IN_SLOT, maxAmountIn)
        }
    }

    function get() internal view returns (uint256 maxAmountIn) {
        assembly ('memory-safe') {
            maxAmountIn := tload(MAX_AMOUNT_IN_SLOT)
        }
    }
}
