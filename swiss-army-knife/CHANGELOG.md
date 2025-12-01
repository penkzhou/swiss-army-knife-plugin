# 变更日志

本项目的所有重要变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [未发布]

## [0.6.0] - 2025-12-01

### 新增

- **PR Review 工作流（8 阶段）**：通过 `/fix-pr-review <PR_NUMBER>` 自动分析和修复 PR 中的代码审查评论
  - Phase 0-2: 初始化、评论获取、评论过滤
  - Phase 3: 置信度评估和优先级分类
  - Phase 4: 调用对应技术栈的 bugfix 工作流
  - Phase 5-6: 生成回复并提交到 GitHub
  - Phase 7: 审查、汇总与知识沉淀

- **CI Job 修复工作流（7 阶段）**：通过 `/fix-failed-job <JOB_URL>` 自动分析和修复 GitHub Actions 失败的 job
  - 日志获取和错误提取
  - 失败类型分类和根因分析
  - 置信度驱动的修复决策
  - 可选 git commit 和 job retry

- **6 个并行 Review Agents**：在 Phase 5/7 中执行代码审查
  - `code-reviewer`: 通用代码审查
  - `silent-failure-hunter`: 静默失败检测
  - `code-simplifier`: 代码简化
  - `test-analyzer`: 测试覆盖分析
  - `comment-analyzer`: 注释准确性检查
  - `type-design-analyzer`: 类型设计分析
  - `review-fixer`: 自动修复 ≥80 置信度问题（最多 3 次循环）

- **知识模式库**：`skills/knowledge-patterns/` 支持高价值修复的智能沉淀和相似度匹配

- **elements-of-style Skill**：Strunk 写作规则，提升文档质量
  - 集成到 6 个生成人类可读文本的 agents
  - 轻量模式支持 6 条核心规则（含 Rule 12 具体语言）

### 变更

- 重构 bugfix agents：合并重复 agents 为共享 agents，通过 `stack` 参数区分技术栈
- 移除 comment-filter 的时间窗口过滤逻辑
- 更新 CLAUDE.md 文档，反映 8 个 skills

### 修复

- 修复 hooks.json 格式，对齐 Claude Code 官方规范
- 增强 agents 的错误处理和重试逻辑
- 修复 shell 脚本的健壮性问题

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

[未发布]: https://github.com/penkzhou/swiss-army-knife-plugin/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/penkzhou/swiss-army-knife-plugin/compare/v0.5.0...v0.6.0
[0.2.1]: https://github.com/penkzhou/swiss-army-knife-plugin/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/penkzhou/swiss-army-knife-plugin/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/penkzhou/swiss-army-knife-plugin/releases/tag/v0.1.0
