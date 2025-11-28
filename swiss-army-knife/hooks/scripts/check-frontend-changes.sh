#!/bin/bash
# Check for frontend-related changes and output context for SessionStart
# Output goes to stdout (added to Claude's context for SessionStart)

set -e

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    exit 0
fi

# Get changed files from last commit
CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null || echo "")

if [ -z "$CHANGED_FILES" ]; then
    exit 0
fi

# Check for frontend-related changes
HAS_FRONTEND_CHANGES=false

for file in $CHANGED_FILES; do
    case "$file" in
        *.test.ts|*.test.tsx|*/components/*.tsx|*/hooks/*.ts)
            HAS_FRONTEND_CHANGES=true
            break
            ;;
    esac
done

if [ "$HAS_FRONTEND_CHANGES" = true ]; then
    echo "📝 检测到前端代码变更，如需修复测试问题可使用 \`/swiss-army-knife:fix-frontend\`"
fi

exit 0
