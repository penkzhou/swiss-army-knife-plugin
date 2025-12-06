---
description: 合并依赖更新 PR（Renovate + Dependabot），减少 CI 成本
argument-hint: "[--bot=all|renovate|dependabot] [--dry-run] [--frontend-only] [--backend-only] [--log] [--verbose]"
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

# Merge Dependency PRs Command

将多个依赖更新 PR 合成为一个，减少 CI 成本，提升效率。

**宣布**："我正在使用 merge-dep-prs 命令合并依赖更新。"

---

## 参数解析

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--bot` | `all` | 依赖管理 bot（all=两者/renovate/dependabot） |
| `--dry-run` | `false` | 只分析不执行 |
| `--frontend-only` | `false` | 仅处理前端依赖 |
| `--backend-only` | `false` | 仅处理后端依赖 |
| `--log` | `false` | 启用过程日志（INFO 级别） |
| `--verbose` | `false` | 启用详细日志（DEBUG 级别，隐含 --log） |

### 日志参数说明

- `--log`：记录关键步骤、依赖变更、Git 操作
- `--verbose`：额外记录详细的 PR 解析信息和命令输出
- 日志文件位置：`.claude/logs/swiss-army-knife/merge-dep-prs/`
- 生成两种格式：`.jsonl`（程序查询）和 `.log`（人类阅读）

**示例**：
- `/merge-dep-prs` - 合并所有依赖更新 PR
- `/merge-dep-prs --bot=renovate --dry-run` - 预览 Renovate PR
- `/merge-dep-prs --frontend-only` - 仅合并前端依赖

**Bot 配置说明**（参见 `config/defaults.yaml` 中的 `dependency_management.bots`）：

| Bot | 配置键 | Author 过滤 | PR 标题模式 |
|-----|--------|-------------|-------------|
| `all` | `authors`（复数） | `app/renovate` + `app/dependabot` | 无 |
| `renovate` | `author`（单数） | `app/renovate` | `^(chore\|fix\|feat)\(deps\):` |
| `dependabot` | `author`（单数） | `app/dependabot` | `^(Bump \|(chore\|build\|fix)\(deps(-dev)?\): [Bb]ump )` |

---

## 重要原则

**不要使用 `git merge` 合并 PR**，而是直接修改依赖文件并重新生成 lock 文件。

原因：
1. 避免合并冲突
2. 更高效地处理多个依赖更新
3. 保持提交历史清晰

---

## 步骤 1: 准备工作

### 1.1 验证 Git 状态

确保当前在最新的 main 分支。如果不在 main 分支，尝试切换：

```bash
git branch --show-current
git checkout main
git pull
```

**如果切换或拉取失败**，报告错误原因并询问用户是否继续。常见原因：未提交的更改、合并冲突、网络问题。

### 1.2 加载配置

读取 `config/defaults.yaml` 中的 `stacks.dependency_management` 配置，然后用项目配置 `.claude/swiss-army-knife.yaml`（如存在）覆盖。

需要的配置项：
- `dependency_management.frontend.{package_file, lock_command, keywords}`
- `dependency_management.backend.{package_file, lock_command, keywords}`
- `dependency_management.bots` - Bot 与 author 的映射

**注意**：`lock_command` 已包含目录切换（如 `cd frontend &&`），直接执行即可。

### 1.3 验证配置

在继续之前，验证必需的配置：

1. **检查依赖文件是否存在**（根据 `--frontend-only`/`--backend-only` 参数决定检查哪些）：
   - 前端：检查 `dependency_management.frontend.package_file` 是否存在
   - 后端：检查 `dependency_management.backend.package_file` 是否存在

2. **检查 lock 命令工具是否可用**：
   - 前端：检查 `pnpm`/`npm`/`yarn` 是否安装
   - 后端：检查 `uv`/`pip`/`poetry` 是否安装

**如果文件不存在或工具未安装**：
- 报告具体问题
- 如果是单一技术栈缺失，询问用户是否继续处理另一技术栈
- 如果两者都有问题，停止执行

---

## 步骤 2: 收集依赖更新信息

### 2.1 获取 PR 列表

根据 `--bot` 参数从配置 `dependency_management.bots` 中查找对应的 author，然后获取开放 PR：

```bash
gh pr list --state open --author {author} --json number,title,body
```

**注意**：`--bot=all` 时需要分别获取 `app/renovate` 和 `app/dependabot` 的 PR，合并去重。

**错误处理**：如果命令失败，根据错误类型处理（认证问题提示 `gh auth login`、API 限流重试、网络问题停止）。空结果是正常情况。

### 2.2 解析 PR 信息

对每个 PR，从 body 中提取：

- 依赖包名
- 旧版本 → 新版本
- 变更类型（major/minor/patch）

### 2.3 分类整理

使用配置 `dependency_management.{frontend|backend}.keywords` 匹配 PR 标题和内容，分类为前端或后端依赖。

**如果指定了 `--frontend-only` 或 `--backend-only`**，只保留对应分类。

---

## 步骤 3: Dry-run 检查点

**如果指定了 `--dry-run`**，展示分析结果并停止：

```text
[DRY RUN] 发现 {count} 个待合并的 PR

前端 ({frontend_count}): PR #{number} {package} {old} → {new}
后端 ({backend_count}): PR #{number} {package} {old} → {new}

使用不带 --dry-run 的命令执行合并。
```

---

## 步骤 4: 创建合并分支

首先捕获日期变量（避免跨午夜执行时日期不一致）：

```bash
MERGE_DATE=$(date +%Y%m%d)
BRANCH_NAME="chore/merge-dependencies-${MERGE_DATE}"
git checkout -b "${BRANCH_NAME}"
```

**后续步骤使用 `${BRANCH_NAME}` 变量**，确保分支名称一致。

---

## 步骤 5: 直接修改依赖文件

对每个技术栈（frontend/backend），如果有依赖更新且未被参数排除：

1. 读取依赖文件（`dependency_management.{stack}.package_file`）
2. 使用 Edit 工具批量更新版本号
3. 运行 lock 命令（`dependency_management.{stack}.lock_command`）

**如果 lock 命令失败**：立即停止，报告错误，提供恢复命令（`git checkout -- {stack}/`），询问用户是否手动解决后重试。

---

## 步骤 6: 验证变更

运行项目的检查命令（从配置 `stacks.{frontend|backend}` 获取）。

| 验证结果 | 处理方式 |
|---------|---------|
| 全部通过 | 继续步骤 7 |
| Lint 失败 | 尝试自动修复（如 `eslint --fix`），重试 |
| 测试失败 | 询问用户：1) 中止并回滚，2) 标记为 Draft PR 并继续，3) 部分回滚后重试 |

**测试失败时**，必须明确询问用户选择，不可静默继续。选择 2 时必须在 PR 中添加警告标记。

---

## 步骤 7: 提交和推送

提交所有变更并推送（使用步骤 4 中捕获的 `${BRANCH_NAME}` 变量）：

```bash
git add .
git commit -m "chore(deps): 合并依赖更新 ($(date +%Y-%m-%d))"
git push -u origin "${BRANCH_NAME}"
```

---

## 步骤 8: 创建 PR

使用 `gh pr create` 创建 PR：

```bash
gh pr create --title "chore(deps): 合并依赖更新 (YYYY-MM-DD)" --body "$(cat <<'EOF'
## 概要

合并以下依赖更新 PR，减少 CI 执行次数。

## 包含的 PR

### 前端依赖
{foreach frontend_pr}
- #{number}: {title}
{/foreach}

### 后端依赖
{foreach backend_pr}
- #{number}: {title}
{/foreach}

## 变更详情

### 前端
| 包名 | 旧版本 | 新版本 |
|------|--------|--------|
{frontend_changes}

### 后端
| 包名 | 旧版本 | 新版本 |
|------|--------|--------|
{backend_changes}

## 验证结果

- [ ] 代码质量检查：{lint_status}
- [ ] 测试结果：{test_status}

## 后续工作

{如果有测试失败，说明原因和后续计划}
EOF
)"
```

---

## 步骤 9: 完成报告

输出合并摘要：

```text
=== 依赖合并完成 ===

分支: chore/merge-dependencies-{date}
PR: {pr_url}

已合并的依赖更新:
- 前端: {frontend_count} 个包
- 后端: {backend_count} 个包

原始 PR（可在合并后关闭）:
{foreach pr}
- #{number}: {title}
{/foreach}

下一步:
1. 等待 CI 检查通过
2. 代码审查后合并 PR
3. 关闭原始的依赖更新 PR
```

---

## 错误处理

| 错误场景 | 处理方式 |
|---------|---------|
| Git 操作失败 | 提供恢复命令：`git checkout main && git branch -D chore/merge-dependencies-{date}` |
| Lock 命令失败 | 报告错误，检查版本冲突，建议手动解决 |
| 无可合并的 PR | 说明已检查的 bot 和可能原因（已是最新、已合并、未配置 bot），建议检查配置文件 |
