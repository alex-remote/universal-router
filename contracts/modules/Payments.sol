// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Constants} from '../libraries/Constants.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {BipsLibrary} from '@uniswap/v4-periphery/src/libraries/BipsLibrary.sol';
import {PaymentsImmutables} from '../modules/PaymentsImmutables.sol';
import {SafeTransferLib} from 'solmate/src/utils/SafeTransferLib.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';

/// @title 支付合约
/// @notice 执行与 ETH 及代币支付相关的各类操作
abstract contract Payments is PaymentsImmutables {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;
    using BipsLibrary for uint256;

    error InsufficientToken();
    error InsufficientETH();
    error InvalidPortion();

    /// @notice 向接收方支付一定数量的 ETH 或 ERC20
    /// @param token 要支付的代币（可用 Constants.ETH 表示 ETH）
    /// @param recipient 接收付款的地址
    /// @param value 要支付的数量
    function pay(address token, address recipient, uint256 value) internal {
        if (token == Constants.ETH) {
            recipient.safeTransferETH(value);
        } else {
            if (value == ActionConstants.CONTRACT_BALANCE) {
                value = ERC20(token).balanceOf(address(this));
            }

            ERC20(token).safeTransfer(recipient, value);
        }
    }

    /// @notice 将合约持有的 ETH 或 ERC20 按比例支付给接收方
    /// @param token 要支付的代币（可用 Constants.ETH 表示 ETH）
    /// @param recipient 接收付款的地址
    /// @param bips 占合约全部余额的比例，以 bips（基点）计
    function payPortion(address token, address recipient, uint256 bips) internal {
        if (token == Constants.ETH) {
            uint256 balance = address(this).balance;
            uint256 amount = balance.calculatePortion(bips);
            recipient.safeTransferETH(amount);
        } else {
            uint256 balance = ERC20(token).balanceOf(address(this));
            uint256 amount = balance.calculatePortion(bips);
            ERC20(token).safeTransfer(recipient, amount);
        }
    }

    /// @notice 以 1e18 精度将合约持有的 ETH 或 ERC20 按比例支付给接收方
    /// @param token 要支付的代币（可用 Constants.ETH 表示 ETH）
    /// @param recipient 接收付款的地址
    /// @param portion 占合约全部余额的比例，其中 1e18 表示 100%
    function payPortionFullPrecision(address token, address recipient, uint256 portion) internal {
        if (portion > 1e18) revert InvalidPortion();
        if (token == Constants.ETH) {
            uint256 balance = address(this).balance;
            uint256 amount = balance * portion / 1e18;
            recipient.safeTransferETH(amount);
        } else {
            uint256 balance = ERC20(token).balanceOf(address(this));
            uint256 amount = balance * portion / 1e18;
            ERC20(token).safeTransfer(recipient, amount);
        }
    }

    /// @notice 将合约持有的全部 ERC20 或 ETH 清扫到指定地址
    /// @param token 要清扫的代币（可用 Constants.ETH 表示 ETH）
    /// @param recipient 接收付款的地址
    /// @param amountMinimum 期望的最小数量
    function sweep(address token, address recipient, uint256 amountMinimum) internal {
        uint256 balance;
        if (token == Constants.ETH) {
            balance = address(this).balance;
            if (balance < amountMinimum) revert InsufficientETH();
            if (balance > 0) recipient.safeTransferETH(balance);
        } else {
            balance = ERC20(token).balanceOf(address(this));
            if (balance < amountMinimum) revert InsufficientToken();
            if (balance > 0) ERC20(token).safeTransfer(recipient, balance);
        }
    }

    /// @notice 将一定数量的 ETH 包装为 WETH
    /// @param recipient WETH 的接收方
    /// @param amount 要包装的数量（可为 CONTRACT_BALANCE）
    function wrapETH(address recipient, uint256 amount) internal {
        if (amount == ActionConstants.CONTRACT_BALANCE) {
            amount = address(this).balance;
        } else if (amount > address(this).balance) {
            revert InsufficientETH();
        }
        if (amount > 0) {
            WETH9.deposit{value: amount}();
            if (recipient != address(this)) {
                WETH9.transfer(recipient, amount);
            }
        }
    }

    /// @notice 将合约持有的全部 WETH 解包为 ETH
    /// @param recipient ETH 的接收方
    /// @param amountMinimum 期望获得的 ETH 最小数量
    function unwrapWETH9(address recipient, uint256 amountMinimum) internal {
        uint256 value = WETH9.balanceOf(address(this));
        if (value < amountMinimum) {
            revert InsufficientETH();
        }
        if (value > 0) {
            WETH9.withdraw(value);
            if (recipient != address(this)) {
                recipient.safeTransferETH(value);
            }
        }
    }
}
