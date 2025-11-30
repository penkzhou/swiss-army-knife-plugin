# Knowledge Patterns 知识沉淀设计

> 生成时间: 2025-12-01
> 状态: 已验证，待实现

## 1. 背景与目标

### 问题
当前 fix-pr-review 流程在 Phase 7 中只是"建议"更新最佳实践文档，没有自动沉淀机制。导致：
- 相同问题重复出现时无法快速定位已有解决方案
- 经验教训无法积累和复用

### 目标
1. **自动沉淀**：高价值修复（P0/P1 + 置信度 ≥ 85）自动写入知识库
2. **智能合并**：相似模式自动追加实例，避免重复
3. **双重可用**：AI 自动查阅 + 人类可读

## 2. 设计决策

| 维度 | 决策 | 理由 |
|------|------|------|
| 使用者 | AI + 人类 | 需要结构化元数据便于 AI 搜索，同时保持 Markdown 可读性 |
| 内容粒度 | 实例级别 | 保留完整上下文（PR、文件、代码），便于追溯和学习 |
| 重复处理 | 智能合并 | 相似度 ≥70 追加，40-69 询问，<40 新建 |
| 组织方式 | 平铺 + 索引 | 简单直观，通过 SKILL.md 索引导航 |

## 3. 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    fix-pr-review 工作流                      │
│                                                             │
│  Phase 7: summary-reporter agent                            │
│      └─→ 调用 knowledge-writer agent（高价值修复时）          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│               knowledge-writer agent (新增)                  │
│                                                             │
│  1. 读取现有索引 (SKILL.md)                                  │
│  2. 计算相似度（基于关键词和技术栈）                           │
│  3. 决策：追加现有 or 创建新模式                              │
│  4. 写入模式文件 + 更新索引                                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           skills/knowledge-patterns/SKILL.md                 │
│                                                             │
│  - AI 自动加载，可在后续 fix-pr-review 时查阅                 │
│  - 包含模式索引表 + 分类导航                                  │
│  - 人类可读的 Markdown 格式                                  │
└─────────────────────────────────────────────────────────────┘
```

## 4. 文件结构

```
swiss-army-knife/
├── skills/
│   └── knowledge-patterns/
│       ├── SKILL.md              # Skill 入口，包含索引
│       └── patterns/             # 模式文件目录
│           ├── auth-token-expiry.md
│           ├── db-transaction-rollback.md
│           └── ...
└── agents/
    └── pr-review/
        └── knowledge-writer.md   # 新增 agent
```

## 5. 模式文件格式

```markdown
---
id: auth-token-expiry
title: Token 过期检查遗漏
tags: [auth, security, backend]
stack: backend
severity: P0
created: 2025-11-28
updated: 2025-12-01
instances: 2
---

# Token 过期检查遗漏

## 模式描述
在认证流程中遗漏 token 过期时间检查，导致过期 token 仍可使用。

## 典型信号
- reviewer 评论包含 "expiry"、"过期"、"token" 关键词
- 代码中有 `decode_token()` 但无时间校验

## 推荐修复
1. 在 token 解码后立即检查 `exp` 字段
2. 过期返回 401 状态码

---

## 实例记录

### 实例 1: PR #123 (2025-11-28)
- **文件**: `src/auth.py:42`
- **Reviewer**: @alice_dev
- **评论**: "这里应该检查 token 是否过期"
- **修复 Commit**: `abc123d`
- **Bugfix 文档**: [链接](../../docs/bugfix/2025-11-28-pr-123-token-expiry.md)
```

## 6. 相似度算法

```python
def calculate_similarity(new_fix, existing_pattern):
    score = 0

    # 1. 技术栈匹配 (30分)
    if new_fix.stack == existing_pattern.stack:
        score += 30

    # 2. 标签重叠度 (30分)
    tag_overlap = len(new_fix.tags & existing_pattern.tags)
    tag_total = len(new_fix.tags | existing_pattern.tags)
    score += 30 * (tag_overlap / tag_total) if tag_total > 0 else 0

    # 3. 关键词匹配 (25分)
    keyword_similarity = jaccard(new_fix.keywords, existing_pattern.keywords)
    score += 25 * keyword_similarity

    # 4. 文件路径模式 (15分)
    if path_pattern_match(new_fix.file_path, existing_pattern.file_patterns):
        score += 15

    return score
```

**决策阈值**：

| 相似度 | 行为 |
|--------|------|
| ≥ 70 | 追加实例到现有模式 |
| 40-69 | 询问用户决定 |
| < 40 | 创建新模式 |

## 7. 实现任务

### 7.1 创建 knowledge-patterns Skill
- 文件：`skills/knowledge-patterns/SKILL.md`
- 内容：索引表 + 分类导航 + 使用指南
- 创建：`skills/knowledge-patterns/patterns/` 目录

### 7.2 创建 knowledge-writer Agent
- 文件：`agents/pr-review/knowledge-writer.md`
- 职责：相似度检测、智能合并、文件写入、索引更新
- 工具：Read, Write, Edit, Glob, Grep

### 7.3 修改 summary-reporter Agent
- 文件：`agents/pr-review/summary-reporter.md`
- 修改：在知识沉淀步骤调用 knowledge-writer agent
- 触发条件：P0/P1 + 置信度 ≥ 85

## 8. 验收标准

1. [ ] 高价值修复自动写入 `skills/knowledge-patterns/patterns/`
2. [ ] 相似模式正确追加实例而非重复创建
3. [ ] SKILL.md 索引表自动更新
4. [ ] AI 在后续 fix-pr-review 时能查阅已有模式
5. [ ] 人类可直接阅读模式文档
