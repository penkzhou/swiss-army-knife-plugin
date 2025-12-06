---
description: 修复失败的 GitHub Action job（7 阶段流程，Phase 0-6）
argument-hint: "<JOB_URL> [--dry-run] [--auto-commit] [--retry-job] [--phase=0,1,2,3,4,5,6|all] [--log] [--verbose]"
allowed-tools: Read, Task, AskUserQuestion, Bash
---

# Fix Failed Job Workflow v2.0

自动分析和修复失败的 GitHub Action job。

**宣布**："我正在使用 Fix Failed Job v2.0 工作流分析并修复 CI Job 失败。"

---

## 参数解析

从用户输入中解析参数：

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `<JOB_URL>` | 是 | - | 失败的 job URL |
| `--dry-run` | 否 | `false` | 只分析不执行修复 |
| `--auto-commit` | 否 | `false` | 修复后自动创建 git commit |
| `--retry-job` | 否 | `false` | 修复后触发 job 重新运行 |
| `--phase=X,Y` | 否 | `all` | 指定执行阶段 |
| `--log` | 否 | `false` | 启用过程日志（INFO 级别） |
| `--verbose` | 否 | `false` | 启用详细日志（DEBUG 级别，隐含 --log） |

### 日志参数说明

- `--log`：记录 Phase/Agent 事件、置信度决策、用户交互
- `--verbose`：额外记录完整的 agent 输入输出（文件可能较大）
- 日志文件位置：`.claude/logs/swiss-army-knife/ci-job/`
- 生成两种格式：`.jsonl`（程序查询）和 `.log`（人类阅读）

### URL 格式验证

支持的格式：
```text
https://github.com/{owner}/{repo}/actions/runs/{run_id}/job/{job_id}
https://github.com/{owner}/{repo}/actions/runs/{run_id}/jobs/{job_id}
```

如果未提供 `JOB_URL` 或格式无效，使用 AskUserQuestion 询问用户。

---

## 调用 Master Coordinator

使用 Task tool 调用 **ci-job-master-coordinator** agent：

> 使用 ci-job-master-coordinator agent 执行 CI Job 修复工作流：
>
> ## 输入
>
> ```json
> {
>   "job_url": "{解析的 JOB_URL}",
>   "args": {
>     "dry_run": {--dry-run 解析结果},
>     "auto_commit": {--auto-commit 解析结果},
>     "retry_job": {--retry-job 解析结果},
>     "phase": "{--phase 解析结果或 'all'}"
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
| `partial` | 展示部分成功报告，列出剩余问题 |
| `failed` | 展示错误详情，建议修复方案 |
| `user_cancelled` | 确认用户取消，展示已完成工作 |
| `dry_run_complete` | 展示分析报告，不实际执行 |

---

## 输出展示

从协调器返回中提取关键信息：

```text
=== CI Job 修复完成 ===

状态: {status}
Job: {init_ctx.job_info.name} (#{init_ctx.job_info.id})
仓库: {init_ctx.repo_info.full_name}

失败分析:
- 类型: {classification_result.summary.primary_type}
- 失败数: {classification_result.summary.total_failures}
- 可自动修复: {classification_result.summary.auto_fixable}

根因分析:
- 根因: {root_cause_result.analyses[0].root_cause.description}
- 置信度: {root_cause_result.overall_confidence}%

修复结果:
- 已修复: {fix_result.summary.fixed}
- 跳过: {fix_result.summary.skipped}
- 失败: {fix_result.summary.failed}
- 变更文件: {fix_result.changed_files}

Review 结果:
- 发现问题: {review_result.summary.initial_issues}
- 已修复: {review_result.summary.fixed_issues}

后续操作:
- Git commit: {final_actions.commit_created}
- Job 重试: {final_actions.job_rerun_triggered}
```

---

## 使用示例

### 基本用法

```bash
/fix-failed-job https://github.com/owner/repo/actions/runs/12345/job/67890
```

### Dry Run 模式

```bash
/fix-failed-job https://github.com/owner/repo/actions/runs/12345/job/67890 --dry-run
```

### 自动提交并重试

```bash
/fix-failed-job https://github.com/owner/repo/actions/runs/12345/job/67890 --auto-commit --retry-job
```

### 指定执行阶段

```bash
/fix-failed-job https://github.com/owner/repo/actions/runs/12345/job/67890 --phase=0,1,2
```
