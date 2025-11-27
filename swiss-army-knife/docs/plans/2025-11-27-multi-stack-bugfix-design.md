# Multi-Stack Bugfix Workflow 设计文档

> 日期：2025-11-27
> 版本：v0.3.0
> 状态：待实现

## 1. 背景与目标

### 1.1 当前问题

- **命名不明确**：`/fix` 命令未体现技术栈（实际仅支持 frontend）
- **路径硬编码**：`docs/bugfix/`、`docs/best-practices/04-testing/frontend/` 等路径写死在多个文件中
- **扩展性差**：无法支持 backend、e2e 等其他技术栈

### 1.2 目标

1. 重命名命令为 `/fix-frontend`、`/fix-backend`、`/fix-e2e`
2. 实现配置驱动的路径和参数管理
3. 支持项目级配置覆盖插件默认值
4. 为 backend 和 e2e 提供占位框架

## 2. 设计决策

| 维度 | 决策 | 理由 |
|------|------|------|
| 命令结构 | 多命令独立 | 清晰区分技术栈，用户体验直观 |
| Agent 复用 | 技术栈独立 Agent | 各技术栈错误模式差异大，独立更灵活 |
| 文档查找 | 配置目录 + 关键词搜索 | 灵活适配不同项目结构 |
| 配置策略 | 插件默认 + 项目覆盖 | 开箱即用，同时支持定制 |
| 目录结构 | 目录分组 | 清晰分离，易于导航和维护 |

## 3. 目录结构

```
swiss-army-knife/
├── .claude-plugin/
│   └── plugin.json
├── config/
│   └── defaults.yaml            # 默认配置
├── commands/
│   ├── fix-frontend.md
│   ├── fix-backend.md
│   └── fix-e2e.md
├── agents/
│   ├── frontend/
│   │   ├── error-analyzer.md
│   │   ├── root-cause.md
│   │   ├── solution.md
│   │   ├── executor.md
│   │   ├── quality-gate.md
│   │   └── knowledge.md
│   ├── backend/
│   │   └── ... (占位)
│   └── e2e/
│       └── ... (占位)
├── skills/
│   ├── frontend-bugfix/SKILL.md
│   ├── backend-bugfix/SKILL.md
│   └── e2e-bugfix/SKILL.md
├── docs/
│   └── plans/
└── README.md
```

## 4. 配置系统

### 4.1 默认配置 (`config/defaults.yaml`)

```yaml
stacks:
  frontend:
    name: "Frontend (React/TypeScript)"
    test_command: "make test TARGET=frontend"
    lint_command: "make lint TARGET=frontend"
    typecheck_command: "make typecheck TARGET=frontend"
    docs:
      bugfix_dir: "docs/bugfix"
      best_practices_dir: "docs/best-practices"
      search_keywords:
        mock: ["mock", "msw", "vi.mock", "server.use"]
        async: ["async", "await", "findBy", "waitFor"]
        type: ["typescript", "type", "interface", "as any"]
    error_patterns:
      mock_conflict:
        frequency: 71
        signals: ["vi.mock", "server.use"]
      type_mismatch:
        frequency: 15
        signals: ["as any", "type error"]
      async_timing:
        frequency: 8
        signals: ["findBy", "await"]
      render_issue:
        frequency: 4
        signals: ["render", "screen"]
      cache_dependency:
        frequency: 2
        signals: ["useEffect", "useMemo"]

  backend:
    name: "Backend (Node.js/Python)"
    test_command: "make test TARGET=backend"
    lint_command: "make lint TARGET=backend"
    docs:
      bugfix_dir: "docs/bugfix"
      best_practices_dir: "docs/best-practices"
      search_keywords:
        database: ["database", "query", "ORM", "SQL"]
        api: ["endpoint", "request", "response", "REST"]
        auth: ["authentication", "authorization", "token"]
    error_patterns: {}  # 待定义

  e2e:
    name: "E2E (Playwright/Cypress)"
    test_command: "make test TARGET=e2e"
    docs:
      bugfix_dir: "docs/bugfix"
      best_practices_dir: "docs/best-practices"
      search_keywords:
        selector: ["selector", "locator", "element"]
        timing: ["timeout", "wait", "retry"]
        network: ["intercept", "mock", "request"]
    error_patterns: {}  # 待定义
```

### 4.2 项目覆盖 (`.claude/swiss-army-knife.yaml`)

```yaml
# 仅覆盖需要定制的部分
stacks:
  frontend:
    test_command: "pnpm test:unit"
    docs:
      best_practices_dir: "documentation/testing"
```

### 4.3 配置合并逻辑

1. 加载插件默认配置
2. 检查项目根目录 `.claude/swiss-army-knife.yaml`
3. 深度合并：项目配置覆盖默认配置的对应字段
4. 未指定字段保留默认值

## 5. Agent 注册

### 5.1 plugin.json 配置

```json
{
  "name": "swiss-army-knife",
  "version": "0.3.0",
  "description": "Multi-stack bugfix workflow plugin",
  "agents": {
    "frontend-error-analyzer": "agents/frontend/error-analyzer.md",
    "frontend-root-cause": "agents/frontend/root-cause.md",
    "frontend-solution": "agents/frontend/solution.md",
    "frontend-executor": "agents/frontend/executor.md",
    "frontend-quality-gate": "agents/frontend/quality-gate.md",
    "frontend-knowledge": "agents/frontend/knowledge.md",
    "backend-error-analyzer": "agents/backend/error-analyzer.md",
    "backend-root-cause": "agents/backend/root-cause.md",
    "e2e-error-analyzer": "agents/e2e/error-analyzer.md",
    "e2e-root-cause": "agents/e2e/root-cause.md"
  }
}
```

### 5.2 命名约定

- Agent ID: `{stack}-{role}`
- 调用格式: `swiss-army-knife:{agent-id}`

## 6. 文档搜索与自动创建

### 6.1 搜索流程

1. 读取配置获取 `best_practices_dir` 和 `search_keywords`
2. 根据错误类型选择关键词组
3. 使用 Grep 在目录中搜索包含关键词的 `.md` 文件
4. 按相关度排序返回匹配文档
5. 无匹配时创建占位文档

### 6.2 占位文档模板

```markdown
# {keyword} 最佳实践

> 此文档由 swiss-army-knife 插件自动创建，请补充内容。

## 待补充内容

- [ ] 常见问题和解决方案
- [ ] 推荐模式
- [ ] 反模式警告

## 相关错误类型

{error_types}

## 参考资源

<!-- 添加参考链接 -->
```

## 7. 迁移计划

### 7.1 文件迁移映射

| 当前位置 | 迁移后位置 |
|----------|-----------|
| `commands/fix.md` | `commands/fix-frontend.md` |
| `agents/error-analyzer.md` | `agents/frontend/error-analyzer.md` |
| `agents/root-cause.md` | `agents/frontend/root-cause.md` |
| `agents/solution.md` | `agents/frontend/solution.md` |
| `agents/executor.md` | `agents/frontend/executor.md` |
| `agents/quality-gate.md` | `agents/frontend/quality-gate.md` |
| `agents/knowledge.md` | `agents/frontend/knowledge.md` |
| `skills/bugfix-workflow/` | `skills/frontend-bugfix/` |

### 7.2 实现范围 (v0.3.0)

| 技术栈 | 状态 | 说明 |
|--------|------|------|
| Frontend | 完整实现 | 迁移现有 agent，更新为配置驱动 |
| Backend | 骨架占位 | 目录结构 + 基础 agent 模板 |
| E2E | 骨架占位 | 目录结构 + 基础 agent 模板 |

## 8. README 更新要点

需要在 README 中添加：

1. **配置说明**：默认配置位置、项目覆盖方式
2. **命令使用**：`/fix-frontend`、`/fix-backend`、`/fix-e2e` 用法
3. **扩展指南**：如何为新技术栈添加 agent
4. **配置示例**：常见项目的配置示例

## 9. 后续演进

- **v0.3.x**：完善 backend agent 错误模式和诊断逻辑
- **v0.4.x**：完善 e2e agent 错误模式和诊断逻辑
- **v0.5.x**：跨技术栈知识共享机制
