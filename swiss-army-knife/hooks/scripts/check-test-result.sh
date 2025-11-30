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

# Check if test failed
# 使用更精确的模式匹配，减少误报（如测试名含 "error" 等）
# 匹配策略:
#   - 行首的明确失败标记: FAIL, FAILED, ERROR:
#   - Jest 格式: "Tests: X failed" 或 "X failed,"
#   - pytest 格式: "X failed" 在摘要行, "FAILED" 标记
#   - 明确的运行时错误: AssertionError, TypeError, SyntaxError 作为独立词
TEST_FAILED=false

# 检查明确的失败指示（行首或明确的测试结果格式）
if echo "$TOOL_RESPONSE" | grep -qE '^(FAIL|FAILED|ERROR:)'; then
    TEST_FAILED=true
# Jest/Vitest 格式: "Tests: X failed" 或 "X failed,"
elif echo "$TOOL_RESPONSE" | grep -qE 'Tests:.*[0-9]+ failed|[0-9]+ failed,'; then
    TEST_FAILED=true
# pytest 格式: "X failed" 在结果摘要行
elif echo "$TOOL_RESPONSE" | grep -qE '=+ [0-9]+ failed'; then
    TEST_FAILED=true
# 明确的异常类型（作为独立词，非子串）
elif echo "$TOOL_RESPONSE" | grep -qwE 'AssertionError|TypeError|SyntaxError|ReferenceError'; then
    TEST_FAILED=true
fi

if [ "$TEST_FAILED" = true ]; then
    # Output suggestion to stderr with exit code 2 so Claude sees it
    echo "💡 检测到${STACK}测试失败，建议使用 \`${CMD}\` 启动标准化 bugfix 流程" >&2
    exit 2
fi

# Test passed, no output needed
exit 0
