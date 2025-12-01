---
name: execute-plan
description: 计划执行工作流知识库，包含计划格式规范、任务解析、依赖分析和执行策略
---

# Execute Plan Skill

本 Skill 提供计划执行工作流的核心知识，包括计划格式规范、任务解析规则、依赖分析算法和批次执行策略。

---

## 1. 计划格式规范

### 1.1 支持的格式

| 格式 | 文件扩展名 | 检测方式 |
|------|-----------|----------|
| Markdown | `.md` | 文件扩展名 + 任务模式检测 |
| YAML | `.yaml`, `.yml` | 文件扩展名 + `tasks:` 键检测 |

### 1.2 Markdown 计划格式

**任务标记模式**（按优先级检测）：

```markdown
## Task 1: 实现用户认证模块
描述：实现基于 JWT 的用户认证...

## Task 2: 添加数据库迁移
描述：...
```

```markdown
### 1. 创建 API 端点
描述：...

### 2. 添加单元测试
描述：...
```

```markdown
- [ ] 重构认证中间件
- [ ] 添加错误处理
- [ ] 更新文档
```

```markdown
1. **创建用户服务**
   - 文件: `src/services/user.ts`
   - 描述: ...

2. **添加数据验证**
   - 文件: `src/validators/user.ts`
   - 描述: ...
```

### 1.3 YAML 计划格式

```yaml
title: "用户认证系统实现"
description: "实现完整的用户认证流程"

tasks:
  - id: T-001
    title: "创建用户模型"
    description: "定义 User 数据模型和相关类型"
    files:
      - src/models/user.ts
      - src/types/user.ts
    dependencies: []
    complexity: low

  - id: T-002
    title: "实现认证服务"
    description: "实现登录、注册、Token 刷新逻辑"
    files:
      - src/services/auth.ts
    dependencies:
      - T-001
    complexity: medium
```

### 1.4 任务字段规范

| 字段 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `id` | 否 | string | 任务 ID（自动生成如 T-001） |
| `title` | 是 | string | 任务标题 |
| `description` | 否 | string | 任务描述 |
| `files` | 否 | string[] | 涉及的文件列表 |
| `dependencies` | 否 | string[] | 依赖的任务 ID |
| `complexity` | 否 | enum | low/medium/high |
| `test_files` | 否 | string[] | 相关测试文件 |

---

## 2. 任务解析规则

### 2.1 Markdown 任务提取

**解析优先级**：

1. `## Task N:` 模式
2. `### N.` 模式
3. `- [ ]` 模式
4. `N. **xxx**` 模式

**示例解析**：

```markdown
## Task 1: 创建用户服务

实现用户 CRUD 操作的服务层。

**文件**：
- `src/services/user.ts`
- `src/types/user.ts`

**依赖**：无

**测试**：
- `tests/services/user.test.ts`
```

解析结果：

```json
{
  "id": "T-001",
  "title": "创建用户服务",
  "description": "实现用户 CRUD 操作的服务层。",
  "files": ["src/services/user.ts", "src/types/user.ts"],
  "dependencies": [],
  "test_files": ["tests/services/user.test.ts"],
  "complexity": "medium"
}
```

### 2.2 复杂度推断

如果计划未显式指定复杂度，根据以下规则推断：

| 条件 | 复杂度 |
|------|--------|
| 涉及文件 ≤ 2 且无依赖 | low |
| 涉及文件 3-5 或有 1-2 个依赖 | medium |
| 涉及文件 > 5 或有 > 2 个依赖 | high |

### 2.3 ID 自动生成

如果任务无 ID，按顺序生成：

- `T-001`, `T-002`, `T-003`, ...

---

## 3. 依赖分析算法

### 3.1 显式依赖

计划中通过 `dependencies` 字段声明的依赖关系。

### 3.2 隐式依赖检测

自动检测以下隐式依赖：

1. **同文件修改**：多个任务修改同一文件时，按任务顺序形成依赖链
2. **类型/接口依赖**：任务 A 创建类型，任务 B 使用该类型
3. **导入依赖**：任务 A 创建模块，任务 B 导入该模块

### 3.3 拓扑排序

使用 Kahn 算法进行拓扑排序：

```python
def topological_sort(tasks, dependencies):
    in_degree = {t.id: 0 for t in tasks}
    for deps in dependencies.values():
        for dep in deps:
            in_degree[dep] += 1

    queue = [t for t in tasks if in_degree[t.id] == 0]
    result = []

    while queue:
        task = queue.pop(0)
        result.append(task)
        for t in tasks:
            if task.id in dependencies.get(t.id, []):
                in_degree[t.id] -= 1
                if in_degree[t.id] == 0:
                    queue.append(t)

    if len(result) != len(tasks):
        raise CyclicDependencyError("检测到循环依赖")

    return result
```

### 3.4 循环依赖检测

如果检测到循环依赖：

1. **停止**执行
2. 报告循环涉及的任务
3. 建议解决方案（拆分任务或重新排序）

---

## 4. 批次执行策略

### 4.1 批次划分原则

1. **依赖优先**：同一批次内的任务不应有依赖关系
2. **复杂度平衡**：每批包含的 high 复杂度任务不超过 1 个
3. **大小限制**：每批任务数不超过配置的 `batch_size`

### 4.2 批次生成算法

```python
def generate_batches(sorted_tasks, batch_size, max_parallel):
    batches = []
    current_batch = []
    completed = set()

    for task in sorted_tasks:
        # 检查依赖是否已完成
        deps_satisfied = all(d in completed for d in task.dependencies)

        # 检查是否可以并行（无同文件修改）
        can_parallel = not any(
            set(task.files) & set(t.files)
            for t in current_batch
        )

        if deps_satisfied and can_parallel and len(current_batch) < batch_size:
            current_batch.append(task)
        else:
            if current_batch:
                batches.append(current_batch)
                completed.update(t.id for t in current_batch)
            current_batch = [task]

    if current_batch:
        batches.append(current_batch)

    return batches
```

### 4.3 批次内并行

同一批次内的任务可以并行执行，条件：

1. 任务之间无依赖
2. 任务不修改同一文件
3. 并行数不超过 `max_parallel`

---

## 5. 置信度评估标准

### 5.1 任务置信度

每个任务的置信度基于以下因素：

| 因素 | 权重 | 评分标准 |
|------|------|----------|
| 文件存在性 | 30% | 目标文件/目录是否存在或可创建 |
| 描述清晰度 | 25% | 任务描述是否明确可执行 |
| 依赖可满足 | 25% | 依赖任务是否已定义且无循环 |
| 复杂度合理 | 20% | 复杂度评估是否合理 |

### 5.2 计划整体置信度

整体置信度 = 所有任务置信度的加权平均

权重：
- high 复杂度任务：权重 3
- medium 复杂度任务：权重 2
- low 复杂度任务：权重 1

### 5.3 置信度决策

| 整体置信度 | 行为 |
|-----------|------|
| ≥ 80 | 自动继续执行 |
| 60-79 | 展示验证结果，询问用户是否继续 |
| 40-59 | 建议调整计划后重试 |
| < 40 | 停止，报告计划无法执行 |

---

## 6. TDD 执行流程

### 6.1 每个任务的 TDD 周期

```text
1. RED Phase
   ├─ 识别或创建测试文件
   ├─ 编写失败的测试用例
   └─ 运行测试确认失败

2. GREEN Phase
   ├─ 实现最小代码使测试通过
   └─ 运行测试确认通过

3. REFACTOR Phase
   ├─ 重构代码（保持测试通过）
   ├─ 运行 lint 检查
   └─ 运行类型检查
```

### 6.2 TDD 跳过条件

以下情况可跳过 TDD：

1. 纯配置文件修改
2. 文档更新
3. 样式/格式调整

---

## 7. 常见问题处理

### 7.1 计划格式无法解析

**症状**：无法识别任务列表

**解决**：
1. 检查是否使用支持的格式（Markdown/YAML）
2. 确认任务标记符合规范
3. 提供示例格式供参考

### 7.2 循环依赖

**症状**：拓扑排序失败

**解决**：
1. 识别循环涉及的任务
2. 建议拆分任务或调整依赖
3. 支持用户手动打破循环

### 7.3 文件冲突

**症状**：多个任务修改同一文件且无法确定顺序

**解决**：
1. 检测同文件修改的任务
2. 建议添加显式依赖
3. 串行执行冲突任务

### 7.4 置信度过低

**症状**：整体置信度 < 40

**可能原因**：
- 任务描述不清晰
- 目标文件不存在
- 依赖关系复杂或有循环

**解决**：
1. 报告具体的低置信度任务
2. 列出影响置信度的因素
3. 建议改进措施

---

## 8. 输出格式规范

### 8.1 init_ctx 格式

```json
{
  "config": {
    "test_command": "make test",
    "lint_command": "make lint",
    "typecheck_command": "make typecheck",
    "batch_size": 3,
    "docs": {
      "bugfix_dir": "docs/bugfix",
      "best_practices_dir": "docs/best-practices"
    }
  },
  "plan_info": {
    "source": "file",
    "path": "docs/plans/feature-auth.md",
    "title": "用户认证系统实现",
    "format": "markdown",
    "total_tasks": 5
  },
  "tasks": [...],
  "project_info": {
    "plugin_root": "/path/to/project",
    "git": {
      "branch": "feature/auth",
      "modified_files": []
    },
    "detected_stack": "mixed"
  }
}
```

### 8.2 验证结果格式

```json
{
  "validation_results": [...],
  "execution_order": ["T-001", "T-002", "T-003"],
  "batches": [
    {
      "batch_id": 1,
      "tasks": ["T-001", "T-002"],
      "can_parallel": true
    }
  ],
  "overall_confidence": 85,
  "recommendation": "proceed"
}
```

### 8.3 执行报告格式

```json
{
  "execution_results": [
    {
      "task_id": "T-001",
      "status": "completed",
      "tdd_cycles": 1,
      "changes": [...],
      "duration_seconds": 120
    }
  ],
  "summary": {
    "total": 5,
    "completed": 4,
    "skipped": 1,
    "failed": 0
  },
  "review_results": {...},
  "knowledge_extracted": [...]
}
```
