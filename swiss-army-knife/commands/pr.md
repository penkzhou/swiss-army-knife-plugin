---
description: 自动分析改动、运行质量检查、提交 commit 并创建 PR
argument-hint: "[--no-qa] [--draft] [--log] [--verbose]"
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion
---

# PR Command

基于项目所有改动文件，分析变更内容，运行质量检查，提交 commit 并创建 PR。

**宣布**："我正在使用 pr 命令分析改动并创建 PR。"

---

## 参数解析

从用户输入中解析参数：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--no-qa` | `false` | 跳过质量检查（不推荐） |
| `--draft` | `false` | 创建草稿 PR |
| `--log` | `false` | 启用过程日志（INFO 级别） |
| `--verbose` | `false` | 启用详细日志（DEBUG 级别，隐含 --log） |

### 日志参数说明

- `--log`：记录关键步骤、Git 操作、质量检查结果
- `--verbose`：额外记录详细的 diff 分析和命令输出
- 日志文件位置：`.claude/logs/swiss-army-knife/pr/`
- 生成两种格式：`.jsonl`（程序查询）和 `.log`（人类阅读）

**示例**：

- `/pr` - 分析改动并创建 PR
- `/pr --draft` - 创建草稿 PR
- `/pr --no-qa` - 跳过质量检查
- `/pr --log` - 启用过程日志

---

## 步骤 0: 环境准备

### 0.1 验证 gh CLI 认证

**在开始任何工作之前，必须先验证 gh CLI 已认证**：

```bash
gh auth status
```

**检查认证结果**：

```bash
# 捕获认证状态输出，便于诊断失败原因
AUTH_OUTPUT=$(gh auth status 2>&1)
AUTH_STATUS=$?

if [ $AUTH_STATUS -ne 0 ]; then
  echo "ERROR: GitHub CLI 认证检查失败"
  echo ""
  echo "认证状态输出："
  echo "$AUTH_OUTPUT"
  echo ""
  echo "请运行 'gh auth login' 进行认证"
  exit 1
fi
```

> **重要**：如果 gh 未认证，必须在流程最开始就停止，避免用户完成所有工作后才发现无法创建 PR。

### 0.2 初始化日志（如果启用 --log 或 --verbose）

**生成 session_id**（与其他命令保持一致）：

```bash
# 使用 /dev/urandom 生成 8 位随机字符串，确保唯一性
SESSION_ID=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 8)
```

**创建日志目录和文件**：

```bash
LOG_DIR=".claude/logs/swiss-army-knife/pr"
LOG_ENABLED=true

# 创建日志目录（带错误检查）
if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
  echo "⚠️ 警告：无法创建日志目录 ${LOG_DIR}，日志功能已禁用" >&2
  LOG_ENABLED=false
fi

TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
JSONL_FILE="${LOG_DIR}/${TIMESTAMP}_${SESSION_ID}.jsonl"
LOG_FILE="${LOG_DIR}/${TIMESTAMP}_${SESSION_ID}.log"

# 验证文件可写（仅当目录创建成功时）
if [ "$LOG_ENABLED" = true ]; then
  if ! touch "$JSONL_FILE" 2>/dev/null || ! touch "$LOG_FILE" 2>/dev/null; then
    echo "⚠️ 警告：无法创建日志文件，日志功能已禁用" >&2
    LOG_ENABLED=false
  fi
fi
```

**记录 SESSION_START**（仅当日志已启用）：

```bash
if [ "$LOG_ENABLED" = true ]; then
  # JSONL 格式
  echo '{"ts":"'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'","level":"I","type":"SESSION_START","session_id":"'$SESSION_ID'","command":"/pr","args":{"no_qa":'$NO_QA',"draft":'$DRAFT',"log":true}}' >> "$JSONL_FILE"

  # 文本格式
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] INFO | SESSION_START | PR Command ($SESSION_ID)" >> "$LOG_FILE"
fi
```

> **注意**：后续每个步骤开始和结束时，如果启用了日志，都应追加对应的日志记录。

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

**分支命名规则**：

```text
feat/<short-description>   # 新功能，如 feat/add-auth-module
fix/<short-description>    # 修复问题，如 fix/login-timeout
docs/<short-description>   # 文档更新，如 docs/api-reference
refactor/<short-description> # 代码重构
chore/<short-description>  # 构建/工具变更
```

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

   **检查 merge 结果**：

   ```bash
   # 检查是否有冲突
   if [ -n "$(git ls-files -u)" ]; then
     echo "ERROR: 与 main 分支存在合并冲突"
     echo "冲突文件："
     git ls-files -u | awk '{print $4}' | sort -u
     echo ""
     echo "请手动解决冲突后再运行此命令"
     echo "或执行 'git merge --abort' 取消合并"
     exit 1
   fi
   ```

   > **重要**：如果 merge 产生冲突，必须停止流程并列出冲突文件，让用户手动处理。

---

## 步骤 2: 分析改动

### 2.1 获取改动文件列表

```bash
git status --porcelain
git diff --stat
git diff --cached --stat
```

**检查是否有改动**：

```bash
# 检查是否有任何改动（工作区 + 暂存区）
if [ -z "$(git status --porcelain)" ]; then
  echo "ERROR: 没有检测到任何改动，无法创建 PR"
  echo "请先进行代码修改后再运行此命令"
  exit 1
fi
```

> **重要**：如果没有任何改动（工作区和暂存区都为空），必须停止流程并提示用户。

### 2.2 分析改动内容

对于每个改动的文件：

1. 读取文件 diff：`git diff <file>` 或 `git diff --cached <file>`
2. 总结改动要点
3. 识别改动类型：feat/fix/docs/refactor/chore/test

---

## 步骤 3: 质量检查（除非指定 --no-qa）

### 3.1 检测项目 QA 命令

**首先检测包管理器**（用于 Node.js 项目）：

```bash
# 检测包管理器
if [ -f pnpm-lock.yaml ]; then
  PKG_MANAGER="pnpm"
elif [ -f yarn.lock ]; then
  PKG_MANAGER="yarn"
elif [ -f package-lock.json ]; then
  PKG_MANAGER="npm"
else
  PKG_MANAGER="npm"  # 默认使用 npm
fi
```

**然后按以下优先级检测项目使用的质量检查命令**：

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
     # 检查 ruff 配置
     grep -q "\[tool.ruff" pyproject.toml && echo "ruff: ruff check ."
     # 检查 black 配置
     grep -q "\[tool.black" pyproject.toml && echo "black: black --check ."
     # 检查 mypy 配置
     grep -q "\[tool.mypy" pyproject.toml && echo "mypy: mypy ."
     # 检查 pytest 配置
     grep -q "\[tool.pytest" pyproject.toml && echo "pytest: pytest"
     # 检查 poetry scripts
     grep -q "\[tool.poetry.scripts" pyproject.toml && echo "poetry scripts available"
   fi
   ```

### 3.2 运行质量检查

根据检测结果运行对应命令。使用上一步检测到的 `$PKG_MANAGER`：

| 检测到 | 运行命令 |
|--------|----------|
| Makefile 有 `qa` | `make qa` |
| Makefile 有 `lint` | `make lint` |
| package.json 有 `lint` | `$PKG_MANAGER run lint` |
| package.json 有 `check` | `$PKG_MANAGER run check` |
| package.json 有 `test` | `$PKG_MANAGER run test` |
| pyproject.toml + ruff | `ruff check .` |
| pyproject.toml + black | `black --check .` |
| pyproject.toml + mypy | `mypy .` |

**如果质量检查失败**：

1. 显示错误详情
2. 询问用户：
   - "发现质量检查错误。是否要我尝试自动修复？"
   - 选项：[自动修复] [手动修复] [跳过检查继续]

3. 如果选择自动修复，运行对应的 fix 命令（如 `make lint-fix`、`npm run lint -- --fix`）

### 3.3 质量检查跳过审计

**如果用户指定了 `--no-qa` 或选择跳过检查**：

1. 在 PR body 中添加警告标记：

   ```markdown
   > ⚠️ **注意**：此 PR 跳过了质量检查（lint/test）
   ```

2. 如果启用了日志，记录跳过事件：

   ```bash
   # JSONL 格式
   echo '{"ts":"'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'","level":"W","type":"QA_SKIPPED","session_id":"'$SESSION_ID'","reason":"user_requested"}' >> "$JSONL_FILE"

   # 文本格式
   echo "[$(date +"%Y-%m-%d %H:%M:%S")] WARN | QA_SKIPPED | 质量检查被用户跳过" >> "$LOG_FILE"
   ```

> **重要**：跳过质量检查应该有明确的审计记录，方便后续追溯问题。

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

> **注意**：`git add -A` 会暂存所有改动（包括新文件、修改和删除）。
> 如果需要更精确控制，可以：
>
> - 只添加已跟踪文件的修改：`git add -u`
> - 交互式选择：`git add -p`
> - 添加特定文件：`git add <file1> <file2>`

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

**检查 push 结果**：

```bash
PUSH_RESULT=$?
if [ $PUSH_RESULT -ne 0 ]; then
  echo "ERROR: 推送分支失败，退出码: $PUSH_RESULT"
  echo "可能的原因："
  echo "  - 没有远程仓库写权限"
  echo "  - 远程分支有新提交需要先 pull"
  echo "  - 网络连接问题"
  exit 1
fi
```

> **重要**：如果 push 失败，必须停止流程并向用户报告错误，不能继续创建 PR。

### 6.2 生成 PR 内容

基于 commit 分析生成：

- **Title**: 简洁描述主要改动
- **Body**: 包含以下部分：
  - `## Summary`: 改动摘要（2-3 个要点）
  - `## Changes`: 改动文件列表和说明
  - `## Test Plan`: 测试说明（如适用）

### 6.3 创建 PR

**如果指定了 `--draft` 参数**：

```bash
gh pr create \
  --title "<PR title>" \
  --body "<PR body>" \
  --draft
```

**否则创建正式 PR**：

```bash
gh pr create \
  --title "<PR title>" \
  --body "<PR body>"
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
