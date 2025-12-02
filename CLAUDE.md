# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**重要：请使用中文回答所有问题。**

## 仓库概述

这是一个 Claude Code 插件 marketplace 仓库，包含 `swiss-army-knife` 插件（v1.0.0）。该插件实现了多技术栈标准化工作流：

- **6 阶段 Bugfix 工作流**：支持 Frontend (React/TypeScript)、Backend (Python/FastAPI)、E2E (Playwright/Cypress)
- **8 阶段 PR Review 工作流**：自动分析和修复 GitHub PR 中的代码审查评论
- **7 阶段 CI Job 修复工作流**：自动分析和修复 GitHub Actions 失败的 job
- **6 阶段计划执行工作流**：执行实施计划，支持 TDD 和批次执行

## 技术栈

| 类别 | 技术 |
|------|------|
| 语言 | Markdown、YAML、JSON |
| 框架 | Claude Code Plugin System |
| Lint 工具 | markdownlint-cli、markdown-link-check |
| CI/CD | GitHub Actions |
| 版本 | v1.0.0 |

**关键依赖：**

- Node.js 20+ （仅用于 lint 检查）
- markdownlint-cli（Markdown 格式检查）
- GitHub CLI `gh`（PR Review 和 CI Job 工作流需要）

## 目录结构

```text
swiss-army-knife-plugin/
├── .claude-plugin/
│   └── marketplace.json           # Marketplace 清单
├── .claude/
│   └── settings.local.json        # 本地 Claude 设置
├── .github/workflows/             # CI/CD 工作流
├── CLAUDE.md                      # Marketplace 指南（本文件）
├── README.md                      # Marketplace 说明
└── swiss-army-knife/              # 主插件目录
    ├── .claude-plugin/
    │   └── plugin.json            # 插件清单 (v0.5.0)
    ├── CLAUDE.md                  # 插件开发指南（详细）
    ├── README.md                  # 插件使用说明
    ├── CHANGELOG.md               # 版本历史
    ├── agents/                    # 47 个专业化 sub-agents
    │   ├── backend/               # 后端专用 (4 个)
    │   ├── bugfix/                # 通用 Bugfix (5 个)
    │   ├── ci-job/                # CI Job 修复 (7 个)
    │   ├── e2e/                   # E2E 测试专用 (4 个)
    │   ├── execute-plan/          # 计划执行 (5 个)
    │   ├── frontend/              # 前端专用 (4 个)
    │   ├── pr-review/             # PR Review (10 个)
    │   └── review/                # 通用 Review (8 个)
    ├── commands/                  # 8 个斜杠命令
    │   ├── execute-plan.md        # 计划执行工作流
    │   ├── fix-backend.md         # 后端 Bugfix 工作流
    │   ├── fix-e2e.md             # E2E Bugfix 工作流
    │   ├── fix-frontend.md        # 前端 Bugfix 工作流
    │   ├── fix-failed-job.md      # CI Job 修复工作流
    │   ├── fix-pr-review.md       # PR Review 工作流
    │   ├── merge-dep-prs.md       # 合并依赖更新 PR（Renovate/Dependabot）
    │   └── release.md             # 版本发布自动化
    ├── skills/                    # 10 个知识库
    │   ├── backend-bugfix/        # Python/FastAPI 错误模式
    │   ├── bugfix-workflow/       # 通用 TDD 流程
    │   ├── ci-job-analysis/       # CI 失败分析
    │   ├── coordinator-patterns/  # Coordinator 通用模式
    │   ├── e2e-bugfix/            # Playwright/Cypress 错误模式
    │   ├── elements-of-style/     # Strunk 写作规则
    │   ├── execute-plan/          # 计划执行模式
    │   ├── frontend-bugfix/       # React/TypeScript 错误模式
    │   ├── knowledge-patterns/    # PR Review 修复模式库
    │   └── pr-review-analysis/    # PR Review 分析
    ├── hooks/                     # 事件钩子
    │   ├── hooks.json             # Hook 配置
    │   └── scripts/               # Hook 脚本
    ├── config/                    # 默认配置
    │   └── defaults.yaml          # 多技术栈配置
    └── docs/                      # 文档和设计
        └── plans/                 # 设计文档
```

## 插件统计

| 类别 | 数量 |
|------|------|
| Commands | 8 |
| Agents | 47 |
| Skills | 10 |
| Hooks | 2 (PostToolUse, SessionStart) |

## 主要命令

### Bugfix 工作流（6 阶段）

| 命令 | 说明 |
|------|------|
| `/fix-frontend` | 前端 bugfix 工作流 (React/TypeScript/Vitest) |
| `/fix-backend` | 后端 bugfix 工作流 (Python/FastAPI/pytest) |
| `/fix-e2e` | E2E 测试 bugfix 工作流 (Playwright/Cypress) |

**阶段流程：**

```text
Phase 0: 初始化 + 错误分析 → Phase 1: 根因诊断 → Phase 2: 方案设计
    → Phase 3: 文档生成 → Phase 4: TDD 执行 → Phase 5: 验证审查
```

### PR Review 工作流（8 阶段）

| 命令 | 说明 |
|------|------|
| `/fix-pr-review <PR_NUMBER>` | 自动分析和修复 PR 中的代码审查评论 |

### CI Job 修复工作流（7 阶段）

| 命令 | 说明 |
|------|------|
| `/fix-failed-job <JOB_URL>` | 分析和修复失败的 GitHub Actions job |

### 工具命令

| 命令 | 说明 |
|------|------|
| `/merge-dep-prs [--bot=...]` | 合并依赖更新 PR（Renovate/Dependabot） |
| `/release [major\|minor\|patch]` | 自动化版本发布（更新 CHANGELOG, git tag） |

## 核心特性

### 1. 置信度驱动的流程控制

工作流基于置信度分数（0-100）智能决策。不同阶段使用不同阈值，反映业务场景差异：

#### 根因分析阶段（Bugfix Phase 1）

| 置信度 | 行为 | 原因 |
|--------|------|------|
| ≥60 | 自动继续 | 诊断存在不确定性，允许较低阈值 |
| 40-59 | 询问用户 | 需要用户确认方向 |
| <40 | 停止执行 | 信息不足，需收集更多上下文 |

#### 修复执行阶段（PR Review/CI Job Phase 4）

| 置信度 | 行为 | 原因 |
|--------|------|------|
| ≥80 | 自动修复 | 代码变更需要高确定性 |
| 60-79 | 询问用户 | 需用户审核后执行 |
| 40-59 | 标记/跳过 | 建议手动处理 |
| <40 | 跳过 | 置信度过低，回复 reviewer |

#### 代码审查阶段（Review Phase 5/7）

| 置信度 | 行为 | 原因 |
|--------|------|------|
| ≥80 | 报告并自动修复 | 避免误报噪声 |
| <80 | 不报告 | 仅内部追踪 |

> **设计原则**：根因分析允许较低阈值（60）因为诊断本身存在不确定性；修复执行要求较高阈值（80）因为代码变更影响直接。

### 2. 6+1 Review Agents 架构

在 Phase 5（Bugfix）或 Phase 7（PR Review）中，**6 个审查 agents 并行执行**：

- `code-reviewer` - 通用代码质量审查
- `silent-failure-hunter` - 静默失败检测
- `code-simplifier` - 代码简化和可维护性
- `test-analyzer` - 测试覆盖质量分析
- `comment-analyzer` - 注释准确性检查
- `type-design-analyzer` - 类型设计分析

**+ 1 个修复 agent 串行执行**：发现的 ≥80 置信度问题由 `review-fixer` agent 自动修复，最多 3 次循环。

### 3. 知识模式沉淀

高价值修复自动提取到 `skills/knowledge-patterns/` 知识库，支持：

- 智能相似度匹配
- 跨 PR 模式复用
- 实例合并去重

### 4. 模型使用策略

| 模型 | 用途 | 说明 |
|------|------|------|
| `opus` | 复杂分析、方案设计、代码审查 | 最强推理能力 |
| `sonnet` | 初始化、知识提取、配置加载 | 平衡性能成本 |
| `haiku` | 文档生成 | 快速低成本 |
| `inherit` | 验证、执行 | 保持上下文一致性 |

## 常用命令

### 开发环境

```bash
# 添加此 marketplace 到 Claude Code
/plugin marketplace add /path/to/swiss-army-knife-plugin

# 安装插件
/plugin install swiss-army-knife@swiss-army-knife-plugin

# 验证插件结构
/plugin validate swiss-army-knife/

# 重新安装（修改后）
/plugin uninstall swiss-army-knife@swiss-army-knife-plugin
/plugin install swiss-army-knife@swiss-army-knife-plugin
```

### Lint 检查

```bash
# 安装 lint 工具（首次）
npm install -g markdownlint-cli

# 运行 Markdown 格式检查
markdownlint '**/*.md' --ignore node_modules

# 检查单个文件
markdownlint swiss-army-knife/commands/fix-frontend.md
```

### 验证与测试

由于这是一个纯 Markdown/YAML 配置项目，没有传统的单元测试。验证方式：

1. **格式验证**：通过 markdownlint 检查 Markdown 格式
2. **链接验证**：CI 自动检查 Markdown 中的链接有效性
3. **功能验证**：安装插件后在目标项目中运行命令测试

### CI 工作流

| 工作流 | 触发条件 | 说明 |
|--------|----------|------|
| `markdown-lint.yml` | push/PR 修改 `.md` 文件 | Markdown 格式和链接检查 |
| `claude.yml` | push/PR | Claude Code 自动化任务 |
| `claude-code-review.yml` | PR | Claude Code 代码审查 |

## 项目配置

在目标项目中创建 `.claude/swiss-army-knife.yaml` 覆盖默认配置：

```yaml
stacks:
  frontend:
    test_command: "npm run test"
    lint_command: "npm run lint"
    typecheck_command: "npm run typecheck"
  backend:
    test_command: "pytest"
    lint_command: "ruff check"
```

## 贡献指南

### 编码规范

#### Markdown 文件

- 遵循 `.markdownlint.json` 配置规则
- 行长度限制 500 字符（代码块和表格除外）
- 使用 fenced 代码块（``` 而非缩进）
- 避免裸 HTML（允许：`<br>`, `<details>`, `<summary>`, `<img>`, `<a>`, `<sup>`, `<sub>`）

#### Agent 文件

```yaml
# 必需的 Frontmatter 字段
name: agent-name           # 唯一标识符，使用 kebab-case
description: Use this...   # 触发条件描述
model: opus|sonnet|haiku|inherit
tools: Read, Glob, Grep    # 显式工具权限
```

#### Command 文件

```yaml
# 必需的 Frontmatter 字段
description: 简短描述
argument-hint: "[--flag=value]"
allowed-tools: Read, Write, Task
```

#### 命名约定

| 类型 | 命名规则 | 示例 |
|------|----------|------|
| Agent | `{功能}-{角色}.md` | `error-analyzer.md`, `root-cause.md` |
| Command | `{动作}-{目标}.md` | `fix-frontend.md`, `merge-dep-prs.md` |
| Skill | `{技术栈}-{功能}/SKILL.md` | `frontend-bugfix/SKILL.md` |

### 代码审查流程

1. **提交 PR**：所有更改通过 PR 提交，不直接推送到 main
2. **CI 检查**：
   - Markdown 格式检查（markdownlint）
   - 链接有效性检查
   - Claude Code Review（自动）
3. **人工审查**：
   - Agent 逻辑正确性
   - Frontmatter 字段完整性
   - 工具权限最小化原则
4. **合并要求**：
   - CI 检查全部通过
   - 至少一个 Approve

### 新增组件检查清单

- [ ] Frontmatter 字段完整
- [ ] `name` 唯一且符合命名规范
- [ ] `tools` 只声明必需的工具
- [ ] `model` 根据任务复杂度选择合适的模型
- [ ] 通过 `markdownlint` 检查
- [ ] 更新 `plugin.json` 版本号（如适用）
- [ ] 更新 `CHANGELOG.md`

## 详细文档

- **插件开发指南**：[swiss-army-knife/CLAUDE.md](swiss-army-knife/CLAUDE.md)
- **使用说明**：[swiss-army-knife/README.md](swiss-army-knife/README.md)
- **版本历史**：[swiss-army-knife/CHANGELOG.md](swiss-army-knife/CHANGELOG.md)

## 相关文档

- [Claude Code 概述](https://code.claude.com/docs/en/overview)
- [Claude Code 插件介绍](https://www.anthropic.com/news/claude-code-plugins)
- [Agent Skills 介绍](https://www.anthropic.com/news/skills)
- [Sub-agents 指南](https://code.claude.com/docs/en/sub-agents)
- [Hooks 参考文档](https://code.claude.com/docs/en/hooks)
- [Claude Code 最佳实践](https://www.anthropic.com/engineering/claude-code-best-practices)
