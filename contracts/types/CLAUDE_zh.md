# 类型定义

## 概述

本目录包含在整个 Universal Router 合约中使用的 Solidity 类型定义和结构体。

## 关键文件

- `RouterParameters.sol` - 用于路由器初始化的配置结构体

## 用途

RouterParameters 结构体定义了初始化一个 Universal Router 实例所需的全部不可变配置：
- **支付相关地址**：Permit2、WETH9
- **Uniswap 协议**：V2/V3/V4 工厂地址及初始化代码哈希（init code hash）
- **V3→V4 迁移**：头寸管理器（position manager）地址
- **跨链桥集成**：Across Protocol 的 spoke pool

这种集中式的类型定义确保所有部署网络之间的配置保持一致。

## 自动更新说明

修改本目录或其子目录中的文件后，运行 `/update-claude-md` 以使本文档与代码库保持同步。
