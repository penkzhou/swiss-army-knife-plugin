---
description: 执行标准化前端 Bugfix 工作流（六阶段流程）
argument-hint: "[--phase=0,1,2,3,4,5|all] [--dry-run]"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task", "TodoWrite", "AskUserQuestion"]
---

# Bugfix Frontend Workflow v2.1

基于测试失败的前端用例，执行标准化 bugfix 流程。

**宣布**："我正在使用 Bugfix Frontend v2.1 工作流进行问题修复。"

---

## 参数解析

从用户输入中解析参数：
- `--phase=X,Y` 或 `--phase=all`：指定执行阶段（默认 all）
- `--dry-run`：只分析不执行修改

---

## Phase 0: 问题收集与分类

### 0.1 获取测试失败输出

如果用户没有提供测试输出，运行测试获取：

```bash
make test TARGET=frontend 2>&1 | head -200
```

### 0.2 启动 error-analyzer agent

使用 Task tool 启动 error-analyzer agent 解析测试输出：

```
subagent_type: "swiss-army-knife-plugin:error-analyzer"
prompt: |
  分析以下测试失败输出，完成错误解析、分类、历史匹配和文档匹配。

  ## 测试输出
  [粘贴测试输出]

  ## 项目路径
  - bugfix 文档: docs/bugfix/
  - troubleshooting: docs/best-practices/04-testing/frontend/troubleshooting.md
```

### 0.3 记录到 TodoWrite

使用 TodoWrite 记录所有待处理错误，格式：
```
- 处理错误 #1: [文件:行号] [错误类型] - [简述]
- 处理错误 #2: ...
```

---

## Phase 1: 诊断分析

### 1.1 启动 root-cause agent

使用 Task tool 启动 root-cause agent 进行根因分析：

```
subagent_type: "swiss-army-knife-plugin:root-cause"
prompt: |
  基于以下信息进行根因分析：

  ## 结构化错误
  [Phase 0 的输出]

  ## 相关代码
  [使用 Read 获取的相关代码]

  ## 参考诊断文档
  [匹配的 troubleshooting 章节]
```

### 1.2 置信度决策

根据 root-cause agent 返回的置信度（0-100）：

| 置信度 | 行为 |
|--------|------|
| >= 60 | 继续 Phase 2 |
| 40-59 | **暂停**，向用户展示分析结果并询问是否继续 |
| < 40 | **停止**，向用户询问更多信息 |

---

## Phase 2: 方案设计

### 2.1 启动 solution agent

使用 Task tool 启动 solution agent 设计修复方案：

```
subagent_type: "swiss-army-knife-plugin:solution"
prompt: |
  基于以下根因分析设计修复方案：

  ## 根因分析
  [Phase 1 的输出]

  ## 参考最佳实践
  - docs/best-practices/04-testing/frontend/README.md
  - docs/best-practices/04-testing/frontend/implementation-guide.md
```

### 2.2 安全审查

如果涉及以下文件类型，进行安全审查：
- 认证相关 (`auth`, `login`, `token`)
- API 调用 (`api`, `fetch`, `axios`)
- 用户输入处理

---

## Phase 3: 方案文档化

### 3.1 生成 Bugfix 文档

如果不是 `--dry-run` 模式，使用 Write tool 创建文档：

```
文件路径: docs/bugfix/{YYYY-MM-DD}-{issue-slug}.md
```

文档模板：

```markdown
# [问题描述] Bugfix 报告

> 日期：{date}
> 置信度：{confidence}/100

## 1. 问题概述

### 1.1 错误信息
[结构化错误列表]

### 1.2 根因分析
[根因描述 + 证据]

## 2. 修复方案

### 2.1 主方案
[方案描述]

### 2.2 TDD 计划

#### RED Phase
```typescript
// 先写失败测试
```

#### GREEN Phase
```typescript
// 最小实现
```

#### REFACTOR Phase
- [ ] 重构项 1
- [ ] 重构项 2

### 2.3 影响分析
[影响范围]

### 2.4 风险评估
[风险列表]

## 3. 验证计划
- [ ] 单元测试通过
- [ ] 覆盖率 >= 90%
- [ ] 无回归
```

### 3.2 等待用户确认

**询问用户**：
> "Bugfix 方案已生成，请查看 docs/bugfix/{date}-{issue}.md。
> 确认后开始实施，或提出调整意见。"

如果是 `--dry-run` 模式，到此结束。

---

## Phase 4: 实施执行

### 4.1 启动 executor agent

使用 Task tool 启动 executor agent 执行 TDD 修复：

```
subagent_type: "swiss-army-knife-plugin:executor"
prompt: |
  执行 TDD 修复流程：

  ## TDD 计划
  [Phase 2 的 TDD 计划]

  ## 执行要求
  1. RED: 先运行测试确认失败
  2. GREEN: 实现最小代码使测试通过
  3. REFACTOR: 重构代码保持测试通过

  ## 验证命令
  - make test TARGET=frontend FILTER={test_file}
  - make lint TARGET=frontend
  - make typecheck TARGET=frontend
```

### 4.2 批次报告

每批完成后向用户报告进度，等待确认后继续。

---

## Phase 5: 验证与沉淀

### 5.1 启动 quality-gate agent

使用 Task tool 启动 quality-gate agent 检查质量门禁：

```
subagent_type: "swiss-army-knife-plugin:quality-gate"
prompt: |
  执行质量门禁检查：

  ## 变更文件
  [变更文件列表]

  ## 门禁标准
  - 覆盖率 >= 90%
  - 新增代码覆盖率 = 100%
  - lint/typecheck 必须通过
  - 无回归
```

### 5.2 启动 knowledge agent

如果质量门禁通过，启动 knowledge agent 进行知识沉淀：

```
subagent_type: "swiss-army-knife-plugin:knowledge"
prompt: |
  基于以下修复过程，提取可沉淀的知识：

  ## 修复过程
  [完整修复过程记录]

  ## 现有文档
  - docs/bugfix/
  - docs/best-practices/04-testing/frontend/

  ## 判断标准
  - 是否是新发现的问题模式？
  - 解决方案是否可复用？
  - 是否有值得记录的教训？
```

### 5.3 完成报告

汇总整个修复过程，向用户报告：
- 修复的问题列表
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

### E4: 覆盖率不达标
- **行为**：补充测试用例
- **输出**：缺失覆盖的代码区域

---

## 关键原则

1. **TodoWrite 跟踪**：记录所有待处理项，防止遗漏
2. **置信度驱动**：低置信度时停止，不要猜测
3. **TDD 强制**：所有代码变更必须先写测试
4. **增量验证**：每步后验证，不要积累问题
5. **知识沉淀**：有价值的经验必须记录
6. **用户确认**：关键决策点等待用户反馈
