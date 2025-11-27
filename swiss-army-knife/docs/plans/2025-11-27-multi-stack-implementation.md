# Multi-Stack Bugfix Workflow 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 swiss-army-knife 插件从单一 frontend 支持重构为多技术栈（frontend/backend/e2e）支持，实现配置驱动的路径管理。

**Architecture:** 目录分组架构，每个技术栈有独立的 agent 集合。配置系统支持插件默认值 + 项目级覆盖。Command 负责读取配置并注入到 Agent prompt。

**Tech Stack:** Claude Code Plugin (Markdown + YAML + JSON)

---

## Task 1: 创建配置系统

**Files:**
- Create: `swiss-army-knife/config/defaults.yaml`

**Step 1: 创建 config 目录**

Run: `mkdir -p swiss-army-knife/config`

**Step 2: 创建默认配置文件**

```yaml
# swiss-army-knife/config/defaults.yaml
# Multi-stack bugfix workflow 默认配置
# 项目可通过 .claude/swiss-army-knife.yaml 覆盖

stacks:
  frontend:
    name: "Frontend (React/TypeScript)"
    test_command: "make test TARGET=frontend"
    lint_command: "make lint TARGET=frontend"
    typecheck_command: "make typecheck TARGET=frontend"
    docs:
      bugfix_dir: "docs/bugfix"
      best_practices_dir: "docs/best-practices"
      search_keywords:
        mock: ["mock", "msw", "vi.mock", "server.use", "HttpResponse"]
        async: ["async", "await", "findBy", "waitFor", "act"]
        type: ["typescript", "type", "interface", "as any", "generic"]
        render: ["render", "screen", "component", "props"]
        hook: ["useEffect", "useMemo", "useCallback", "useState"]
    error_patterns:
      mock_conflict:
        frequency: 71
        signals: ["vi.mock", "server.use"]
        description: "Mock 层次冲突（Hook Mock vs HTTP Mock）"
      type_mismatch:
        frequency: 15
        signals: ["as any", "type error", "Property.*does not exist"]
        description: "TypeScript 类型不匹配"
      async_timing:
        frequency: 8
        signals: ["findBy", "await", "act\\("]
        description: "异步操作时序问题"
      render_issue:
        frequency: 4
        signals: ["render", "screen", "not wrapped in act"]
        description: "组件渲染问题"
      cache_dependency:
        frequency: 2
        signals: ["useEffect", "useMemo", "dependency"]
        description: "Hook 缓存依赖问题"

  backend:
    name: "Backend (Node.js/Python)"
    test_command: "make test TARGET=backend"
    lint_command: "make lint TARGET=backend"
    typecheck_command: "make typecheck TARGET=backend"
    docs:
      bugfix_dir: "docs/bugfix"
      best_practices_dir: "docs/best-practices"
      search_keywords:
        database: ["database", "query", "ORM", "SQL", "transaction"]
        api: ["endpoint", "request", "response", "REST", "GraphQL"]
        auth: ["authentication", "authorization", "token", "JWT", "session"]
        validation: ["validation", "schema", "input", "sanitize"]
    error_patterns: {}  # 待项目实际使用时完善

  e2e:
    name: "E2E (Playwright/Cypress)"
    test_command: "make test TARGET=e2e"
    lint_command: "make lint TARGET=e2e"
    docs:
      bugfix_dir: "docs/bugfix"
      best_practices_dir: "docs/best-practices"
      search_keywords:
        selector: ["selector", "locator", "element", "getBy", "findBy"]
        timing: ["timeout", "wait", "retry", "polling"]
        network: ["intercept", "mock", "request", "route"]
        assertion: ["expect", "assert", "toHave", "toBe"]
    error_patterns: {}  # 待项目实际使用时完善
```

**Step 3: 验证 YAML 语法**

Run: `cat swiss-army-knife/config/defaults.yaml | head -20`
Expected: 文件内容正确显示，无语法错误

**Step 4: Commit**

```bash
git add swiss-army-knife/config/defaults.yaml
git commit -m "feat: add multi-stack default configuration"
```

---

## Task 2: 创建 frontend agent 目录结构

**Files:**
- Create: `swiss-army-knife/agents/frontend/` 目录
- Move: `agents/*.md` → `agents/frontend/*.md`

**Step 1: 创建 frontend 子目录**

Run: `mkdir -p swiss-army-knife/agents/frontend`

**Step 2: 移动现有 agent 文件**

Run:
```bash
cd swiss-army-knife && \
mv agents/error-analyzer.md agents/frontend/ && \
mv agents/root-cause.md agents/frontend/ && \
mv agents/solution.md agents/frontend/ && \
mv agents/executor.md agents/frontend/ && \
mv agents/quality-gate.md agents/frontend/ && \
mv agents/knowledge.md agents/frontend/
```

**Step 3: 验证移动结果**

Run: `ls -la swiss-army-knife/agents/frontend/`
Expected: 6 个 .md 文件

**Step 4: Commit**

```bash
git add swiss-army-knife/agents/
git commit -m "refactor: move agents to frontend subdirectory"
```

---

## Task 3: 创建 backend/e2e 占位 agent

**Files:**
- Create: `swiss-army-knife/agents/backend/error-analyzer.md`
- Create: `swiss-army-knife/agents/backend/root-cause.md`
- Create: `swiss-army-knife/agents/e2e/error-analyzer.md`
- Create: `swiss-army-knife/agents/e2e/root-cause.md`

**Step 1: 创建目录**

Run: `mkdir -p swiss-army-knife/agents/backend swiss-army-knife/agents/e2e`

**Step 2: 创建 backend error-analyzer 占位**

```markdown
<!-- swiss-army-knife/agents/backend/error-analyzer.md -->
---
model: opus
allowed-tools: ["Read", "Glob", "Grep"]
whenToUse: |
  Use this agent when analyzing backend test failures (Node.js, Python, etc.).

  Examples:
  <example>
  Context: User runs backend tests and they fail
  user: "make test TARGET=backend 失败了"
  assistant: "我将使用 backend-error-analyzer agent 分析测试失败"
  </example>
---

# Backend Error Analyzer Agent

> ⚠️ 此 Agent 为占位模板，需要根据项目实际情况完善。

你是后端测试错误分析专家。你的任务是解析测试输出，完成错误分类和文档匹配。

## 待定义内容

- [ ] 错误分类体系（参考 frontend 的 mock_conflict/type_mismatch 等）
- [ ] 后端特有错误模式（数据库连接、API 错误、认证失败等）
- [ ] 诊断文档映射

## 输出格式

返回结构化的分析结果（与 frontend 格式一致）：

```json
{
  "errors": [...],
  "summary": {...},
  "history_matches": [...],
  "troubleshoot_matches": [...]
}
```

## 工具使用

- **Read**: 读取测试文件和源代码
- **Glob**: 搜索历史文档
- **Grep**: 搜索特定错误模式
```

**Step 3: 创建 backend root-cause 占位**

```markdown
<!-- swiss-army-knife/agents/backend/root-cause.md -->
---
model: opus
allowed-tools: ["Read", "Glob", "Grep"]
whenToUse: |
  Use this agent for root cause analysis of backend test failures.

  Examples:
  <example>
  Context: Error analysis complete, need diagnosis
  user: "分析完错误了，帮我找根因"
  assistant: "我将使用 backend-root-cause agent 进行根因分析"
  </example>
---

# Backend Root Cause Agent

> ⚠️ 此 Agent 为占位模板，需要根据项目实际情况完善。

你是后端测试根因分析专家。基于错误分析结果，诊断问题根因。

## 待定义内容

- [ ] 后端特有的诊断模式
- [ ] 置信度评估标准
- [ ] 常见根因模板

## 输出格式

```json
{
  "root_cause": "根因描述",
  "confidence": 0-100,
  "evidence": ["证据列表"],
  "suggested_fix": "修复建议"
}
```
```

**Step 4: 创建 e2e error-analyzer 占位**

```markdown
<!-- swiss-army-knife/agents/e2e/error-analyzer.md -->
---
model: opus
allowed-tools: ["Read", "Glob", "Grep"]
whenToUse: |
  Use this agent when analyzing E2E test failures (Playwright, Cypress, etc.).

  Examples:
  <example>
  Context: User runs e2e tests and they fail
  user: "make test TARGET=e2e 失败了"
  assistant: "我将使用 e2e-error-analyzer agent 分析测试失败"
  </example>
---

# E2E Error Analyzer Agent

> ⚠️ 此 Agent 为占位模板，需要根据项目实际情况完善。

你是 E2E 测试错误分析专家。你的任务是解析测试输出，完成错误分类和文档匹配。

## 待定义内容

- [ ] E2E 错误分类体系（选择器失败、超时、网络拦截等）
- [ ] 浏览器特有错误模式
- [ ] 诊断文档映射

## 输出格式

返回结构化的分析结果：

```json
{
  "errors": [...],
  "summary": {...},
  "history_matches": [...],
  "troubleshoot_matches": [...]
}
```
```

**Step 5: 创建 e2e root-cause 占位**

```markdown
<!-- swiss-army-knife/agents/e2e/root-cause.md -->
---
model: opus
allowed-tools: ["Read", "Glob", "Grep"]
whenToUse: |
  Use this agent for root cause analysis of E2E test failures.

  Examples:
  <example>
  Context: E2E error analysis complete
  user: "E2E 测试失败分析完了，找根因"
  assistant: "我将使用 e2e-root-cause agent 进行根因分析"
  </example>
---

# E2E Root Cause Agent

> ⚠️ 此 Agent 为占位模板，需要根据项目实际情况完善。

你是 E2E 测试根因分析专家。基于错误分析结果，诊断问题根因。

## 待定义内容

- [ ] E2E 特有的诊断模式（DOM 变化、异步加载、网络延迟等）
- [ ] 置信度评估标准
- [ ] 常见根因模板

## 输出格式

```json
{
  "root_cause": "根因描述",
  "confidence": 0-100,
  "evidence": ["证据列表"],
  "suggested_fix": "修复建议"
}
```
```

**Step 6: 验证文件创建**

Run: `ls -la swiss-army-knife/agents/backend/ swiss-army-knife/agents/e2e/`
Expected: 每个目录 2 个 .md 文件

**Step 7: Commit**

```bash
git add swiss-army-knife/agents/backend/ swiss-army-knife/agents/e2e/
git commit -m "feat: add backend and e2e placeholder agents"
```

---

## Task 4: 更新 frontend agent 移除硬编码路径

**Files:**
- Modify: `swiss-army-knife/agents/frontend/error-analyzer.md`
- Modify: `swiss-army-knife/agents/frontend/knowledge.md`

**Step 1: 更新 error-analyzer.md**

将硬编码路径改为配置占位符说明。找到并替换以下内容：

原文：
```markdown
- 在 docs/bugfix/ 目录搜索相似案例
```

改为：
```markdown
- 在配置指定的 bugfix_dir 目录搜索相似案例（由 Command 通过 prompt 注入）
```

原文：
```markdown
| mock_conflict | troubleshooting.md#陷阱-1-过度依赖单元测试 |
```

改为：
```markdown
| mock_conflict | 搜索 best_practices_dir 中包含 "mock" 关键词的文档 |
```

**Step 2: 更新 knowledge.md**

找到并替换以下内容：

原文：
```markdown
## 文档存储位置

- **Bugfix 报告**：`docs/bugfix/YYYY-MM-DD-issue-name.md`
- **Troubleshooting**：`docs/best-practices/04-testing/frontend/troubleshooting.md`
- **Implementation Guide**：`docs/best-practices/04-testing/frontend/implementation-guide.md`
```

改为：
```markdown
## 文档存储位置

文档路径由配置指定（通过 Command prompt 注入）：

- **Bugfix 报告**：`{bugfix_dir}/YYYY-MM-DD-issue-name.md`
- **Best Practices**：`{best_practices_dir}/` 目录下搜索相关文档

如果搜索不到相关文档，创建占位文档引导团队完善。
```

**Step 3: 验证修改**

Run: `grep -n "docs/bugfix" swiss-army-knife/agents/frontend/*.md`
Expected: 无硬编码路径输出（或仅在注释/示例中）

**Step 4: Commit**

```bash
git add swiss-army-knife/agents/frontend/
git commit -m "refactor: remove hardcoded paths from frontend agents"
```

---

## Task 5: 重命名 fix.md 为 fix-frontend.md 并更新

**Files:**
- Rename: `commands/fix.md` → `commands/fix-frontend.md`
- Modify: 更新内容支持配置加载

**Step 1: 重命名文件**

Run: `mv swiss-army-knife/commands/fix.md swiss-army-knife/commands/fix-frontend.md`

**Step 2: 更新 frontmatter**

将文件开头的 frontmatter 从：
```yaml
---
description: 执行标准化前端 Bugfix 工作流（六阶段流程）
argument-hint: "[--phase=0,1,2,3,4,5|all] [--dry-run]"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task", "TodoWrite", "AskUserQuestion"]
---
```

改为：
```yaml
---
description: 执行标准化 Frontend Bugfix 工作流（六阶段流程）
argument-hint: "[--phase=0,1,2,3,4,5|all] [--dry-run]"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task", "TodoWrite", "AskUserQuestion"]
---
```

**Step 3: 添加配置加载逻辑**

在 `## Phase 0: 问题收集与分类` 之前添加新章节：

```markdown
## 配置加载

### 加载步骤

1. 读取插件默认配置: `${PLUGIN_ROOT}/config/defaults.yaml`
2. 检查项目配置: `.claude/swiss-army-knife.yaml`
3. 如存在项目配置，深度合并覆盖默认值
4. 提取 `stacks.frontend` 配置用于后续流程

### 配置变量

以下变量将注入到各 Agent prompt 中：

- `${config.test_command}` - 测试命令
- `${config.lint_command}` - Lint 命令
- `${config.typecheck_command}` - 类型检查命令
- `${config.docs.bugfix_dir}` - Bugfix 文档目录
- `${config.docs.best_practices_dir}` - 最佳实践目录
- `${config.docs.search_keywords}` - 文档搜索关键词
- `${config.error_patterns}` - 错误模式定义

---
```

**Step 4: 更新 Agent 调用**

将所有 `subagent_type: "swiss-army-knife-plugin:error-analyzer"` 改为 `subagent_type: "swiss-army-knife:frontend-error-analyzer"`

类似地更新其他 agent 引用：
- `root-cause` → `frontend-root-cause`
- `solution` → `frontend-solution`
- `executor` → `frontend-executor`
- `quality-gate` → `frontend-quality-gate`
- `knowledge` → `frontend-knowledge`

**Step 5: 更新硬编码命令**

将：
```bash
make test TARGET=frontend 2>&1 | head -200
```

改为：
```bash
${config.test_command} 2>&1 | head -200
```

**Step 6: 验证修改**

Run: `grep -n "swiss-army-knife-plugin:" swiss-army-knife/commands/fix-frontend.md`
Expected: 无输出（旧格式已全部替换）

**Step 7: Commit**

```bash
git add swiss-army-knife/commands/
git commit -m "refactor: rename fix to fix-frontend with config support"
```

---

## Task 6: 创建 fix-backend.md 和 fix-e2e.md 命令

**Files:**
- Create: `swiss-army-knife/commands/fix-backend.md`
- Create: `swiss-army-knife/commands/fix-e2e.md`

**Step 1: 创建 fix-backend.md**

```markdown
---
description: 执行标准化 Backend Bugfix 工作流（六阶段流程）
argument-hint: "[--phase=0,1,2,3,4,5|all] [--dry-run]"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task", "TodoWrite", "AskUserQuestion"]
---

# Bugfix Backend Workflow v0.1

> ⚠️ 此命令为占位模板，Agent 尚未完善。

基于测试失败的后端用例，执行标准化 bugfix 流程。

**宣布**："我正在使用 Bugfix Backend v0.1 工作流进行问题修复。"

---

## 配置加载

1. 读取插件默认配置: `${PLUGIN_ROOT}/config/defaults.yaml`
2. 检查项目配置: `.claude/swiss-army-knife.yaml`
3. 提取 `stacks.backend` 配置

---

## Phase 0: 问题收集与分类

### 0.1 获取测试失败输出

```bash
${config.test_command} 2>&1 | head -200
```

### 0.2 启动 error-analyzer agent

```yaml
subagent_type: "swiss-army-knife:backend-error-analyzer"
prompt: |
  分析以下测试失败输出...

  ## 配置
  - bugfix_dir: ${config.docs.bugfix_dir}
  - best_practices_dir: ${config.docs.best_practices_dir}
  - search_keywords: ${config.docs.search_keywords}
```

---

## Phase 1-5: 待完善

后续阶段参考 fix-frontend.md 实现，使用 backend-* agent。

当前仅支持 Phase 0 错误分析。
```

**Step 2: 创建 fix-e2e.md**

```markdown
---
description: 执行标准化 E2E Bugfix 工作流（六阶段流程）
argument-hint: "[--phase=0,1,2,3,4,5|all] [--dry-run]"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task", "TodoWrite", "AskUserQuestion"]
---

# Bugfix E2E Workflow v0.1

> ⚠️ 此命令为占位模板，Agent 尚未完善。

基于测试失败的 E2E 用例，执行标准化 bugfix 流程。

**宣布**："我正在使用 Bugfix E2E v0.1 工作流进行问题修复。"

---

## 配置加载

1. 读取插件默认配置: `${PLUGIN_ROOT}/config/defaults.yaml`
2. 检查项目配置: `.claude/swiss-army-knife.yaml`
3. 提取 `stacks.e2e` 配置

---

## Phase 0: 问题收集与分类

### 0.1 获取测试失败输出

```bash
${config.test_command} 2>&1 | head -200
```

### 0.2 启动 error-analyzer agent

```yaml
subagent_type: "swiss-army-knife:e2e-error-analyzer"
prompt: |
  分析以下测试失败输出...

  ## 配置
  - bugfix_dir: ${config.docs.bugfix_dir}
  - best_practices_dir: ${config.docs.best_practices_dir}
  - search_keywords: ${config.docs.search_keywords}
```

---

## Phase 1-5: 待完善

后续阶段参考 fix-frontend.md 实现，使用 e2e-* agent。

当前仅支持 Phase 0 错误分析。
```

**Step 3: 验证文件创建**

Run: `ls -la swiss-army-knife/commands/`
Expected: fix-frontend.md, fix-backend.md, fix-e2e.md, release.md

**Step 4: Commit**

```bash
git add swiss-army-knife/commands/fix-backend.md swiss-army-knife/commands/fix-e2e.md
git commit -m "feat: add fix-backend and fix-e2e placeholder commands"
```

---

## Task 7: 重命名 skill 目录

**Files:**
- Rename: `skills/bugfix-workflow/` → `skills/frontend-bugfix/`
- Create: `skills/backend-bugfix/SKILL.md` (占位)
- Create: `skills/e2e-bugfix/SKILL.md` (占位)

**Step 1: 重命名 frontend skill**

Run: `mv swiss-army-knife/skills/bugfix-workflow swiss-army-knife/skills/frontend-bugfix`

**Step 2: 更新 skill frontmatter**

修改 `skills/frontend-bugfix/SKILL.md` 的 frontmatter：

```yaml
---
name: frontend-bugfix
description: |
  Use this skill when debugging frontend test failures, fixing bugs in React/TypeScript code, or following TDD methodology for frontend bug fixes.
version: 2.1.0
---
```

**Step 3: 创建 backend-bugfix skill 占位**

```markdown
<!-- swiss-army-knife/skills/backend-bugfix/SKILL.md -->
---
name: backend-bugfix
description: |
  Use this skill when debugging backend test failures (Node.js, Python, etc.) or following TDD methodology for backend bug fixes.
version: 0.1.0
---

# Backend Bugfix Workflow Skill

> ⚠️ 此 Skill 为占位模板，待完善。

本 skill 提供后端测试 bugfix 的工作流知识。

## 待定义内容

- [ ] 错误分类体系
- [ ] 置信度评分系统
- [ ] TDD 流程（后端特化）
- [ ] 质量门禁标准

## 参考

参考 frontend-bugfix skill 的结构进行完善。
```

**Step 4: 创建 e2e-bugfix skill 占位**

```markdown
<!-- swiss-army-knife/skills/e2e-bugfix/SKILL.md -->
---
name: e2e-bugfix
description: |
  Use this skill when debugging E2E test failures (Playwright, Cypress, etc.) or following TDD methodology for E2E bug fixes.
version: 0.1.0
---

# E2E Bugfix Workflow Skill

> ⚠️ 此 Skill 为占位模板，待完善。

本 skill 提供 E2E 测试 bugfix 的工作流知识。

## 待定义内容

- [ ] 错误分类体系（选择器、超时、网络等）
- [ ] 置信度评分系统
- [ ] E2E 特有的调试技巧
- [ ] 质量门禁标准

## 参考

参考 frontend-bugfix skill 的结构进行完善。
```

**Step 5: 创建目录并写入文件**

Run: `mkdir -p swiss-army-knife/skills/backend-bugfix swiss-army-knife/skills/e2e-bugfix`

**Step 6: 验证结构**

Run: `ls -la swiss-army-knife/skills/`
Expected: frontend-bugfix/, backend-bugfix/, e2e-bugfix/

**Step 7: Commit**

```bash
git add swiss-army-knife/skills/
git commit -m "refactor: rename bugfix-workflow to frontend-bugfix, add placeholders"
```

---

## Task 8: 更新 plugin.json

**Files:**
- Modify: `swiss-army-knife/.claude-plugin/plugin.json`

**Step 1: 更新 plugin.json 内容**

```json
{
  "name": "swiss-army-knife",
  "version": "0.3.0",
  "description": "Multi-stack bugfix workflow plugin supporting frontend, backend, and e2e with 6-phase process",
  "author": {
    "name": "penkzhou"
  },
  "license": "MIT",
  "keywords": ["bugfix", "testing", "TDD", "frontend", "backend", "e2e", "workflow", "multi-stack"]
}
```

**Step 2: 验证 JSON 语法**

Run: `cat swiss-army-knife/.claude-plugin/plugin.json | python3 -m json.tool`
Expected: 格式化输出，无错误

**Step 3: Commit**

```bash
git add swiss-army-knife/.claude-plugin/plugin.json
git commit -m "chore: bump version to 0.3.0, update description"
```

---

## Task 9: 更新 README.md 添加配置说明

**Files:**
- Modify: `swiss-army-knife/README.md`

**Step 1: 更新 README 内容**

在现有内容基础上添加配置说明章节：

```markdown
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

## 命令

| 命令 | 说明 | 状态 |
|------|------|------|
| `/fix-frontend` | Frontend bugfix 工作流 | ✅ 完整 |
| `/fix-backend` | Backend bugfix 工作流 | 🔧 占位 |
| `/fix-e2e` | E2E bugfix 工作流 | 🔧 占位 |
```

**Step 2: Commit**

```bash
git add swiss-army-knife/README.md
git commit -m "docs: add configuration documentation to README"
```

---

## Task 10: 更新 CLAUDE.md

**Files:**
- Modify: `swiss-army-knife/CLAUDE.md`

**Step 1: 更新架构描述**

更新工作流流程图和组件说明，反映新的多技术栈架构。

**Step 2: 更新目标项目假设**

将：
```markdown
### 目标项目假设

工作流假设目标项目使用：

- `make test TARGET=frontend` 运行测试
```

改为：
```markdown
### 目标项目假设

工作流通过配置支持多种项目结构：

- 默认使用 `make test TARGET={stack}` 运行测试
- 可通过 `.claude/swiss-army-knife.yaml` 自定义命令和路径
- 文档路径支持关键词搜索，无需硬编码
```

**Step 3: Commit**

```bash
git add swiss-army-knife/CLAUDE.md
git commit -m "docs: update CLAUDE.md for multi-stack architecture"
```

---

## Task 11: 更新 CHANGELOG.md

**Files:**
- Modify: `swiss-army-knife/CHANGELOG.md`

**Step 1: 添加 v0.3.0 变更记录**

在文件顶部添加：

```markdown
## [0.3.0] - 2025-11-27

### Added
- 多技术栈支持：frontend, backend, e2e
- 配置系统：`config/defaults.yaml` + 项目级覆盖
- 新命令：`/fix-frontend`, `/fix-backend`, `/fix-e2e`
- Backend/E2E 占位 Agent 和 Skill

### Changed
- 重命名 `/fix` → `/fix-frontend`
- Agent 目录结构：`agents/{stack}/`
- Skill 目录结构：`skills/{stack}-bugfix/`
- 移除硬编码路径，改为配置驱动

### Migration
- 现有 `/fix` 用户需改用 `/fix-frontend`
```

**Step 2: Commit**

```bash
git add swiss-army-knife/CHANGELOG.md
git commit -m "docs: add v0.3.0 changelog"
```

---

## Task 12: 最终验证

**Step 1: 验证目录结构**

Run: `find swiss-army-knife -type f -name "*.md" -o -name "*.yaml" -o -name "*.json" | sort`

Expected 结构：
```
swiss-army-knife/.claude-plugin/plugin.json
swiss-army-knife/agents/backend/error-analyzer.md
swiss-army-knife/agents/backend/root-cause.md
swiss-army-knife/agents/e2e/error-analyzer.md
swiss-army-knife/agents/e2e/root-cause.md
swiss-army-knife/agents/frontend/error-analyzer.md
swiss-army-knife/agents/frontend/executor.md
swiss-army-knife/agents/frontend/knowledge.md
swiss-army-knife/agents/frontend/quality-gate.md
swiss-army-knife/agents/frontend/root-cause.md
swiss-army-knife/agents/frontend/solution.md
swiss-army-knife/commands/fix-backend.md
swiss-army-knife/commands/fix-e2e.md
swiss-army-knife/commands/fix-frontend.md
swiss-army-knife/commands/release.md
swiss-army-knife/config/defaults.yaml
swiss-army-knife/CHANGELOG.md
swiss-army-knife/CLAUDE.md
swiss-army-knife/README.md
swiss-army-knife/skills/backend-bugfix/SKILL.md
swiss-army-knife/skills/e2e-bugfix/SKILL.md
swiss-army-knife/skills/frontend-bugfix/SKILL.md
```

**Step 2: 验证无硬编码路径残留**

Run: `grep -r "docs/best-practices/04-testing" swiss-army-knife/`
Expected: 无输出或仅在注释/示例中

**Step 3: 创建最终 commit**

```bash
git add .
git commit -m "feat: complete multi-stack bugfix workflow v0.3.0"
```

---

## 完成检查清单

- [ ] Task 1: 配置系统创建
- [ ] Task 2: Frontend agent 目录迁移
- [ ] Task 3: Backend/E2E 占位 agent 创建
- [ ] Task 4: Frontend agent 移除硬编码路径
- [ ] Task 5: fix.md 重命名并更新
- [ ] Task 6: fix-backend.md 和 fix-e2e.md 创建
- [ ] Task 7: Skill 目录重命名和占位创建
- [ ] Task 8: plugin.json 更新
- [ ] Task 9: README.md 配置说明
- [ ] Task 10: CLAUDE.md 更新
- [ ] Task 11: CHANGELOG.md 更新
- [ ] Task 12: 最终验证
