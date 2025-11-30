---
description: 修复失败的 GitHub Action job（7 阶段流程，Phase 0-6）
argument-hint: "<JOB_URL> [--dry-run] [--auto-commit] [--retry-job] [--phase=0,1,2,3,4,5,6|all]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task, TodoWrite, AskUserQuestion, SlashCommand
---

# Fix Failed Job Workflow v1.0

自动分析和修复失败的 GitHub Action job。

**宣布**："我正在使用 Fix Failed Job v1.0 工作流分析并修复 CI Job 失败。"

---

## 参数解析

从用户输入中解析参数：

- `<JOB_URL>`：必填，失败的 job URL
- `--dry-run`：只分析不执行修复
- `--auto-commit`：修复后自动创建 git commit
- `--retry-job`：修复后触发 job 重新运行
- `--phase`：指定执行阶段（默认 all）

### 参数验证

1. `JOB_URL` 必须匹配 GitHub Actions job URL 格式
2. 如果未提供 `JOB_URL`，询问用户
3. `--phase` 必须是 0-6 的数字或 `all`

### URL 格式验证

支持的格式：

```text
https://github.com/{owner}/{repo}/actions/runs/{run_id}/job/{job_id}
https://github.com/{owner}/{repo}/actions/runs/{run_id}/jobs/{job_id}
```

---

## Phase 0: 初始化

### 0.1 启动 init-collector agent

使用 Task tool 调用 ci-job-init-collector agent：

> 使用 ci-job-init-collector agent 初始化 CI Job 修复工作流：
>
> ## 任务
>
> 1. 解析 Job URL
> 2. 验证 GitHub CLI 可用性
> 3. 获取 Job 和 Workflow Run 元信息
> 4. 验证 Job 状态（必须是已完成且失败）
> 5. 加载配置
>
> ## Job URL
>
> {JOB_URL}

### 0.2 验证 init-collector 输出

验证返回的 JSON 格式：

1. **格式验证**：确保返回有效 JSON
2. **必填字段检查**：
   - `job_info.id` 存在
   - `job_info.conclusion` 为 `failure`
   - `repo_info` 对象存在
   - `config` 对象存在
3. **警告展示与处理**：
   - 如果 `warnings` 存在且非空：
     a. **区分 critical 和 non-critical 警告**
     b. **Critical 警告** (`warning.critical == true`)：
        - 向用户显示并**询问是否继续**
        - 示例：配置解析失败、gh CLI 认证问题
     c. **Non-critical 警告** (`warning.critical == false`)：
        - 仅显示信息，不阻塞流程
        - 示例：使用了备用方案、建议更新配置

   **警告展示格式**：

   ```text
   ⚠️ 发现 {n} 个警告：

   🔴 Critical:
   - [CONFIG_PARSE_ERROR] 项目配置文件格式错误，使用默认配置
     建议: 请修复 .claude/swiss-army-knife.yaml 格式

   🟡 Non-critical:
   - [FALLBACK_USED] 主命令失败，使用备用方案获取日志

   继续执行？[Y/N]  (仅当存在 critical 警告时询问)
   ```

4. **失败处理**：
   - 格式无效：**停止**
   - Job 不存在：**停止**
   - Job 仍在运行：**停止**
   - Job 未失败：**停止**
   - gh CLI 不可用：**停止**

### 0.3 提取上下文变量

从 init-collector 输出中提取，存储为 `init_ctx`：

| 数据 | 路径 |
|------|------|
| Job ID | `init_ctx["job_info"]["id"]` |
| Run ID | `init_ctx["job_info"]["run_id"]` |
| Job 名称 | `init_ctx["job_info"]["name"]` |
| 仓库 | `init_ctx["repo_info"]["full_name"]` |
| 配置 | `init_ctx["config"]` |

---

## Phase 1: 日志获取与解析

### 1.1 启动 log-fetcher agent

使用 Task tool 调用 ci-job-log-fetcher agent：

> 使用 ci-job-log-fetcher agent 获取并解析 Job 日志：
>
> ## Job 信息
>
> - Job ID: {init_ctx["job_info"]["id"]}
> - Run ID: {init_ctx["job_info"]["run_id"]}
> - 仓库: {init_ctx["repo_info"]["full_name"]}
> - Job 名称: {init_ctx["job_info"]["name"]}
>
> ## 任务
>
> 1. 下载完整 Job 日志
> 2. 识别失败的 step(s)
> 3. 提取错误相关的日志片段
> 4. 初步分类失败类型

### 1.2 验证输出

1. 检查 `status` 字段：
   - `success`：继续正常流程
   - `partial`：日志解析不完整，需要特殊处理（见下方）
   - `failed`：**停止**并报告错误
2. 检查 `failed_steps` 数组是否存在且非空
3. 如果日志不可用（`LOGS_UNAVAILABLE`），**停止**并报告

**`status: partial` 的特殊处理**：

当 log-fetcher 返回 `status: partial` 时，表示日志解析不完整：

1. **检查 `blocks_auto_fix` 标志**：
   - 如果 `blocks_auto_fix: true`：
     - 设置工作流上下文 `workflow_ctx.blocks_auto_fix = true`
     - 显示警告："⚠️ 日志解析不完整，自动修复已禁用"
     - 继续到 Phase 2-3 进行分析，但 Phase 4 将跳过自动修复
   - 如果 `blocks_auto_fix: false` 或不存在：
     - 显示警告但继续正常流程

2. **在后续阶段传递标志**：
   - Phase 2 分类时：如果 `workflow_ctx.blocks_auto_fix == true`，强制将所有分类的置信度上限设为 39（跳过阈值）
   - Phase 4 修复时：检查此标志，如果为 true 则跳过自动修复，仅展示分析结果

```text
⚠️ 日志解析状态: partial

原因: {parse_quality.reason}
- 已识别 Steps: {parse_quality.steps_identified}
- 已提取错误: {parse_quality.errors_extracted}
- 解析置信度: {parse_quality.confidence}%

由于日志解析不完整，自动修复已禁用。
继续分析以获取诊断信息...
```

### 1.3 展示日志摘要

```text
日志获取结果：
- 总行数: {log_stats.total_lines}
- 失败 Step 数: {failed_steps.length}
- 错误类型: {error_summary.primary_type}
- 关键错误: {error_summary.error_count} 个
```

---

## Phase 2: 失败分类

### 2.1 启动 failure-classifier agent

使用 Task tool 调用 ci-job-failure-classifier agent：

> 使用 ci-job-failure-classifier agent 分类失败：
>
> ## 失败步骤
>
> [Phase 1 的 failed_steps 输出]
>
> ## 错误摘要
>
> [Phase 1 的 error_summary 输出]
>
> ## Job 信息
>
> [Phase 0 的 job_info]
>
> ## 配置
>
> [Phase 0 的 config]

### 2.2 验证输出

1. 检查 `classifications` 数组存在
2. 检查每个分类有 `failure_type` 和 `confidence`

### 2.3 记录到 TodoWrite

使用 TodoWrite 记录所有待处理的失败：

```javascript
TodoWrite([
  { content: "[F001] 修复 test_failure: test_login 失败 (85%)", status: "pending", activeForm: "准备修复中" },
  { content: "[F002] 修复 lint_failure: eslint 错误 (92%)", status: "pending", activeForm: "准备修复中" },
  ...
])
```

### 2.4 展示分类摘要

```text
失败分类结果：
- 总计: {summary.total_failures}
- 可自动修复: {summary.auto_fixable}
- 按类型: test={by_type.test_failure}, lint={by_type.lint_failure}, build={by_type.build_failure}
- 按技术栈: Backend={by_stack.backend}, Frontend={by_stack.frontend}, E2E={by_stack.e2e}
- 整体置信度: {summary.overall_confidence}%

建议: {recommendation.action} - {recommendation.reason}
```

### 2.5 检查是否可继续

如果 `recommendation.action` 为 `manual`：

- 展示分析结果
- **停止**并报告 "置信度过低或不可自动修复，建议手动处理"

---

## Phase 3: 根因分析

### 3.1 启动 root-cause agent

使用 Task tool 调用 ci-job-root-cause agent：

> 使用 ci-job-root-cause agent 分析根因：
>
> ## 分类结果
>
> [Phase 2 的 classifications 输出]
>
> ## 错误摘要
>
> [Phase 1 的 error_summary]
>
> ## 日志路径
>
> [Phase 1 的 full_log_path]
>
> ## 配置
>
> [配置]

### 3.2 验证输出

1. 检查 `analyses` 数组存在
2. 验证每个分析有 `root_cause` 和 `fix_suggestion`

### 3.3 展示分析结果

```text
根因分析结果：

[F001] test_login 失败
├── 置信度: 85%
├── 根因: {root_cause.description}
├── 证据:
│   - {evidence[0]}
│   - {evidence[1]}
├── 历史匹配: {history_matches[0].doc_path} (相似度: {similarity}%)
└── 建议修复: {fix_suggestion.approach}
```

---

## Phase 4: 修复执行

### 4.1 检查 dry-run 模式

如果 `--dry-run`：

- 展示将要执行的操作（包括修复方法、预计变更文件）
- **跳过 Phase 4 的实际修复执行**
- **跳过 Phase 5 的验证和审查**（因为没有实际变更）
- **直接进入 Phase 6 生成分析报告**（报告中标记 `dry_run: true`）

> **精确跳过说明**：dry-run 模式下，Phase 0-3（分析阶段）正常执行，Phase 4-5（修复和审查）被跳过，Phase 6 生成不含修复结果的分析报告。

### 4.2 启动 fix-coordinator agent

使用 Task tool 调用 ci-job-fix-coordinator agent：

> 使用 ci-job-fix-coordinator agent 协调修复：
>
> ## 根因分析结果
>
> [Phase 3 的 analyses 输出]
>
> ## 配置
>
> [配置]
>
> ## 模式
>
> - dry_run: {dry_run}
> - auto_commit: false (在 Phase 6 处理)
>
> ## 处理要求
>
> 1. 高置信度 (>=80) 自动修复
> 2. 中置信度 (60-79) 询问用户
> 3. 低置信度 (<60) 跳过
> 4. lint_failure 走快速路径 (直接 lint --fix)
> 5. 其他类型调用对应技术栈的 bugfix 工作流

### 4.3 处理修复结果

1. 更新 TodoWrite 状态
2. 记录修复成功/失败

### 4.4 展示修复摘要

```text
修复执行结果：
- 已修复: {fixed}
- 跳过: {skipped}
- 失败: {failed}
- 用户拒绝: {user_declined}

变更文件:
- {file1} ({lines_changed1} 行)
- {file2} ({lines_changed2} 行)
```

---

## Phase 5: 验证与审查

### 5.1 本地验证

运行验证命令：

```bash
# 运行受影响的测试
{test_command}

# 运行 lint
{lint_command}

# 运行类型检查
{typecheck_command}
```

如果验证失败：

1. **报告失败详情**：

   ```text
   ⚠️ 本地验证失败

   失败项目:
   - 测试: {test_result}
   - Lint: {lint_result}
   - 类型检查: {typecheck_result}

   变更文件:
   - {modified_files}
   ```

2. **提供选项询问用户**：

   ```text
   请选择:
   [R] 回滚所有变更 (git checkout -- {modified_files})
   [C] 继续到 Review 阶段（可能发现更多问题）
   [M] 手动处理（保留变更，退出工作流）
   ```

3. **如果用户选择回滚**：

   ```bash
   # 回滚变更
   git checkout -- {modified_files}
   ```

   然后**停止工作流**，报告 "变更已回滚，工作流终止"。

### 5.2 并行启动 6 个 review agents

使用 Task tool **并行**调用以下 6 个 review agents 审查修复代码：

```text
并行执行（使用 Task tool，subagent_type 格式）：
├── swiss-army-knife:review:code-reviewer         # 通用代码审查
├── swiss-army-knife:review:silent-failure-hunter # 静默失败检测
├── swiss-army-knife:review:code-simplifier       # 代码简化
├── swiss-army-knife:review:test-analyzer         # 测试覆盖分析
├── swiss-army-knife:review:comment-analyzer      # 注释准确性
└── swiss-army-knife:review:type-design-analyzer  # 类型设计分析
```

> **注意**：Agent 名称格式为 `{plugin}:{category}:{agent-name}`，与 `agents/review/` 目录下的文件名对应。

每个 agent 的 prompt 模板：

> 使用 {agent_name} agent 审查 CI Job 修复的代码变更：
>
> ## 变更文件
>
> [Phase 4 修改的文件列表]
>
> ## 项目规范
>
> 参考 CLAUDE.md 中的项目规范
>
> ## 审查要求
>
> - 只报告置信度 >= 80 的问题
> - 输出标准 JSON 格式

### 5.3 汇总 review 结果

收集所有 review agents 的输出，汇总问题：

```python
all_issues = []
for agent_result in review_results:
    if agent_result["status"] == "success":
        all_issues.extend(agent_result["issues"])

critical_issues = [i for i in all_issues if i["confidence"] >= 90]
important_issues = [i for i in all_issues if 80 <= i["confidence"] < 90]
fixable_issues = [i for i in all_issues if i.get("auto_fixable", False)]
```

### 5.4 Review-Fix 循环（最多 3 次）

**循环条件**：存在置信度 >= 80 且 `auto_fixable: true` 的问题

**循环流程**：

```text
iteration = 0
max_iterations = 3
previous_issue_count = len(fixable_issues)
loop_status = "running"  # running | converged | diverged | max_reached

WHILE (存在 >=80 的可修复问题) AND (iteration < max_iterations):

    1. 启动 review-fixer agent 修复问题
    2. 验证修复（lint, typecheck, tests）
    3. 重新运行 6 个 review agents（并行）
    4. 汇总新的问题列表
    5. 收敛检测：
       current_count = len(new_fixable_issues)
       IF current_count > previous_issue_count:
           loop_status = "diverged"
           BREAK  # 立即停止，问题在增加
       ELIF current_count == 0:
           loop_status = "converged"
           BREAK  # 成功收敛，无更多问题
       ELSE:
           previous_issue_count = current_count
    6. iteration++

END WHILE

IF iteration >= max_iterations AND 仍有问题:
    loop_status = "max_reached"
```

**收敛失败时的用户通知**（`loop_status == "diverged"`）：

当检测到问题数增加（发散）时，**必须**向用户显示明确警告：

```text
⚠️ Review-Fix 循环异常终止

状态: 发散（问题数增加）
- 迭代次数: {iteration}
- 初始问题数: {initial_count}
- 当前问题数: {current_count} (↑ 增加了 {current_count - initial_count} 个)

这可能表明：
1. 修复引入了新的代码问题
2. 修复破坏了其他代码的正确性
3. Review agents 发现了之前遗漏的问题

建议操作:
[R] 回滚本次迭代的修复 (git checkout -- {last_modified_files})
[K] 保留当前变更，手动审查
[D] 查看详细的问题对比 (新增 vs 已修复)

请选择操作: [R/K/D]
```

**达到最大迭代次数时的通知**（`loop_status == "max_reached"`）：

```text
ℹ️ Review-Fix 循环达到最大次数

状态: 达到上限 (3 次迭代)
- 初始问题数: {initial_count}
- 当前问题数: {current_count}
- 已修复问题: {fixed_count}

剩余 {current_count} 个问题未自动修复，建议人工处理。
```

### 5.5 展示 review 报告

```text
=== Review 报告 ===

迭代统计：
- 总迭代次数: {iteration}
- 初始问题数: {initial_count}
- 最终问题数: {final_count}
- 已修复问题: {fixed_count}

已修复问题列表：
- [CR-001] src/api.py:42 - 代码规范问题 ✓
- [SFH-002] src/utils.py:15 - 空 catch 块 ✓

剩余建议（未自动修复）：
- [TD-001] src/models.py:30 - 类型设计可改进（需人工处理）
```

---

## Phase 6: 汇总与可选重试

### 6.1 启动 summary-reporter agent

使用 Task tool 调用 ci-job-summary-reporter agent：

> 使用 ci-job-summary-reporter agent 生成报告：
>
> ## 所有阶段输出
>
> - Phase 0: {init_ctx}
> - Phase 1: {log_result}
> - Phase 2: {classification_result}
> - Phase 3: {root_cause_result}
> - Phase 4: {fix_result}
> - Phase 5: {review_result}
>
> ## 参数
>
> - auto_commit: {auto_commit}
> - retry_job: {retry_job}
>
> ## 配置
>
> [配置]

### 6.2 展示最终报告

向用户展示完整处理摘要：

- Job 失败分析结果
- 代码修复结果
- Review 审查结果
- Git commit 状态（如果启用 --auto-commit）
- Job 重试状态（如果启用 --retry-job）

### 6.3 标记 TodoWrite 完成

将所有待办事项标记为完成。

---

## 异常处理

### E1: 无效的 Job URL

- **行为**：Phase 0 停止
- **输出**："无效的 Job URL 格式，请提供完整的 GitHub Actions job URL"

### E2: Job 不存在

- **行为**：Phase 0 停止
- **输出**："Job 不存在或无权限访问"

### E3: Job 仍在运行

- **行为**：Phase 0 停止
- **输出**："Job 仍在运行中，请等待完成后再分析"

### E4: Job 未失败

- **行为**：Phase 0 停止
- **输出**："Job 已成功完成，无需修复"

### E5: 日志不可用

- **行为**：Phase 1 停止
- **输出**："Job 日志不可用，可能已过期（GitHub 保留 90 天）"

### E6: 无法识别失败类型

- **行为**：Phase 2 警告，继续但建议手动处理
- **输出**："无法识别失败类型，置信度低"

### E7: 修复工作流失败

- **行为**：记录失败，继续处理其他
- **输出**："失败 {id} 修复失败：{reason}"

### E8: 验证失败

- **行为**：报告失败，询问用户是否继续
- **输出**："修复后验证失败，测试仍未通过"

---

## 关键原则

1. **TodoWrite 跟踪**：记录所有待处理失败，防止遗漏
2. **置信度驱动**：低置信度时询问用户或跳过，不强行处理
3. **Lint 快速路径**：lint 失败直接 `--fix`，不走完整工作流
4. **联动工作流**：调用对应技术栈的 bugfix 流程
5. **Review 审查**：修复后用 6 个 review agents 审查代码质量
6. **知识沉淀**：有价值的修复记录到文档

---

## 使用示例

### 基本用法

```bash
/fix-failed-job https://github.com/owner/repo/actions/runs/12345/job/67890
```

分析并修复失败的 Job。

### Dry Run 模式

```bash
/fix-failed-job https://github.com/owner/repo/actions/runs/12345/job/67890 --dry-run
```

只分析不执行修复。

### 自动提交并重试

```bash
/fix-failed-job https://github.com/owner/repo/actions/runs/12345/job/67890 --auto-commit --retry-job
```

修复后自动提交并重新运行 Job。

### 指定执行阶段

```bash
/fix-failed-job https://github.com/owner/repo/actions/runs/12345/job/67890 --phase=0,1,2
```

只执行 Phase 0-2（分析阶段）。
