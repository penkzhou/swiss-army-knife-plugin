---
description: 执行实施计划（六阶段流程）
argument-hint: "<PLAN_FILE> [--phase=0,1,2,3,4,5|all] [--dry-run] [--fast] [--skip-review] [--batch-size=N]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task, TodoWrite, AskUserQuestion
---

# Execute Plan Workflow v1.0

基于实施计划文件，执行标准化 6 阶段执行流程。

**宣布**："我正在使用 Execute Plan v1.0 工作流执行计划。"

---

## 参数解析

从用户输入中解析参数：

- `<PLAN_FILE>`：必填，计划文件路径
- `--phase=X,Y` 或 `--phase=all`：指定执行阶段（默认 all）
- `--dry-run`：只分析不执行修改
- `--fast`：跳过方案细化（Phase 2）
- `--skip-review`：跳过 Review 审查（Phase 4.2-4.3）
- `--batch-size=N`：覆盖默认批次大小（默认 3）

### Phase 依赖关系验证

**Phase 依赖关系**：

| Phase | 依赖 | 说明 |
| ----- | ---- | ---- |
| 0 | 无 | 可独立运行 |
| 1 | Phase 0 输出 | 需要 init_ctx |
| 2 | Phase 1 输出 | 需要验证结果 |
| 3 | Phase 1 输出 + 用户确认 | 需要执行顺序 |
| 4 | Phase 3 输出 | 需要执行结果 |
| 5 | Phase 4 输出 | 需要 Review 结果 |

**跳过 Phase 时的验证**：

如果指定 `--phase=N`（N > 0），检查是否存在前置 Phase 的输出：

- **不存在前置输出**：报错 "Phase N 依赖 Phase M 输出，请先运行 --phase=0,...,M 或使用 --phase=all"
- **存在前置输出**：继续执行

---

## Phase 0: 初始化与计划解析

### 0.0 计划文件前置检查

在调用 init-collector agent 之前，先验证计划文件：

1. **文件存在性**：确认 `PLAN_FILE` 路径存在
2. **文件非空**：检查文件内容非空
3. **格式识别**：确认是支持的格式（`.md`、`.yaml`、`.yml`）

**空文件处理**：

如果计划文件为空或只包含空白字符：

```text
错误：计划文件为空

文件路径: {PLAN_FILE}
建议：
1. 确认文件路径正确
2. 使用支持的格式（Markdown 或 YAML）编写计划
3. 参考 execute-plan skill 中的计划格式规范
```

**停止**，不继续执行。

### 0.1 启动 execute-plan-init-collector agent

使用 Task tool 调用 execute-plan-init-collector agent 初始化工作流上下文：

> 使用 execute-plan-init-collector agent 初始化计划执行工作流：
>
> ## 任务
>
> 1. 加载配置（defaults.yaml + 项目配置深度合并）
> 2. 解析计划文件
> 3. 收集项目信息（Git 状态、目录结构、技术栈检测）
>
> ## 计划文件路径
>
> [用户提供的 PLAN_FILE 路径]

### 0.2 验证 init-collector 输出

验证 init-collector 返回的 JSON 格式：

1. **格式验证**：确保返回有效 JSON

   **JSON 解析错误处理**：

   ```python
   try:
       result = json.loads(agent_output)
   except json.JSONDecodeError as e:
       # 停止执行，报告详细错误
       report_error({
           "code": "JSON_PARSE_ERROR",
           "message": f"init-collector agent 返回无效 JSON",
           "details": f"解析错误: {e.msg}，位置: 行 {e.lineno} 列 {e.colno}",
           "content_preview": agent_output[:200] + "..." if len(agent_output) > 200 else agent_output,
           "suggestion": "请检查 agent 输出是否被截断或包含非 JSON 内容"
       })
       # 停止，不继续执行
   ```

2. **必填字段检查**：
   - `config` 存在
   - `plan_info.path` 存在且非空
   - `tasks` 数组存在且非空
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
   - 格式无效：**停止**，报告 "Init collector 输出格式无效，内容预览: {前 200 字符}"
   - 必填字段缺失：**停止**，报告缺失的字段
   - `status` 为 `failed`：**停止**，报告错误详情

### 0.3 提取配置变量

从 init-collector 输出中提取配置变量，存储为 `init_ctx`，用于后续 Phase。

**常用路径快捷引用**：

| 数据 | 路径 |
|------|------|
| 测试命令 | `init_ctx["config"]["test_command"]` |
| Lint 命令 | `init_ctx["config"]["lint_command"]` |
| 类型检查命令 | `init_ctx["config"]["typecheck_command"]` |
| 批次大小 | `init_ctx["config"]["batch_size"]` |
| 计划标题 | `init_ctx["plan_info"]["title"]` |
| 任务列表 | `init_ctx["tasks"]` |
| 检测到的技术栈 | `init_ctx["project_info"]["detected_stack"]` |

**配置路径验证**：

在使用配置路径前，验证其存在性：

```python
# 验证必需路径
required_paths = [
    init_ctx["config"]["docs"]["best_practices_dir"],
    init_ctx["config"]["docs"]["bugfix_dir"]
]

for path in required_paths:
    if path and not path_exists(path):
        add_warning({
            "code": "PATH_NOT_FOUND",
            "message": f"配置路径不存在: {path}",
            "impact": "相关功能可能无法正常工作",
            "severity": "warning",
            "critical": False
        })
```

**init_ctx 持久化**：

- `init_ctx` 存储在当前会话内存中
- 跨会话恢复时需重新运行 Phase 0
- 使用 `--phase=N`（N > 0）跳过时，系统会验证 init_ctx 是否存在

### 0.4 记录到 TodoWrite

使用 TodoWrite 记录所有待执行任务，格式：

```text
- [T-001] {任务标题} - {复杂度}
- [T-002] ...
```

---

## Phase 1: 计划验证与依赖分析

### 1.1 启动 execute-plan-validator agent

使用 Task tool 调用 execute-plan-validator agent：

> 使用 execute-plan-validator agent 验证计划：
>
> ## init_ctx
>
> [Phase 0 的 init_ctx 输出]

### 1.2 验证 Agent 输出

验证 execute-plan-validator 返回的 JSON 格式：

1. **必填字段检查**：
   - `validation_results` 数组存在
   - `execution_order` 数组存在
   - `batches` 数组存在
   - `overall_confidence` 存在且为数字
   - `recommendation` 存在
2. **失败处理**：
   - 格式无效：**停止**，报告错误
   - `status` 为 `failed`（如循环依赖）：**停止**，报告详情

### 1.3 置信度验证与决策

**验证置信度分数**：

1. 检查 `overall_confidence` 存在且为数字
2. 检查范围 0-100

**无效分数处理**：

- 分数缺失：**停止**，报告 "Validator agent 未返回置信度分数"
- 非数字：**停止**，报告 "置信度分数格式无效"
- 超出范围（<0 或 >100）：**停止**，报告 "置信度分数超出有效范围 (0-100)"

**有效分数决策**：

| 置信度 | 行为 |
| -------- | ------ |
| >= 80 | 继续 Phase 2 |
| 60-79 | **暂停**，向用户展示验证结果并询问是否继续 |
| 40-59 | **暂停**，建议调整计划后重试 |
| < 40 | **停止**，报告计划无法执行 |

### 1.4 展示验证摘要

```text
=== 计划验证结果 ===

计划: {plan_info.title}
任务数: {total_tasks}
整体置信度: {overall_confidence}%
建议: {recommendation}

执行顺序:
1. [T-001] {title} (置信度: {confidence}%)
2. [T-002] {title} (置信度: {confidence}%)
...

批次划分:
- 批次 1: T-001, T-003 (可并行)
- 批次 2: T-002 (依赖 T-001)

问题:
- [T-002] 目标文件不存在（将创建）
```

---

## Phase 2: 方案细化（可选）

**跳过条件**：

- `--fast` 参数启用
- 计划已包含详细实施步骤

### 2.1 为每个任务生成 TDD 计划

对于每个任务，使用 Task tool 调用 bugfix-solution agent：

> 使用 bugfix-solution agent（stack: {detected_stack}）设计任务实施方案：
>
> ## 任务信息
>
> - ID: {task_id}
> - 标题: {title}
> - 描述: {description}
> - 目标文件: {files}
> - 依赖: {dependencies}
>
> ## 上下文
>
> 这是新功能实现任务（非 bugfix），请设计实现方案而非修复方案。
> 关注：
> - 合理的代码结构和模块划分
> - TDD 测试覆盖策略
> - 与现有代码的集成点
>
> ## 参考最佳实践
>
> - {init_ctx.config.docs.best_practices_dir}/README.md

### 2.2 汇总方案

收集所有任务的实施方案，存储为 `solutions`。

---

## Phase 3: 批次执行

### 3.1 Dry Run 检查

如果是 `--dry-run` 模式：

- 展示将要执行的操作
- **停止**，不实际执行

### 3.2 启动 execute-plan-executor-coordinator agent

使用 Task tool 调用 execute-plan-executor-coordinator agent：

> 使用 execute-plan-executor-coordinator agent 执行计划：
>
> ## init_ctx
>
> [Phase 0 的 init_ctx]
>
> ## validation_results
>
> [Phase 1 的验证结果]
>
> ## solutions（如有）
>
> [Phase 2 的方案]
>
> ## 执行参数
>
> - dry_run: {--dry-run}
> - batch_size: {--batch-size 或默认值}

### 3.3 验证执行结果

验证 executor-coordinator 返回的 JSON：

1. **必填字段检查**：
   - `execution_results` 数组存在
   - `summary` 存在
2. **失败处理**：
   - 全部失败：**停止**，展示失败详情
   - 部分失败：继续，但**必须保留失败上下文**

**部分失败上下文保留**：

当存在失败任务时，必须记录以下信息并传递给后续 Phase：

```python
failure_context = {
    "failed_tasks": [
        {
            "task_id": "T-002",
            "error_code": "TEST_FAILED",
            "error_message": "expected 'user' but got 'undefined'",
            "stack_trace": "...",  # 如有
            "retry_attempts": 2,
            "last_attempt_output": "..."
        }
    ],
    "blocked_tasks": ["T-003", "T-004"],  # 因依赖失败被阻塞的任务
    "partial_changes": [...]  # 失败前已完成的变更
}
```

**立即向用户展示**：

```text
⚠️ 部分任务执行失败：

失败任务：
- [T-002] 实现认证服务
  错误: TEST_FAILED - expected 'user' but got 'undefined'
  重试次数: 2

被阻塞任务：
- [T-003] 添加 API 路由（依赖 T-002）
- [T-004] 编写集成测试（依赖 T-002）

是否继续执行 Phase 4（Review）？
[Y] 是，审查已完成的任务
[N] 否，停止并查看失败详情
```

---

## Phase 4: 验证与 Review 审查

### 4.1 完整验证

运行完整验证：

```bash
# 运行所有测试
{init_ctx.config.test_command}

# 运行 lint
{init_ctx.config.lint_command}

# 运行类型检查
{init_ctx.config.typecheck_command}
```

如果验证失败，**暂停**并展示失败详情。

### 4.2 并行启动 6 个 review agents

**跳过条件**：`--skip-review` 参数启用

使用 Task tool **并行**调用以下 6 个 review agents：

```text
并行执行（agents/review/ 目录下的 agents）：
├── code-reviewer             # 通用代码审查
├── silent-failure-hunter     # 静默失败检测
├── code-simplifier           # 代码简化
├── test-analyzer             # 测试覆盖分析
├── comment-analyzer          # 注释准确性
└── type-design-analyzer      # 类型设计分析
```

每个 agent 的 prompt 模板：

> 使用 {agent_name} agent 审查代码变更：
>
> ## 变更文件
>
> [Phase 3 执行结果中的变更文件列表]
>
> ## 项目规范
>
> 参考 CLAUDE.md 中的项目规范
>
> ## 审查要求
>
> - 只报告置信度 ≥ 80 的问题
> - 输出标准 JSON 格式

### 4.3 汇总 review 结果

收集所有 review agents 的输出，汇总问题：

```python
all_issues = []
failed_agents = []
success_count = 0

for agent_result in review_results:
    if agent_result["status"] == "success":
        all_issues.extend(agent_result["issues"])
        success_count += 1
    else:
        # 记录失败的 agent
        failed_agents.append({
            "agent": agent_result["agent_name"],
            "error": agent_result.get("error", "Unknown error"),
            "status": agent_result["status"]
        })

# 最小覆盖检查（必须在分类之前）
MIN_REQUIRED_AGENTS = 4
if success_count < MIN_REQUIRED_AGENTS:
    # 停止执行，不继续 Review-Fix 循环
    report_error({
        "code": "INSUFFICIENT_REVIEW_COVERAGE",
        "message": f"Review 覆盖不足：{success_count}/6 agents 成功，最少需要 {MIN_REQUIRED_AGENTS} 个",
        "failed_agents": failed_agents,
        "suggestion": "请检查 agent 配置或重试"
    })
    # 停止，不继续执行

# 按严重程度分类
critical_issues = [i for i in all_issues if i["confidence"] >= 90]
important_issues = [i for i in all_issues if 80 <= i["confidence"] < 90]
fixable_issues = [i for i in all_issues if i.get("auto_fixable", False)]
```

**失败 Agent 处理**：

如果存在失败的 review agents：

1. **立即向用户展示警告**：
   ```text
   ⚠️ 以下 review agents 执行失败：
   - {agent_name}: {error}
   ```
2. **强制最少覆盖要求**：至少 4/6 个 agents 成功才继续执行
   - **不足时停止**：报告 "Review 覆盖不足：{success_count}/6 agents 成功，最少需要 4 个"
   - **不询问用户**：这是硬性要求，不是可选的

展示汇总：

```text
Review 汇总：
- 成功 Agents: {success_count}/6
- 失败 Agents: {failed_count} {failed_agents_list}
- 总问题数: {total}
- Critical (≥90): {critical_count}
- Important (80-89): {important_count}
- 可自动修复: {fixable_count}
```

### 4.4 Review-Fix 循环（最多 3 次）

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
       > - lint: {init_ctx.config.lint_command}
       > - typecheck: {init_ctx.config.typecheck_command}
       > - test: {init_ctx.config.test_command}

    2. 验证修复结果
       - 检查 review-fixer 输出的 verification_status
       - 如果验证失败，记录并继续

    3. 重新运行验证（快速）

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

### 4.5 展示最终 review 报告

```text
=== Review 最终报告 ===

迭代统计：
- 总迭代次数: {iteration}
- 初始问题数: {initial_count}
- 最终问题数: {final_count}
- 已修复问题: {fixed_count}

已修复问题列表：
- [CR-001] src/services/auth.ts:42 - 缺少错误处理 ✓
- [SFH-002] src/hooks/useAuth.ts:15 - 空 catch 块 ✓

剩余建议（未自动修复）：
- [TD-001] src/types/user.ts:30 - 类型设计可改进（需人工处理）

正面观察：
- 代码结构清晰
- 测试覆盖完整
```

---

## Phase 5: 汇总与知识沉淀

### 5.1 启动 execute-plan-summary-reporter agent

使用 Task tool 调用 execute-plan-summary-reporter agent：

> 使用 execute-plan-summary-reporter agent 生成执行报告：
>
> ## init_ctx
>
> [Phase 0 的输出]
>
> ## validation_results
>
> [Phase 1 的输出]
>
> ## execution_results
>
> [Phase 3 的输出]
>
> ## review_results
>
> [Phase 4 的输出]

### 5.2 启动 bugfix-knowledge agent

如果执行成功，启动 bugfix-knowledge agent 进行知识沉淀：

> 使用 bugfix-knowledge agent 基于以下执行过程，提取可沉淀的知识：
>
> ## 执行过程
>
> [完整执行过程记录]
>
> ## 现有文档
>
> - {init_ctx.config.docs.bugfix_dir}
> - {init_ctx.config.docs.best_practices_dir}
>
> ## 判断标准
>
> - 是否是新发现的问题模式？
> - 解决方案是否可复用？
> - 是否有值得记录的教训？

### 5.3 完成报告

汇总整个执行过程，向用户报告：

```text
=== 计划执行完成 ===

计划: {plan_title}
耗时: {duration}

执行结果:
- 总任务: {total}
- 已完成: {completed}
- 跳过: {skipped}
- 失败: {failed}

变更统计:
- 创建文件: {files_created}
- 修改文件: {files_modified}
- 新增代码: +{lines_added} 行

Review 结果:
- 发现问题: {issues_found}
- 已修复: {issues_fixed}

验证状态:
- 测试: {tests_status}
- Lint: {lint_status}
- 类型检查: {typecheck_status}

报告已保存: {report_path}

后续步骤:
1. {next_step_1}
2. {next_step_2}
```

---

## 异常处理

### E1: 置信度低（< 40）

- **行为**：停止执行，向用户报告
- **输出**：验证问题列表 + 改进建议

### E2: 循环依赖

- **行为**：停止执行，报告循环涉及的任务
- **输出**：依赖图 + 解决建议

### E3: 任务执行失败

- **行为**：记录失败，继续执行其他任务（如无依赖）
- **输出**：失败详情 + 可能原因

### E4: 验证失败

- **行为**：暂停，展示失败详情
- **输出**：测试/Lint/类型检查错误详情

### Agent 调用错误处理

所有 Task 工具调用 sub-agent 时应遵循以下错误处理：

#### AE1: Agent 调用超时

- **检测**：Task 工具超过 30 分钟未返回
- **行为**：**停止**当前 Phase
- **输出**："{agent_name} agent 响应超时，可能由于任务复杂度过高。建议：1) 简化任务范围 2) 手动提供部分信息 3) 重试"

#### AE2: Agent 输出截断

- **检测**：返回的 JSON 不完整（解析失败）
- **行为**：**停止**当前 Phase
- **输出**："{agent_name} agent 输出被截断，请重试或简化任务范围"

#### AE3: Agent 未返回预期格式

- **检测**：返回内容不是 JSON 或缺少必要字段
- **行为**：**停止**当前 Phase
- **输出**："{agent_name} agent 返回格式异常，预期 JSON 包含 {required_fields}，实际收到：{content_preview}"

---

## 关键原则

1. **TodoWrite 跟踪**：记录所有待执行任务，防止遗漏
2. **置信度驱动**：低置信度时停止，不要猜测
3. **TDD 强制**：所有代码变更必须通过 TDD 流程
4. **批次确认**：每批完成后等待用户确认
5. **增量验证**：每步后验证，不要积累问题
6. **知识沉淀**：有价值的经验必须记录
7. **用户确认**：关键决策点等待用户反馈
