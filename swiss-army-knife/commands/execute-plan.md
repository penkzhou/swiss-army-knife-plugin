---
description: 执行实施计划（六阶段流程）
argument-hint: "<PLAN_FILE> [--phase=0,1,2,3,4,5|all] [--dry-run] [--fast] [--skip-review] [--batch-size=N]"
allowed-tools: Read, Task, AskUserQuestion
---

# Execute Plan Workflow v2.0

基于实施计划文件，执行标准化 6 阶段执行流程。

**宣布**："我正在使用 Execute Plan v2.0 工作流执行计划。"

---

## 参数解析

从用户输入中解析参数：

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `<PLAN_FILE>` | 是 | - | 计划文件路径 |
| `--phase=X,Y` | 否 | `all` | 指定执行阶段 |
| `--dry-run` | 否 | `false` | 只分析不执行 |
| `--fast` | 否 | `false` | 跳过方案细化（Phase 2） |
| `--skip-review` | 否 | `false` | 跳过 Review 审查（Phase 4） |
| `--batch-size=N` | 否 | `3` | 批次大小 |

---

## 前置验证

在调用协调器前，验证计划文件：

1. **文件存在性**：确认 `PLAN_FILE` 路径存在
2. **文件非空**：检查文件内容非空
3. **格式识别**：确认是支持的格式（`.md`、`.yaml`、`.yml`）

**验证失败处理**：

```text
错误：计划文件不存在或为空

文件路径: {PLAN_FILE}
建议：
1. 确认文件路径正确
2. 使用支持的格式（Markdown 或 YAML）编写计划
3. 参考 execute-plan skill 中的计划格式规范
```

**停止**，不继续执行。

---

## 调用 Master Coordinator

使用 Task tool 调用 **execute-plan-master-coordinator** agent：

> 使用 execute-plan-master-coordinator agent 执行计划：
>
> ## 输入
>
> ```json
> {
>   "plan_path": "{PLAN_FILE}",
>   "args": {
>     "dry_run": {--dry-run 解析结果},
>     "fast": {--fast 解析结果},
>     "skip_review": {--skip-review 解析结果},
>     "batch_size": {--batch-size 解析结果或默认值 3},
>     "phase": "{--phase 解析结果或 'all'}"
>   }
> }
> ```

---

## 验证协调器响应

在处理返回前，**必须**验证 Task 工具调用是否成功：

### 1. 调用成功性检查

如果 Task 工具调用失败（网络错误、agent 未找到、超时），展示错误并**停止**：

```text
错误：协调器调用失败

原因: {错误消息}
建议:
1. 检查网络连接
2. 确认插件已正确安装
3. 重试命令
```

### 2. 响应格式验证

检查响应是否为有效 JSON 且包含 `status` 字段：

- 响应必须是有效 JSON
- 必须包含 `status` 字段
- `status` 必须是 `success|partial|failed|user_cancelled|dry_run_complete` 之一

**验证失败处理**：

```text
错误：协调器响应格式无效

收到的响应: {原始响应前 200 字符}
建议:
1. 重试命令
2. 如果问题持续，请报告此错误
```

**停止**，不继续处理无效响应。

---

## 处理协调器返回

协调器返回标准 JSON 格式，根据 `status` 字段处理：

| status | 处理方式 |
|--------|----------|
| `success` | 展示成功报告，流程完成 |
| `partial` | 展示部分成功报告，列出失败任务 |
| `failed` | 展示错误详情，建议修复方案 |
| `user_cancelled` | 确认用户取消，展示已完成工作 |
| `dry_run_complete` | 展示分析报告，不实际执行 |

---

## 输出展示

从协调器返回的 `summary_report` 中提取关键信息：

```text
=== 计划执行完成 ===

计划: {summary_report.title}
状态: {status}

执行结果:
- 总任务: {execution_results.summary.total}
- 已完成: {execution_results.summary.completed}
- 失败: {execution_results.summary.failed}

Review 结果:
- 发现问题: {review_results.summary.initial_issues}
- 已修复: {review_results.summary.fixed_issues}

报告路径: {summary_report.report_path}
```
