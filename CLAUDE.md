# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Claude Code plugin implementing a standardized 6-phase frontend bugfix workflow for React/TypeScript projects. The workflow orchestrates specialized agents through a main `/fix` command.

## Architecture

### Workflow Flow

```
/fix command → Phase 0-5 orchestration
     │
     ├─ Phase 0: error-analyzer agent → Parse & classify errors
     ├─ Phase 1: root-cause agent → Diagnose with confidence scoring
     ├─ Phase 2: solution agent → Design TDD fix plan
     ├─ Phase 3: (main controller) → Generate bugfix docs
     ├─ Phase 4: executor agent → TDD implementation (RED-GREEN-REFACTOR)
     └─ Phase 5: quality-gate + knowledge agents → Verify & document
```

### Component Roles

- **`commands/fix.md`**: Main orchestrator - parses args, dispatches agents via Task tool, handles decision points
- **`agents/*.md`**: Specialized subagents with specific tool permissions and output formats (JSON)
- **`skills/bugfix-workflow/SKILL.md`**: Auto-activated knowledge base for error patterns and TDD practices
- **`hooks/hooks.json`**: Trigger suggestions on test failures or frontend code changes

### Confidence-Driven Flow Control

The workflow uses confidence scores (0-100) to determine behavior:
- **≥60**: Auto-continue
- **40-59**: Pause and ask user
- **<40**: Stop and gather more info

This is implemented in the root-cause agent output and evaluated in fix.md Phase 1.2.

## Plugin Development

### Testing Changes

```bash
# Create a test marketplace directory structure
mkdir -p test-marketplace/.claude-plugin
# Add marketplace.json pointing to this plugin
# Then in Claude Code:
/plugin marketplace add /path/to/test-marketplace
/plugin install swiss-army-knife-plugin@test-marketplace

# After changes:
/plugin uninstall swiss-army-knife-plugin@test-marketplace
/plugin install swiss-army-knife-plugin@test-marketplace
```

### Adding Components

- **Commands**: Add `.md` file to `commands/` with YAML frontmatter (`description`, `argument-hint`, `allowed-tools`)
- **Agents**: Add `.md` file to `agents/` with frontmatter (`model`, `allowed-tools`, `whenToUse` with examples)
- **Skills**: Create `skills/{name}/SKILL.md` with frontmatter (`name`, `description`, `version`)
- **Hooks**: Add entry to `hooks/hooks.json` (`event`, `matcher`, `config`)

### Key Frontmatter Fields

```yaml
# For agents
model: opus                    # Required model
allowed-tools: ["Read", "Glob"] # Explicit tool permissions
whenToUse: |                   # When Claude should use this agent
  Description with <example> blocks

# For commands
description: Short description
argument-hint: "[--flag=value]"
allowed-tools: ["Read", "Write", "Task"]
```

## Domain Knowledge

### Error Classification (by frequency)

| Type | Frequency | Key Signal |
|------|-----------|------------|
| mock_conflict | 71% | vi.mock + server.use coexisting |
| type_mismatch | 15% | `as any`, incomplete mock data |
| async_timing | 8% | Missing await, getBy vs findBy |
| render_issue | 4% | Conditional render, state update |
| cache_dependency | 2% | Incomplete useEffect deps |

### Target Project Assumptions

The workflow assumes the target project uses:
- `make test TARGET=frontend` for running tests
- `make lint TARGET=frontend` / `make typecheck TARGET=frontend` for QA
- `docs/bugfix/` for storing bugfix reports
- `docs/best-practices/04-testing/frontend/` for reference docs
