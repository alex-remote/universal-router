# 英文注释中文翻译 · 任务进度跟踪

> 本文档由主代理维护，子代理每完成一组文件并汇报后，主代理在此勾选对应文件。`- [ ]` 表示未翻译，`- [x]` 表示已翻译并通过校验。

## 翻译规则

1. 代码文件：在英文注释原位置直接替换为中文，**翻译前后文件行数不变**，非注释代码一字不改。
2. 保留专有名词、函数名、变量名、合约名、NatSpec 标签（`@notice` / `@dev` / `@param <名称>` / `@return` 等）以及 `SPDX-License-Identifier`、lint 指令、被注释掉的代码。
3. 英文 `.md` 文件：原件不动，在同一路径生成 `<原名>_zh.md` 译文，逐行对应、行数与原件一致。
4. 校验方式：脚本比对 `git HEAD` 原件，确认行数一致且每行非注释代码部分完全相同。

## 统计范围

- 统计对象：仓库中 git 跟踪的文件，**不含** `lib/` 下的 5 个 git 子模块（forge-std / permit2 / solmate / v3-periphery / v4-periphery，属外部依赖，本仓库未检出其内容）。
- 不含无注释概念的文件：`*.json`（35 个）、`*.pdf`（5 个审计报告）、`snapshots/*.snap`（5 个）、`yarn.lock`、`foundry.lock`、`LICENSE`、`.nvmrc`。
- 另有 32 个代码/配置文件经扫描不含英文注释（仅有 `SPDX` 许可证标识或完全无注释），无需翻译，列于文末备查。

| 类别 | 文件数 | 总行数 |
| --- | ---: | ---: |
| 含英文注释的代码/配置文件（原位翻译） | 92 | 12619 |
| 英文 Markdown 文件（生成 `_zh.md`） | 14 | 744 |
| **需处理合计** | **106** | **13363** |
| 无英文注释、无需翻译的文件 | 32 | 1043 |

## 子代理分工与进度

| 子代理 | 范围 | 文件数 | 行数 | 状态 |
| --- | --- | ---: | ---: | --- |
| A01 | 核心合约：Dispatcher / Lock | 3 | 399 | ✅ 已完成 |
| A02 | 核心合约：Router / RouteSigner / 接口 | 5 | 329 | 进行中 |
| A03 | 库 / 类型 / 部署辅助合约 | 7 | 155 | ✅ 已完成 |
| A04 | 模块：Payments / Permit2 / 迁移 | 6 | 375 | ✅ 已完成 |
| A05 | 模块：Uniswap V2 | 3 | 303 | ✅ 已完成 |
| A06 | 模块：Uniswap V3 / V4 | 4 | 419 | ✅ 已完成 |
| A07 | 部署脚本 | 29 | 778 | ✅ 已完成 |
| A08 | Foundry 测试：RouteSigner | 1 | 653 | ✅ 已完成 |
| A09 | Foundry 测试：SwapProxy / V2 / Router / Locker / ChainedActions | 5 | 803 | ✅ 已完成 |
| A10 | Foundry 测试：V3 / Mock / PermissionedPools | 4 | 442 | ✅ 已完成 |
| A11 | 集成测试：V3ToV4Migration | 1 | 1655 | ✅ 已完成 |
| A12 | 集成测试：UniswapMixed | 1 | 924 | ✅ 已完成 |
| A13 | 集成测试：UniswapV4 | 1 | 817 | ✅ 已完成 |
| A14 | 集成测试：V2 / V3 / UniversalRouter | 3 | 1040 | ✅ 已完成 |
| A15 | Gas 测试：Uniswap | 1 | 1293 | ✅ 已完成 |
| A16 | Gas 测试：UniversalVSSwapRouter / Payments | 2 | 732 | ✅ 已完成 |
| A17 | Gas 测试：V3ToV4Migration + 测试共享工具 | 8 | 1144 | ✅ 已完成 |
| A18 | CI 工作流与配置文件 | 8 | 358 | ✅ 已完成 |
| M01 | README.md | 1 | 228 | ✅ 已完成 |
| M02 | PR 审查提示词 | 1 | 182 | ✅ 已完成 |
| M03 | CLAUDE.md（根目录 / audit / contracts 上半） | 6 | 148 | 进行中 |
| M04 | CLAUDE.md（contracts 下半 / 部署 / 测试） | 6 | 186 | 进行中 |

## 一、代码 / 配置文件（原位替换注释）

> 格式：文件路径 — 行数（扫描到的注释行数，估算值）

### A01 · 核心合约：Dispatcher / Lock

- [x] `contracts/base/Dispatcher.sol` — 341 行（注释约 54 行）
- [x] `contracts/base/Lock.sol` — 31 行（注释约 8 行）
- [x] `contracts/libraries/Locker.sol` — 27 行（注释约 5 行）

### A02 · 核心合约：Router / RouteSigner / 接口

- [ ] `contracts/UniversalRouter.sol` — 98 行（注释约 10 行）
- [ ] `contracts/SwapProxy.sol` — 34 行（注释约 11 行）
- [ ] `contracts/base/RouteSigner.sol` — 96 行（注释约 21 行）
- [ ] `contracts/interfaces/ISwapProxy.sol` — 24 行（注释约 9 行）
- [ ] `contracts/interfaces/IUniversalRouter.sol` — 77 行（注释约 39 行）

### A03 · 库 / 类型 / 部署辅助合约

- [x] `contracts/libraries/Commands.sol` — 49 行（注释约 14 行）
- [x] `contracts/libraries/Constants.sol` — 31 行（注释约 11 行）
- [x] `contracts/libraries/MaxInputAmount.sol` — 20 行（注释约 2 行）
- [x] `contracts/types/RouterParameters.sol` — 20 行（注释约 4 行）
- [x] `contracts/deploy/UnsupportedProtocol.sol` — 12 行（注释约 2 行）
- [x] `contracts/test/ImportsForTypechain.sol` — 15 行（注释约 2 行）
- [x] `contracts/test/TestCustomErrors.sol` — 8 行（注释约 1 行）

### A04 · 模块：Payments / Permit2 / 迁移

- [x] `contracts/modules/ChainedActions.sol` — 58 行（注释约 4 行）
- [x] `contracts/modules/MigratorImmutables.sol` — 25 行（注释约 4 行）
- [x] `contracts/modules/Payments.sol` — 120 行（注释约 24 行）
- [x] `contracts/modules/PaymentsImmutables.sol` — 23 行（注释约 2 行）
- [x] `contracts/modules/Permit2Payments.sol` — 46 行（注释约 15 行）
- [x] `contracts/modules/V3ToV4Migrator.sol` — 103 行（注释约 19 行）

### A05 · 模块：Uniswap V2

- [x] `contracts/modules/uniswap/UniswapImmutables.sol` — 30 行（注释约 4 行）
- [x] `contracts/modules/uniswap/v2/UniswapV2Library.sol` — 149 行（注释约 51 行）
- [x] `contracts/modules/uniswap/v2/V2SwapRouter.sol` — 124 行（注释约 18 行）

### A06 · 模块：Uniswap V3 / V4

- [x] `contracts/modules/uniswap/v3/BytesLib.sol` — 94 行（注释约 29 行）
- [x] `contracts/modules/uniswap/v3/V3Path.sol` — 43 行（注释约 14 行）
- [x] `contracts/modules/uniswap/v3/V3SwapRouter.sol` — 247 行（注释约 44 行）
- [x] `contracts/modules/uniswap/v4/V4SwapRouter.sol` — 35 行（注释约 1 行）

### A07 · 部署脚本

- [x] `script/DeployUniversalRouter.s.sol` — 71 行（注释约 5 行）
- [x] `script/deployParameters/DeployArbitrum.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployArbitrumGoerli.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployArc.s.sol` — 27 行（注释约 3 行）
- [x] `script/deployParameters/DeployAvalanche.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployBSC.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployBaseGoerli.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployBaseSepolia.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployBlast.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployCelo.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployCeloAlfajores.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployGoerli.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployHyperEVM.s.sol` — 29 行（注释约 4 行）
- [x] `script/deployParameters/DeployLinea.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployMegaETH.s.sol` — 26 行（注释约 2 行）
- [x] `script/deployParameters/DeployMonad.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployOPSepolia.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployOptimism.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployOptimismGoerli.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployPolygon.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployPolygonMumbai.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployRobinhood.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeploySoneium.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployTempo.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployUnichain.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployUnichainSepolia.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployWorldchain.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployXLayer.s.sol` — 25 行（注释约 1 行）
- [x] `script/deployParameters/DeployZora.s.sol` — 25 行（注释约 1 行）

### A08 · Foundry 测试：RouteSigner

- [x] `test/foundry-tests/RouteSigner.t.sol` — 653 行（注释约 76 行）

### A09 · Foundry 测试：SwapProxy / V2 / Router / Locker / ChainedActions

- [x] `test/foundry-tests/SwapProxy.t.sol` — 206 行（注释约 16 行）
- [x] `test/foundry-tests/UniswapV2.t.sol` — 235 行（注释约 5 行）
- [x] `test/foundry-tests/UniversalRouter.t.sol` — 159 行（注释约 2 行）
- [x] `test/foundry-tests/Locker.t.sol` — 40 行（注释约 1 行）
- [x] `test/foundry-tests/external/ChainedActions.fork.t.sol` — 163 行（注释约 3 行）

### A10 · Foundry 测试：V3 / Mock / PermissionedPools

- [x] `test/foundry-tests/UniswapV3.t.sol` — 285 行（注释约 34 行）
- [x] `test/foundry-tests/mock/MockV3Pool.sol` — 49 行（注释约 8 行）
- [x] `test/foundry-tests/permissionedPools/PermissionedSweep.t.sol` — 97 行（注释约 13 行）
- [x] `test/foundry-tests/permissionedPools/PermissionedV4.t.sol` — 11 行（注释约 3 行）

### A11 · 集成测试：V3ToV4Migration

- [x] `test/integration-tests/V3ToV4Migration.test.ts` — 1655 行（注释约 109 行）

### A12 · 集成测试：UniswapMixed

- [x] `test/integration-tests/UniswapMixed.test.ts` — 924 行（注释约 97 行）

### A13 · 集成测试：UniswapV4

- [x] `test/integration-tests/UniswapV4.test.ts` — 817 行（注释约 50 行）

### A14 · 集成测试：V2 / V3 / UniversalRouter

- [x] `test/integration-tests/UniswapV2.test.ts` — 452 行（注释约 25 行）
- [x] `test/integration-tests/UniswapV3.test.ts` — 368 行（注释约 17 行）
- [x] `test/integration-tests/UniversalRouter.test.ts` — 220 行（注释约 7 行）

### A15 · Gas 测试：Uniswap

- [x] `test/integration-tests/gas-tests/Uniswap.gas.test.ts` — 1293 行（注释约 74 行）

### A16 · Gas 测试：UniversalVSSwapRouter / Payments

- [x] `test/integration-tests/gas-tests/UniversalVSSwapRouter.gas.test.ts` — 600 行（注释约 49 行）
- [x] `test/integration-tests/gas-tests/Payments.gas.test.ts` — 132 行（注释约 10 行）

### A17 · Gas 测试：V3ToV4Migration + 测试共享工具

- [x] `test/integration-tests/gas-tests/V3ToV4Migration.gas.test.ts` — 492 行（注释约 15 行）
- [x] `test/integration-tests/shared/constants.ts` — 29 行（注释约 3 行）
- [x] `test/integration-tests/shared/helpers.ts` — 12 行（注释约 2 行）
- [x] `test/integration-tests/shared/planner.ts` — 129 行（注释约 7 行）
- [x] `test/integration-tests/shared/protocolHelpers/permit2.ts` — 114 行（注释约 1 行）
- [x] `test/integration-tests/shared/swapRouter02Helpers.ts` — 86 行（注释约 3 行）
- [x] `test/integration-tests/shared/v4Helpers.ts` — 152 行（注释约 1 行）
- [x] `test/integration-tests/shared/v4Planner.ts` — 130 行（注释约 20 行）

### A18 · CI 工作流与配置文件

- [x] `.github/workflows/claude-code-review.yml` — 38 行（注释约 1 行）
- [x] `.github/workflows/claude-pr-metadata-update.yml` — 47 行（注释约 5 行）
- [x] `.github/workflows/deploy.yml` — 46 行（注释约 5 行）
- [x] `.github/workflows/forge.yml` — 64 行（注释约 7 行）
- [x] `.github/workflows/lint.yml` — 45 行（注释约 4 行）
- [x] `.github/workflows/test.yml` — 54 行（注释约 6 行）
- [x] `.gitignore` — 24 行（注释约 4 行）
- [x] `foundry.toml` — 40 行（注释约 1 行）

## 二、Markdown 文件（生成 `_zh.md` 译文）

> 格式：原件路径 → 译文路径 — 行数

### M01 · README.md

- [x] `README.md` → `README_zh.md` — 228 行

### M02 · PR 审查提示词

- [x] `.claude/prompts/claude-pr-review.md` → `.claude/prompts/claude-pr-review_zh.md` — 182 行

### M03 · CLAUDE.md（根目录 / audit / contracts 上半）

- [ ] `CLAUDE.md` → `CLAUDE_zh.md` — 47 行
- [ ] `audit/CLAUDE.md` → `audit/CLAUDE_zh.md` — 17 行
- [ ] `contracts/base/CLAUDE.md` → `contracts/base/CLAUDE_zh.md` — 22 行
- [ ] `contracts/deploy/CLAUDE.md` → `contracts/deploy/CLAUDE_zh.md` — 17 行
- [ ] `contracts/interfaces/CLAUDE.md` → `contracts/interfaces/CLAUDE_zh.md` — 21 行
- [ ] `contracts/libraries/CLAUDE.md` → `contracts/libraries/CLAUDE_zh.md` — 24 行

### M04 · CLAUDE.md（contracts 下半 / 部署 / 测试）

- [ ] `contracts/modules/CLAUDE.md` → `contracts/modules/CLAUDE_zh.md` — 32 行
- [ ] `contracts/test/CLAUDE.md` → `contracts/test/CLAUDE_zh.md` — 25 行
- [ ] `contracts/types/CLAUDE.md` → `contracts/types/CLAUDE_zh.md` — 23 行
- [ ] `deploy-addresses/CLAUDE.md` → `deploy-addresses/CLAUDE_zh.md` — 40 行
- [ ] `script/deployParameters/CLAUDE.md` → `script/deployParameters/CLAUDE_zh.md` — 34 行
- [ ] `test/integration-tests/shared/CLAUDE.md` → `test/integration-tests/shared/CLAUDE_zh.md` — 32 行

## 附录：无需翻译的文件（无英文注释）

| 文件 | 行数 |
| --- | ---: |
| `.env.example` | 1 |
| `.github/CODEOWNERS` | 1 |
| `.gitmodules` | 15 |
| `.prettierignore` | 10 |
| `.prettierrc` | 5 |
| `contracts/interfaces/external/IV3SpokePool.sol` | 19 |
| `contracts/test/ExampleModule.sol` | 16 |
| `contracts/test/MintableERC20.sol` | 15 |
| `contracts/test/ReenteringWETH.sol` | 23 |
| `hardhat.config.ts` | 84 |
| `remappings.txt` | 7 |
| `script/DeploySwapProxy.s.sol` | 15 |
| `script/deployParameters/DeployBase.s.sol` | 25 |
| `script/deployParameters/DeployInk.s.sol` | 25 |
| `script/deployParameters/DeployMainnet.s.sol` | 25 |
| `script/deployParameters/DeploySepolia.s.sol` | 25 |
| `test/foundry-tests/MaxInputAmount.t.sol` | 28 |
| `test/foundry-tests/mock/MockERC20.sol` | 12 |
| `test/foundry-tests/uniswapTokens/v2DaiWeth.t.sol` | 18 |
| `test/foundry-tests/uniswapTokens/v2MockMock.t.sol` | 24 |
| `test/foundry-tests/uniswapTokens/v2MockWeth.t.sol` | 22 |
| `test/foundry-tests/uniswapTokens/v2WethApe.t.sol` | 18 |
| `test/integration-tests/CheckOwnership.test.ts` | 54 |
| `test/integration-tests/gas-tests/CheckOwnership.gas.test.ts` | 37 |
| `test/integration-tests/shared/deployUniversalRouter.ts` | 51 |
| `test/integration-tests/shared/encodeCall.ts` | 118 |
| `test/integration-tests/shared/executeRouter.ts` | 81 |
| `test/integration-tests/shared/expect.ts` | 6 |
| `test/integration-tests/shared/getPermitNFTSignature.ts` | 58 |
| `test/integration-tests/shared/getPermitV4Signature.ts` | 56 |
| `test/integration-tests/shared/mainnetForkHelpers.ts` | 112 |
| `test/integration-tests/shared/parseEvents.ts` | 37 |
