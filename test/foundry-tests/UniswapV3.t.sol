// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {V3SwapRouter} from '../../contracts/modules/uniswap/v3/V3SwapRouter.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterParameters} from '../../contracts/types/RouterParameters.sol';
import {ActionConstants} from '@uniswap/v4-periphery/src/libraries/ActionConstants.sol';
import {MockERC20} from './mock/MockERC20.sol';
import {MockV3Pool} from './mock/MockV3Pool.sol';

contract UniswapV3Test is Test {
    // 90% 兑换比率：输入 100 → 输出 90
    uint256 constant RATE = 0.9e18;
    uint256 constant PRECISION = 1e36;
    uint24 constant FEE = 3000;

    address constant V3_FACTORY = address(0xBEEF);
    bytes32 constant POOL_INIT_CODE_HASH = bytes32(uint256(0xDEAD));
    address constant RECIPIENT = address(0x1234);

    UniversalRouter router;
    MockERC20 tokenA; // 地址最小
    MockERC20 tokenB;
    MockERC20 tokenC; // 地址最大

    function setUp() public {
        // 部署代币并按地址排序
        address[3] memory tokens;
        for (uint256 i = 0; i < 3; i++) {
            tokens[i] = address(new MockERC20());
        }
        if (tokens[0] > tokens[1]) (tokens[0], tokens[1]) = (tokens[1], tokens[0]);
        if (tokens[1] > tokens[2]) (tokens[1], tokens[2]) = (tokens[2], tokens[1]);
        if (tokens[0] > tokens[1]) (tokens[0], tokens[1]) = (tokens[1], tokens[0]);
        tokenA = MockERC20(tokens[0]);
        tokenB = MockERC20(tokens[1]);
        tokenC = MockERC20(tokens[2]);

        // 部署路由器
        RouterParameters memory params = RouterParameters({
            permit2: address(0),
            weth9: address(0),
            v2Factory: address(0),
            v3Factory: V3_FACTORY,
            pairInitCodeHash: bytes32(0),
            poolInitCodeHash: POOL_INIT_CODE_HASH,
            v4PoolManager: address(0),
            permissionsAdapterFactory: address(0),
            v3NFTPositionManager: address(0),
            v4PositionManager: address(0),
            spokePool: address(0)
        });
        router = new UniversalRouter(params);

        // 在确定性地址上部署模拟池
        _deployMockPool(address(tokenA), address(tokenB));
        _deployMockPool(address(tokenB), address(tokenC));
    }

    // ──────────────────────────────────────────────
    // 精确输入 - 单跳
    // ──────────────────────────────────────────────

    function testV3ExactInputSingleHopNoSlippage() public {
        deal(address(tokenA), address(router), 100 ether);

        bytes memory path = abi.encodePacked(address(tokenA), FEE, address(tokenB));
        _executeV3ExactIn(RECIPIENT, 100 ether, 0, path, new uint256[](0));

        assertEq(tokenB.balanceOf(RECIPIENT), 90 ether);
    }

    function testV3ExactInputSingleHopSlippagePass() public {
        deal(address(tokenA), address(router), 100 ether);

        bytes memory path = abi.encodePacked(address(tokenA), FEE, address(tokenB));
        uint256[] memory slippage = new uint256[](1);
        slippage[0] = 0.8e36; // 阈值 80%，实际为 90%
        _executeV3ExactIn(RECIPIENT, 100 ether, 0, path, slippage);

        assertEq(tokenB.balanceOf(RECIPIENT), 90 ether);
    }

    function testV3ExactInputSingleHopSlippageFail() public {
        deal(address(tokenA), address(router), 100 ether);

        bytes memory path = abi.encodePacked(address(tokenA), FEE, address(tokenB));
        uint256[] memory slippage = new uint256[](1);
        slippage[0] = 0.95e36; // 阈值 95%，实际为 90%

        vm.expectRevert();
        _executeV3ExactIn(RECIPIENT, 100 ether, 0, path, slippage);
    }

    // ──────────────────────────────────────────────
    // 精确输入 - 多跳
    // ──────────────────────────────────────────────

    function testV3ExactInputMultiHopSlippagePass() public {
        deal(address(tokenA), address(router), 100 ether);

        bytes memory path = abi.encodePacked(address(tokenA), FEE, address(tokenB), FEE, address(tokenC));
        uint256[] memory slippage = new uint256[](2);
        slippage[0] = 0.8e36; // 第 0 跳：A→B
        slippage[1] = 0.8e36; // 第 1 跳：B→C
        _executeV3ExactIn(RECIPIENT, 100 ether, 0, path, slippage);

        assertEq(tokenC.balanceOf(RECIPIENT), 81 ether);
    }

    function testV3ExactInputMultiHopSlippageFailFirstHop() public {
        deal(address(tokenA), address(router), 100 ether);

        bytes memory path = abi.encodePacked(address(tokenA), FEE, address(tokenB), FEE, address(tokenC));
        uint256[] memory slippage = new uint256[](2);
        slippage[0] = 0.95e36; // 第 0 跳限制过严
        slippage[1] = 0.8e36;

        vm.expectRevert();
        _executeV3ExactIn(RECIPIENT, 100 ether, 0, path, slippage);
    }

    function testV3ExactInputMultiHopSlippageFailSecondHop() public {
        deal(address(tokenA), address(router), 100 ether);

        bytes memory path = abi.encodePacked(address(tokenA), FEE, address(tokenB), FEE, address(tokenC));
        uint256[] memory slippage = new uint256[](2);
        slippage[0] = 0.8e36;
        slippage[1] = 0.95e36; // 第 1 跳限制过严

        vm.expectRevert();
        _executeV3ExactIn(RECIPIENT, 100 ether, 0, path, slippage);
    }

    // ──────────────────────────────────────────────
    // 精确输出 - 单跳
    // ──────────────────────────────────────────────

    function testV3ExactOutputSingleHopSlippagePass() public {
        deal(address(tokenA), address(router), 200 ether);

        // 精确输出的路径是反向的：B → A（用于 A→B 的交易）
        bytes memory path = abi.encodePacked(address(tokenB), FEE, address(tokenA));
        uint256[] memory slippage = new uint256[](1);
        slippage[0] = 0.8e36; // 阈值 80%，实际为 90%
        _executeV3ExactOut(RECIPIENT, 90 ether, type(uint256).max, path, slippage);

        assertEq(tokenB.balanceOf(RECIPIENT), 90 ether);
    }

    function testV3ExactOutputSingleHopSlippageFail() public {
        deal(address(tokenA), address(router), 200 ether);

        bytes memory path = abi.encodePacked(address(tokenB), FEE, address(tokenA));
        uint256[] memory slippage = new uint256[](1);
        slippage[0] = 0.95e36; // 阈值 95%，实际为 90%

        vm.expectRevert();
        _executeV3ExactOut(RECIPIENT, 90 ether, type(uint256).max, path, slippage);
    }

    // ──────────────────────────────────────────────
    // 精确输出 - 多跳（用于捕获 bug 的测试）
    // ──────────────────────────────────────────────

    function testV3ExactOutputMultiHopSlippagePass() public {
        deal(address(tokenA), address(router), 200 ether);

        // 交易 A→B→C，精确输出 81 C。路径反向：C-B-A
        bytes memory path = abi.encodePacked(address(tokenC), FEE, address(tokenB), FEE, address(tokenA));
        uint256[] memory slippage = new uint256[](2);
        slippage[0] = 0.8e36; // 第 0 跳：A→B
        slippage[1] = 0.8e36; // 第 1 跳：B→C
        _executeV3ExactOut(RECIPIENT, 81 ether, type(uint256).max, path, slippage);

        assertEq(tokenC.balanceOf(RECIPIENT), 81 ether);
    }

    /// @notice 该测试用于捕获精确输出中第 0 跳滑点检查被跳过的 bug。
    /// 第 0 跳（A→B）在交易顺序上是第一跳，但在精确输出中最后执行。
    /// 存在该 bug 时，minHopPriceX36[0] 从未被检查。
    function testV3ExactOutputMultiHopSlippageFailHop0() public {
        deal(address(tokenA), address(router), 200 ether);

        bytes memory path = abi.encodePacked(address(tokenC), FEE, address(tokenB), FEE, address(tokenA));
        uint256[] memory slippage = new uint256[](2);
        slippage[0] = 0.95e36; // 第 0 跳（A→B）限制过严 - 此检查必须生效
        slippage[1] = 0.8e36; // 第 1 跳（B→C）正常

        vm.expectRevert();
        _executeV3ExactOut(RECIPIENT, 81 ether, type(uint256).max, path, slippage);
    }

    function testV3ExactOutputMultiHopSlippageFailHop1() public {
        deal(address(tokenA), address(router), 200 ether);

        bytes memory path = abi.encodePacked(address(tokenC), FEE, address(tokenB), FEE, address(tokenA));
        uint256[] memory slippage = new uint256[](2);
        slippage[0] = 0.8e36; // 第 0 跳正常
        slippage[1] = 0.95e36; // 第 1 跳（B→C）限制过严

        vm.expectRevert();
        _executeV3ExactOut(RECIPIENT, 81 ether, type(uint256).max, path, slippage);
    }

    // ──────────────────────────────────────────────
    // 每跳滑点数组长度无效
    // ──────────────────────────────────────────────

    function testV3ExactInputInvalidHopSlippageLength() public {
        deal(address(tokenA), address(router), 100 ether);

        bytes memory path = abi.encodePacked(address(tokenA), FEE, address(tokenB));
        uint256[] memory slippage = new uint256[](2); // 错误：只有 1 跳却给了 2 个值

        vm.expectRevert(V3SwapRouter.V3HopPriceAndPathLengthMismatch.selector);
        _executeV3ExactIn(RECIPIENT, 100 ether, 0, path, slippage);
    }

    function testV3ExactOutputInvalidHopSlippageLength() public {
        deal(address(tokenA), address(router), 200 ether);

        bytes memory path = abi.encodePacked(address(tokenB), FEE, address(tokenA));
        uint256[] memory slippage = new uint256[](2); // 错误：只有 1 跳却给了 2 个值

        vm.expectRevert(V3SwapRouter.V3HopPriceAndPathLengthMismatch.selector);
        _executeV3ExactOut(RECIPIENT, 90 ether, type(uint256).max, path, slippage);
    }

    // ──────────────────────────────────────────────
    // 辅助函数
    // ──────────────────────────────────────────────

    function _executeV3ExactIn(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes memory path,
        uint256[] memory minHopPriceX36
    ) internal {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(recipient, amountIn, amountOutMin, path, false, minHopPriceX36);
        router.execute(commands, inputs);
    }

    function _executeV3ExactOut(
        address recipient,
        uint256 amountOut,
        uint256 amountInMax,
        bytes memory path,
        uint256[] memory minHopPriceX36
    ) internal {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(recipient, amountOut, amountInMax, path, false, minHopPriceX36);
        router.execute(commands, inputs);
    }

    function _deployMockPool(address token0, address token1) internal {
        MockV3Pool mock = new MockV3Pool(token0, token1, RATE);
        address expected = _computePoolAddress(token0, token1, FEE);
        vm.etch(expected, address(mock).code);
        // 给池注入代币，供兑换过程中转出
        deal(token0, expected, 10000 ether);
        deal(token1, expected, 10000 ether);
    }

    function _computePoolAddress(address _tokenA, address _tokenB, uint24 fee) internal pure returns (address) {
        if (_tokenA > _tokenB) (_tokenA, _tokenB) = (_tokenB, _tokenA);
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff', V3_FACTORY, keccak256(abi.encode(_tokenA, _tokenB, fee)), POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
