# Swiss Army Knife Plugin Marketplace

This repository is a Claude Code plugin marketplace containing specialized plugins for development workflows.

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [swiss-army-knife](./swiss-army-knife/) | Standardized frontend bugfix workflow with 6-phase process |

## Installation

```bash
# Add this marketplace
/plugin marketplace add /path/to/swiss-army-knife-plugin

# Install plugin
/plugin install swiss-army-knife@swiss-army-knife-plugin
```

## Structure

```
swiss-army-knife-plugin/           # Marketplace root
├── .claude-plugin/
│   └── marketplace.json           # Marketplace manifest
└── swiss-army-knife/              # Plugin directory
    ├── .claude-plugin/
    │   └── plugin.json            # Plugin manifest
    ├── agents/                    # Specialized agents
    ├── commands/                  # Slash commands
    ├── hooks/                     # Event handlers
    └── skills/                    # Agent skills
```

## License

MIT
