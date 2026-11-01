# 部署参数脚本

## 概述

本目录包含为 Universal Router 定义各网络专属部署参数的 Foundry 脚本。每个脚本为特定区块链网络提供 RouterParameters 配置。

## 网络

**主网脚本：**
- `DeployMainnet.s.sol` - Ethereum 主网
- `DeployArbitrum.s.sol` - Arbitrum One
- `DeployOptimism.s.sol` - Optimism
- `DeployPolygon.s.sol` - Polygon PoS
- `DeployBase.s.sol` - Base
- `DeployAvalanche.s.sol` - Avalanche
- `DeployBSC.s.sol` - BNB Smart Chain
- `DeployCelo.s.sol` - Celo
- `DeployBlast.s.sol` - Blast
- `DeployZora.s.sol` - Zora
- `DeployInk.s.sol` - Ink
- `DeploySoneium.s.sol` - Soneium
- `DeployWorldchain.s.sol` - Worldchain
- `DeployUnichain.s.sol` - Unichain

**测试网脚本：**
- `DeploySepolia.s.sol`、`DeployGoerli.s.sol`、`DeployBaseSepolia.s.sol`、`DeployBaseGoerli.s.sol`、`DeployOPSepolia.s.sol`、`DeployOptimismGoerli.s.sol`、`DeployArbitrumGoerli.s.sol`、`DeployPolygonMumbai.s.sol`、`DeployCeloAlfajores.s.sol`、`DeployUnichainSepolia.s.sol`

## 用途

每个脚本返回一个 RouterParameters 结构体，其中包含该网络专属的地址，涵盖 Uniswap 工厂合约、WETH、Permit2 及其他协议依赖。

## 自动更新说明

修改本目录或其子目录中的文件后，运行 `/update-claude-md` 以使本文档与代码库保持同步。
