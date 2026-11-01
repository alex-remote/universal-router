// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/// @notice 在 transient storage（瞬态存储）中实现重入锁的库。
/// @dev 不存储布尔值，而是存储锁持有者的地址，使合约能够知道是谁锁定了合约
/// TODO: 当 Solidity 支持 transient 关键字后，可删除此库。
library Locker {
    // 以瞬态方式保存锁状态的槽位。bytes32(uint256(keccak256("Locker")) - 1)
    bytes32 constant LOCKER_SLOT = 0x0e87e1788ebd9ed6a7e63c70a374cd3283e41cad601d21fbe27863899ed4a708;

    function set(address locker) internal {
        // locker 始终为 msg.sender 或 address(0)，因此无需清理
        assembly ('memory-safe') {
            tstore(LOCKER_SLOT, locker)
        }
    }

    function get() internal view returns (address locker) {
        assembly ('memory-safe') {
            locker := tload(LOCKER_SLOT)
        }
    }

    function isLocked() internal view returns (bool) {
        return Locker.get() != address(0);
    }
}
