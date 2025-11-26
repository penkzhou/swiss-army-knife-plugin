---
description: 执行标准化 E2E Bugfix 工作流（六阶段流程）
argument-hint: "[--phase=0,1,2,3,4,5|all] [--dry-run]"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task", "TodoWrite", "AskUserQuestion"]
---

# Bugfix E2E Workflow v0.1

> ⚠️ 此命令为占位模板，Agent 尚未完善。

基于测试失败的 E2E 用例，执行标准化 bugfix 流程。

**宣布**："我正在使用 Bugfix E2E v0.1 工作流进行问题修复。"

---

## 配置加载

1. 读取插件默认配置: `${PLUGIN_ROOT}/config/defaults.yaml`
2. 检查项目配置: `.claude/swiss-army-knife.yaml`
3. 提取 `stacks.e2e` 配置

---

## Phase 0: 问题收集与分类

### 0.1 获取测试失败输出

```bash
${config.test_command} 2>&1 | head -200
```

### 0.2 启动 error-analyzer agent

```yaml
subagent_type: "swiss-army-knife:e2e-error-analyzer"
prompt: |
  分析以下测试失败输出...

  ## 配置
  - bugfix_dir: ${config.docs.bugfix_dir}
  - best_practices_dir: ${config.docs.best_practices_dir}
  - search_keywords: ${config.docs.search_keywords}
```

---

## Phase 1-5: 待完善

后续阶段参考 fix-frontend.md 实现，使用 e2e-* agent。

当前仅支持 Phase 0 错误分析。
