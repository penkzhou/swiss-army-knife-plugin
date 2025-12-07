# 工作流日志增强计划

**日期**: 2025-12-06
**状态**: 部分完成（2025-12-06 审查更新）
**优先级**: 高
**触发**: 分析 CI Job 修复工作流日志时发现记录不完整

> **2025-12-06 审查结果**：经代码审查发现，大部分功能已实现完毕。本次更新标记已完成项，并明确剩余待完成任务。

---

## 问题背景

在分析 `.claude/logs/swiss-army-knife/ci-job/2025-12-06_202433_job-57294410274_frg0508r.jsonl` 日志文件时，发现当前日志记录存在多处缺失，无法完整追踪工作流执行过程。

### 日志样本分析

```jsonl
{"ts":"...","type":"SESSION_START","session_id":"frg0508r","workflow":"ci-job",...}
{"ts":"...","type":"PHASE_START","phase":"phase_0","phase_name":"初始化"}
{"ts":"...","type":"PHASE_END","phase":"phase_0","status":"success","duration_ms":5000}
{"ts":"...","type":"PHASE_START","phase":"phase_1","phase_name":"日志获取"}
{"ts":"...","type":"PHASE_END","phase":"phase_1","status":"success","duration_ms":3000}
...
{"ts":"...","type":"SESSION_END","status":"success","total_duration_ms":60000}
```

**问题**：日志只有 PHASE_START/END 包裹，缺少中间的执行细节。

---

## 问题 1: 缺少 AGENT_CALL/AGENT_RESULT 事件 ✅ 已完成

### 现状

> **2025-12-06 已修复**：`ci-job-master-coordinator.md` 已在所有 Phase (0-6) 中实现完整的 AGENT_CALL/AGENT_RESULT 日志记录。

| Phase | AGENT_CALL | AGENT_RESULT |
|-------|------------|--------------|
| Phase 0 | ✅ | ✅ |
| Phase 1 | ✅ | ✅ |
| Phase 2 | ✅ | ✅ |
| Phase 3 | ✅ | ✅ |
| Phase 4 | ✅ | ✅ |
| Phase 5 | ✅ | ✅ |
| Phase 6 | ✅ | ✅ |

### 实现位置

- `agents/ci-job/master-coordinator.md` 第 139-172 行（Phase 0 示例）
- 每个 Phase 都有对应的 AGENT_CALL/AGENT_RESULT 记录代码

---

## 问题 2: 缺少 STEP_START/STEP_END 事件 ✅ 已完成

### 现状

> **2025-12-06 完成**：所有 agents 均已实现详细日志代码。

| Agent | 规范定义 | 详细代码 | 状态 |
|-------|---------|---------|------|
| job-init-collector | ✅ | ✅ | 完成 |
| job-log-fetcher | ✅ | ✅ | 完成 |
| job-failure-classifier | ✅ | ✅ | 完成（2025-12-06 补充） |
| job-root-cause | ✅ | ✅ | 完成（2025-12-06 补充） |
| job-fix-coordinator | ✅ | ✅ | 完成（2025-12-06 补充） |
| job-summary-reporter | ✅ | ⚠️ 仅 KNOWLEDGE | 基本完成 |
| review-coordinator | ✅ | ✅ | 完成 |

### ~~待完成任务~~ ✅ 已完成

~~为以下 3 个 agents 补充详细的 STEP_START/STEP_END bash 代码：~~
- ~~`agents/ci-job/job-failure-classifier.md`~~ ✅
- ~~`agents/ci-job/job-root-cause.md`~~ ✅
- ~~`agents/ci-job/job-fix-coordinator.md`~~ ✅

---

## 问题 3: 缺少 DATA_COLLECTED 事件 ✅ 部分完成

### 现状

> **2025-12-06 审查**：主要的数据收集 agents 已实现 DATA_COLLECTED 事件。

| Agent | DATA_COLLECTED | 状态 |
|-------|----------------|------|
| job-init-collector | ✅ 2 处 | 完成 |
| job-log-fetcher | ✅ 5 处 | 完成 |

### 实现位置

- `job-init-collector.md` 第 240-244 行（Job 元信息）、第 312-316 行（配置加载）
- `job-log-fetcher.md` 第 399-493 行（每个步骤都有 DATA_COLLECTED）

---

## 问题 4: 缺少 TOOL_USE 事件 (DEBUG 级别) ✅ 已完成

### 现状

> **2025-12-06 审查**：`job-log-fetcher.md` 已实现 TOOL_USE 事件记录（第 502-510 行）。

### 实现位置

- `job-log-fetcher.md` 第 502-510 行：DEBUG 级别的 TOOL_USE 记录
- 规范在 `workflow-logging` skill 第 245-260 行已完整定义

---

## 问题 5: 缺少 REVIEW 相关事件 ✅ 已完成

### 现状

> **2025-12-06 审查**：`review-coordinator.md` 已完整实现所有 REVIEW 事件。

| 事件类型 | 实现位置 | 状态 |
|----------|---------|------|
| REVIEW_PARALLEL_START | 第 421-431 行 | ✅ |
| REVIEW_PARALLEL_END | 第 421-431 行 | ✅ |
| REVIEW_FIX_ITERATION | 第 465-473 行 | ✅ |
| Agent 失败记录 | 第 437-449 行 | ✅ |

### 实现详情

- 并行启动 6 个 review agents 时记录 REVIEW_PARALLEL_START
- 所有 agents 返回后记录 REVIEW_PARALLEL_END（包含每个 agent 的结果统计）
- 每次 review-fix 循环记录 REVIEW_FIX_ITERATION（包含 iteration 次数、issues_before/after）
- 对失败情况有详细的错误记录（NULL_RESPONSE、MISSING_STATUS 等）

---

## 问题 6: 缺少 KNOWLEDGE 事件 ✅ 已完成

### 现状

> **2025-12-06 审查确认**：KNOWLEDGE 事件已完整实现。

| 组件 | 实现内容 | 状态 |
|------|---------|------|
| workflow-logging skill | KNOWLEDGE_EXTRACTION, KNOWLEDGE_SKIPPED 事件定义 | ✅ |
| job-summary-reporter | 详细的 KNOWLEDGE 事件记录代码（第 400-433 行） | ✅ |
| CLAUDE.md | 过程日志章节文档 | ✅ |

### 实现详情

`job-summary-reporter.md` 第 400-433 行包含：
- `KNOWLEDGE_EXTRACTION` 事件的完整 bash 代码
- `KNOWLEDGE_SKIPPED` 事件的完整 bash 代码
- 跳过原因枚举（low_confidence, no_fix_made, one_time_issue, already_documented, not_reusable）

---

## 修改计划（2025-12-06 更新）

### 阶段 1: Master Coordinator 日志增强 ✅ 已完成

**目标**: 确保每个 agent 调用都有 AGENT_CALL/RESULT 记录

**文件**:

- [x] `agents/ci-job/master-coordinator.md` - ✅ 已完成
- [ ] `agents/bugfix/master-coordinator.md` - 待验证
- [ ] `agents/pr-review/master-coordinator.md` - 待验证
- [ ] `agents/execute-plan/master-coordinator.md` - 待验证

### 阶段 2: Phase Agents 日志增强 ✅ 已完成

**目标**: 每个 agent 内部步骤都有 STEP_START/END 记录

**CI Job 工作流文件**:

- [x] `agents/ci-job/job-init-collector.md` - ✅ 完整代码
- [x] `agents/ci-job/job-log-fetcher.md` - ✅ 完整代码
- [x] `agents/ci-job/job-failure-classifier.md` - ✅ 完整代码（2025-12-06 补充）
- [x] `agents/ci-job/job-root-cause.md` - ✅ 完整代码（2025-12-06 补充）
- [x] `agents/ci-job/job-fix-coordinator.md` - ✅ 完整代码（2025-12-06 补充）
- [x] `agents/ci-job/job-summary-reporter.md` - ✅ 已有 KNOWLEDGE 事件代码

### 阶段 3: Review Coordinator 日志增强 ✅ 已完成

**目标**: 记录 Review-Fix 循环的完整过程

**文件**:

- [x] `agents/review/review-coordinator.md` - ✅ 完整实现

### 阶段 4: 其他工作流同步 ❓ 待验证

**目标**: 将 CI Job 的日志增强同步到其他工作流

**文件**:

- [ ] Bugfix 工作流相关 agents - 待验证
- [ ] PR Review 工作流相关 agents - 待验证
- [ ] Execute Plan 工作流相关 agents - 待验证

---

## 剩余任务清单

### 高优先级 ✅ 已完成

1. ~~**为 3 个 CI Job agents 补充详细日志代码**~~：（2025-12-06 已完成）
   - ~~`job-failure-classifier.md` - 5 个步骤~~ ✅
   - ~~`job-root-cause.md` - 5 个步骤~~ ✅
   - ~~`job-fix-coordinator.md` - 6 个步骤~~ ✅

### 中优先级

2. **验证其他 Master Coordinators**：
   - `bugfix/master-coordinator.md`
   - `pr-review/master-coordinator.md`
   - `execute-plan/master-coordinator.md`

3. **验证其他工作流的 Phase Agents**：
   - Bugfix 工作流 agents
   - PR Review 工作流 agents
   - Execute Plan 工作流 agents

---

## 日志记录模板

### AGENT_CALL (Master Coordinator)

```bash
# 在 Task 调用前
if [[ "${log_ctx_enabled}" == "true" ]]; then
    echo '{"ts":"'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'","level":"I","type":"AGENT_CALL","session_id":"'${session_id}'","phase":"'${phase}'","agent":"'${agent_name}'","model":"'${model}'"}' >> "${jsonl_file}"
    echo "[$(date +"%Y-%m-%d %H:%M:%S.000")] INFO | AGENT_CALL   | ${agent_name} (${model})" >> "${log_file}"
fi
```

### AGENT_RESULT (Master Coordinator)

```bash
# 在 Task 返回后
if [[ "${log_ctx_enabled}" == "true" ]]; then
    echo '{"ts":"'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'","level":"I","type":"AGENT_RESULT","session_id":"'${session_id}'","phase":"'${phase}'","agent":"'${agent_name}'","status":"'${status}'","duration_ms":'${duration}'}' >> "${jsonl_file}"
    echo "[$(date +"%Y-%m-%d %H:%M:%S.000")] INFO | AGENT_RESULT | ${agent_name} | ${status} | ${duration}ms" >> "${log_file}"
fi
```

### STEP_START/END (Phase Agent)

```bash
# 步骤开始
echo '{"ts":"'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'","level":"I","type":"STEP_START","session_id":"'${session_id}'","phase":"'${phase}'","agent":"'${agent_name}'","step":"'${step_id}'","step_name":"'${step_name}'","step_index":'${step_index}',"total_steps":'${total_steps}'}' >> "${jsonl_file}"

# 步骤结束
echo '{"ts":"'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'","level":"I","type":"STEP_END","session_id":"'${session_id}'","phase":"'${phase}'","agent":"'${agent_name}'","step":"'${step_id}'","status":"'${status}'","duration_ms":'${duration}'}' >> "${jsonl_file}"
```

### DATA_COLLECTED (Phase Agent)

```bash
echo '{"ts":"'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'","level":"I","type":"DATA_COLLECTED","session_id":"'${session_id}'","phase":"'${phase}'","agent":"'${agent_name}'","data_type":"'${data_type}'","summary":'${summary_json}'}' >> "${jsonl_file}"
```

### TOOL_USE (Phase Agent, DEBUG only)

```bash
if [[ "${log_ctx_level}" == "debug" ]]; then
    echo '{"ts":"'$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'","level":"D","type":"TOOL_USE","session_id":"'${session_id}'","phase":"'${phase}'","agent":"'${agent_name}'","step":"'${step_id}'","tool":"'${tool_name}'","target":"'${target}'","status":"'${status}'"}' >> "${jsonl_file}"
fi
```

---

## 预期效果

修改完成后，日志应该呈现完整的执行链：

```jsonl
{"type":"SESSION_START","workflow":"ci-job",...}

{"type":"PHASE_START","phase":"phase_0","phase_name":"初始化"}
{"type":"AGENT_CALL","phase":"phase_0","agent":"ci-job-init-collector","model":"sonnet"}
{"type":"STEP_START","agent":"ci-job-init-collector","step":"validate_gh_cli","step_index":1,"total_steps":5}
{"type":"TOOL_USE","agent":"ci-job-init-collector","tool":"Bash","target":"gh --version"}
{"type":"STEP_END","agent":"ci-job-init-collector","step":"validate_gh_cli","status":"success","duration_ms":500}
{"type":"STEP_START","agent":"ci-job-init-collector","step":"parse_url","step_index":2}
{"type":"STEP_END","agent":"ci-job-init-collector","step":"parse_url","status":"success"}
{"type":"DATA_COLLECTED","agent":"ci-job-init-collector","data_type":"job_metadata","summary":{...}}
{"type":"AGENT_RESULT","phase":"phase_0","agent":"ci-job-init-collector","status":"success","duration_ms":4700}
{"type":"PHASE_END","phase":"phase_0","status":"success","duration_ms":5000}

...

{"type":"PHASE_START","phase":"phase_5","phase_name":"验证与审查"}
{"type":"REVIEW_PARALLEL_START","agents":["review-code-reviewer",...]}
{"type":"AGENT_CALL","agent":"review-code-reviewer","model":"opus"}
{"type":"AGENT_CALL","agent":"review-silent-failure-hunter","model":"opus"}
...
{"type":"REVIEW_PARALLEL_END","duration_ms":30000,"total_issues":4}
{"type":"REVIEW_FIX_ITERATION","iteration":1,"issues_before":4,"issues_after":1}
{"type":"PHASE_END","phase":"phase_5","status":"success"}

{"type":"PHASE_START","phase":"phase_6","phase_name":"汇总报告"}
{"type":"AGENT_CALL","agent":"ci-job-summary-reporter"}
{"type":"STEP_START","step":"aggregate_results"}
{"type":"STEP_END","step":"aggregate_results"}
{"type":"STEP_START","step":"generate_report"}
{"type":"STEP_END","step":"generate_report"}
{"type":"STEP_START","step":"extract_knowledge"}
{"type":"KNOWLEDGE_EXTRACTION","result":{"extracted":true,"pattern_name":"..."}}
{"type":"STEP_END","step":"extract_knowledge"}
{"type":"AGENT_RESULT","agent":"ci-job-summary-reporter","status":"success"}
{"type":"PHASE_END","phase":"phase_6","status":"success"}

{"type":"SESSION_END","status":"success","total_duration_ms":60000}
```

---

## 验收标准

1. [ ] 每个 Phase 都有 AGENT_CALL 和 AGENT_RESULT 事件
2. [ ] 每个 agent 内部主要步骤都有 STEP_START/END 事件
3. [ ] 关键数据收集点都有 DATA_COLLECTED 事件
4. [ ] `--verbose` 模式下有 TOOL_USE 事件
5. [ ] Phase 5 有完整的 REVIEW 事件链
6. [ ] Phase 6 有 KNOWLEDGE_EXTRACTION 或 KNOWLEDGE_SKIPPED 事件
7. [ ] 日志可用于完整还原工作流执行过程

---

## 工作量估计

| 阶段 | 文件数 | 复杂度 |
|------|--------|--------|
| 阶段 1: Master Coordinators | 4 | 中 |
| 阶段 2: CI Job Phase Agents | 6 | 高 |
| 阶段 3: Review Coordinator | 1 | 中 |
| 阶段 4: 其他工作流同步 | ~20 | 低（模式相同） |

**建议**：先完成 CI Job 工作流（阶段 1-3），验证效果后再同步到其他工作流。

---

## 相关文档

- `skills/workflow-logging/SKILL.md` - 日志格式规范
- `agents/ci-job/master-coordinator.md` - CI Job 总协调器
- `CLAUDE.md` - 项目文档（过程日志章节）
