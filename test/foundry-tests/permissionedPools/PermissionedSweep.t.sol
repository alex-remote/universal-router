// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {UniversalRouter} from '../../../contracts/UniversalRouter.sol';
import {Payments} from '../../../contracts/modules/Payments.sol';
import {Commands} from '../../../contracts/libraries/Commands.sol';
import {Constants} from '../../../contracts/libraries/Constants.sol';
import {RouterParameters} from '../../../contracts/types/RouterParameters.sol';
import {MockERC20} from '../mock/MockERC20.sol';

/// @notice 仅将某一个地址解析为固定的底层代币，其他地址一律解析为零地址。
/// @dev 适配器地址从不会被调用，因此无需是合约。这里有意将
///      address(0) 解析为一个非零哨兵值：真实的工厂合约在此处会返回零，但依赖这一点会使
///      ETH 清扫依赖外部合约的行为，因此 Dispatcher 改为对 ETH 直接短路处理。
///      该短路逻辑若出现任何回归，都会在此处表现为 ETH 清扫失败。
contract MockPermissionsAdapterFactory {
    address public immutable adapter;
    address public immutable underlying;
    address public constant ZERO_RESOLVES_TO = address(0xBADE7);

    constructor(address _adapter, address _underlying) {
        adapter = _adapter;
        underlying = _underlying;
    }

    function verifiedPermissionsAdapterOf(address token) external view returns (address) {
        if (token == address(0)) return ZERO_RESOLVES_TO;
        return token == adapter ? underlying : address(0);
    }
}

/// @notice 覆盖 Dispatcher 中 SWEEP 的适配器解析分支，该分支在测试套件的其余部分中
///         无法触达，因为其他所有 fixture 在部署路由器时都未设置工厂合约。
contract PermissionedSweepTest is Test {
    address constant RECIPIENT = address(1234);
    address constant ADAPTER = address(0xADA9741E4);
    uint256 constant AMOUNT = 10 ** 18;

    UniversalRouter router;
    MockERC20 underlying;
    MockERC20 ordinary;

    function setUp() public {
        underlying = new MockERC20();
        ordinary = new MockERC20();
        RouterParameters memory params;
        params.permissionsAdapterFactory = address(new MockPermissionsAdapterFactory(ADAPTER, address(underlying)));
        router = new UniversalRouter(params);
    }

    function _sweep(address token, uint256 amountMin) internal {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.SWEEP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(token, RECIPIENT, amountMin);
        router.execute(commands, inputs);
    }

    /// @dev 清扫适配器时必须交付路由器实际持有的底层代币。若没有这一
    ///      替换，这里会读到 balanceOf(ADAPTER) == 0，并静默地什么也不转账。
    function test_sweep_adapterDeliversUnderlying() public {
        underlying.mint(address(router), AMOUNT);

        _sweep(ADAPTER, AMOUNT);

        assertEq(underlying.balanceOf(RECIPIENT), AMOUNT);
        assertEq(underlying.balanceOf(address(router)), 0);
    }

    /// @dev amountMinimum 针对底层代币的余额进行校验，而非适配器的零余额。
    function test_sweep_adapterRevertsBelowAmountMinimum() public {
        underlying.mint(address(router), AMOUNT);

        vm.expectRevert(Payments.InsufficientToken.selector);
        _sweep(ADAPTER, AMOUNT + 1);
    }

    /// @dev 反例：工厂合约无法解析的代币按其自身被清扫，不做替换。
    function test_sweep_nonAdapterTokenUnaffected() public {
        ordinary.mint(address(router), AMOUNT);

        _sweep(address(ordinary), AMOUNT);

        assertEq(ordinary.balanceOf(RECIPIENT), AMOUNT);
    }

    /// @dev 在工厂合约已设置的情况下，ETH 清扫也必须正常工作。Constants.ETH 为 address(0)，解析逻辑
    ///      会在到达工厂合约之前对其短路。
    function test_sweep_ethWithLiveFactory() public {
        vm.deal(address(router), AMOUNT);

        _sweep(Constants.ETH, AMOUNT);

        assertEq(RECIPIENT.balance, AMOUNT);
        assertEq(address(router).balance, 0);
    }
}
