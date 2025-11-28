# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**重要：请使用中文回答所有问题。**

## 仓库概述

这是一个 Claude Code 插件 marketplace 仓库，包含可安装的 Claude Code 插件集合。

## 目录结构

```text
swiss-army-knife-plugin/
├── .claude-plugin/marketplace.json  # Marketplace 清单
├── README.md                        # Marketplace 说明
└── swiss-army-knife/                # 插件目录
    ├── .claude-plugin/plugin.json   # 插件清单
    ├── CLAUDE.md                    # 插件开发指南（详细）
    ├── agents/                      # 专业化 sub-agents
    ├── commands/                    # 斜杠命令
    ├── skills/                      # 知识库
    ├── hooks/                       # 事件钩子
    └── config/                      # 默认配置
```

## 包含的插件

### swiss-army-knife

标准化 6 阶段 bugfix 工作流插件，支持多技术栈（后端、E2E、前端），以及 8 阶段 PR Code Review 处理工作流。

**主要命令：**

- `/fix-backend` - 后端 bugfix 工作流
- `/fix-e2e` - E2E 测试 bugfix 工作流
- `/fix-frontend` - 前端 bugfix 工作流
- `/fix-pr-review` - PR Code Review 处理工作流

**详细开发文档请参考：** `swiss-army-knife/CLAUDE.md`

## 开发操作

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

## 相关文档

- [Claude Code 插件文档](https://docs.anthropic.com/en/docs/claude-code/plugins)
- [Agent Skills 最佳实践](https://docs.anthropic.com/en/docs/claude-code/skills)
- [Sub-agents 指南](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
