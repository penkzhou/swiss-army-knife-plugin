# Swiss Army Knife Plugin

多技术栈标准化工作流插件，支持 6 阶段 Bugfix、8 阶段 PR Review、7 阶段 CI Job 修复和 6 阶段计划执行工作流。所有工作流采用统一的三层架构，实现完全闭环。

## 特性

- **完全闭环架构**：命令层仅做参数解析，所有逻辑由 master-coordinator 管理
- **共享 Review 组件**：6 个 review agents + review-coordinator 被所有工作流复用
- **置信度驱动决策**：自动/询问/跳过基于分析置信度
- **TDD 实践**：强制 RED-GREEN-REFACTOR 流程
- **知识沉淀**：高价值修复自动提取到知识库

## Installation

```bash
# 添加 marketplace
/plugin marketplace add /path/to/swiss-army-knife-plugin

# 安装插件
/plugin install swiss-army-knife@swiss-army-knife-plugin
```

## 配置

### 项目级配置

在项目根目录创建 `.claude/swiss-army-knife.yaml`：

```yaml
stacks:
  frontend:
    test_command: "pnpm test:unit"
    lint_command: "pnpm lint"
    typecheck_command: "pnpm typecheck"
  backend:
    test_command: "pytest"
    lint_command: "ruff check"
```

## 命令

| 命令 | 说明 | 阶段 |
|------|------|------|
| `/fix-frontend` | Frontend bugfix 工作流 | 6 阶段 (Phase 0-5) |
| `/fix-backend` | Backend bugfix 工作流 | 6 阶段 (Phase 0-5) |
| `/fix-e2e` | E2E bugfix 工作流 | 6 阶段 (Phase 0-5) |
| `/fix-pr-review <PR_NUMBER>` | PR Review 处理工作流 | 8 阶段 (Phase 0-7) |
| `/fix-failed-job <JOB_URL>` | CI Job 修复工作流 | 7 阶段 (Phase 0-6) |
| `/execute-plan <PLAN_FILE>` | 计划执行工作流 | 6 阶段 (Phase 0-5) |

## 架构

### 统一三层架构

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

### 组件统计

| 类别 | 数量 |
|------|------|
| Commands | 6 |
| Agents | 47 |
| Skills | 10 |
| Hooks | 2 |

### Agents 分布

| 目录 | 数量 | 说明 |
|------|------|------|
| `agents/bugfix/` | 5 | 共享 Bugfix agents (含 master-coordinator) |
| `agents/backend/` | 4 | 后端专用 agents |
| `agents/e2e/` | 4 | E2E 测试专用 agents |
| `agents/frontend/` | 4 | 前端专用 agents |
| `agents/pr-review/` | 10 | PR Review agents (含 master-coordinator) |
| `agents/ci-job/` | 7 | CI Job 修复 agents (含 master-coordinator) |
| `agents/execute-plan/` | 5 | 计划执行 agents (含 master-coordinator) |
| `agents/review/` | 8 | 共享 Review agents (含 review-coordinator) |

### Review Agents (共享)

在所有工作流的 Review 阶段并行执行：

- `review-coordinator` - 管理 Review-Fix 循环
- `code-reviewer` - 通用代码审查
- `silent-failure-hunter` - 静默失败检测
- `code-simplifier` - 代码简化
- `test-analyzer` - 测试覆盖分析
- `comment-analyzer` - 注释准确性
- `type-design-analyzer` - 类型设计分析
- `review-fixer` - 自动修复 ≥80 置信度问题

## 工作流

### Bugfix 工作流 (6 阶段)

```text
Phase 0: 问题收集与分类 → init-collector + error-analyzer
Phase 1: 诊断分析       → root-cause (置信度决策)
Phase 2: 方案设计       → solution
Phase 3: 方案文档化     → doc-writer
Phase 4: 实施执行       → executor (TDD)
Phase 5: 验证与审查     → review-coordinator + knowledge
```

### 置信度评分

| 分数 | 级别 | 行为 |
|------|------|------|
| ≥80 | 高 | 自动执行 |
| 60-79 | 中 | 询问用户后执行 |
| 40-59 | 低 | 展示分析，建议手动 |
| <40 | 极低 | 跳过 |

## 使用示例

### Bugfix

```bash
# 完整工作流
/fix-frontend

# 只执行分析阶段
/fix-frontend --phase=0,1

# 预览模式
/fix-frontend --dry-run
```

### PR Review

```bash
# 处理 PR 评论
/fix-pr-review 123

# 指定优先级
/fix-pr-review 123 --priority=P0,P1
```

### CI Job 修复

```bash
# 修复失败的 job
/fix-failed-job https://github.com/owner/repo/actions/runs/12345/job/67890

# 修复后自动提交并重试
/fix-failed-job https://github.com/owner/repo/actions/runs/12345/job/67890 --auto-commit --retry-job
```

### 计划执行

```bash
# 执行计划
/execute-plan path/to/plan.md

# 快速模式（跳过方案细化）
/execute-plan path/to/plan.md --fast
```

## 目录结构

```text
swiss-army-knife/
├── .claude-plugin/
│   └── plugin.json           # 插件清单
├── commands/                  # 6 个命令
│   ├── fix-frontend.md
│   ├── fix-backend.md
│   ├── fix-e2e.md
│   ├── fix-pr-review.md
│   ├── fix-failed-job.md
│   └── execute-plan.md
├── agents/                    # 47 个 agents
│   ├── bugfix/               # 共享 Bugfix (含 master-coordinator)
│   ├── backend/              # 后端专用
│   ├── e2e/                  # E2E 专用
│   ├── frontend/             # 前端专用
│   ├── pr-review/            # PR Review (含 master-coordinator)
│   ├── ci-job/               # CI Job (含 master-coordinator)
│   ├── execute-plan/         # Execute Plan (含 master-coordinator)
│   └── review/               # 共享 Review (含 review-coordinator)
├── skills/                    # 10 个知识库
│   ├── bugfix-workflow/
│   ├── backend-bugfix/
│   ├── e2e-bugfix/
│   ├── frontend-bugfix/
│   ├── pr-review-analysis/
│   ├── ci-job-analysis/
│   ├── knowledge-patterns/
│   ├── elements-of-style/
│   ├── execute-plan/
│   └── coordinator-patterns/
├── hooks/                     # 事件钩子
│   └── hooks.json
└── config/                    # 默认配置
    └── defaults.yaml
```

## License

MIT
