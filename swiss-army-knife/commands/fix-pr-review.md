---
description: 处理 PR 中的 Code Review 评论（8 阶段流程，Phase 0-7）
argument-hint: "<PR_NUMBER> [--dry-run] [--priority=P0,P1,P2] [--auto-reply] [--log] [--verbose]"
allowed-tools: Read, Task, AskUserQuestion, Bash
---

# Fix PR Review Workflow v2.0

基于 GitHub PR 中的 Code Review 评论，执行标准化的分析和修复流程。

**宣布**："我正在使用 Fix PR Review v2.0 工作流处理 PR 评论。"

---

## 参数解析

从用户输入中解析参数：

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `<PR_NUMBER>` | 是 | - | PR 编号（正整数） |
| `--dry-run` | 否 | `false` | 只分析不执行修复和回复 |
| `--priority=X,Y` | 否 | `P0,P1` | 指定处理的优先级 |
| `--auto-reply` | 否 | `true` | 自动回复 reviewer |
| `--log` | 否 | `false` | 启用过程日志（INFO 级别） |
| `--verbose` | 否 | `false` | 启用详细日志（DEBUG 级别，隐含 --log） |

### 日志参数说明

- `--log`：记录 Phase/Agent 事件、置信度决策、用户交互
- `--verbose`：额外记录完整的 agent 输入输出（文件可能较大）
- 日志文件位置：`.claude/logs/swiss-army-knife/pr-review/`
- 生成两种格式：`.jsonl`（程序查询）和 `.log`（人类阅读）

### 参数验证

1. `PR_NUMBER` 必须是正整数
2. `--priority` 必须是 P0/P1/P2/P3 的组合
3. 如果未提供 `PR_NUMBER`，使用 AskUserQuestion 询问用户

---

## 调用 Master Coordinator

使用 Task tool 调用 **pr-review-master-coordinator** agent：

> 使用 pr-review-master-coordinator agent 执行 PR Review 工作流：
>
> ## 输入
>
> ```json
> {
>   "pr_number": {PR_NUMBER},
>   "args": {
>     "dry_run": {--dry-run 解析结果},
>     "priority": {--priority 解析结果或 ["P0", "P1"]},
>     "auto_reply": {--auto-reply 解析结果或 true}
>   },
>   "logging": {
>     "enabled": {--log 或 --verbose 解析结果，true/false},
>     "level": "{--verbose 时为 'debug'，--log 时为 'info'}",
>     "session_id": "{生成 8 位随机字符串，如 'a1b2c3d4'}"
>   }
> }
> ```

### 生成 session_id

使用以下方法生成 8 位随机 ID：

```bash
cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 8
```

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
| `partial` | 展示部分成功报告，列出失败的评论处理 |
| `failed` | 展示错误详情，建议修复方案 |
| `user_cancelled` | 确认用户取消，展示已完成工作 |
| `dry_run_complete` | 展示分析报告，不实际执行 |

---

## 输出展示

从协调器返回中提取关键信息：

```text
=== PR Review 处理完成 ===

状态: {status}

评论处理:
- 总评论: {comments_summary.total}
- 有效评论: {comments_summary.classified}
- 按优先级: P0={by_priority.P0}, P1={by_priority.P1}

修复结果:
- 已修复: {fix_results.summary.fixed}
- 跳过: {fix_results.summary.skipped}
- 失败: {fix_results.summary.failed}

回复状态:
- 已提交: {responses.submitted}
- 失败: {responses.failed}

Review 结果:
- 发现问题: {review_results.summary.initial_issues}
- 已修复: {review_results.summary.fixed_issues}

报告路径: {report_path}
```
