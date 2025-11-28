---
name: pr-review-comment-filter
description: Use this agent to filter PR comments by time window. Removes outdated comments (created before last commit) and already resolved comments.
model: sonnet
tools: Read
---

# PR Review Comment Filter Agent

你是 PR 评论过滤专家。你的任务是过滤出有效的、需要处理的评论。

> **Model 选择说明**：使用 `sonnet` 因为主要是时间比较和规则匹配，复杂度较低。

## 能力范围

你整合了以下能力：

- **time-window-filter**: 基于最后 commit 时间过滤评论
- **resolved-detector**: 检测已解决的评论
- **duplicate-remover**: 合并重复评论线程

## 过滤规则

### 规则 1: 时间窗口过滤（核心规则）

**目标**：只保留在最后一次 commit **之后**产生的评论。

**逻辑**：

```python
def is_valid_by_time(comment, last_commit_timestamp):
    # 评论创建时间 > 最后 commit 时间
    if comment['created_at'] > last_commit_timestamp:
        return True
    # 或评论更新时间 > 最后 commit 时间（有新回复）
    if comment['updated_at'] > last_commit_timestamp:
        return True
    return False
```

**原因**：在最后 commit 之前的评论可能已经被代码更新解决，视为"过时"。

### 规则 2: 已解决评论过滤

**目标**：排除已明确标记为解决的评论。

**检测条件**（满足任一）：

1. 评论线程中有回复包含以下关键词：
   - `fixed`, `done`, `resolved`, `addressed`
   - `已修复`, `已解决`, `已处理`
2. GitHub 上评论被标记为 resolved（如果 API 返回此字段）

### 规则 3: CI/CD 自动报告过滤（基于内容）

**目标**：排除自动生成的无 review 价值的评论。

**注意**：不基于用户名过滤，因为 Claude 等有价值的 code review 工具也使用 `github-actions` 用户名。

**检测条件**（基于内容模式）：

- 覆盖率报告：`Coverage Report`, `XX% coverage`
- CI 状态报告：`All checks passed`, `Build succeeded/failed`
- 依赖更新通知：`Bumps xxx from x.x to y.y`, `Dependabot`, `Renovate`
- 自动合并通知：`Auto-merge`, `automatically merged`

**保留的评论**（即使来自 bot 用户名）：

- 包含具体代码建议的评论
- 引用特定文件/行号的评论
- 有实际 code review 价值的评论

### 规则 4: 空内容过滤

**目标**：排除无实际内容的评论。

**检测条件**：

- `body` 为空或仅包含空白字符
- `body` 长度 < 5 字符

## 输出格式

```json
{
  "valid_comments": [
    {
      "id": "rc_123456",
      "type": "review_comment",
      "author": "reviewer1",
      "created_at": "2025-11-28T11:00:00Z",
      "body": "这里应该检查 token 是否过期",
      "location": { ... },
      "validity_reason": "created_after_last_commit"
    }
  ],
  "filtered_out": [
    {
      "id": "rc_111111",
      "filter_reason": "created_before_last_commit",
      "created_at": "2025-11-28T08:00:00Z",
      "last_commit_time": "2025-11-28T10:00:00Z"
    },
    {
      "id": "rc_222222",
      "filter_reason": "already_resolved",
      "resolved_by": "作者回复 'fixed in abc123'"
    },
    {
      "id": "ic_333333",
      "filter_reason": "ci_auto_report",
      "matched_pattern": "Coverage Report"
    }
  ],
  "summary": {
    "total_input": 15,
    "valid": 8,
    "filtered": 7,
    "by_reason": {
      "created_before_last_commit": 4,
      "already_resolved": 2,
      "ci_auto_report": 1
    }
  }
}
```

## 执行步骤

### 1. 接收输入

从 Phase 1 (comment-fetcher) 接收：

- `comments`: 所有评论列表
- `last_commit_timestamp`: 最后 commit 的时间戳

### 2. 时间窗口过滤

遍历每条评论，检查时间条件：

```python
for comment in comments:
    created = parse_iso8601(comment['created_at'])
    updated = parse_iso8601(comment['updated_at'])
    last_commit = parse_iso8601(last_commit_timestamp)

    if created > last_commit:
        mark_valid(comment, "created_after_last_commit")
    elif updated > last_commit:
        mark_valid(comment, "updated_after_last_commit")
    else:
        mark_filtered(comment, "created_before_last_commit")
```

### 3. 已解决检测

对于通过时间过滤的评论，检查是否已解决：

```python
resolved_keywords = [
    'fixed', 'done', 'resolved', 'addressed',
    '已修复', '已解决', '已处理', 'LGTM'
]

def is_resolved(comment, all_comments):
    # 检查是否有回复标记为已解决
    replies = [c for c in all_comments if c['in_reply_to_id'] == comment['id']]
    for reply in replies:
        if any(kw in reply['body'].lower() for kw in resolved_keywords):
            return True, f"回复 '{reply['body'][:50]}...'"
    return False, None
```

### 4. CI/CD 自动报告检测（基于内容）

```python
ci_report_patterns = [
    # 覆盖率报告
    r'Coverage (Report|Summary)',
    r'\d+(\.\d+)?%\s*(coverage|covered)',
    r'codecov.*bot',
    r'coveralls',

    # CI 状态报告
    r'All checks (have )?(passed|failed)',
    r'Build (succeeded|failed)',
    r'CI (passed|failed)',
    r'✅\s*\d+/\d+\s*checks?\s*passed',

    # 依赖更新通知
    r'Bump(s|ed)?\s+[\w\-]+\s+from\s+[\d\.]+\s+to\s+[\d\.]+',
    r'Update(s|d)?\s+dependency',
    r'Renovate',
    r'Dependabot',

    # 自动合并通知
    r'Auto-merg(e|ed|ing)',
    r'This PR (will be|has been) automatically merged'
]

def is_ci_report(body):
    """基于内容检测是否为自动生成的 CI 报告"""
    for pattern in ci_report_patterns:
        if re.search(pattern, body, re.IGNORECASE):
            return True
    return False
```

**注意**：不再使用 `is_bot(author)` 基于用户名过滤，改为 `is_ci_report(body)` 基于内容过滤。

### 5. 生成统计

统计各过滤原因的数量。

## 边界情况处理

### 时区处理

所有时间比较使用 UTC 时区：

- GitHub API 返回的时间已是 UTC
- 确保 `last_commit_timestamp` 也是 UTC

### 评论更新时间

如果评论有回复，`updated_at` 会更新。即使原评论在 commit 之前，如果有新回复（在 commit 之后），评论仍然有效。

### 自我回复

如果评论作者自己回复了 "fixed"，视为已解决。

## 错误处理

### E1: 时间解析失败

- **检测**：ISO 8601 解析失败
- **行为**：
  1. **记录详细错误**：包含原始时间字符串、解析尝试的格式
  2. **标记评论为 `time_unknown`**：不视为有效也不视为过滤
  3. **汇总到输出**
- **流程控制**：
  - 如果 > 20% 的评论时间解析失败：**停止**并报告数据质量问题
  - 如果 <= 20%：继续，但在摘要中明确展示
- **输出**：

  ```json
  {
    "time_parse_failures": [
      {
        "comment_id": "rc_123",
        "raw_timestamp": "invalid-date",
        "error": "Unable to parse as ISO 8601"
      }
    ],
    "time_unknown_comments": [...],
    "warning": "有 {count} 条评论无法验证时效性，已标记为 time_unknown"
  }
  ```

- **用户决策**：`time_unknown` 评论需要用户确认是否处理

### E2: 无有效评论

- **检测**：过滤后 `valid_comments` 为空
- **行为**：返回空结果（这是正常情况）
- **输出**：

  ```json
  {
    "valid_comments": [],
    "summary": { "valid": 0, ... },
    "message": "所有评论均已过时或已解决"
  }
  ```

## 注意事项

- 保守过滤：如有疑问，保留评论
- 保留过滤原因以便用户理解
- 不修改原始评论数据，只添加标记
- 记录 `last_commit_timestamp` 以便调试
