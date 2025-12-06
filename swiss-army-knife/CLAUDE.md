# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**重要：请使用中文回答所有问题。**

## 项目概述

这是一个 Claude Code 插件，实现了：

1. **标准化 6 阶段 bugfix 工作流**：支持多技术栈（后端、端到端、前端），通过 `/fix-backend`、`/fix-e2e`、`/fix-frontend` 命令协调
2. **PR Code Review 处理工作流**：8 阶段流程 (Phase 0-7)，通过 `/fix-pr-review` 命令自动分析和修复 PR 中的代码审查评论
3. **CI Job 失败修复工作流**：7 阶段流程 (Phase 0-6)，通过 `/fix-failed-job` 命令自动分析和修复 GitHub Actions 失败的 job
4. **计划执行工作流**：6 阶段流程 (Phase 0-5)，通过 `/execute-plan` 命令执行实施计划，支持 TDD、批次执行和完整代码审查
5. **依赖管理工具**：通过 `/merge-dep-prs` 命令合并依赖更新 PR（Renovate/Dependabot），减少 CI 成本

## 架构

### 统一三层架构

所有工作流采用相同的三层架构，实现完全闭环：

```text
命令层 (*.md) ─── 仅参数解析 + 调用 master-coordinator
    │
    └── master-coordinator agent ─── 协调各 Phase、置信度决策、用户交互
            │
            ├── Phase agents (各工作流专有)
            │
            └── review-coordinator agent (共享) ─── 管理 Review-Fix 循环
                    ├── 6 个 review agents (并行)
                    └── review-fixer agent (循环)
```

### 工作流流程

#### Bugfix 工作流 (6 阶段)

```text
/fix-backend / /fix-e2e / /fix-frontend 命令 → 参数解析
     │
     └── bugfix-master-coordinator (共享，通过 stack 参数区分)
             │
             ├─ Phase 0: 问题收集与分类
             │   ├─ init-collector agent → 加载配置、收集测试输出、项目信息
             │   └─ error-analyzer agent → 解析和分类错误
             ├─ Phase 1: root-cause agent → 带置信度评分的诊断分析 + 置信度决策
             ├─ Phase 2: bugfix-solution agent → 设计 TDD 修复方案
             ├─ Phase 3: bugfix-doc-writer agent → 生成 bugfix 文档
             ├─ Phase 4: bugfix-executor agent → TDD 实现 (RED-GREEN-REFACTOR)
             └─ Phase 5: review-coordinator (共享) + bugfix-knowledge
                     ├─ 6 个 review agents (并行)
                     └─ review-fixer agent (最多 3 次循环)
```

#### PR Review 工作流 (8 阶段，Phase 0-7)

```text
/fix-pr-review <PR_NUMBER> 命令 → 参数解析
     │
     └── pr-review-master-coordinator
             │
             ├─ Phase 0: init-collector agent → 验证 gh CLI、获取 PR 元信息
             ├─ Phase 1: comment-fetcher agent → 获取 review/issue comments
             ├─ Phase 2: comment-filter agent → 过滤已解决、CI 自动报告
             ├─ Phase 3: comment-classifier agent → 置信度评估、优先级分类
             ├─ Phase 4: fix-coordinator agent → 置信度决策 + 调用 bugfix 工作流
             ├─ Phase 5: response-generator agent → 生成回复内容
             ├─ Phase 6: response-submitter agent → 提交回复到 PR
             └─ Phase 7: review-coordinator (共享) + knowledge-writer + summary-reporter
                     ├─ 6 个 review agents (并行)
                     └─ review-fixer agent (最多 3 次循环)
```

#### CI Job 失败修复工作流 (7 阶段，Phase 0-6)

```text
/fix-failed-job <JOB_URL> 命令 → 参数解析
     │
     └── ci-job-master-coordinator
             │
             ├─ Phase 0: init-collector agent → 解析 URL、验证 gh CLI、获取 Job 元信息
             ├─ Phase 1: log-fetcher agent → 下载日志、识别失败 step、提取错误
             ├─ Phase 2: failure-classifier agent → 失败类型分类、技术栈识别
             ├─ Phase 3: root-cause agent → 深度分析、历史匹配、生成修复建议
             ├─ Phase 4: fix-coordinator agent → 置信度决策 + 调用 bugfix 工作流
             ├─ Phase 5: review-coordinator (共享) + 本地验证
             │       ├─ 6 个 review agents (并行)
             │       └─ review-fixer agent (最多 3 次循环)
             └─ Phase 6: summary-reporter agent → 报告、可选 git commit、可选 job retry
```

#### 计划执行工作流 (6 阶段，Phase 0-5)

```text
/execute-plan <PLAN_FILE> 命令 → 参数解析
     │
     └── execute-plan-master-coordinator
             │
             ├─ Phase 0: init-collector agent → 加载配置、解析计划文件、收集项目信息
             ├─ Phase 1: validator agent → 验证任务、分析依赖 + 置信度决策
             ├─ Phase 2: bugfix-solution agent → 为每个任务生成 TDD 计划（可选）
             ├─ Phase 3: executor-coordinator agent → 批次执行、TDD 流程
             ├─ Phase 4: review-coordinator (共享) + 完整验证
             │       ├─ 6 个 review agents (并行)
             │       └─ review-fixer agent (最多 3 次循环)
             └─ Phase 5: summary-reporter agent + bugfix-knowledge
```

### 组件结构

插件采用多技术栈架构，共 47 个 agents：

- **Commands**（7 个）：仅参数解析 + 调用 master-coordinator
  - `commands/fix-backend.md`、`commands/fix-e2e.md`、`commands/fix-frontend.md` - Bugfix 入口
  - `commands/fix-pr-review.md` - PR Review 入口
  - `commands/fix-failed-job.md` - CI Job 修复入口
  - `commands/execute-plan.md` - 计划执行入口
  - `commands/merge-dep-prs.md` - 依赖合并工具（Renovate/Dependabot）
- **Master Coordinators**（4 个）：工作流总协调器，管理 Phase 间状态、置信度决策、用户交互
  - `agents/bugfix/master-coordinator.md` - 协调 Bugfix Phase 0-5（共享，通过 stack 参数区分）
  - `agents/pr-review/master-coordinator.md` - 协调 PR Review Phase 0-7
  - `agents/ci-job/master-coordinator.md` - 协调 CI Job Phase 0-6
  - `agents/execute-plan/master-coordinator.md` - 协调 Execute Plan Phase 0-5
- **Review Coordinator**（共享组件）：
  - `agents/review/review-coordinator.md` - 管理 Review-Fix 循环，被所有工作流复用
- **Agents**：按技术栈和功能组织
  - `agents/bugfix/`（5 个）：通用 Bugfix agents（master-coordinator、doc-writer、executor、knowledge、solution）
  - `agents/backend/`（4 个）：后端专用 agents（init-collector、error-analyzer、root-cause、quality-gate）
  - `agents/e2e/`（4 个）：E2E 测试专用 agents（init-collector、error-analyzer、root-cause、quality-gate）
  - `agents/frontend/`（4 个）：前端专用 agents（init-collector、error-analyzer、root-cause、quality-gate）
  - `agents/pr-review/`（10 个）：PR Review agents（master-coordinator、init-collector、comment-fetcher、comment-filter、comment-classifier、fix-coordinator、response-generator、response-submitter、knowledge-writer、summary-reporter）
  - `agents/ci-job/`（7 个）：CI Job 修复 agents（master-coordinator、init-collector、log-fetcher、failure-classifier、root-cause、fix-coordinator、summary-reporter）
  - `agents/execute-plan/`（5 个）：计划执行 agents（master-coordinator、init-collector、validator、executor-coordinator、summary-reporter）
  - `agents/review/`（8 个）：通用 Review agents（在所有工作流中并行执行）
    - `review-coordinator.md` (`name: review-coordinator`) - 管理 Review-Fix 循环（共享）
    - `code-reviewer.md` (`name: review-code-reviewer`) - 通用代码审查、项目规范合规性检查
    - `silent-failure-hunter.md` (`name: review-silent-failure-hunter`) - 静默失败和错误处理检测
    - `code-simplifier.md` (`name: review-code-simplifier`) - 代码简化和可维护性提升
    - `test-analyzer.md` (`name: review-test-analyzer`) - 测试覆盖质量分析
    - `comment-analyzer.md` (`name: review-comment-analyzer`) - 注释准确性和完整性检查
    - `type-design-analyzer.md` (`name: review-type-design-analyzer`) - 类型设计和封装性分析
    - `review-fixer.md` (`name: review-fixer`) - 自动修复置信度 ≥80 的问题
- **Skills**：按技术栈和功能提供知识库
  - `skills/bugfix-workflow/SKILL.md` - ✅ 完整，包含通用 TDD 流程、输出格式规范、置信度评分标准
  - `skills/backend-bugfix/SKILL.md` - ✅ 完整，包含 Python/FastAPI 错误模式和 pytest 最佳实践
  - `skills/e2e-bugfix/SKILL.md` - ✅ 完整，包含 Playwright 错误模式和调试技巧
  - `skills/frontend-bugfix/SKILL.md` - ✅ 完整，包含 React/TypeScript 错误模式和 vitest/jest 最佳实践
  - `skills/pr-review-analysis/SKILL.md` - ✅ 完整，包含置信度评估、优先级分类、技术栈识别和回复最佳实践
  - `skills/ci-job-analysis/SKILL.md` - ✅ 完整，包含 CI 失败类型分类、置信度评估、技术栈识别和常见错误模式
  - `skills/knowledge-patterns/SKILL.md` - ✅ 完整，PR Review 修复模式库，支持智能相似度匹配和实例合并
  - `skills/elements-of-style/SKILL.md` - ✅ 完整，Strunk 写作规则，用于提升文档质量
  - `skills/execute-plan/SKILL.md` - ✅ 完整，计划格式规范、任务解析、依赖分析和批次执行策略
  - `skills/coordinator-patterns/SKILL.md` - ✅ 完整，Coordinator 通用模式：Phase 验证、错误处理、TodoWrite 管理
- **Configuration**：`.claude/swiss-army-knife.yaml` - 项目级配置，自定义命令和路径
- **Hooks**：`hooks/hooks.json` - 在测试失败或代码变更时触发建议

### 组件职责

- **Commands**：入口点 - 仅解析参数，调用对应的 master-coordinator（约 80-140 行）
- **Master Coordinators**：工作流总协调器 - 管理所有 Phase 执行、状态传递、置信度决策、用户交互
- **Review Coordinator**：Review-Fix 循环管理器 - 被所有工作流共享，消除重复代码
- **Phase Agents**：专业化子 agent，具有特定的工具权限和输出格式（JSON），按技术栈组织
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

#### CI Job 失败修复工作流

- **≥80**：高置信度，自动修复
- **60-79**：中置信度，询问用户后修复
- **40-59**：低置信度，展示分析结果，建议手动修复
- **<40**：极低置信度，跳过并报告原因

置信度基于 4 个加权因素计算：

- 信号明确性 (Signal Clarity) - 40%：错误信号是否清晰明确
- 文件定位 (File Location) - 30%：是否能定位到具体文件和行号
- 模式匹配 (Pattern Match) - 20%：是否匹配已知错误模式
- 上下文完整 (Context Complete) - 10%：是否有完整的堆栈追踪

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

## 过程日志

所有工作流支持过程日志，用于追踪执行状态和 debug 问题。

### 开启日志

在任何命令中添加 `--log` 或 `--verbose` 参数：

| 参数 | 级别 | 记录内容 |
|------|------|----------|
| `--log` | INFO | Phase/Agent 事件、置信度决策、用户交互 |
| `--verbose` | DEBUG | 额外包含完整的 agent 输入输出（文件较大） |

**示例**：

```bash
# 开启 INFO 日志
/swiss-army-knife:fix-frontend --log

# 开启 DEBUG 日志
/swiss-army-knife:fix-backend --verbose

# PR Review 工作流
/swiss-army-knife:fix-pr-review 123 --log
```

### 日志文件位置

日志保存在项目根目录下，按工作流类型分目录：

```text
.claude/logs/swiss-army-knife/
├── bugfix/           # fix-frontend, fix-backend, fix-e2e
├── pr-review/        # fix-pr-review
├── ci-job/           # fix-failed-job
└── execute-plan/     # execute-plan
```

**文件命名**：`{日期}_{时间}_{标识符}_{会话ID}.{格式}`

- 示例：`2024-12-06_143052_frontend_a1b2c3d4.jsonl`
- 每次执行生成 `.jsonl`（程序查询）和 `.log`（人类阅读）两个文件

### 查看日志

**文本格式**（实时跟踪）：

```bash
# 跟踪最新日志
tail -f .claude/logs/swiss-army-knife/bugfix/*.log

# 查看错误
grep "ERROR" .claude/logs/swiss-army-knife/bugfix/*.log

# 查看决策点
grep "DECN" .claude/logs/swiss-army-knife/bugfix/*.log
```

**JSONL 格式**（结构化查询）：

```bash
# 查看会话摘要
jq 'select(.type == "SESSION_START" or .type == "SESSION_END")' xxx.jsonl

# 查看所有错误
jq 'select(.level == "E")' xxx.jsonl

# 查看 Phase 耗时
jq 'select(.type == "PHASE_END") | {phase, duration_ms, status}' xxx.jsonl

# 查看置信度决策
jq 'select(.type == "CONFIDENCE_DECISION")' xxx.jsonl
```

### Debug 工作流

#### 关键事件

| 事件 | 含义 |
|------|------|
| `SESSION_START` | 工作流开始，记录命令参数和环境 |
| `PHASE_START/END` | 每个阶段的开始和结束 |
| `CONFIDENCE_DECISION` | 置信度决策（auto_continue/ask_user/stop） |
| `USER_INTERACTION` | 用户交互（问题和回答） |
| `ERROR` | 错误和失败 |
| `SESSION_END` | 工作流结束，记录总耗时和摘要 |

#### 常见问题排查

| 问题 | 排查方法 |
|------|----------|
| 工作流未执行 | 检查 `SESSION_START` 是否存在 |
| Phase 失败 | 搜索 `PHASE_END` + `status: "failed"` |
| 置信度过低停止 | 搜索 `CONFIDENCE_DECISION`，查看 `confidence_score` |
| Review 循环异常 | 搜索 `REVIEW_FIX_ITERATION`，查看迭代次数 |

#### 常见错误码

| 错误码 | 含义 | 解决方法 |
|--------|------|----------|
| `CONFIDENCE_TOO_LOW` | 置信度低于阈值 | 提供更多上下文或手动处理 |
| `GIT_UNAVAILABLE` | Git 不可用 | 确保在 Git 仓库中运行 |
| `CONFIG_INVALID` | 配置无效 | 检查 `.claude/swiss-army-knife.yaml` |
| `AGENT_TIMEOUT` | Agent 执行超时 | 检查网络或简化任务 |

### 自定义日志配置

在项目的 `.claude/swiss-army-knife.yaml` 中覆盖默认配置：

```yaml
logging:
  enabled: true      # 默认开启日志
  level: "debug"     # 默认使用 DEBUG 级别
  output_dir: ".logs/swiss-army-knife"  # 自定义输出目录
  retention_days: 7  # 保留 7 天
```

详细的日志格式规范参见 `skills/workflow-logging/SKILL.md`。

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
