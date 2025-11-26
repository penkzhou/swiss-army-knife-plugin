# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**重要：请使用中文回答所有问题。**

## 项目概述

这是一个 Claude Code 插件，实现了针对 React/TypeScript 项目的标准化 6 阶段前端 bugfix 工作流。工作流通过主命令 `/fix` 协调各个专业化 agent。

## 架构

### 工作流流程

```text
/fix 命令 → Phase 0-5 协调
     │
     ├─ Phase 0: error-analyzer agent → 解析和分类错误
     ├─ Phase 1: root-cause agent → 带置信度评分的诊断分析
     ├─ Phase 2: solution agent → 设计 TDD 修复方案
     ├─ Phase 3: (主控制器) → 生成 bugfix 文档
     ├─ Phase 4: executor agent → TDD 实现 (RED-GREEN-REFACTOR)
     └─ Phase 5: quality-gate + knowledge agents → 验证和知识沉淀
```

### 组件职责

- **`commands/fix.md`**：主协调器 - 解析参数，通过 Task 工具分发 agent，处理决策点
- **`agents/*.md`**：专业化子 agent，具有特定的工具权限和输出格式（JSON）
- **`skills/bugfix-workflow/SKILL.md`**：自动激活的知识库，包含错误模式和 TDD 实践
- **`hooks/hooks.json`**：在测试失败或前端代码变更时触发建议

### 置信度驱动的流程控制

工作流使用置信度分数（0-100）来决定行为：

- **≥60**：自动继续
- **40-59**：暂停并询问用户
- **<40**：停止并收集更多信息

这在 root-cause agent 输出中实现，并在 fix.md Phase 1.2 中评估。

## 插件开发

### 测试变更

```bash
# 创建测试 marketplace 目录结构
mkdir -p test-marketplace/.claude-plugin
# 添加 marketplace.json 指向此插件
# 然后在 Claude Code 中：
/plugin marketplace add /path/to/test-marketplace
/plugin install swiss-army-knife-plugin@test-marketplace

# 修改后重新安装：
/plugin uninstall swiss-army-knife-plugin@test-marketplace
/plugin install swiss-army-knife-plugin@test-marketplace
```

### 添加组件

- **Commands**：在 `commands/` 添加 `.md` 文件，包含 YAML frontmatter（`description`、`argument-hint`、`allowed-tools`）
- **Agents**：在 `agents/` 添加 `.md` 文件，包含 frontmatter（`model`、`allowed-tools`、`whenToUse` 带示例）
- **Skills**：创建 `skills/{name}/SKILL.md`，包含 frontmatter（`name`、`description`、`version`）
- **Hooks**：在 `hooks/hooks.json` 添加条目（`event`、`matcher`、`config`）

### 关键 Frontmatter 字段

```yaml
# Agent 用
model: opus                    # 所需模型
allowed-tools: ["Read", "Glob"] # 显式工具权限
whenToUse: |                   # Claude 何时使用此 agent
  描述，包含 <example> 块

# Command 用
description: 简短描述
argument-hint: "[--flag=value]"
allowed-tools: ["Read", "Write", "Task"]
```

## 领域知识

### 错误分类（按频率）

| 类型 | 频率 | 关键信号 |
| ------ | ------ | ---------- |
| mock_conflict | 71% | vi.mock 和 server.use 共存 |
| type_mismatch | 15% | `as any`，不完整的 mock 数据 |
| async_timing | 8% | 缺少 await，getBy vs findBy |
| render_issue | 4% | 条件渲染，状态更新 |
| cache_dependency | 2% | 不完整的 useEffect 依赖 |

### 目标项目假设

工作流假设目标项目使用：

- `make test TARGET=frontend` 运行测试
- `make lint TARGET=frontend` / `make typecheck TARGET=frontend` 进行 QA
- `docs/bugfix/` 存储 bugfix 报告
- `docs/best-practices/04-testing/frontend/` 存储参考文档
