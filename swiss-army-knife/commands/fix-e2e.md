---
description: 执行标准化 E2E Bugfix 工作流（六阶段流程）
argument-hint: "[--phase=0,1,2,3,4,5|all] [--dry-run]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task, TodoWrite, AskUserQuestion
---

# Bugfix E2E Workflow v2.2

基于测试失败的端到端用例，执行标准化 bugfix 流程。

**宣布**："我正在使用 Bugfix E2E v2.2 工作流进行问题修复。"

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

## Phase 0: 问题收集与分类

### 0.1 启动 init-collector agent

使用 Task tool 调用 e2e-init-collector agent 初始化工作流上下文：

> 使用 e2e-init-collector agent 初始化 bugfix 工作流：
>
> ## 任务
>
> 1. 加载配置（defaults.yaml + 项目配置深度合并）
> 2. 收集测试失败输出（如果用户未提供）
> 3. 收集项目信息（Git 状态、目录结构、依赖信息、浏览器配置）
>
> ## 用户提供的测试输出（如有）
>
> [如果用户提供了测试输出，粘贴在这里；否则留空让 agent 自动运行测试]

### 0.2 验证 init-collector 输出

验证 init-collector 返回的 JSON 格式：

1. **格式验证**：确保返回有效 JSON
2. **必填字段检查**：
   - `config.test_command` 存在且非空
   - `config.docs.bugfix_dir` 存在
   - `test_output.raw` 存在且非空
   - `test_output.status` 为有效值（`test_failed` | `command_failed` | `success`）
   - `project_info.plugin_root` 存在
3. **警告展示**：
   - 如果 `warnings` 数组存在且非空，**立即向用户展示所有警告**：

     ```text
     ⚠️ 初始化警告：
     - [{code}] {message}
       影响：{impact}
     ```

   - 如果任何警告的 `critical: true`，暂停询问用户是否继续
4. **失败处理**：
   - 格式无效：**停止**，报告 "Init collector 输出格式无效"
   - 必填字段缺失：**停止**，报告缺失的字段
   - `test_output.status` 为 `command_failed`：**停止**，报告 "测试命令执行失败，请检查环境配置"

### 0.3 提取配置变量

从 init-collector 输出中提取配置变量，存储为 `init_ctx`，用于后续 Phase。

**常用路径快捷引用**：

| 数据 | 路径 |
|------|------|
| 测试命令 | `init_ctx["config"]["test_command"]` |
| Lint 命令 | `init_ctx["config"]["lint_command"]` |
| Bugfix 文档目录 | `init_ctx["config"]["docs"]["bugfix_dir"]` |
| 最佳实践目录 | `init_ctx["config"]["docs"]["best_practices_dir"]` |
| 测试输出 | `init_ctx["test_output"]["raw"]` |
| 测试状态 | `init_ctx["test_output"]["status"]` |
| Git 变更文件 | `init_ctx["project_info"]["git"]["modified_files"]` |
| 浏览器配置 | `init_ctx["project_info"]["browser_config"]` |

**注意**：E2E 测试不需要独立的 `typecheck_command`，类型检查通常集成在构建流程中。

**init_ctx 持久化**：

- `init_ctx` 存储在当前会话内存中
- 跨会话恢复时需重新运行 Phase 0
- 使用 `--phase=N`（N > 0）跳过时，系统会验证 init_ctx 是否存在

**可选字段防护**：
构建 agent prompt 时，检查可选字段是否为 `null`：

- 如果 `init_ctx["project_info"]["git"]` 为 `null`：使用 "(Git 信息不可用)" 替代 git 相关字段
- 如果 `init_ctx["project_info"]["browser_config"]` 为 `null`：使用 "(浏览器配置不可用)" 替代
- 在 prompt 中明确标注哪些信息因不可用而缺失

### 0.4 启动 error-analyzer agent

使用 Task tool 调用 e2e-error-analyzer agent，**使用 init_ctx 中的数据**：

> 使用 e2e-error-analyzer agent 分析以下测试失败输出，完成错误解析、分类、历史匹配和文档匹配。
>
> ## 测试输出
>
> [从 init_ctx["test_output"]["raw"] 获取]
>
> ## 项目路径
>
> - bugfix 文档: [从 init_ctx["config"]["docs"]["bugfix_dir"] 获取]
> - troubleshooting: [从 init_ctx["config"]["docs"]["best_practices_dir"] 获取]/troubleshooting.md
>
> ## 项目上下文（供参考）
>
> - Git 变更文件: [如果 init_ctx["project_info"]["git"] 非 null，从 modified_files 获取；否则填 "(Git 信息不可用)"]
> - 最近 commit: [如果 init_ctx["project_info"]["git"] 非 null，从 last_commit 获取；否则填 "(Git 信息不可用)"]
> - 测试框架: [从 init_ctx["project_info"]["test_framework"] 获取]
> - 浏览器配置: [如果 init_ctx["project_info"]["browser_config"] 非 null，获取配置；否则填 "(浏览器配置不可用)"]

### 0.5 验证 error-analyzer 输出

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

### 0.6 记录到 TodoWrite

使用 TodoWrite 记录所有待处理错误，格式：

```text
- 处理错误 #1: [文件:行号] [错误类型] - [简述]
- 处理错误 #2: ...
```

---

## Phase 1: 诊断分析

### 1.1 启动 root-cause agent

使用 Task tool 调用 e2e-root-cause agent，prompt 示例：

> 使用 e2e-root-cause agent 进行根因分析：
>
> ## 结构化错误
>
> [Phase 0 error-analyzer 的输出]
>
> ## 相关代码
>
> [使用 Read 获取的相关代码]
>
> ## 参考诊断文档
>
> [从 init_ctx["config"]["docs"]["best_practices_dir"] 获取]/troubleshooting.md
>
> ## 项目上下文（供参考）
>
> - Git 变更文件: [如果 init_ctx["project_info"]["git"] 非 null，从 modified_files 获取；否则填 "(Git 信息不可用)"]
> - 最近 commit: [如果 init_ctx["project_info"]["git"] 非 null，从 last_commit 获取；否则填 "(Git 信息不可用)"]
> - 浏览器配置: [如果 init_ctx["project_info"]["browser_config"] 非 null，获取配置；否则填 "(浏览器配置不可用)"]

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

使用 Task tool 调用 e2e-solution agent，prompt 示例：

> 使用 e2e-solution agent 设计修复方案：
>
> ## 根因分析
>
> [Phase 1 root-cause 的输出]
>
> ## 参考最佳实践
>
> - [从 init_ctx["config"]["docs"]["best_practices_dir"] 获取]/README.md
> - [从 init_ctx["config"]["docs"]["best_practices_dir"] 获取]/implementation-guide.md

### 2.2 安全审查

如果涉及以下文件类型，进行安全审查：

- 认证流程 (`login`, `auth`, `session`)
- 敏感数据展示 (`password`, `token`, `secret`)
- 网络拦截 (`intercept`, `route`, `mock`)

---

## Phase 3: 方案文档化

### 3.1 启动 doc-writer agent

如果不是 `--dry-run` 模式，使用 Task tool 调用 e2e-doc-writer agent：

> 使用 e2e-doc-writer agent 生成 Bugfix 文档：
>
> ## 根因分析
>
> [Phase 1 root-cause 的输出]
>
> ## 修复方案
>
> [Phase 2 solution 的输出]
>
> ## 文档配置
>
> - bugfix_dir: [从 init_ctx["config"]["docs"]["bugfix_dir"] 获取]
> - 日期: [当前日期 YYYY-MM-DD]
> - 置信度: [Phase 1 的置信度分数]

### 3.2 验证 doc-writer 输出

验证 doc-writer 返回的 JSON 格式：

1. **Agent 响应验证**：
   - Task 工具返回值非空（null/undefined 检查）
   - 返回值是有效 JSON（可解析）
   - 如果失败：**停止**，报告 "doc-writer agent 未返回有效响应"

2. **必填字段检查**：
   - `status` 字段存在
   - `status` 为 "success"（不接受其他值如 "partial"）
   - `document.path` 存在且为非空字符串（长度 > 0）

3. **文件存在性验证**：
   - 使用 Read tool 验证 `document.path` 文件已创建
   - 如果文件不存在：**停止**，报告 "文档未创建，请检查目录权限"

4. **失败处理**：
   - `status` 为 "failed"：**停止**，报告 `error` 字段内容
   - `status` 为其他值：**停止**，报告 "doc-writer 返回未知状态: {status}"

### 3.3 等待用户确认

**询问用户**：
> "Bugfix 方案已生成，请查看 [doc-writer 输出的 document.path]。
> 确认后开始实施，或提出调整意见。"

如果是 `--dry-run` 模式，到此结束。

---

## Phase 4: 实施执行

### 4.1 启动 executor agent

使用 Task tool 调用 e2e-executor agent，prompt 示例：

> 使用 e2e-executor agent 执行 TDD 修复流程：
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
> - [从 init_ctx["config"]["test_command"] 获取]
> - [从 init_ctx["config"]["lint_command"] 获取]

### 4.2 批次报告

每批完成后向用户报告进度，等待确认后继续。

---

## Phase 5: 验证、审查与沉淀

### 5.1 启动 quality-gate agent

使用 Task tool 调用 e2e-quality-gate agent，prompt 示例：

> 使用 e2e-quality-gate agent 执行质量门禁检查：
>
> ## 变更文件
> [变更文件列表]
>
> ## 门禁标准
> - 所有 E2E 测试通过
> - 无视觉回归
> - lint 必须通过
> - 无功能回归

### 5.2 并行启动 6 个 review agents

使用 Task tool **并行**调用以下 6 个 review agents：

```text
并行执行：
├── review-code-reviewer      # 通用代码审查
├── review-silent-failure-hunter  # 静默失败检测
├── review-code-simplifier    # 代码简化
├── review-test-analyzer      # 测试覆盖分析
├── review-comment-analyzer   # 注释准确性
└── review-type-design-analyzer   # 类型设计分析
```

每个 agent 的 prompt 模板：

> 使用 {agent_name} agent 审查代码变更：
>
> ## 变更文件
> [变更文件列表，使用 git diff --name-only 获取]
>
> ## 项目规范
> 参考 CLAUDE.md 中的项目规范
>
> ## 审查要求
> - 只报告置信度 ≥ 80 的问题
> - 输出标准 JSON 格式

### 5.3 汇总 review 结果

收集所有 review agents 的输出，汇总问题：

```python
all_issues = []
for agent_result in review_results:
    if agent_result["status"] == "success":
        all_issues.extend(agent_result["issues"])

# 按严重程度分类
critical_issues = [i for i in all_issues if i["confidence"] >= 90]
important_issues = [i for i in all_issues if 80 <= i["confidence"] < 90]
fixable_issues = [i for i in all_issues if i.get("auto_fixable", False)]
```

展示汇总：

```text
Review 汇总：
- 总问题数: {total}
- Critical (≥90): {critical_count}
- Important (80-89): {important_count}
- 可自动修复: {fixable_count}
```

### 5.4 Review-Fix 循环（最多 3 次）

**循环条件**：存在置信度 ≥ 80 且 `auto_fixable: true` 的问题

**循环流程**：

```text
iteration = 0
max_iterations = 3
previous_issue_count = len(fixable_issues)
consecutive_no_improvement = 0
termination_reason = None

WHILE (存在 ≥80 的可修复问题) AND (iteration < max_iterations):

    1. 启动 review-fixer agent
       > 使用 review-fixer agent 修复以下问题：
       >
       > ## 待修复问题
       > [置信度 ≥80 且 auto_fixable 的问题列表]
       >
       > ## 验证命令
       > - lint: [init_ctx["config"]["lint_command"]]
       > - test: [init_ctx["config"]["test_command"]]

    2. 验证修复结果
       - 检查 review-fixer 输出的 verification_status
       - 如果验证失败，记录并继续

    3. 重新运行 quality-gate（快速验证）

    4. 重新运行 6 个 review agents（并行）

    5. 汇总新的问题列表
       current_issue_count = len(new_fixable_issues)

    6. 收敛检测
       IF current_issue_count >= previous_issue_count:
           consecutive_no_improvement++
           IF current_issue_count > previous_issue_count:
               termination_reason = "issues_increased"
               BREAK
           IF consecutive_no_improvement >= 2:
               termination_reason = "converged"
               BREAK
       ELSE:
           consecutive_no_improvement = 0
           previous_issue_count = current_issue_count

    7. iteration++

END WHILE

IF termination_reason IS NULL:
    IF len(new_fixable_issues) == 0:
        termination_reason = "no_fixable_issues"
    ELSE:
        termination_reason = "max_iterations"
```

**循环终止条件**：
- `no_fixable_issues` - 没有置信度 ≥ 80 的可修复问题
- `max_iterations` - 达到最大迭代次数（3 次）
- `converged` - 连续 2 次迭代问题数量未减少
- `issues_increased` - 问题数量增加，立即暂停

**问题增加时的处理**：
立即暂停并向用户报告新增问题列表。

### 5.5 展示最终 review 报告

```text
=== Review 最终报告 ===

迭代统计：
- 总迭代次数: {iteration}
- 初始问题数: {initial_count}
- 最终问题数: {final_count}
- 已修复问题: {fixed_count}

已修复问题列表：
- [CR-001] tests/e2e/login.spec.ts:42 - 选择器过于脆弱 ✓
- [SFH-002] tests/e2e/utils.ts:15 - 空 catch 块 ✓

剩余建议（未自动修复）：
- [TD-001] tests/e2e/fixtures.ts:30 - 类型设计可改进（需人工处理）

正面观察：
- 测试结构清晰
- Page Object 模式使用良好
```

### 5.6 启动 knowledge agent

如果质量门禁通过，使用 Task tool 调用 e2e-knowledge agent，prompt 示例：

> 使用 e2e-knowledge agent 提取可沉淀的知识：
>
> ## 修复过程
> [完整修复过程记录，包括 review-fix 循环]
>
> ## 现有文档
> - [从 init_ctx["config"]["docs"]["bugfix_dir"] 获取]
> - [从 init_ctx["config"]["docs"]["best_practices_dir"] 获取]
>
> ## 判断标准
> - 是否是新发现的问题模式？
> - 解决方案是否可复用？
> - 是否有值得记录的教训？
> - review 发现的问题是否值得记录到最佳实践？

### 5.7 完成报告

汇总整个修复过程，向用户报告：

- 修复的问题列表
- Review 审查结果
- 自动修复的问题
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

### E4: 环境问题

- **行为**：检查浏览器、网络、服务状态
- **输出**：环境问题诊断 + 修复建议

### Agent 调用错误处理

所有 Task 工具调用 sub-agent 时应遵循以下错误处理：

#### AE1: Agent 调用超时

- **检测**：Task 工具超过 30 分钟未返回
- **行为**：**停止**当前 Phase
- **输出**："{agent_name} agent 响应超时，可能由于项目复杂度过高或网络问题。建议：1) 简化问题范围 2) 手动提供部分信息 3) 重试"

#### AE2: Agent 输出截断

- **检测**：返回的 JSON 不完整（解析失败）
- **行为**：**停止**当前 Phase
- **输出**："{agent_name} agent 输出被截断，请重试或简化问题范围"

#### AE3: Agent 未返回预期格式

- **检测**：返回内容不是 JSON 或缺少必要字段
- **行为**：**停止**当前 Phase
- **输出**："{agent_name} agent 返回格式异常，预期 JSON 包含 {required_fields}，实际收到：{content_preview}"

---

## 关键原则

1. **TodoWrite 跟踪**：记录所有待处理项，防止遗漏
2. **置信度驱动**：低置信度时停止，不要猜测
3. **TDD 强制**：所有代码变更必须先写测试
4. **增量验证**：每步后验证，不要积累问题
5. **知识沉淀**：有价值的经验必须记录
6. **用户确认**：关键决策点等待用户反馈
7. **环境隔离**：确保测试环境稳定可重现
