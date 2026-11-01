// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import 'forge-std/Test.sol';
import {UniversalRouter} from '../../contracts/UniversalRouter.sol';
import {RouteSigner} from '../../contracts/base/RouteSigner.sol';
import {IUniversalRouter} from '../../contracts/interfaces/IUniversalRouter.sol';
import {Lock} from '../../contracts/base/Lock.sol';
import {Constants} from '../../contracts/libraries/Constants.sol';
import {Commands} from '../../contracts/libraries/Commands.sol';
import {RouterParameters} from '../../contracts/types/RouterParameters.sol';

contract ContextCapture {
    UniversalRouter public router;
    address public capturedSigner;
    bytes32 public capturedIntent;
    bytes32 public capturedData;

    constructor(UniversalRouter _router) {
        router = _router;
    }

    // 此函数会在执行过程中被调用，并尝试读取签名上下文
    function captureContext() external payable {
        (capturedSigner, capturedIntent, capturedData) = router.signedRouteContext();
    }

    receive() external payable {
        // 接收 ETH 时捕获上下文
        (capturedSigner, capturedIntent, capturedData) = router.signedRouteContext();
    }
}

contract ReentrantMaliciousContract {
    UniversalRouter public router;

    constructor(UniversalRouter _router) {
        router = _router;
    }

    receive() external payable {
        // 尝试用任意参数重入 executeSigned
        // 由于 isNotLocked 修饰器，这里应回滚（revert）
        bytes memory commands = abi.encodePacked(bytes1(0x00));
        bytes[] memory inputs = new bytes[](0);

        router.executeSigned{value: 0}(
            commands, inputs, bytes32(0), bytes32(0), false, bytes32(0), hex'', block.timestamp + 1000
        );
    }
}

contract RouteSignerTest is Test {
    uint256 constant AMOUNT = 10 ** 18;

    UniversalRouter router;
    ContextCapture capturer;

    // 用于 EIP712 签名的签名者
    address signer;
    uint256 signerPrivateKey;

    function setUp() public {
        RouterParameters memory params = RouterParameters({
            permit2: address(0),
            weth9: address(0),
            v2Factory: address(0),
            v3Factory: address(0),
            pairInitCodeHash: bytes32(0),
            poolInitCodeHash: bytes32(0),
            v4PoolManager: address(0),
            permissionsAdapterFactory: address(0),
            v3NFTPositionManager: address(0),
            v4PositionManager: address(0),
            spokePool: address(0)
        });
        router = new UniversalRouter(params);
        capturer = new ContextCapture(router);

        (signer, signerPrivateKey) = makeAddrAndKey('signer');
    }

    function getDomainSeparator() internal view returns (bytes32) {
        return getDomainSeparatorFor(router);
    }

    function getDomainSeparatorFor(UniversalRouter _router) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes('UniversalRouter')),
                keccak256(bytes('2')),
                block.chainid,
                address(_router)
            )
        );
    }

    function signExecution(
        bytes memory commands,
        bytes[] memory inputs,
        bytes32 intent,
        bytes32 data,
        address sender,
        bytes32 nonce,
        uint256 deadline
    ) internal view returns (bytes memory signature) {
        bytes32 EXECUTE_SIGNED_TYPEHASH = keccak256(
            'ExecuteSigned(bytes commands,bytes[] inputs,bytes32 intent,bytes32 data,address sender,bytes32 nonce,uint256 deadline)'
        );

        // 按 EIP712 规则对 inputs 数组做哈希
        bytes32[] memory inputHashes = new bytes32[](inputs.length);
        for (uint256 i = 0; i < inputs.length; i++) {
            inputHashes[i] = keccak256(inputs[i]);
        }
        bytes32 inputsHash = keccak256(abi.encodePacked(inputHashes));

        // 构造结构体哈希
        bytes32 structHash = keccak256(
            abi.encode(EXECUTE_SIGNED_TYPEHASH, keccak256(commands), inputsHash, intent, data, sender, nonce, deadline)
        );

        // 获取域分隔符（domain separator）
        bytes32 domainSeparator = getDomainSeparator();

        // 构造摘要（digest）
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));

        // 签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function testExecuteSigned() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('nonce1');
        uint256 deadline = block.timestamp + 1000;

        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, true, nonce, signature, deadline);

        // 验证执行过程中正确捕获了上下文
        address expectedSigner = signer;
        assertEq(capturer.capturedSigner(), expectedSigner, 'Signer mismatch during execution');
        assertEq(capturer.capturedIntent(), intent, 'Intent mismatch during execution');
        assertEq(capturer.capturedData(), data, 'Data mismatch during execution');

        // 验证 nonce 已被标记为已使用
        assertTrue(router.noncesUsed(expectedSigner, nonce), 'Nonce should be marked as used');

        // 验证执行结束后上下文已被清除
        (address storedSigner, bytes32 storedIntent, bytes32 storedData) = router.signedRouteContext();
        assertEq(storedSigner, address(0), 'Signer should be cleared after execution');
        assertEq(storedIntent, bytes32(0), 'Intent should be cleared after execution');
        assertEq(storedData, bytes32(0), 'Data should be cleared after execution');
    }

    function testExecuteSignedWrongSender() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('nonce2');
        uint256 deadline = block.timestamp + 1000;

        // 以 address(this) 作为 sender 进行签名
        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 尝试从另一个地址调用
        address alice = makeAddr('alice');
        vm.deal(alice, AMOUNT);
        vm.prank(alice);

        // 不会回滚（revert），但会恢复出错误的签名者
        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, true, nonce, signature, deadline);

        // 验证恢复出的签名者不是预期的签名者
        address expectedSigner = signer;
        assertTrue(capturer.capturedSigner() != expectedSigner, 'Signer should not match when called from wrong sender');

        // 但 intent 和 data 仍应被正确存储
        assertEq(capturer.capturedIntent(), intent, 'Intent should match');
        assertEq(capturer.capturedData(), data, 'Data should match');
    }

    function testExecuteSignedNoSenderVerification() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('nonce3');
        uint256 deadline = block.timestamp + 1000;

        // 以 address(0) 作为 sender 进行签名（不校验 sender）
        bytes memory signature = signExecution(commands, inputs, intent, data, address(0), nonce, deadline);

        // 从另一个地址调用
        address bob = makeAddr('bob');
        vm.deal(bob, AMOUNT);
        vm.prank(bob);

        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, false, nonce, signature, deadline);

        // 验证执行过程中正确捕获了上下文
        address expectedSigner = signer;
        assertEq(capturer.capturedSigner(), expectedSigner, 'Signer mismatch during execution');
        assertEq(capturer.capturedIntent(), intent, 'Intent mismatch during execution');
        assertEq(capturer.capturedData(), data, 'Data mismatch during execution');
    }

    function testExecuteSignedMultipleCommands() public {
        // 创建 3 条转账命令
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.TRANSFER)), bytes1(uint8(Commands.TRANSFER)), bytes1(uint8(Commands.TRANSFER))
        );

        address recipient1 = makeAddr('recipient1');
        address recipient2 = makeAddr('recipient2');

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(Constants.ETH, recipient1, AMOUNT / 3);
        inputs[1] = abi.encode(Constants.ETH, address(capturer), AMOUNT / 3); // 这会触发 receive() 并捕获上下文
        inputs[2] = abi.encode(Constants.ETH, recipient2, AMOUNT / 3);

        bytes32 intent = keccak256('multi-command-intent');
        bytes32 data = keccak256('multi-command-data');
        bytes32 nonce = keccak256('nonce4');
        uint256 deadline = block.timestamp + 1000;

        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, true, nonce, signature, deadline);

        // 验证执行过程中正确捕获了上下文（来自第二条命令）
        address expectedSigner = signer;
        assertEq(capturer.capturedSigner(), expectedSigner, 'Signer mismatch during multi-command execution');
        assertEq(capturer.capturedIntent(), intent, 'Intent mismatch during multi-command execution');
        assertEq(capturer.capturedData(), data, 'Data mismatch during multi-command execution');

        // 验证所有转账均已发生
        assertEq(recipient1.balance, AMOUNT / 3, 'Recipient1 should have received ETH');
        assertEq(recipient2.balance, AMOUNT / 3, 'Recipient2 should have received ETH');

        // 验证执行结束后上下文已被清除
        (address storedSigner, bytes32 storedIntent, bytes32 storedData) = router.signedRouteContext();
        assertEq(storedSigner, address(0), 'Signer should be cleared after execution');
        assertEq(storedIntent, bytes32(0), 'Intent should be cleared after execution');
        assertEq(storedData, bytes32(0), 'Data should be cleared after execution');
    }

    function testNonceReplayProtection() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('replay-nonce');
        uint256 deadline = block.timestamp + 1000;

        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 第一次执行应成功
        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, true, nonce, signature, deadline);

        // 使用相同 nonce 的第二次执行应回滚（revert）
        vm.expectRevert(RouteSigner.NonceAlreadyUsed.selector);
        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, true, nonce, signature, deadline);
    }

    function testOptionalNonce() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 optionalNonce = bytes32(type(uint256).max); // 用于跳过 nonce 检查的哨兵值
        uint256 deadline = block.timestamp + 1000;

        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), optionalNonce, deadline);

        address expectedSigner = signer;

        // 第一次执行应成功
        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, true, optionalNonce, signature, deadline);

        // 验证 nonce 未被标记为已使用
        assertFalse(router.noncesUsed(expectedSigner, optionalNonce), 'Optional nonce should not be marked as used');

        // 使用相同签名的第二次执行也应成功（无重放保护）
        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, true, optionalNonce, signature, deadline);
    }

    function testExpiredDeadline() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('deadline-nonce');
        uint256 deadline = block.timestamp - 1; // 截止时间已过

        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 应以 TransactionDeadlinePassed 回滚（revert）
        vm.expectRevert(IUniversalRouter.TransactionDeadlinePassed.selector);
        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, true, nonce, signature, deadline);
    }

    function testInvalidSignature() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('invalid-sig-nonce');
        uint256 deadline = block.timestamp + 1000;

        // 构造一个完全无效的签名
        bytes memory invalidSignature = abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(2)), uint8(27));

        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, false, nonce, invalidSignature, deadline);

        // 验证恢复出的签名者不是预期的签名者
        address expectedSigner = signer;
        assertTrue(capturer.capturedSigner() != expectedSigner, 'Invalid signature should recover different signer');
    }

    function testTamperedCommands() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('tampered-commands-nonce');
        uint256 deadline = block.timestamp + 1000;

        // 使用原始 commands 签名
        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 篡改 commands：使用带允许回滚（allow revert）标志的 TRANSFER
        bytes memory tamperedCommands =
            abi.encodePacked(bytes1(uint8(Commands.TRANSFER) | uint8(Commands.FLAG_ALLOW_REVERT)));

        router.executeSigned{value: AMOUNT}(tamperedCommands, inputs, intent, data, false, nonce, signature, deadline);

        // 验证恢复出的签名者不是预期的签名者
        address expectedSigner = signer;
        assertTrue(capturer.capturedSigner() != expectedSigner, 'Tampered commands should recover different signer');
    }

    function testTamperedInputs() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('tampered-inputs-nonce');
        uint256 deadline = block.timestamp + 1000;

        // 使用原始 inputs 签名
        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 篡改 inputs：更改接收方
        address differentRecipient = makeAddr('differentRecipient');
        bytes[] memory tamperedInputs = new bytes[](1);
        tamperedInputs[0] = abi.encode(Constants.ETH, differentRecipient, AMOUNT);

        router.executeSigned{value: AMOUNT}(commands, tamperedInputs, intent, data, false, nonce, signature, deadline);

        // 验证恢复出的签名者不是预期的签名者
        address expectedSigner = signer;
        assertTrue(capturer.capturedSigner() != expectedSigner, 'Tampered inputs should recover different signer');
    }

    function testTamperedIntent() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('tampered-intent-nonce');
        uint256 deadline = block.timestamp + 1000;

        // 使用原始 intent 签名
        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 篡改 intent
        bytes32 tamperedIntent = keccak256('different-intent');

        router.executeSigned{value: AMOUNT}(commands, inputs, tamperedIntent, data, false, nonce, signature, deadline);

        // 验证恢复出的签名者不是预期的签名者
        address expectedSigner = signer;
        assertTrue(capturer.capturedSigner() != expectedSigner, 'Tampered intent should recover different signer');
    }

    function testTamperedData() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('tampered-data-nonce');
        uint256 deadline = block.timestamp + 1000;

        // 使用原始 data 签名
        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 篡改 data
        bytes32 tamperedData = keccak256('different-data');

        router.executeSigned{value: AMOUNT}(commands, inputs, intent, tamperedData, false, nonce, signature, deadline);

        // 验证恢复出的签名者不是预期的签名者
        address expectedSigner = signer;
        assertTrue(capturer.capturedSigner() != expectedSigner, 'Tampered data should recover different signer');
    }

    function testTamperedNonce() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('original-nonce');
        uint256 deadline = block.timestamp + 1000;

        // 使用原始 nonce 签名
        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 篡改 nonce
        bytes32 tamperedNonce = keccak256('tampered-nonce');

        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, false, tamperedNonce, signature, deadline);

        // 验证恢复出的签名者不是预期的签名者
        address expectedSigner = signer;
        assertTrue(capturer.capturedSigner() != expectedSigner, 'Tampered nonce should recover different signer');
    }

    function testWrongDeadlineMismatch() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('deadline-mismatch-nonce');
        uint256 deadline = block.timestamp + 1000;

        // 使用某个截止时间签名
        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 使用不同的截止时间调用
        uint256 differentDeadline = block.timestamp + 2000;

        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, false, nonce, signature, differentDeadline);

        // 验证恢复出的签名者不是预期的签名者
        address expectedSigner = signer;
        assertTrue(capturer.capturedSigner() != expectedSigner, 'Wrong deadline should recover different signer');
    }

    function testRegularExecuteHasNoContext() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT);

        // 使用常规的 execute()（而非 executeSigned）执行
        router.execute{value: AMOUNT}(commands, inputs, block.timestamp + 1000);

        // 验证执行过程中未捕获到任何上下文
        assertEq(capturer.capturedSigner(), address(0), 'Signer should be zero during regular execute');
        assertEq(capturer.capturedIntent(), bytes32(0), 'Intent should be zero during regular execute');
        assertEq(capturer.capturedData(), bytes32(0), 'Data should be zero during regular execute');

        // 验证执行结束后上下文仍为零
        (address storedSigner, bytes32 storedIntent, bytes32 storedData) = router.signedRouteContext();
        assertEq(storedSigner, address(0), 'Signer should be zero after regular execute');
        assertEq(storedIntent, bytes32(0), 'Intent should be zero after regular execute');
        assertEq(storedData, bytes32(0), 'Data should be zero after regular execute');
    }

    function testNestedExecuteSubPlanPreservesContext() public {
        // 创建一个向 capturer 合约转账的子计划（该合约会捕获上下文）
        bytes memory subCommands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory subInputs = new bytes[](1);
        subInputs[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT / 2);

        // 创建包含 EXECUTE_SUB_PLAN 的主命令
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.EXECUTE_SUB_PLAN)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(subCommands, subInputs);

        bytes32 intent = keccak256('nested-intent');
        bytes32 data = keccak256('nested-data');
        bytes32 nonce = keccak256('nested-nonce');
        uint256 deadline = block.timestamp + 1000;

        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, true, nonce, signature, deadline);

        // 验证嵌套执行过程中上下文得以保留
        address expectedSigner = signer;
        assertEq(capturer.capturedSigner(), expectedSigner, 'Signer should be preserved in nested execution');
        assertEq(capturer.capturedIntent(), intent, 'Intent should be preserved in nested execution');
        assertEq(capturer.capturedData(), data, 'Data should be preserved in nested execution');

        // 验证执行结束后上下文已被清除
        (address storedSigner, bytes32 storedIntent, bytes32 storedData) = router.signedRouteContext();
        assertEq(storedSigner, address(0), 'Signer should be cleared after execution');
        assertEq(storedIntent, bytes32(0), 'Intent should be cleared after execution');
        assertEq(storedData, bytes32(0), 'Data should be cleared after execution');
    }

    function testContextNotLeakedBetweenTransactions() public {
        // 第一笔交易：签名执行
        bytes memory commands1 = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs1 = new bytes[](1);
        inputs1[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT / 2);

        bytes32 intent1 = keccak256('intent1');
        bytes32 data1 = keccak256('data1');
        bytes32 nonce1 = keccak256('nonce-tx1');
        uint256 deadline1 = block.timestamp + 1000;

        bytes memory signature1 = signExecution(commands1, inputs1, intent1, data1, address(this), nonce1, deadline1);

        router.executeSigned{value: AMOUNT / 2}(commands1, inputs1, intent1, data1, true, nonce1, signature1, deadline1);

        // 验证第一笔交易的上下文
        address expectedSigner = signer;
        assertEq(capturer.capturedSigner(), expectedSigner, 'First transaction should capture signer');
        assertEq(capturer.capturedIntent(), intent1, 'First transaction should capture intent1');
        assertEq(capturer.capturedData(), data1, 'First transaction should capture data1');

        // 验证第一笔交易结束后上下文已被清除
        (address storedSigner, bytes32 storedIntent, bytes32 storedData) = router.signedRouteContext();
        assertEq(storedSigner, address(0), 'Context should be cleared between transactions');
        assertEq(storedIntent, bytes32(0), 'Intent should be cleared between transactions');
        assertEq(storedData, bytes32(0), 'Data should be cleared between transactions');

        // 第二笔交易：另一次签名执行
        bytes memory commands2 = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs2 = new bytes[](1);
        inputs2[0] = abi.encode(Constants.ETH, address(capturer), AMOUNT / 2);

        bytes32 intent2 = keccak256('intent2');
        bytes32 data2 = keccak256('data2');
        bytes32 nonce2 = keccak256('nonce-tx2');
        uint256 deadline2 = block.timestamp + 1000;

        bytes memory signature2 = signExecution(commands2, inputs2, intent2, data2, address(this), nonce2, deadline2);

        router.executeSigned{value: AMOUNT / 2}(commands2, inputs2, intent2, data2, true, nonce2, signature2, deadline2);

        // 验证第二笔交易拥有自己的上下文（未从第一笔泄漏）
        assertEq(capturer.capturedSigner(), expectedSigner, 'Second transaction should capture signer');
        assertEq(capturer.capturedIntent(), intent2, 'Second transaction should capture intent2 (not intent1)');
        assertEq(capturer.capturedData(), data2, 'Second transaction should capture data2 (not data1)');

        // 验证第二笔交易结束后上下文已被清除
        (storedSigner, storedIntent, storedData) = router.signedRouteContext();
        assertEq(storedSigner, address(0), 'Context should be cleared after second transaction');
        assertEq(storedIntent, bytes32(0), 'Intent should be cleared after second transaction');
        assertEq(storedData, bytes32(0), 'Data should be cleared after second transaction');
    }

    function testDifferentContractAddresses() public {
        // 部署第二个路由器
        RouterParameters memory params = RouterParameters({
            permit2: address(0),
            weth9: address(0),
            v2Factory: address(0),
            v3Factory: address(0),
            pairInitCodeHash: bytes32(0),
            poolInitCodeHash: bytes32(0),
            v4PoolManager: address(0),
            permissionsAdapterFactory: address(0),
            v3NFTPositionManager: address(0),
            v4PositionManager: address(0),
            spokePool: address(0)
        });
        UniversalRouter router2 = new UniversalRouter(params);

        // 为 router2 部署一个上下文捕获合约
        ContextCapture capturer2 = new ContextCapture(router2);

        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(capturer2), AMOUNT);

        bytes32 intent = keccak256('intent');
        bytes32 data = keccak256('data');
        bytes32 nonce = keccak256('different-contract-nonce');
        uint256 deadline = block.timestamp + 1000;

        // 为 router1 签名（域分隔符中使用 router1 的地址）
        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 尝试用 router1 的签名在 router2 上执行
        router2.executeSigned{value: AMOUNT}(commands, inputs, intent, data, false, nonce, signature, deadline);

        // 验证恢复出的签名者不是预期的签名者（因为域分隔符不同）
        address expectedSigner = signer;
        assertTrue(capturer2.capturedSigner() != expectedSigner, 'Signature should not be valid for different contract');
    }

    function testReentrantMaliciousContract() public {
        // 部署恶意合约
        ReentrantMaliciousContract malicious = new ReentrantMaliciousContract(router);

        // 创建向恶意合约转账的命令
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.TRANSFER)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(Constants.ETH, address(malicious), AMOUNT);

        bytes32 intent = keccak256('reentry-intent');
        bytes32 data = keccak256('reentry-data');
        bytes32 nonce = keccak256('reentry-nonce');
        uint256 deadline = block.timestamp + 1000;

        bytes memory signature = signExecution(commands, inputs, intent, data, address(this), nonce, deadline);

        // 预期回滚（revert）：恶意合约的重入尝试会失败，并导致 ETH 转账失败
        // （重入因签名无效而失败，该失败发生在 isNotLocked 检查之前）
        vm.expectRevert('ETH_TRANSFER_FAILED');
        router.executeSigned{value: AMOUNT}(commands, inputs, intent, data, true, nonce, signature, deadline);
    }
}
