# Swiss Army Knife Plugin

A personal collection of useful Claude Code components for daily development.

## Installation

```bash
# Add to Claude Code plugins
claude plugins add /path/to/swiss-army-knife-plugin

# Or link for development
claude plugins link /path/to/swiss-army-knife-plugin
```

## Components

### Commands

| Command | Description |
|---------|-------------|
| `/swiss-army-knife-plugin:fix` | 执行标准化前端 Bugfix 工作流（六阶段流程） |

### Agents

| Agent | Description |
|-------|-------------|
| `error-analyzer` | 解析测试输出，完成错误分类、历史匹配和文档匹配 |
| `root-cause` | 深入分析测试失败的根本原因，提供置信度评分 |
| `solution` | 设计完整的修复方案，包括 TDD 计划、影响分析和安全审查 |
| `executor` | 按 TDD 流程执行修复方案，进行增量验证 |
| `quality-gate` | 验证修复是否满足质量标准（覆盖率、lint、typecheck） |
| `knowledge` | 从修复过程中提取可沉淀的知识，生成文档 |

### Skills

| Skill | Description |
|-------|-------------|
| `bugfix-workflow` | 前端测试 bugfix 完整工作流知识，包括错误分类、置信度评分和 TDD 最佳实践 |

### Hooks

| Event | Trigger |
|-------|---------|
| `PostToolUse` | 前端测试失败后建议使用 bugfix 流程 |
| `SessionStart` | 检测到前端代码变更时提示 |

## Bugfix Workflow

六阶段工作流：

```
Phase 0: 问题收集与分类 → error-analyzer
Phase 1: 诊断分析       → root-cause
Phase 2: 方案设计       → solution
Phase 3: 方案文档化     → (主控制器)
Phase 4: 实施执行       → executor
Phase 5: 验证与沉淀     → quality-gate + knowledge
```

### 置信度评分

| 分数 | 级别 | 行为 |
|------|------|------|
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

```
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
├── hooks/                # Event handlers
│   └── hooks.json
└── scripts/              # Shared utilities
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
