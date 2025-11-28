---
description: 处理 PR 中的 Code Review 评论（8 阶段流程，Phase 0-7）
argument-hint: "<PR_NUMBER> [--dry-run] [--priority=P0,P1,P2] [--auto-reply]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task, TodoWrite, AskUserQuestion
---

# Fix PR Review Workflow v1.0

基于 GitHub PR 中的 Code Review 评论，执行标准化的分析和修复流程。

**宣布**："我正在使用 Fix PR Review v1.0 工作流处理 PR 评论。"

---

## 参数解析

从用户输入中解析参数：

- `<PR_NUMBER>`：必填，PR 编号
- `--dry-run`：只分析不提交回复
- `--priority=P0,P1,P2`：指定处理的优先级（默认 P0,P1）
- `--auto-reply`：自动回复 reviewer（默认 true）

### 参数验证

1. `PR_NUMBER` 必须是正整数
2. `--priority` 必须是 P0/P1/P2/P3 的组合
3. 如果未提供 `PR_NUMBER`，询问用户

---

## Phase 0: 初始化

### 0.1 启动 init-collector agent

使用 Task tool 调用 pr-review-init-collector agent：

> 使用 pr-review-init-collector agent 初始化 PR Review 工作流：
>
> ## 任务
>
> 1. 验证 GitHub CLI 可用性
> 2. 获取 PR #{PR_NUMBER} 元信息
> 3. 获取最后一次 commit 信息
> 4. 加载配置
>
> ## PR 编号
>
> {PR_NUMBER}

### 0.2 验证 init-collector 输出

验证返回的 JSON 格式：

1. **格式验证**：确保返回有效 JSON
2. **必填字段检查**：
   - `pr_info.number` 存在且匹配
   - `pr_info.last_commit.sha` 存在
   - `pr_info.last_commit.timestamp` 存在
   - `config` 对象存在
3. **警告展示**：
   - 如果 `warnings` 存在且非空，向用户展示
   - 如果 PR 状态不是 OPEN，警告但继续
4. **失败处理**：
   - 格式无效：**停止**
   - PR 不存在：**停止**
   - gh CLI 不可用：**停止**

### 0.3 提取上下文变量

从 init-collector 输出中提取，存储为 `init_ctx`：

| 数据 | 路径 |
|------|------|
| PR 编号 | `init_ctx["pr_info"]["number"]` |
| 最后 commit SHA | `init_ctx["pr_info"]["last_commit"]["sha"]` |
| 最后 commit 时间 | `init_ctx["pr_info"]["last_commit"]["timestamp"]` |
| 置信度阈值 | `init_ctx["config"]["confidence_threshold"]` |
| 技术栈路径模式 | `init_ctx["config"]["stack_path_patterns"]` |
| 回复模板 | `init_ctx["config"]["response_templates"]` |

---

## Phase 1: 评论获取

### 1.1 启动 comment-fetcher agent

使用 Task tool 调用 pr-review-comment-fetcher agent：

> 使用 pr-review-comment-fetcher agent 获取 PR 评论：
>
> ## PR 信息
>
> - 编号: {init_ctx["pr_info"]["number"]}
> - 仓库: {init_ctx["project_info"]["repo"]}
>
> ## 任务
>
> 获取所有 review comments 和 issue comments

### 1.2 验证输出

1. **非空验证**：确保 Task 工具返回非空值
   - 如果为 null/undefined：**停止**，报告 "comment-fetcher agent 未返回响应"
2. **格式验证**：确保返回有效 JSON
3. 检查 `comments` 数组存在
4. **状态验证**：检查 `status` 字段
   - 如果为 `PARTIAL_SUCCESS`：向用户展示警告，询问是否继续处理不完整数据
   - 如果为 `FAILED`：**停止**并报告错误原因
5. 如果 `comments` 为空，**停止**并报告 "PR 没有评论"
6. 记录 `summary.total` 到日志

---

## Phase 2: 评论过滤

### 2.1 启动 comment-filter agent

使用 Task tool 调用 pr-review-comment-filter agent：

> 使用 pr-review-comment-filter agent 过滤评论：
>
> ## 评论列表
>
> [Phase 1 的 comments 输出]
>
> ## 过滤条件
>
> - 最后 commit 时间: {init_ctx["pr_info"]["last_commit"]["timestamp"]}
> - 排除 Bot 评论: true
> - 排除已解决评论: true

### 2.2 验证输出

1. 检查 `valid_comments` 数组存在
2. 如果为空：
   - **停止**并报告 "所有评论均在最后 commit 之前，已过时"
3. 展示过滤摘要：

   ```text
   评论过滤结果：
   - 总评论: {total_input}
   - 有效评论: {valid}
   - 已过滤: {filtered}
     - 早于最后 commit: {by_reason.created_before_last_commit}
     - 已解决: {by_reason.already_resolved}
     - CI 自动报告: {by_reason.ci_auto_report}
   ```

---

## Phase 3: 评论分类

### 3.1 启动 comment-classifier agent

使用 Task tool 调用 pr-review-comment-classifier agent：

> 使用 pr-review-comment-classifier agent 分类评论：
>
> ## 有效评论
>
> [Phase 2 的 valid_comments 输出]
>
> ## 配置
>
> - 置信度阈值: {init_ctx["config"]["confidence_threshold"]}
> - 技术栈路径模式: {init_ctx["config"]["stack_path_patterns"]}
> - 分类关键词: {init_ctx["config"]["classification_keywords"]}

### 3.2 验证输出

1. 检查 `classified_comments` 数组存在
2. 验证每条评论有 `classification` 对象

### 3.3 记录到 TodoWrite

使用 TodoWrite 记录所有待处理评论：

```javascript
TodoWrite([
  { content: "[P0] 评论 #rc_123456: {描述}", status: "pending", activeForm: "处理 P0 评论中" },
  { content: "[P1] 评论 #rc_234567: {描述}", status: "pending", activeForm: "处理 P1 评论中" },
  ...
])
```

### 3.4 展示分类摘要

```text
评论分类结果：
- 总计: {total}
- 可操作: {actionable}
- 按优先级: P0={by_priority.P0}, P1={by_priority.P1}, P2={by_priority.P2}, P3={by_priority.P3}
- 按置信度: 高={by_confidence.high}, 中={by_confidence.medium}, 低={by_confidence.low}
- 按技术栈: Backend={by_stack.backend}, Frontend={by_stack.frontend}, E2E={by_stack.e2e}
```

### 3.5 过滤处理范围

根据 `--priority` 参数过滤：

```python
target_priorities = args.priority or ['P0', 'P1']
comments_to_process = [
    c for c in classified_comments
    if c['classification']['priority'] in target_priorities
]
```

如果过滤后为空，**停止**并报告 "没有符合优先级条件的评论"。

---

## Phase 4: 修复协调

### 4.1 检查 dry-run 模式

如果 `--dry-run`：

- 跳过实际修复
- 只展示将要执行的操作
- 跳到 Phase 6

### 4.2 启动 fix-coordinator agent

使用 Task tool 调用 pr-review-fix-coordinator agent：

> 使用 pr-review-fix-coordinator agent 协调修复：
>
> ## 待处理评论
>
> [Phase 3 过滤后的评论]
>
> ## 配置
>
> - 置信度阈值: {init_ctx["config"]["confidence_threshold"]}
> - 优先级配置: {init_ctx["config"]["priority"]}
>
> ## 处理要求
>
> 1. 按优先级顺序处理 (P0 → P1 → P2)
> 2. 高置信度 (>=80) 自动修复
> 3. 中置信度 (60-79) 询问用户
> 4. 低置信度 (40-59) 标记需澄清
> 5. 极低置信度 (<40) 跳过，回复 reviewer
> 6. 调用对应技术栈的 bugfix 工作流

### 4.3 处理修复结果

1. 更新 TodoWrite 状态
2. 记录修复成功/失败

### 4.4 展示修复摘要

```text
修复执行结果：
- 已修复: {fixed}
- 跳过: {skipped}
- 失败: {failed}

已创建 commits:
- {sha1}: {message1}
- {sha2}: {message2}
```

---

## Phase 5: 回复生成

### 5.1 启动 response-generator agent

使用 Task tool 调用 pr-review-response-generator agent：

> 使用 pr-review-response-generator agent 生成回复：
>
> ## 修复结果
>
> [Phase 4 的 fix_results 输出]
>
> ## 原始评论
>
> [Phase 3 的 classified_comments]
>
> ## 回复模板
>
> {init_ctx["config"]["response_templates"]}

### 5.2 验证输出

1. 检查每条评论都有对应的回复
2. 回复内容不为空

---

## Phase 6: 回复提交

### 6.1 检查 dry-run 模式

如果 `--dry-run`：

- 展示将要提交的回复预览
- 跳过实际提交
- 跳到 Phase 7

### 6.2 检查 auto-reply 参数

如果 `--auto-reply=false` 或未设置且非交互模式：

- 询问用户是否提交回复
- 用户拒绝则跳过

### 6.3 启动 response-submitter agent

使用 Task tool 调用 pr-review-response-submitter agent：

> 使用 pr-review-response-submitter agent 提交回复：
>
> ## 回复列表
>
> [Phase 5 的 responses 输出]
>
> ## PR 信息
>
> - 编号: {init_ctx["pr_info"]["number"]}
> - 仓库: {init_ctx["project_info"]["repo"]}
>
> ## 模式
>
> - dry_run: {dry_run}

### 6.4 展示提交结果

```text
回复提交结果：
- 已提交: {submitted}
- 失败: {failed}

回复链接：
- rc_123456: https://github.com/.../pull/123#discussion_r789012
- ...
```

---

## Phase 7: 汇总报告

### 7.1 启动 summary-reporter agent

使用 Task tool 调用 pr-review-summary-reporter agent：

> 使用 pr-review-summary-reporter agent 生成报告：
>
> ## 所有阶段输出
>
> - Phase 0: {init_ctx}
> - Phase 1: {comments}
> - Phase 2: {filtered_comments}
> - Phase 3: {classified_comments}
> - Phase 4: {fix_results}
> - Phase 5: {responses}
> - Phase 6: {submission_results}
>
> ## 报告配置
>
> - 报告目录: {init_ctx["config"]["docs"]["review_reports_dir"]}

### 7.2 展示最终报告

向用户展示处理摘要。

### 7.3 标记 TodoWrite 完成

将所有待办事项标记为完成。

---

## 异常处理

### E1: PR 不存在

- **行为**：Phase 0 停止
- **输出**："PR #{number} 不存在，请检查 PR 编号"

### E2: 无有效评论

- **行为**：Phase 2 停止
- **输出**："所有评论均在最后 commit 之前，已过时"

### E3: GitHub API 限流

- **行为**：暂停并等待，或返回部分结果
- **输出**："GitHub API 限流，等待 {seconds} 秒后继续"

### E4: 修复工作流失败

- **行为**：记录失败，继续处理下一个
- **输出**："评论 {id} 修复失败：{reason}"

### E5: 回复提交失败

- **行为**：保存到本地，提示手动提交
- **输出**："部分回复提交失败，已保存到 {file}"

---

## 关键原则

1. **TodoWrite 跟踪**：记录所有待处理评论，防止遗漏
2. **时间窗口过滤**：只处理最后 commit 之后的评论
3. **置信度驱动**：低置信度时询问用户，不强行处理
4. **联动工作流**：调用对应技术栈的 bugfix 流程
5. **自动回复**：处理完成后自动回复 reviewer
6. **知识沉淀**：高价值修复记录到最佳实践

---

## 使用示例

### 基本用法

```bash
/fix-pr-review 123
```

处理 PR #123 的所有 P0 和 P1 评论。

### Dry Run 模式

```bash
/fix-pr-review 123 --dry-run
```

只分析不执行修复和回复。

### 指定优先级

```bash
/fix-pr-review 123 --priority=P0,P1,P2
```

处理 P0、P1 和 P2 优先级的评论。

### 禁用自动回复

```bash
/fix-pr-review 123 --auto-reply=false
```

修复后不自动回复，手动确认后提交。
