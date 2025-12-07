---
allowed-tools: Bash(gh issue view:*), Bash(gh search:*), Bash(gh issue list:*), Bash(gh pr comment:*), Bash(gh pr diff:*), Bash(gh pr view:*), Bash(gh pr list:*)
description: 依赖更新合成器
argument-hint: "[--bot=all|renovate|dependabot] [--dry-run] [--frontend-only] [--backend-only] [--log] [--verbose]"
disable-model-invocation: false
---

将多个依赖更新 PR 合成为一个，减少 CI 成本，提升效率。

## 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--bot=<type>` | `all` | 筛选 bot 类型：`all`（全部）、`renovate`、`dependabot` |
| `--dry-run` | `false` | 只展示将要合并的 PR，不执行实际操作 |
| `--frontend-only` | `false` | 只处理前端依赖更新 |
| `--backend-only` | `false` | 只处理后端依赖更新 |
| `--log` | `false` | 启用 INFO 级别日志 |
| `--verbose` | `false` | 启用 DEBUG 级别日志（包含详细操作信息） |

**示例**：

```bash
# 合并所有 bot 的依赖更新
/swiss-army-knife:merge-dep-prs

# 只处理 Renovate 的前端依赖
/swiss-army-knife:merge-dep-prs --bot=renovate --frontend-only

# Dry run 模式查看将要合并的 PR
/swiss-army-knife:merge-dep-prs --dry-run
```

**重要原则**：不要使用 `git merge` 合并 PR，而是直接修改依赖文件并重新生成 lock 文件。

## 执行步骤

### 1. 准备工作

- 确保当前在最新的 main 分支
- 如果不在 main 分支，先切换到 main 并 `git pull` 拉取最新代码

### 2. 收集依赖更新信息

1. 使用 `gh pr list --state open --author app/renovate` 获取所有 Renovate PR，使用 `gh pr list --state open --author app/dependabot` 获取所有 Dependabot PR
2. 对每个 PR 使用 `gh pr view <number> --json body` 查看详细信息
3. 从 PR body 中提取依赖包名和版本变更信息
4. 分类整理：
   - **前端依赖**：`package.json` 相关的更新
   - **后端依赖**：`pyproject.toml` 相关的更新

### 3. 创建合并分支

```bash
git checkout -b chore/merge-dependencies-$(date +%Y%m%d)
```

### 4. 直接修改依赖文件（核心步骤）

**前端依赖更新**（如果有）：
1. 直接编辑 `frontend/package.json`
2. 更新所有需要升级的依赖版本号
3. 运行 `cd frontend && npm install` 重新生成 lock 文件

**后端依赖更新**（如果有）：
1. 直接编辑 `backend/pyproject.toml`
2. 更新所有需要升级的依赖版本号
3. 运行 `cd backend && uv sync --all-extras` 重新生成 lock 文件并安装依赖

### 5. 验证变更

```bash
make qa              # 代码质量检查
make test            # 运行测试
```

### 6. 提交和推送

1. 将所有变更添加到一个提交：
   ```bash
   git add .
   git commit -m "chore(deps): 合并依赖更新 ($(date +%Y-%m-%d))"
   ```

2. 推送分支：
   ```bash
   git push -u origin chore/merge-dependencies-$(date +%Y%m%d)
   ```

### 7. 创建 PR

使用 `gh pr create` 创建 PR，包含：
- **标题**：`chore(deps): 合并依赖更新 (YYYY-MM-DD)`
- **描述**：
  - 列出所有合并的 PR 编号和依赖变更
  - 说明验证结果（版本检查、质量检查、测试结果）
  - 注明是否有测试失败及原因
  - 标注后续工作（如果有）

## 注意事项

1. **不要使用 git merge**：直接修改文件更高效，避免冲突
2. **分前后端处理**：前后端依赖分开更新，互不干扰
3. **单次提交**：所有依赖更新放在一个提交中，保持历史清晰
4. **完整测试**：确保 `make qa && make test` 都通过后再提交 PR
5. **记录失败**：如有测试失败，在 PR 描述中明确说明原因和后续计划

## 错误处理

### 常见错误

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `gh: command not found` | GitHub CLI 未安装 | 运行 `brew install gh`（macOS）或参考 [gh 安装文档](https://cli.github.com/) |
| `gh: not logged in` | GitHub CLI 未认证 | 运行 `gh auth login` 进行认证 |
| `No open PRs found` | 没有符合条件的依赖更新 PR | 检查 bot 过滤参数，确认 Renovate/Dependabot 已启用 |
| `npm install failed` | 前端依赖冲突或版本不兼容 | 检查 `package.json` 中的版本范围，必要时手动调整 |
| `uv sync failed` | 后端依赖冲突或版本不兼容 | 检查 `pyproject.toml` 中的版本约束，必要时放宽范围 |
| `make qa failed` | 代码质量检查失败 | 查看具体的 lint 错误，可能需要手动修复格式问题 |
| `make test failed` | 测试失败 | 分析失败原因，可能是依赖 API 变更需要代码适配 |

### 依赖冲突处理

当遇到依赖版本冲突时：

1. **前端（npm）**：
   - 检查 `npm ls <package>` 查看依赖树
   - 使用 `npm dedupe` 尝试自动解决
   - 必要时使用 `overrides` 字段强制版本

2. **后端（uv/pip）**：
   - 检查 `uv pip tree` 查看依赖关系
   - 调整 `pyproject.toml` 中的版本范围
   - 考虑排除某些依赖更新到下次处理

### 部分失败处理

如果部分依赖更新导致测试失败：

1. 使用 `--dry-run` 先查看所有待合并的 PR
2. 使用 `--frontend-only` 或 `--backend-only` 分开处理
3. 在 PR 描述中记录跳过的依赖及原因
4. 创建单独的 issue 跟踪需要修复的依赖更新
