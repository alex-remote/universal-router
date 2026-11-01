# 合约接口

## 概述

本目录包含 Universal Router 及外部协议集成所用的 Solidity 接口。这些接口定义了公开 API，并支持与其他智能合约集成。

## 关键文件

- `IUniversalRouter.sol` - 路由器主接口，包含 execute() 方法和签名验证
- `external/IV3SpokePool.sol` - Across Protocol V3 跨链桥集成接口

## 用途

接口提供：
- **公开 API**：用于路由器执行的标准方法签名
- **类型安全**：用于跨协议操作的结构体定义（如 AcrossV4DepositV3Params）
- **外部集成**：面向 Across 跨链桥等第三方协议的类型化接口

## 自动更新说明

修改本目录或其子目录中的文件后，运行 `/update-claude-md` 以使本文档与代码库保持同步。
