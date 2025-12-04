---
description: 自动分析改动、运行质量检查、提交 commit 并创建 PR
argument-hint: "[--no-qa] [--draft]"
allowed-tools: ["Read", "Glob", "Grep", "Bash", "AskUserQuestion"]
---

# PR Command

基于项目所有改动文件，分析变更内容，运行质量检查，提交 commit 并创建 PR。

**宣布**："我正在使用 pr 命令分析改动并创建 PR。"

---

## 参数解析

从用户输入中解析参数：

- `--no-qa`：跳过质量检查（不推荐）
- `--draft`：创建草稿 PR

**示例**：

- `/pr` - 分析改动并创建 PR
- `/pr --draft` - 创建草稿 PR
- `/pr --no-qa` - 跳过质量检查

---

## 步骤 1: 分支状态检查

### 1.1 获取当前分支

```bash
git branch --show-current
```

### 1.2 根据分支采取不同策略

**如果当前是 main 分支**：

1. 基于 main 创建新的特性分支
2. 询问用户分支名称，或根据改动内容自动生成

**如果当前不是 main 分支**：

1. 检查是否有远程分支：`git fetch origin && git branch -r | grep "origin/$(git branch --show-current)"`
2. 如果有远程分支，检查是否需要 pull：

   ```bash
   git fetch origin
   git status -uno
   ```

3. 如果本地落后于远程，执行 pull：

   ```bash
   git pull origin $(git branch --show-current)
   ```

4. 检查是否需要与 main 同步：

   ```bash
   git fetch origin main
   git merge-base --is-ancestor origin/main HEAD || echo "需要 merge main"
   ```

5. 如果需要，执行 merge main：

   ```bash
   git merge origin/main
   ```

---

## 步骤 2: 分析改动

### 2.1 获取改动文件列表

```bash
git status --porcelain
git diff --stat
git diff --cached --stat
```

### 2.2 分析改动内容

对于每个改动的文件：

1. 读取文件 diff：`git diff <file>` 或 `git diff --cached <file>`
2. 总结改动要点
3. 识别改动类型：feat/fix/docs/refactor/chore/test

---

## 步骤 3: 质量检查（除非指定 --no-qa）

### 3.1 检测项目 QA 命令

按以下优先级检测项目使用的质量检查命令：

1. **Makefile**：检查是否存在 `make qa` 或 `make lint` 或 `make check`

   ```bash
   if [ -f Makefile ]; then
     grep -E "^(qa|lint|check):" Makefile
   fi
   ```

2. **package.json**：检查 npm scripts

   ```bash
   if [ -f package.json ]; then
     # 检查 lint、test、check 等脚本
     cat package.json | grep -E '"(lint|test|check|qa)"'
   fi
   ```

3. **pyproject.toml / setup.cfg**：Python 项目

   ```bash
   if [ -f pyproject.toml ]; then
     # 可能使用 ruff、black、mypy 等
   fi
   ```

### 3.2 运行质量检查

根据检测结果运行对应命令。常见映射：

| 检测到 | 运行命令 |
|--------|----------|
| Makefile 有 `qa` | `make qa` |
| Makefile 有 `lint` | `make lint` |
| package.json 有 `lint` | `npm run lint` 或 `pnpm lint` |
| package.json 有 `check` | `npm run check` |
| pyproject.toml + ruff | `ruff check .` |

**如果质量检查失败**：

1. 显示错误详情
2. 询问用户：
   - "发现质量检查错误。是否要我尝试自动修复？"
   - 选项：[自动修复] [手动修复] [跳过检查继续]

3. 如果选择自动修复，运行对应的 fix 命令（如 `make lint-fix`、`npm run lint -- --fix`）

---

## 步骤 4: 生成 Commit 信息

### 4.1 基于改动分析生成 commit message

遵循 Conventional Commits 格式：

```text
<type>(<scope>): <description>

[可选的详细描述]

[可选的 footer]
```

**类型映射**：

- `feat`: 新功能
- `fix`: 修复问题
- `docs`: 文档更新
- `refactor`: 代码重构
- `chore`: 构建/工具变更
- `test`: 测试相关
- `style`: 代码风格（不影响功能）
- `perf`: 性能优化

### 4.2 确认 commit message

向用户展示生成的 commit message，询问是否需要修改。

---

## 步骤 5: 提交改动

### 5.1 暂存文件

```bash
git add -A
```

### 5.2 创建 commit

```bash
git commit -m "<commit message>"
```

---

## 步骤 6: 创建 PR

### 6.1 推送分支

```bash
git push -u origin $(git branch --show-current)
```

### 6.2 生成 PR 内容

基于 commit 分析生成：

- **Title**: 简洁描述主要改动
- **Body**: 包含以下部分：
  - `## Summary`: 改动摘要（2-3 个要点）
  - `## Changes`: 改动文件列表和说明
  - `## Test Plan`: 测试说明（如适用）

### 6.3 创建 PR

```bash
gh pr create \
  --title "<PR title>" \
  --body "<PR body>" \
  [--draft]  # 如果指定了 --draft 参数
```

---

## 步骤 7: 完成报告

输出结果摘要：

```text
PR 创建成功！

Commit: <commit hash> - <commit message>
PR: <PR URL>
分支: <branch name>

改动文件：
- file1 (新增/修改/删除)
- file2 (新增/修改/删除)
...

下一步：
1. 在 GitHub 上查看 PR：<PR URL>
2. 等待 CI 检查完成
3. 请求 review
```

---

## 错误处理

### Git 冲突

如果遇到 merge 冲突：

1. 列出冲突文件
2. 询问用户如何处理
3. 提供恢复命令：`git merge --abort`

### Push 失败

如果 push 失败：

1. 检查是否是权限问题
2. 检查是否需要 pull
3. 提供具体的解决建议

### PR 创建失败

如果 gh pr create 失败：

1. 检查 gh 是否已认证：`gh auth status`
2. 检查是否已有同名 PR
3. 提供手动创建 PR 的链接
