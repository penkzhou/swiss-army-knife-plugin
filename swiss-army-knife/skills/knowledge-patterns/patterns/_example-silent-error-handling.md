---
id: _example-silent-error-handling
title: "[示例] 错误处理静默失败"
tags: [error-handling, try-catch, silent-failure, example]
file_patterns: [service, handler, api]
stack: backend
severity: P1
created: 2025-12-01
updated: 2025-12-01
instances: 1
is_example: true  # 标记为示例，不会被实际工作流使用
---

# [示例] 错误处理静默失败

> **注意**: 这是一个示例模式文件，展示 knowledge-patterns 的格式规范。
> 实际模式由 knowledge-writer agent 自动沉淀生成，无需手动创建。

## 模式描述

代码中的 try-catch 块捕获异常后未进行任何处理（静默失败），导致：
- 问题难以追踪和调试
- 用户得不到有意义的错误反馈
- 系统状态可能不一致

## 典型信号

- Reviewer 评论包含 "吞掉异常"、"静默失败"、"没有日志" 关键词
- 代码存在空的 catch 块或仅有 pass/continue
- 错误被捕获但返回值/状态未反映错误

## 推荐修复

1. **记录日志**: 至少记录 error 级别日志，包含异常信息和上下文
2. **返回错误状态**: 让调用方知道操作失败
3. **考虑重新抛出**: 如果当前层无法处理，向上传递异常

```python
# 修复前 (静默失败)
try:
    result = process_data(data)
except Exception:
    pass  # 问题：异常被完全忽略

# 修复后 (正确处理)
try:
    result = process_data(data)
except ProcessingError as e:
    logger.error(f"数据处理失败: {e}", extra={"data_id": data.id})
    raise  # 或返回适当的错误响应
```

---

## 实例记录

### 实例 1: PR #示例 (2025-12-01)
- **文件**: src/services/example.py:42
- **Reviewer**: @示例审查者
- **评论**: "这里的异常被静默吞掉了，应该记录日志并返回错误"
- **修复 Commit**: abc123d (示例)
- **Bugfix 文档**: [示例链接](../../docs/bugfix/example.md)

> 这是示例实例记录，展示实际沉淀时的格式。
