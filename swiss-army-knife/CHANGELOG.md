# 变更日志

本项目的所有重要变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

## [0.3.0] - 2025-11-27

### Added
- 多技术栈支持：frontend, backend, e2e
- 配置系统：`config/defaults.yaml` + 项目级覆盖 (`.claude/swiss-army-knife.yaml`)
- 新命令：`/fix-frontend`, `/fix-backend`, `/fix-e2e`
- Backend/E2E 占位 Agent 和 Skill

### Changed
- 重命名 `/fix` → `/fix-frontend`
- Agent 目录结构：`agents/` → `agents/{stack}/`
- Skill 目录结构：`skills/bugfix-workflow/` → `skills/{stack}-bugfix/`
- 移除硬编码路径，改为配置驱动

### Migration
- 现有 `/fix` 用户需改用 `/fix-frontend`

## [0.2.1] - 2025-11-26

### 新增

- 添加 `/release` 命令，自动化版本发布流程
  - 支持 Claude Code 插件和 Node.js 项目的版本管理
  - 自动更新 CHANGELOG.md、plugin.json/package.json
  - 自动创建 git commit 和 tag
  - 支持 `--dry-run` 预览模式和 `--no-push` 选项

## [0.2.0] - 2025-11-26

### 新增

- 添加 Markdown CI 检查工作流，确保文档质量
- 在 CLAUDE.md 中添加官方最佳实践参考链接：
  - Claude Code 插件文档
  - Agent Skills 最佳实践
  - Sub-agents 最佳实践
  - Hooks 开发指南

### 修复

- 修复 Markdown lint 问题，提升文档可读性

## [0.1.0] - 2025-11-26

### 新增

- 初始插件结构，建立基础框架
- 实现标准化 6 阶段前端 bugfix 工作流：
  - Phase 0: 错误解析和分类
  - Phase 1: 根因诊断分析（带置信度评分）
  - Phase 2: TDD 修复方案设计
  - Phase 3: Bugfix 文档生成
  - Phase 4: TDD 实现（RED-GREEN-REFACTOR）
  - Phase 5: 质量门禁和知识沉淀
- 添加 6 个专业化 agents：
  - `error-analyzer`: 错误解析和分类
  - `root-cause`: 根因诊断
  - `solution`: 方案设计
  - `executor`: TDD 实现
  - `quality-gate`: 质量验证
  - `knowledge`: 知识提取
- 实现 `/fix` 主命令，协调整个工作流
- 添加 `bugfix-workflow` skill，提供错误模式知识库
- 配置 hooks，在测试失败或前端代码变更时触发建议
- 添加 GitHub Actions 工作流：
  - Claude PR Assistant workflow
  - Claude Code Review workflow
- 添加 CLAUDE.md，提供中文开发指导
- 完善插件元数据和文档

### 技术细节

- 支持 React/TypeScript 项目
- 置信度驱动的流程控制（≥60 自动继续，40-59 暂停询问，<40 停止收集信息）
- 针对 5 种常见错误类型的专业化处理（mock_conflict 71%、type_mismatch 15%、async_timing 8%、render_issue 4%、cache_dependency 2%）

[未发布]: https://github.com/penkzhou/swiss-army-knife-plugin/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/penkzhou/swiss-army-knife-plugin/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/penkzhou/swiss-army-knife-plugin/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/penkzhou/swiss-army-knife-plugin/releases/tag/v0.1.0
