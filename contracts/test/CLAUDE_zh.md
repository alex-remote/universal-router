# 测试合约

## 概述

本目录包含仅用于测试 Universal Router 的 Solidity 合约，包括模拟代币、测试工具以及用于集成测试的示例模块。

## 关键文件

- `MintableERC20.sol` - 用于测试场景的模拟 ERC20 代币
- `ReenteringWETH.sol` - 具备重入能力的 WETH 模拟合约，用于安全测试
- `TestCustomErrors.sol` - 用于测试自定义错误处理的工具
- `ExampleModule.sol` - 用于扩展测试的示例模块实现
- `ImportsForTypechain.sol` - 为 TypeChain 类型生成汇总导入

## 用途

测试合约用于：
- **代币模拟**：可铸造的 ERC20，用于受控的测试环境
- **安全测试**：重入攻击模拟
- **类型生成**：通过 TypeChain 生成完整的 TypeScript 绑定
- **扩展测试**：展示路由器可扩展性的示例模块

## 自动更新说明

修改本目录或其子目录中的文件后，运行 `/update-claude-md` 以使本文档与代码库保持同步。
