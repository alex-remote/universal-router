# Universal Router

请在提交 Pull Request 之前阅读 [贡献](https://github.com/Uniswap/universal-router#contributions) 一节。

如需查看最新一次部署所使用的智能合约 commit，请参见分支 `deployed-commit`。如需查看此次最新部署在各网络上的地址，请参见文件夹 `deploy-addresses`。

## 总体概览

Universal Router 是一个 ERC20 与 NFT 兑换路由器，让用户在跨多种代币类型进行交易时拥有更大的灵活性。

我们灵活的命令风格使我们能够为用户提供：

- 拆分与交错执行 Uniswap 交易
- 在 8 个市场中购买 NFT
- 交易的部分成交
- ETH 的包装与解包
- 使用 [Permit2](https://github.com/Uniswap/permit2) 实现有时限、由签名控制的代币授权

交易通过一串命令进行编码，使用户对想要执行的操作拥有最大的灵活性。所有这些功能都可在单笔交易中使用，用户可获得的可能性是无穷的

## 合约概览

Universal Router 代码库由 `UniversalRouter` 合约及其所有依赖组成。`UniversalRouter` 的目的是让用户能够在单笔交易中，将 Uniswap ERC20 兑换（V2 和 V3 上）与跨 8 个市场的 NFT 购买统一起来。

`UniversalRouter` 集成了 [Permit2](https://github.com/Uniswap/permit2)，使用户在 ERC20 代币授权方面拥有更高的安全性、灵活性和控制力。

### UniversalRouter 命令编码

对合约入口 `UniversalRouter.execute` 的调用提供 2 个主要参数：

- `bytes commands`：一个字节串。每个单独的字节代表该交易将执行的 1 条命令。
- `bytes[] inputs`：一个字节串数组。数组中的每个元素是某条命令的编码参数。

`commands[i]` 是将使用 `inputs[i]` 作为其编码输入参数的命令。

通过函数重载，`execute` 函数还有一个可选的第三个参数：

- `uint256 deadline`：本交易必须在此之前执行的截止时间戳。在该指定截止时间之后执行的交易将回滚（revert）。

#### 命令字节的结构

每条命令是一个 `bytes1`，包含以下 8 位：

```
 0 1 2 3 4 5 6 7
┌─┬─┬───────────┐
│f│r|  command  │
└─┴─┴───────────┘
```

- `f` 是一个单比特标志，表示是否允许该命令回滚（revert）。如果 `f` 为 `false` 且该命令回滚，则整个交易都会回滚。如果 `f` 为 `true` 且该命令回滚，则交易会继续执行，从而使我们能够实现部分成交。如果使用此标志，请注意附加后续命令，以移出可能遗留在 `UniversalRouter` 合约中未使用的资金。

- `r` 是一位保留空间。这将使我们将来能够扩大命令所用的空间，或添加新的标志。

- `command` 是一个 6 位的唯一标识符，表示应执行的命令。这些命令的取值可以在 Commands.sol 中找到，也可以在下表中查看。

```
   ┌──────┬───────────────────────────────┐
   │ 0x00 │  V3_SWAP_EXACT_IN             │
   ├──────┼───────────────────────────────┤
   │ 0x01 │  V3_SWAP_EXACT_OUT            │
   ├──────┼───────────────────────────────┤
   │ 0x02 │  PERMIT2_TRANSFER_FROM        │
   ├──────┼───────────────────────────────┤
   │ 0x03 │  PERMIT2_PERMIT_BATCH         │
   ├──────┼───────────────────────────────┤
   │ 0x04 │  SWEEP                        │
   ├──────┼───────────────────────────────┤
   │ 0x05 │  TRANSFER                     │
   ├──────┼───────────────────────────────┤
   │ 0x06 │  PAY_PORTION                  │
   ├──────┼───────────────────────────────┤
   │ 0x07 │  -------                      │
   ├──────┼───────────────────────────────┤
   │ 0x08 │  V2_SWAP_EXACT_IN             │
   ├──────┼───────────────────────────────┤
   │ 0x09 │  V2_SWAP_EXACT_OUT            │
   ├──────┼───────────────────────────────┤
   │ 0x0a │  PERMIT2_PERMIT               │
   ├──────┼───────────────────────────────┤
   │ 0x0b │  WRAP_ETH                     │
   ├──────┼───────────────────────────────┤
   │ 0x0c │  UNWRAP_WETH                  │
   ├──────┼───────────────────────────────┤
   │ 0x0d │  PERMIT2_TRANSFER_FROM_BATCH  │
   ├──────┼───────────────────────────────┤
   │ 0x0e-│  -------                      │
   │ 0x20 │                               │
   ├──────┼───────────────────────────────┤
   │ 0x21 │  EXECUTE_SUB_PLAN             │
   ├──────┼───────────────────────────────┤
   │ 0x22-│  -------                      │
   │ 0x3f │                               │
   └──────┴───────────────────────────────┘
```

请注意，序列中间的一些命令未被使用。这些空缺使我们在选择要执行的命令时能够提高 gas 效率。

#### 输入字节的结构

每个输入字节串只是一组参数的 abi 编码。根据所选命令的不同，输入字节串也会不同。例如：

`V3_SWAP_EXACT_IN` 的输入参数是对 5 个参数的编码：

- `address` 交易输出的接收方
- `uint256` 交易的输入代币数量
- `uint256` 用户想要的最小输出代币数量
- `bytes` 你想要沿其进行交易的 UniswapV3 路径
- `bool` 一个标志，表示输入资金应来自调用者（通过 Permit2），还是资金已在 UniversalRouter 中

相比之下，`CRYPTOPUNKS` 只编码了 3 个参数：

- `uint256` 你希望购买的 punk 的 ID
- `address` punk 的接收方
- `uint256` 为该 punk 支付的 ETH 数量

以这种方式将参数编码为字节串，使我们拥有最大的灵活性，能够以节省 gas 的方式支持许多需要不同数据类型的命令。

如需更详细地了解每条命令应提供哪些参数，请查看 `Dispatcher.dispatch` 函数，或者查看 `planner.ts` 中的 `ABI_DEFINITION` 映射。

详细说明每条命令输入参数的开发者文档即将推出！

## 使用方法

### 编译并运行测试

1. 克隆仓库及其所有子模块

使用以下命令克隆仓库：
```
git clone --recurse-submodules https://github.com/Uniswap/universal-router.git
```

2. 创建 `.env` 文件，填入你的分叉/主网 RPC URL

```
FORK_URL='https://your-mainnet-rpc-url'
```

3. 运行 yarn 命令进行编译和测试

### 运行 Hardhat 测试

```console
yarn install
yarn compile
yarn test:hardhat
```

如果在执行 `yarn compile` 时遇到找不到 lib 文件夹中依赖的问题，请尝试使用以下命令克隆所有子模块：
```
git submodule update --init --recursive
```

#### 更新 Hardhat gas 快照

```console
yarn test:gas
```

### 运行 Forge 测试

```console
forge install
forge build
forge test
```
## 集成

1. 安装最新版本的 `@uniswap/universal-router` 包。
2. 为不是 node 包的合约添加 git 子模块。确保存在一个空的 `.gitmodules` 文件。然后运行：
    ```bash
      git submodule add https://github.com/transmissions11/solmate
      git submodule add https://github.com/Uniswap/permit2
    ```
3. 现在你应该能够从 universal-router 导入合约并进行编译。

## 贡献
在提交 PR 之前，请运行以下所有命令并提交产生的改动：
```bash
# make sure all tests pass this will also update gas snapshots
yarn test:all

# lint code
yarn prettier:fix
```

如果你只关心排查 gas 差异，可以运行此命令以仅运行 gas 测试
```bash
yarn test:gas
```

### 部署

在 `script/deployParameters/Deploy<network>.s.sol` 中填写参数

```console
forge script --broadcast \
--rpc-url <RPC-URL> \
--private-key <PRIVATE_KEY> \
--sig 'run()' \
script/deployParameters/Deploy<network>.s.sol:Deploy<network>
```

### 部署并验证

```console
forge script --broadcast \
--rpc-url <RPC-URL> \
--private-key <PRIVATE-KEY> \
--sig 'run()' \
script/deployParameters/Deploy<network>.s.sol:Deploy<network> \
--etherscan-api-key <ETHERSCAN-API-KEY> \
--verify
```

#### 将 Permit2 与 UniversalRouter 一同部署

在 `scripts/deployParameters/<network>.json` 中填写参数

```console
forge script --broadcast \
--rpc-url <RPC-URL> \
--private-key <PRIVATE_KEY> \
--sig 'runAndDeployPermit2(string)' \
script/deployParameters/DeployUniversalRouter.s.sol:DeployUniversalRouter \
<pathToJSON>
```
