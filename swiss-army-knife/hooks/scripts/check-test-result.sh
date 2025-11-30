#!/bin/bash
# Check test results from Bash tool output and suggest bugfix workflow if failed
# Input: JSON via stdin with tool_input.command and tool_response

set -e

# === Critical: Check jq dependency ===
if ! command -v jq &>/dev/null; then
    echo "错误：swiss-army-knife 插件需要安装 jq。请运行：brew install jq (macOS) 或 apt-get install jq (Linux)" >&2
    exit 1
fi

# Read JSON input
INPUT=$(cat)

# === Critical: Validate JSON input ===
if [ -z "$INPUT" ]; then
    # Empty input is expected for some hook invocations, silently exit
    exit 0
fi

if ! echo "$INPUT" | jq -e . &>/dev/null; then
    echo "警告：check-test-result hook 收到无效 JSON 输入，跳过处理" >&2
    exit 0
fi

# Extract command and check if it's a test command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty')

# If command extraction failed, exit gracefully
if [ -z "$COMMAND" ]; then
    exit 0
fi

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
