---
description: 执行标准化 Backend Bugfix 工作流（六阶段流程）
argument-hint: "[--phase=0,1,2,3,4,5|all] [--dry-run]"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task", "TodoWrite", "AskUserQuestion"]
---

# Bugfix Backend Workflow v2.1

基于测试失败的后端用例，执行标准化 bugfix 流程。

**宣布**："我正在使用 Bugfix Backend v2.1 工作流进行问题修复。"

---

## 参数解析

从用户输入中解析参数：

- `--phase=X,Y` 或 `--phase=all`：指定执行阶段（默认 all）
- `--dry-run`：只分析不执行修改

### Phase 依赖关系验证

**Phase 依赖关系**：

| Phase | 依赖 | 说明 |
| ----- | ---- | ---- |
| 0 | 无 | 可独立运行 |
| 1 | Phase 0 输出 | 需要结构化错误数据 |
| 2 | Phase 1 输出 | 需要根因分析结果 |
| 3 | Phase 2 输出 | 需要修复方案 |
| 4 | Phase 3 输出 + 用户确认 | 需要 bugfix 文档 |
| 5 | Phase 4 输出 | 需要执行结果 |

**跳过 Phase 时的验证**：

如果指定 `--phase=N`（N > 0），检查是否存在前置 Phase 的输出：
- **不存在前置输出**：报错 "Phase N 依赖 Phase M 输出，请先运行 --phase=0,...,M 或使用 --phase=all"
- **存在前置输出**：继续执行

---

## 配置加载

### 加载步骤

执行以下步骤加载配置（使用 Read 工具）：

1. **读取插件默认配置**：使用 Glob 找到插件根目录，然后 Read `config/defaults.yaml`
2. **检查项目配置**：检查 `.claude/swiss-army-knife.yaml` 是否存在
3. **深度合并**：如存在项目配置，将其值覆盖默认配置（嵌套对象递归合并）
4. **提取技术栈配置**：从合并后的配置中提取 `stacks.backend` 部分

### 配置变量说明

以下变量需要在调用 Agent 时**手动替换**到 prompt 中（非自动模板）：

| 变量名 | 配置路径 | 说明 |
| ------ | -------- | ---- |
| `config.test_command` | `stacks.backend.test_command` | 测试命令 |
| `config.lint_command` | `stacks.backend.lint_command` | Lint 命令 |
| `config.typecheck_command` | `stacks.backend.typecheck_command` | 类型检查命令 |
| `config.docs.bugfix_dir` | `stacks.backend.docs.bugfix_dir` | Bugfix 文档目录 |
| `config.docs.best_practices_dir` | `stacks.backend.docs.best_practices_dir` | 最佳实践目录 |
| `config.docs.search_keywords` | `stacks.backend.docs.search_keywords` | 文档搜索关键词 |
| `config.error_patterns` | `stacks.backend.error_patterns` | 错误模式定义 |

### 配置注入示例

```python
# 伪代码：展示如何将配置值注入到 Agent prompt
config = load_and_merge_config()
backend = config["stacks"]["backend"]

# 构建实际 prompt 时替换变量
prompt = f"""
分析以下测试失败输出...

## 项目路径
- bugfix 文档: {backend["docs"]["bugfix_dir"]}
- troubleshooting: {backend["docs"]["best_practices_dir"]}/troubleshooting.md
"""
```

**注意**：本文档中的 `${config.*}` 语法是占位符标记，提示需要替换的位置。Claude 在执行时应读取配置文件并手动构建包含实际值的 prompt。

---

## Phase 0: 问题收集与分类

### 0.1 获取测试失败输出

如果用户没有提供测试输出，运行测试获取：

```bash
${config.test_command} 2>&1 | head -200
```

### 0.2 启动 error-analyzer agent

使用 Task tool 调用 backend-error-analyzer agent，prompt 示例：

> 使用 backend-error-analyzer agent 分析以下测试失败输出，完成错误解析、分类、历史匹配和文档匹配。
>
> ## 测试输出
> [粘贴测试输出]
>
> ## 项目路径
> - bugfix 文档: [从配置读取 docs.bugfix_dir]
> - troubleshooting: [从配置读取 docs.best_practices_dir]/troubleshooting.md

### 0.3 验证 Agent 输出

验证 error-analyzer 返回的 JSON 格式：

1. **格式验证**：确保返回有效 JSON
2. **必填字段检查**：
   - `errors` 数组存在且非空
   - 每个 error 包含 `id`, `file`, `category`
   - `summary.total` 与 `errors.length` 一致
3. **失败处理**：
   - 格式无效：**停止**，报告 "Error analyzer 输出格式无效"
   - 必填字段缺失：**停止**，报告缺失的字段
   - 空结果：报告 "未检测到错误，请确认测试是否真的失败"

### 0.4 记录到 TodoWrite

使用 TodoWrite 记录所有待处理错误，格式：

```text
- 处理错误 #1: [文件:行号] [错误类型] - [简述]
- 处理错误 #2: ...
```

---

## Phase 1: 诊断分析

### 1.1 启动 root-cause agent

使用 Task tool 调用 backend-root-cause agent，prompt 示例：

> 使用 backend-root-cause agent 进行根因分析：
>
> ## 结构化错误
> [Phase 0 的输出]
>
> ## 相关代码
> [使用 Read 获取的相关代码]
>
> ## 参考诊断文档
> [匹配的 troubleshooting 章节]

### 1.2 验证 Agent 输出

验证 root-cause 返回的 JSON 格式：

1. **必填字段检查**：
   - `root_cause.description` 非空
   - `confidence.score` 存在
   - `category` 为有效类型
2. **失败处理**：
   - 格式无效：**停止**，报告错误
   - 必填字段缺失：**停止**，报告缺失的字段

### 1.3 置信度验证与决策

**验证置信度分数**：

1. 检查 `confidence.score` 存在且为数字
2. 检查范围 0-100

**无效分数处理**：
- 分数缺失：**停止**，报告 "Root-cause agent 未返回置信度分数"
- 非数字：**停止**，报告 "置信度分数格式无效"
- 超出范围（<0 或 >100）：**停止**，报告 "置信度分数超出有效范围 (0-100)"

**有效分数决策**：

| 置信度 | 行为 |
| -------- | ------ |
| >= 60 | 继续 Phase 2 |
| 40-59 | **暂停**，向用户展示分析结果并询问是否继续 |
| < 40 | **停止**，向用户询问更多信息 |

---

## Phase 2: 方案设计

### 2.1 启动 solution agent

使用 Task tool 调用 backend-solution agent，prompt 示例：

> 使用 backend-solution agent 设计修复方案：
>
> ## 根因分析
> [Phase 1 的输出]
>
> ## 参考最佳实践
> - [从配置读取 docs.best_practices_dir]/README.md
> - [从配置读取 docs.best_practices_dir]/implementation-guide.md

### 2.2 安全审查

如果涉及以下文件类型，进行安全审查：

- 认证相关 (`auth`, `login`, `token`, `jwt`, `session`)
- 数据库操作 (`query`, `sql`, `orm`, `model`)
- API 端点 (`endpoint`, `route`, `api`)
- 用户输入处理 (`request`, `body`, `params`)

---

## Phase 3: 方案文档化

### 3.1 生成 Bugfix 文档

如果不是 `--dry-run` 模式，使用 Write tool 创建文档：

```text
文件路径: ${config.docs.bugfix_dir}/{YYYY-MM-DD}-{issue-slug}.md
```

文档模板：

```markdown
# [问题描述] Bugfix 报告

> 日期：{date}
> 置信度：{confidence}/100

## 1. 问题概述

### 1.1 错误信息
[结构化错误列表]

### 1.2 根因分析
[根因描述 + 证据]

## 2. 修复方案

### 2.1 主方案
[方案描述]

### 2.2 TDD 计划

#### RED Phase
```python
# 先写失败测试
```

#### GREEN Phase

```python
# 最小实现
```

#### REFACTOR Phase

- [ ] 重构项 1
- [ ] 重构项 2

### 2.3 影响分析

[影响范围]

### 2.4 风险评估

[风险列表]

## 3. 验证计划

- [ ] 单元测试通过
- [ ] 覆盖率 >= 90%
- [ ] 无回归
```

### 3.2 等待用户确认

**询问用户**：
> "Bugfix 方案已生成，请查看 ${config.docs.bugfix_dir}/{date}-{issue}.md。
> 确认后开始实施，或提出调整意见。"

如果是 `--dry-run` 模式，到此结束。

---

## Phase 4: 实施执行

### 4.1 启动 executor agent

使用 Task tool 调用 backend-executor agent，prompt 示例：

> 使用 backend-executor agent 执行 TDD 修复流程：
>
> ## TDD 计划
> [Phase 2 的 TDD 计划]
>
> ## 执行要求
> 1. RED: 先运行测试确认失败
> 2. GREEN: 实现最小代码使测试通过
> 3. REFACTOR: 重构代码保持测试通过
>
> ## 验证命令
> - [从配置读取 test_command] FILTER={test_file}
> - [从配置读取 lint_command]
> - [从配置读取 typecheck_command]

### 4.2 批次报告

每批完成后向用户报告进度，等待确认后继续。

---

## Phase 5: 验证与沉淀

### 5.1 启动 quality-gate agent

使用 Task tool 调用 backend-quality-gate agent，prompt 示例：

> 使用 backend-quality-gate agent 执行质量门禁检查：
>
> ## 变更文件
> [变更文件列表]
>
> ## 门禁标准
> - 覆盖率 >= 90%
> - 新增代码覆盖率 = 100%
> - lint/typecheck 必须通过
> - 无回归

### 5.2 启动 knowledge agent

如果质量门禁通过，使用 Task tool 调用 backend-knowledge agent，prompt 示例：

> 使用 backend-knowledge agent 提取可沉淀的知识：
>
> ## 修复过程
> [完整修复过程记录]
>
> ## 现有文档
> - [从配置读取 docs.bugfix_dir]
> - [从配置读取 docs.best_practices_dir]
>
> ## 判断标准
> - 是否是新发现的问题模式？
> - 解决方案是否可复用？
> - 是否有值得记录的教训？

### 5.3 完成报告

汇总整个修复过程，向用户报告：

- 修复的问题列表
- 验证结果
- 沉淀的知识（如有）

---

## 异常处理

### E1: 置信度低（< 40）

- **行为**：停止分析，向用户询问更多信息
- **输出**：已收集的信息 + 需要澄清的问题

### E2: 安全问题

- **行为**：阻塞实施，立即报告
- **输出**：安全漏洞详情 + 修复建议

### E3: 测试持续失败

- **行为**：最多重试 3 次，然后报告
- **输出**：失败详情 + 可能原因 + 建议

### E4: 覆盖率不达标

- **行为**：补充测试用例
- **输出**：缺失覆盖的代码区域

---

## 关键原则

1. **TodoWrite 跟踪**：记录所有待处理项，防止遗漏
2. **置信度驱动**：低置信度时停止，不要猜测
3. **TDD 强制**：所有代码变更必须先写测试
4. **增量验证**：每步后验证，不要积累问题
5. **知识沉淀**：有价值的经验必须记录
6. **用户确认**：关键决策点等待用户反馈
