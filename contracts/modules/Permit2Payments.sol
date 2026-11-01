// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IAllowanceTransfer} from 'permit2/src/interfaces/IAllowanceTransfer.sol';
import {SafeCast160} from 'permit2/src/libraries/SafeCast160.sol';
import {Payments} from './Payments.sol';

/// @title 通过 Permit2 进行支付
/// @notice 与 Permit2 交互以转账代币
abstract contract Permit2Payments is Payments {
    using SafeCast160 for uint256;

    error FromAddressIsNotOwner();

    /// @notice 在 Permit2 上执行 transferFrom
    /// @param token 要转账的代币
    /// @param from 转出地址
    /// @param to 转账的接收方
    /// @param amount 转账数量
    function permit2TransferFrom(address token, address from, address to, uint160 amount) internal {
        PERMIT2.transferFrom(from, to, amount, token);
    }

    /// @notice 在 Permit2 上执行批量 transferFrom
    /// @param batchDetails 描述每一笔待执行转账详情的数组
    /// @param owner 所有转账应归属的所有者地址
    function permit2TransferFrom(IAllowanceTransfer.AllowanceTransferDetails[] calldata batchDetails, address owner)
        internal
    {
        uint256 batchLength = batchDetails.length;
        for (uint256 i = 0; i < batchLength; ++i) {
            if (batchDetails[i].from != owner) revert FromAddressIsNotOwner();
        }
        PERMIT2.transferFrom(batchDetails);
    }

    /// @notice 根据付款方地址，执行常规支付或在 Permit2 上执行 transferFrom
    /// @param token 要转账的代币
    /// @param payer 为该转账付款的地址
    /// @param recipient 转账的接收方
    /// @param amount 转账数量
    function payOrPermit2Transfer(address token, address payer, address recipient, uint256 amount) internal {
        if (payer == address(this)) pay(token, recipient, amount);
        else permit2TransferFrom(token, payer, recipient, amount.toUint160());
    }
}
