# 路由器模块（Router Modules）

## 概述

本目录包含实现特定路由功能的模块化组件。这些模块由 Dispatcher 组合在一起，为跨 Uniswap 各协议的兑换提供全面的路由能力。

## 结构

**支付模块：**
- `Payments.sol` - 核心支付处理（ETH、ERC20 转账）
- `PaymentsImmutables.sol` - 不可变的支付配置
- `Permit2Payments.sol` - 基于 Permit2 的代币授权

**兑换模块：**
- `uniswap/v2/V2SwapRouter.sol` - Uniswap V2 兑换执行
- `uniswap/v3/V3SwapRouter.sol` - Uniswap V3 兑换执行
- `uniswap/v4/V4SwapRouter.sol` - Uniswap V4 兑换执行
- `uniswap/UniswapImmutables.sol` - Uniswap 协议地址

**迁移：**
- `V3ToV4Migrator.sol` - 将流动性从 V3 迁移到 V4
- `MigratorImmutables.sol` - 迁移器配置

**工具：**
- `ChainedActions.sol` - 按顺序执行多个操作
- `uniswap/v2/UniswapV2Library.sol` - V2 数学计算与工具函数
- `uniswap/v3/BytesLib.sol` - 用于 V3 路径的字节操作
- `uniswap/v3/V3Path.sol` - V3 路径编码/解码

## 自动更新说明

修改本目录或其子目录中的文件后，运行 `/update-claude-md` 以使本文档与代码库保持同步。
