# Swiss Army Knife Plugin

A personal collection of useful Claude Code components for daily development.

## Structure

```
swiss-army-knife-plugin/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── commands/             # Slash commands
├── agents/               # Subagents
├── skills/               # Auto-activated skills
├── hooks/                # Event handlers
│   ├── hooks.json
│   └── scripts/
└── scripts/              # Shared utilities
```

## Installation

Add this plugin to your Claude Code configuration:

```bash
# Option 1: Add to global plugins
claude plugins add /path/to/swiss-army-knife-plugin

# Option 2: Link for development
claude plugins link /path/to/swiss-army-knife-plugin
```

## Components

### Commands

Slash commands are invoked via `/swiss-army-knife-plugin:command-name`.

### Agents

Subagents are specialized Claude instances for specific tasks. They can be invoked via the Task tool.

### Skills

Skills auto-activate based on task context. Write clear descriptions so they trigger at the right time.

### Hooks

Event-driven handlers that respond to Claude Code events (PreToolUse, PostToolUse, etc.).

## Development

1. Create components in the appropriate directories
2. Follow the examples in `_example` files
3. Delete example files once you have real components
4. Test with `claude plugins validate`

## Path References

Use `${CLAUDE_PLUGIN_ROOT}` for portable path references in hooks and scripts:

```json
{
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/my-script.sh"
}
```
