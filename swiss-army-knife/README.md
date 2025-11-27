# Swiss Army Knife Plugin

Standardized bugfix workflow plugin with multi-stack support (frontend, backend, e2e) featuring a 6-phase process: error analysis, root cause diagnosis, solution design, TDD execution, quality verification, and knowledge extraction.

## Installation

```bash
# First, add the plugin marketplace (if not already added)
/plugin marketplace add /path/to/marketplace

# Then install the plugin
/plugin install swiss-army-knife-plugin@marketplace-name

# Or for local development, add a local marketplace containing this plugin
/plugin marketplace add /path/to/local-marketplace
/plugin install swiss-army-knife-plugin@local-marketplace
```

## 配置

### 默认配置

插件提供开箱即用的默认配置，位于 `config/defaults.yaml`。

### 项目级覆盖

在项目根目录创建 `.claude/swiss-army-knife.yaml` 可覆盖默认配置：

```yaml
# .claude/swiss-army-knife.yaml
stacks:
  frontend:
    test_command: "pnpm test:unit"  # 覆盖测试命令
    docs:
      best_practices_dir: "documentation/testing"  # 自定义文档路径
```

### 配置项说明

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `test_command` | 测试运行命令 | `make test TARGET={stack}` |
| `lint_command` | Lint 检查命令 | `make lint TARGET={stack}` |
| `docs.bugfix_dir` | Bugfix 文档目录 | `docs/bugfix` |
| `docs.best_practices_dir` | 最佳实践目录 | `docs/best-practices` |
| `docs.search_keywords` | 文档搜索关键词 | 见 defaults.yaml |

## Components

## 命令

| 命令 | 说明 | 状态 |
|------|------|------|
| `/fix-frontend` | Frontend bugfix 工作流 | ✅ 完整 |
| `/fix-backend` | Backend bugfix 工作流 | 🔧 占位 |
| `/fix-e2e` | E2E bugfix 工作流 | 🔧 占位 |
| `/release` | 发布流程 | ✅ 完整 |

### Commands (Legacy)

### Agents

| Agent | Description |
| ------- | ------------- |
| `error-analyzer` | 解析测试输出，完成错误分类、历史匹配和文档匹配 |
| `root-cause` | 深入分析测试失败的根本原因，提供置信度评分 |
| `solution` | 设计完整的修复方案，包括 TDD 计划、影响分析和安全审查 |
| `executor` | 按 TDD 流程执行修复方案，进行增量验证 |
| `quality-gate` | 验证修复是否满足质量标准（覆盖率、lint、typecheck） |
| `knowledge` | 从修复过程中提取可沉淀的知识，生成文档 |

### Skills

| Skill | Description |
| ------- | ------------- |
| `bugfix-workflow` | 前端测试 bugfix 完整工作流知识，包括错误分类、置信度评分和 TDD 最佳实践 |

### Hooks

| Event | Trigger |
| ------- | --------- |
| `PostToolUse` | 前端测试失败后建议使用 bugfix 流程 |
| `SessionStart` | 检测到前端代码变更时提示 |

## Bugfix Workflow

六阶段工作流：

```text
Phase 0: 问题收集与分类 → error-analyzer
Phase 1: 诊断分析       → root-cause
Phase 2: 方案设计       → solution
Phase 3: 方案文档化     → (主控制器)
Phase 4: 实施执行       → executor
Phase 5: 验证与沉淀     → quality-gate + knowledge
```

### 置信度评分

| 分数 | 级别 | 行为 |
| ------ | ------ | ------ |
| 80+ | 高 | 自动执行 |
| 60-79 | 中 | 标记验证后继续 |
| 40-59 | 低 | 暂停询问用户 |
| <40 | 不确定 | 停止收集信息 |

### 使用示例

```bash
# 完整工作流
/swiss-army-knife-plugin:fix

# 只执行特定阶段
/swiss-army-knife-plugin:fix --phase=0,1

# 预览模式（不执行修改）
/swiss-army-knife-plugin:fix --dry-run
```

## Directory Structure

```text
swiss-army-knife-plugin/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── commands/             # Slash commands
│   └── fix.md           # Bugfix workflow command
├── agents/               # Subagents
│   ├── error-analyzer.md
│   ├── root-cause.md
│   ├── solution.md
│   ├── executor.md
│   ├── quality-gate.md
│   └── knowledge.md
├── skills/               # Auto-activated skills
│   └── bugfix-workflow/
│       └── SKILL.md
└── hooks/                # Event handlers
    └── hooks.json
```

## Development

Add new components:

1. **Commands**: Create `.md` files in `commands/`
2. **Agents**: Create `.md` files in `agents/`
3. **Skills**: Create subdirectory in `skills/` with `SKILL.md`
4. **Hooks**: Update `hooks/hooks.json`

Use `${CLAUDE_PLUGIN_ROOT}` for portable path references.

## License

MIT
