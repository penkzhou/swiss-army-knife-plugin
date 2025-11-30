#!/usr/bin/env bash
# Check for frontend-related changes and output context for SessionStart
# Output goes to stdout (added to Claude's context for SessionStart)

set -e

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    exit 0
fi

# === Critical: Handle git errors properly, including shallow clones ===
CHANGED_FILES=""
if git rev-parse HEAD~1 &>/dev/null; then
    # Normal repo with history - get diff from last commit
    CHANGED_FILES=$(git diff --name-only HEAD~1 2>&1) || {
        # Git error occurred (permissions, corrupted repo, etc.)
        # Log warning but don't block the session
        echo "警告：无法获取 git diff，跳过前端变更检测" >&2
        exit 0
    }
else
    # Shallow clone or initial commit - fall back to listing all tracked files
    # This is common in CI environments
    CHANGED_FILES=$(git ls-tree -r --name-only HEAD 2>/dev/null) || {
        exit 0
    }
fi

if [ -z "$CHANGED_FILES" ]; then
    exit 0
fi

# Check for frontend-related changes
# === Fix: Use proper array handling to avoid word splitting on filenames with spaces ===
HAS_FRONTEND_CHANGES=false

while IFS= read -r file; do
    [ -z "$file" ] && continue
    case "$file" in
        *.test.ts|*.test.tsx|*/components/*.tsx|*/hooks/*.ts)
            HAS_FRONTEND_CHANGES=true
            break
            ;;
    esac
done <<< "$CHANGED_FILES"

if [ "$HAS_FRONTEND_CHANGES" = true ]; then
    echo "📝 检测到前端代码变更，如需修复测试问题可使用 \`/swiss-army-knife:fix-frontend\`"
fi

exit 0
