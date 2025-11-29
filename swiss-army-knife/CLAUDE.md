# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**重要：请使用中文回答所有问题。**

## 项目概述

这是一个 Claude Code 插件，实现了：

1. **标准化 6 阶段 bugfix 工作流**：支持多技术栈（后端、端到端、前端），通过 `/fix-backend`、`/fix-e2e`、`/fix-frontend` 命令协调
2. **PR Code Review 处理工作流**：8 阶段流程 (Phase 0-7)，通过 `/fix-pr-review` 命令自动分析和修复 PR 中的代码审查评论

## 架构

### 工作流流程

#### Bugfix 工作流 (6 阶段)

```text
/fix-backend / /fix-e2e / /fix-frontend 命令 → Phase 0-5 协调
     │
     ├─ Phase 0: 问题收集与分类
     │   ├─ init-collector agent → 加载配置、收集测试输出、项目信息
     │   └─ error-analyzer agent → 解析和分类错误
     ├─ Phase 1: root-cause agent → 带置信度评分的诊断分析
     ├─ Phase 2: solution agent → 设计 TDD 修复方案
     ├─ Phase 3: (主控制器) → 生成 bugfix 文档
     ├─ Phase 4: executor agent → TDD 实现 (RED-GREEN-REFACTOR)
     └─ Phase 5: 验证、审查与沉淀
         ├─ quality-gate agent → 质量门禁检查
         ├─ 6 个 review agents (并行) → 代码审查
         │   ├─ review-code-reviewer      # 通用代码审查
         │   ├─ review-silent-failure-hunter  # 静默失败检测
         │   ├─ review-code-simplifier    # 代码简化
         │   ├─ review-test-analyzer      # 测试覆盖分析
         │   ├─ review-comment-analyzer   # 注释准确性
         │   └─ review-type-design-analyzer   # 类型设计分析
         ├─ review-fixer agent → 自动修复 ≥80 置信度问题 (最多 3 次循环)
         └─ knowledge agent → 知识沉淀
```

#### PR Review 工作流 (8 阶段，Phase 0-7)

```text
/fix-pr-review <PR_NUMBER> 命令 → Phase 0-7 协调
     │
     ├─ Phase 0: 初始化
     │   └─ init-collector agent → 验证 gh CLI、获取 PR 元信息、最后 commit 时间
     ├─ Phase 1: 评论获取
     │   └─ comment-fetcher agent → 获取所有 review comments 和 issue comments
     ├─ Phase 2: 评论过滤
     │   └─ comment-filter agent → 过滤过时评论（在最后 commit 之前创建的）
     ├─ Phase 3: 评论分类
     │   └─ comment-classifier agent → 置信度评估、优先级分类、技术栈识别
     ├─ Phase 4: 修复协调
     │   └─ fix-coordinator agent → 调用对应技术栈的 bugfix 工作流
     ├─ Phase 5: 回复生成
     │   └─ response-generator agent → 基于修复结果生成回复
     ├─ Phase 6: 回复提交
     │   └─ response-submitter agent → 通过 gh CLI 提交回复到 PR
     └─ Phase 7: 审查、汇总与沉淀
         ├─ 6 个 review agents (并行) → 代码审查
         ├─ review-fixer agent → 自动修复 ≥80 置信度问题 (最多 3 次循环)
         └─ summary-reporter agent → 生成处理报告和知识沉淀
```

### 组件结构

插件采用多技术栈架构：

- **Commands**：
  - `commands/fix-backend.md`、`commands/fix-e2e.md`、`commands/fix-frontend.md` - 按技术栈分离的 bugfix 协调器
  - `commands/fix-pr-review.md` - PR Code Review 处理协调器
- **Agents**：按技术栈和功能组织
  - `agents/backend/`：后端专用 agents（init-collector、error-analyzer、root-cause、solution、executor、quality-gate、knowledge）
  - `agents/e2e/`：端到端测试专用 agents（含 init-collector）
  - `agents/frontend/`：前端专用 agents（init-collector、error-analyzer、root-cause、solution、executor、quality-gate、knowledge）
  - `agents/pr-review/`：PR Review 专用 agents（init-collector、comment-fetcher、comment-filter、comment-classifier、fix-coordinator、response-generator、response-submitter、summary-reporter）
  - `agents/review/`：通用 Review agents（在所有工作流的 Phase 5/7 中并行执行）
    - `code-reviewer.md` - 通用代码审查、项目规范合规性检查
    - `silent-failure-hunter.md` - 静默失败和错误处理检测
    - `code-simplifier.md` - 代码简化和可维护性提升
    - `test-analyzer.md` - 测试覆盖质量分析
    - `comment-analyzer.md` - 注释准确性和完整性检查
    - `type-design-analyzer.md` - 类型设计和封装性分析
    - `review-fixer.md` - 自动修复置信度 ≥80 的问题
- **Skills**：按技术栈和功能提供知识库
  - `skills/backend-bugfix/SKILL.md` - ✅ 完整，包含 Python/FastAPI 错误模式和 pytest 最佳实践
  - `skills/e2e-bugfix/SKILL.md` - ✅ 完整，包含 Playwright 错误模式和调试技巧
  - `skills/frontend-bugfix/SKILL.md` - ✅ 完整，包含 React/TypeScript 错误模式和 vitest/jest 最佳实践
  - `skills/pr-review-analysis/SKILL.md` - ✅ 完整，包含置信度评估、优先级分类、技术栈识别和回复最佳实践
- **Configuration**：`.claude/swiss-army-knife.yaml` - 项目级配置，自定义命令和路径
- **Hooks**：`hooks/hooks.json` - 在测试失败或代码变更时触发建议

### 组件职责

- **Commands**：主协调器 - 解析参数，通过 Task 工具分发对应技术栈的 agent，处理决策点
- **Agents**：专业化子 agent，具有特定的工具权限和输出格式（JSON），按技术栈组织
- **Skills**：自动激活的知识库，按技术栈提供错误分类、置信度评分和 TDD 实践
- **Configuration**：支持自定义测试命令、文档路径和最佳实践搜索关键词

### 置信度驱动的流程控制

工作流使用置信度分数（0-100）来决定行为：

#### Bugfix 工作流（根因分析）

- **≥60**：自动继续
- **40-59**：暂停并询问用户
- **<40**：停止并收集更多信息

这在 root-cause agent 输出中实现，并在各技术栈的 fix-{stack}.md（如 fix-backend.md）Phase 1.3 中评估。

#### Review 代码审查（Phase 5/7）

- **≥90 (Critical)**：严重问题，自动修复
- **80-89 (Important)**：重要问题，自动修复
- **<80**：低于阈值，不报告（仅内部追踪）

在 Phase 5（bugfix 工作流）或 Phase 7（PR Review 工作流）中，6 个 review agents 并行执行，发现的 ≥80 置信度问题由 review-fixer agent 自动修复，最多循环 3 次直到问题收敛。

#### PR Review 工作流

- **≥80**：高置信度，自动修复
- **60-79**：中置信度，询问用户后处理
- **40-59**：低置信度，标记需澄清
- **<40**：极低置信度，跳过并回复 reviewer

置信度基于 4 个加权因素计算：

- 明确性 (Clarity) - 40%：评论是否清晰指出问题
- 具体性 (Specificity) - 30%：是否有具体示例或测试场景
- 上下文 (Context) - 20%：是否理解代码上下文和影响
- 可复现 (Reproducibility) - 10%：是否有复现步骤

## 插件开发

### 测试变更

```bash
# 此仓库已经是 marketplace 结构，直接添加即可：
/plugin marketplace add /path/to/swiss-army-knife-plugin
/plugin install swiss-army-knife@swiss-army-knife-plugin

# 修改后重新安装：
/plugin uninstall swiss-army-knife@swiss-army-knife-plugin
/plugin install swiss-army-knife@swiss-army-knife-plugin
```

### 添加组件

- **Commands**：在 `commands/` 添加 `.md` 文件（如 `fix-{stack}.md`），包含 YAML frontmatter（`description`、`argument-hint`、`allowed-tools`）
- **Agents**：在对应技术栈目录（`agents/backend/`、`agents/e2e/`）添加 `.md` 文件，包含 frontmatter（`name`、`description`、`model`、`tools`）
- **Skills**：创建 `skills/{name}/SKILL.md`，包含 frontmatter（`name`、`description`）
- **Hooks**：在 `hooks/hooks.json` 添加条目（`event`、`matcher`、`config`）
- **Configuration**：在目标项目的 `.claude/swiss-army-knife.yaml` 中配置技术栈特定的命令和路径

### 关键 Frontmatter 字段

```yaml
# Agent 用
name: backend-error-analyzer   # 必填：agent 名称
description: Use this agent... # 必填：触发条件描述
model: opus                    # 所需模型 (opus/sonnet/haiku/inherit)
tools: Read, Glob, Grep        # 显式工具权限（逗号分隔）
skills: backend-bugfix         # 可选：关联的知识库

# Command 用
description: 简短描述
argument-hint: "[--flag=value]"
allowed-tools: Read, Write, Task   # 显式工具权限（逗号分隔）
```

#### model 字段说明

| 值 | 说明 |
| --- | --- |
| `opus` | 使用最强模型，适合复杂分析和决策 |
| `sonnet` | 平衡性能和成本，适合一般任务 |
| `haiku` | 最快最省成本，适合简单任务 |
| `inherit` | 继承调用者的模型设置，推荐用于保持一致性 |

### 最佳实践参考

开发 Claude Code 插件时，请参考官方文档：

- **[Claude Code 插件文档](https://code.claude.com/docs/en/plugins)**：完整的插件开发指南，包含 API 参考、架构模式和最佳实践
- **[插件 API 参考](https://code.claude.com/docs/en/plugins-reference)**：插件组件的详细规范，包括 commands、agents、skills、hooks 的 frontmatter 字段定义
- **[斜杠命令指南](https://code.claude.com/docs/en/slash-commands)**：自定义斜杠命令的创建和使用，包含 frontmatter 配置和动态参数
- **[Agent Skills 最佳实践](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)**：编写高质量 skill 的指南和模式
- **[Sub-agents 最佳实践](https://code.claude.com/docs/en/sub-agents)**：设计和协调子 agent 的指南，包含 Task 工具使用模式
- **[Hooks 开发指南](https://code.claude.com/docs/en/hooks)**：事件驱动自动化和工作流触发器的实现指南

## 领域知识

### 错误分类（按频率）

**Frontend (React/TypeScript)**

| 类型 | 频率 | 关键信号 |
| ------ | ------ | ---------- |
| mock_conflict | 71% | vi.mock 和 server.use 共存 |
| type_mismatch | 15% | `as any`，不完整的 mock 数据 |
| async_timing | 8% | 缺少 await，getBy vs findBy |
| render_issue | 4% | 条件渲染，状态更新 |
| cache_dependency | 2% | 不完整的 useEffect 依赖 |

**Backend (Python/FastAPI)**

| 类型 | 频率 | 关键信号 |
| ------ | ------ | ---------- |
| database_error | 30% | IntegrityError, sqlalchemy.exc |
| validation_error | 25% | ValidationError, 422 |
| api_error | 20% | HTTPException, 404/405 |
| auth_error | 10% | 401/403, token |
| async_error | 8% | TimeoutError, await |
| config_error | 5% | KeyError, settings |

**E2E (Playwright)**

| 类型 | 频率 | 关键信号 |
| ------ | ------ | ---------- |
| timeout_error | 35% | Timeout exceeded, waiting for |
| selector_error | 25% | strict mode violation, not found |
| assertion_error | 15% | expect().toHave, Expected vs Received |
| network_error | 12% | Route handler, net::ERR |
| navigation_error | 8% | page.goto, ERR_NAME_NOT_RESOLVED |
| environment_error | 3% | browser.launch, Target closed |

### 目标项目假设

工作流通过配置支持多种项目结构：

- 默认使用 `make test TARGET={stack}` 运行测试
- 可通过 `.claude/swiss-army-knife.yaml` 自定义命令和路径
- 文档路径支持关键词搜索，无需硬编码

**默认配置示例：**

```yaml
stacks:
  backend:
    test_command: "make test TARGET=backend"
    lint_command: "make lint TARGET=backend"
    typecheck_command: "make typecheck TARGET=backend"
    docs:
      bugfix_dir: "docs/bugfix/"
      best_practices_dir: "docs/best-practices/"
      search_keywords:
        database: ["database", "query", "ORM"]
```
