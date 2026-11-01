// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {Payments} from './Payments.sol';
import {IV3SpokePool} from '../interfaces/external/IV3SpokePool.sol';
import {AcrossV4DepositV3Params} from '../interfaces/IUniversalRouter.sol';
import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';

abstract contract ChainedActions is Payments {
    using SafeERC20 for IERC20;

    IV3SpokePool public immutable SPOKE_POOL;

    constructor(address spokePool) {
        SPOKE_POOL = IV3SpokePool(spokePool);
    }

    function _acrossV4DepositV3(bytes calldata input) internal {
        AcrossV4DepositV3Params memory params = abi.decode(input, (AcrossV4DepositV3Params));

        uint256 inputAmount = params.inputAmount;
        uint256 callValue = 0;

        // 解析 inputAmount 的哨兵值
        if (inputAmount == ActionConstants.CONTRACT_BALANCE) {
            if (params.useNative) {
                inputAmount = address(this).balance;
            } else {
                inputAmount = IERC20(params.inputToken).balanceOf(address(this));
            }
        }

        if (params.useNative) {
            // 按 Across 文档要求，ETH 路径须以 WETH 作为 inputToken。
            // 路由器当前必须持有与 inputAmount 等量的 ETH。
            callValue = inputAmount;
        } else {
            // 授权 SpokePool 从路由器拉取 ERC20
            IERC20(params.inputToken).forceApprove(address(SPOKE_POOL), inputAmount);
        }

        SPOKE_POOL.depositV3{value: callValue}(
            params.depositor,
            params.recipient,
            params.inputToken,
            params.outputToken,
            inputAmount,
            params.outputAmount,
            params.destinationChainId,
            params.exclusiveRelayer,
            params.quoteTimestamp,
            params.fillDeadline,
            params.exclusivityDeadline,
            params.message
        );
    }
}
