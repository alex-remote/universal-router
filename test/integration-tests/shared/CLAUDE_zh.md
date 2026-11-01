# 测试共享工具

## 概述

本目录包含在各集成测试中共用的 TypeScript 工具和辅助函数。这些模块为路由器部署、交易执行、编码以及协议交互提供通用功能。

## 关键文件

**核心测试基础设施：**
- `deployUniversalRouter.ts` - 部署用于测试的路由器实例
- `executeRouter.ts` - 执行路由器命令并处理错误
- `encodeCall.ts` - 编码路由器命令的 calldata
- `planner.ts` - 用于构建交易序列的命令规划器
- `v4Planner.ts` - V4 专用的命令规划器

**测试工具：**
- `constants.ts` - 共享的测试常量和地址
- `helpers.ts` - 通用测试辅助函数
- `expect.ts` - 自定义断言工具
- `parseEvents.ts` - 从交易回执中解析事件

**协议辅助工具：**
- `mainnetForkHelpers.ts` - 主网分叉测试工具
- `swapRouter02Helpers.ts` - 用于与旧版 SwapRouter02 对比的辅助函数
- `v4Helpers.ts` - Uniswap V4 测试工具
- `getPermitNFTSignature.ts` - 生成 Permit2 NFT 签名
- `getPermitV4Signature.ts` - 生成 V4 permit 签名
- `protocolHelpers/permit2.ts` - Permit2 集成辅助函数

## 自动更新说明

修改本目录或其子目录中的文件后，运行 `/update-claude-md` 以使本文档与代码库保持同步。
