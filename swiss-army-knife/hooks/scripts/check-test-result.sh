#!/bin/bash
# Check test results from Bash tool output and suggest bugfix workflow if failed
# Input: JSON via stdin with tool_input.command and tool_response

set -e

# Read JSON input
INPUT=$(cat)

# Extract command and check if it's a test command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // ""')

# Check if this is a test command
if echo "$COMMAND" | grep -qE 'make test.*TARGET=frontend|make test TARGET=frontend'; then
    STACK="frontend"
    CMD="/swiss-army-knife:fix-frontend"
elif echo "$COMMAND" | grep -qE 'make test.*TARGET=backend|make test TARGET=backend'; then
    STACK="backend"
    CMD="/swiss-army-knife:fix-backend"
elif echo "$COMMAND" | grep -qE 'make test.*TARGET=e2e|make test TARGET=e2e'; then
    STACK="e2e"
    CMD="/swiss-army-knife:fix-e2e"
else
    # Not a test command we care about
    exit 0
fi

# Check if test failed (look for common failure indicators in response)
if echo "$TOOL_RESPONSE" | grep -qiE 'FAIL|ERROR|failed|error:|exception|AssertionError|TypeError|SyntaxError'; then
    # Output suggestion to stderr with exit code 2 so Claude sees it
    echo "💡 检测到${STACK}测试失败，建议使用 \`${CMD}\` 启动标准化 bugfix 流程" >&2
    exit 2
fi

# Test passed, no output needed
exit 0
