// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

struct AcrossV4DepositV3Params {
    address depositor; // 被记为存款人的地址
    address recipient; // 目标链上的接收方
    address inputToken; // 源链上的 ERC20（跨链桥接 ETH 时为 WETH）
    address outputToken; // 目标链上的 ERC20（或 0x0）
    uint256 inputAmount; // 支持 ActionConstants.CONTRACT_BALANCE，以使用合约的全部余额
    uint256 outputAmount;
    uint256 destinationChainId;
    address exclusiveRelayer; // 无独占时为 0x0
    uint32 quoteTimestamp;
    uint32 fillDeadline;
    uint32 exclusivityDeadline;
    bytes message;
    bool useNative; // 若为 true，则调用为 payable 且 value=inputAmount（inputToken 必须为 WETH）
}

interface IUniversalRouter {
    /// @notice 当必须成功的命令执行失败时抛出
    error ExecutionFailed(uint256 commandIndex, bytes message);

    /// @notice 当尝试直接向合约发送 ETH 时抛出
    error ETHNotAccepted();

    /// @notice 当以已过期的截止时间执行命令时抛出
    error TransactionDeadlinePassed();

    /// @notice 当尝试执行命令但提供的输入参数数量不正确时抛出
    error LengthMismatch();

    // @notice 当非 WETH 地址尝试在不带 calldata 的情况下向路由器发送 ETH 时抛出
    error InvalidEthSender();

    /// @notice 使用提供的输入参数执行已编码的命令。若已过截止时间则回滚（revert）。
    /// @param commands 一组拼接在一起的命令，每条命令长 1 字节
    /// @param inputs 字节串数组，包含每条命令经 abi 编码的输入参数
    /// @param deadline 交易必须在此之前执行的截止时间
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;

    /// @notice 在 EIP712 签名验证下执行已编码的命令
    /// @param commands 一组拼接在一起的命令，每条命令长 1 字节
    /// @param inputs 字节串数组，包含每条命令经 abi 编码的输入参数
    /// @param intent 由应用自定义的意图标识符
    /// @param data 由应用自定义的数据
    /// @param verifySender 若为 true，签名必须包含 msg.sender；若为 false，则使用 address(0)
    /// @param nonce 用于防重放的无序 nonce。使用 bytes32(type(uint256).max) 可跳过 nonce 检查
    /// @param signature 授权本次执行的 EIP712 签名
    /// @param deadline 交易必须在此之前执行的截止时间
    /// @dev signer、intent 和 data 会被恢复/存入瞬态存储（transient storage），在整个执行期间有效。
    /// 所有命令（包括通过 EXECUTE_SUB_PLAN 嵌套的子命令）都在签名覆盖范围内。
    /// 命令可通过 signedRouteContext() 访问 signer、intent 和 data。
    /// 外部重入由 execute() 上的 isNotLocked 修饰器阻止。通过
    /// EXECUTE_SUB_PLAN 发生的内部重入是安全的，因为这些子命令属于已签名消息的一部分。
    /// 由于 executeSigned 无法被内部调用，执行过程中不可能更换签名者。
    function executeSigned(
        bytes calldata commands,
        bytes[] calldata inputs,
        bytes32 intent,
        bytes32 data,
        bool verifySender,
        bytes32 nonce,
        bytes calldata signature,
        uint256 deadline
    ) external payable;

    /// @notice 在一次调用中返回全部签名执行上下文（signer、intent、data）
    /// @return signer 签署当前执行的地址；若当前不处于签名执行中则为 address(0)
    /// @return intent 签名执行中的 intent 值；若当前不处于签名执行中则为 bytes32(0)
    /// @return data 签名执行中的 data 值；若当前不处于签名执行中则为 bytes32(0)
    /// @dev 此函数读取瞬态存储，而瞬态存储仅在 executeSigned() 执行期间被设置。
    /// @dev 在 hook 中使用该上下文时，hook 必须验证 msg.sender 是
    /// UniversalRouter 合约。否则，执行链中的恶意合约可能利用该合法的签名上下文
    /// 调用其他合约来滥用它，造成非预期的副作用。
    function signedRouteContext() external view returns (address signer, bytes32 intent, bytes32 data);
}
