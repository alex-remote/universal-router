# Universal Router

## 概述

Uniswap Universal Router 的智能合约——一个灵活、模块化的路由合约，支持跨 Uniswap V2、V3 和 V4 协议的复杂多跳兑换。使用 Solidity 编写，基于 Hardhat 和 Foundry 构建。

## 脚本

- `npm run compile` - 使用 Hardhat 和 Forge 编译合约
- `npm run test:hardhat` - 运行 Hardhat 集成测试
- `npm run test:gas` - 运行 gas 基准测试并生成快照
- `npm run test:all` - 运行全部测试（Hardhat + Foundry）
- `npm run lint` - 格式化 TypeScript 和 Solidity 文件
- `npm run lint:check` - 检查格式但不做修改
- `npm run prettier:fix` - 格式化 TypeScript 和 JSON 文件

## 依赖

<!-- AUTO-GENERATED - Updated by /update-claude-md -->

**生产依赖：**
- **@openzeppelin/contracts** (5.0.2) - 安全的智能合约库
- **@uniswap/v2-core** (1.0.1) - Uniswap V2 协议核心
- **@uniswap/v3-core** (1.0.0) - Uniswap V3 协议核心

**开发依赖：**
- **hardhat** (2.22.14) - 以太坊开发环境
- **@nomicfoundation/hardhat-foundry** (1.1.2) - Hardhat 的 Foundry 集成
- **@uniswap/router-sdk** (^1.3.0) - 用于路由逻辑的 SDK
- **@uniswap/sdk-core** (^3.0.1) - 核心 SDK 工具
- **@uniswap/v2-sdk** (^3.0.1) - 用于测试的 V2 SDK
- **@uniswap/v3-sdk** (^3.8.3) - 用于测试的 V3 SDK
- **ethers** (^5.7.2) - JavaScript 以太坊库
- **typechain** (^4.0.0) - 为合约生成 TypeScript 绑定
- **typescript** (^3.7.3) - TypeScript 编译器

## 目录结构

- `contracts/` - Solidity 智能合约
- `test/` - 测试套件（Foundry + Hardhat）
- `script/` - 部署脚本
- `deploy-addresses/` - 各网络已部署的合约地址
- `audit/` - 安全审计报告

## 自动更新说明

修改本目录或其子目录中的文件后，运行 `/update-claude-md` 以使本文档与代码库保持同步。
