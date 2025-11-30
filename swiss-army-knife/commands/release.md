---
description: 自动化发版流程：更新 CHANGELOG、plugin.json、创建 git tag 并推送
argument-hint: "<version> [--no-push] [--dry-run]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "AskUserQuestion"]
---

# Release Command

自动化插件发版流程，包括更新文档、版本号、创建 tag 和推送。

**宣布**："我正在使用 release 命令执行自动化发版流程。"

---

## 参数解析

从用户输入中解析参数：

- `<version>`：新版本号（必需，格式：X.Y.Z，例如 0.3.0）
- `--no-push`：不自动推送 tag 到远程仓库
- `--dry-run`：预览操作但不实际执行

**示例**：

- `/release 0.3.0` - 发布 0.3.0 版本并推送
- `/release 0.3.0 --no-push` - 发布 0.3.0 但不推送
- `/release 0.3.0 --dry-run` - 预览发布操作

---

## 步骤 1: 参数验证

### 1.1 验证版本号格式

检查版本号是否符合语义化版本格式（X.Y.Z）：

```bash
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "错误：版本号格式不正确。应为 X.Y.Z 格式（例如：0.3.0）"
  exit 1
fi
```

### 1.2 读取当前版本

读取 `.claude-plugin/plugin.json` 获取当前版本号，确保新版本号大于当前版本。

**验证规则**：

- 如果当前是 0.2.0，新版本应该是 0.2.1、0.3.0 或 1.0.0
- 不允许降级版本或使用相同版本号

---

## 步骤 2: 工作区检查

### 2.1 检查 git 状态

确保工作区干净，避免意外提交未完成的工作：

```bash
# 检查是否有未提交的更改
git status --porcelain
```

如果有未提交的更改，询问用户：

- "检测到未提交的更改。是否继续？这些更改将包含在发版提交中。"
- 选项：[继续] [取消]

### 2.2 验证 CHANGELOG.md

读取 `CHANGELOG.md` 并验证：

1. 文件存在
2. 包含 `## [未发布]` 区域
3. [未发布] 区域下有实际内容（不只是空标题）

如果 [未发布] 区域为空，警告用户：

- "CHANGELOG.md 的 [未发布] 区域为空。是否继续发版？"
- 选项：[继续] [取消]

---

## 步骤 3: 更新文件

### 3.1 更新 CHANGELOG.md

执行以下转换：

1. **添加新版本标题**：

   ```markdown
   ## [未发布]

   ## [X.Y.Z] - YYYY-MM-DD
   ```

   将 [未发布] 下的内容移到新版本标题下。

2. **更新底部链接**：

   ```markdown
   [未发布]: https://github.com/penkzhou/swiss-army-knife-plugin/compare/vX.Y.Z...HEAD
   [X.Y.Z]: https://github.com/penkzhou/swiss-army-knife-plugin/compare/vPREV...vX.Y.Z
   ```

**实现**：使用 Read 读取文件，使用 Edit 工具进行精确替换。

### 3.2 更新 plugin.json

更新 `.claude-plugin/plugin.json` 中的版本号：

```json
{
  "version": "X.Y.Z"
}
```

**实现**：使用 Read 和 Edit 工具进行精确替换。

---

## 步骤 4: Git 操作

### 4.1 创建提交

**如果不是 dry-run 模式**：

```bash
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: release version X.Y.Z"
```

### 4.2 创建 tag

```bash
git tag -a vX.Y.Z -m "Release version X.Y.Z"
```

### 4.3 推送（可选）

**如果没有 --no-push 标志**：

```bash
git push origin main
git push origin vX.Y.Z
```

**如果有 --no-push 标志**：

提示用户：

```text
✅ 发版完成！Tag vX.Y.Z 已创建。

要推送到远程仓库，请运行：
  git push origin main
  git push origin vX.Y.Z
```

---

## 步骤 5: 完成报告

输出发版摘要：

```text
🎉 版本 X.Y.Z 发布成功！

✅ 已更新 CHANGELOG.md
✅ 已更新 .claude-plugin/plugin.json
✅ 已创建 git commit
✅ 已创建 tag vX.Y.Z
[✅ 已推送到远程仓库] （如果执行了推送）

下一步：
1. 在 GitHub 上创建 Release：https://github.com/penkzhou/swiss-army-knife-plugin/releases/new?tag=vX.Y.Z
2. 更新 CHANGELOG.md 的 [未发布] 区域，记录下一个版本的变更
```

---

## 错误处理

在每个步骤中，如果遇到错误：

1. 清晰地报告错误信息
2. 如果已经修改了文件，提供恢复命令：

   ```bash
   git checkout CHANGELOG.md .claude-plugin/plugin.json
   git tag -d vX.Y.Z  # 如果 tag 已创建
   ```

3. 停止执行，不继续后续步骤

---

## Dry-run 模式

如果指定了 `--dry-run`：

1. 执行所有验证步骤
2. 显示将要进行的操作（不实际执行）：

   ```text
   [DRY RUN] 将执行以下操作：
   1. 更新 CHANGELOG.md：将 [未发布] 内容移到 [X.Y.Z] - YYYY-MM-DD
   2. 更新 .claude-plugin/plugin.json：version: "0.2.0" → "X.Y.Z"
   3. 创建 git commit：chore: release version X.Y.Z
   4. 创建 git tag：vX.Y.Z
   [5. 推送到远程仓库] （如果没有 --no-push）
   ```

3. 不修改任何文件，不执行 git 操作
