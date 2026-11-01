// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Locker} from '../libraries/Locker.sol';

/// @title Lock
/// @notice 为外部调用提供重入锁的合约
contract Lock {
    /// @notice 外部调用者尝试重入已加锁的函数时抛出
    error ContractLocked();

    /// @notice 强制执行重入锁的修饰器，允许自重入
    /// @dev 若合约未加锁，则以 msg.sender 作为锁持有者
    modifier isNotLocked() {
        // 对所有外部调用者施加重入锁
        if (msg.sender != address(this)) {
            if (Locker.isLocked()) revert ContractLocked();
            Locker.set(msg.sender);
            _;
            Locker.set(address(0));
        } else {
            // 合约允许重入自身，因此不检查锁
            _;
        }
    }

    /// @notice 返回合约当前的锁持有者
    function _getLocker() internal view returns (address) {
        return Locker.get();
    }
}
