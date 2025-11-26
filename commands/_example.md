---
name: example
description: Example slash command template - rename or delete this file
---

# Example Command

This is a template for creating slash commands. To create a new command:

1. Create a new `.md` file in this directory
2. Add YAML frontmatter with `name` and `description`
3. Write the command instructions below the frontmatter

## Usage

When invoked via `/swiss-army-knife-plugin:example`, this prompt will be expanded and sent to Claude.

## Template Variables

You can use arguments in your command:
- `$ARGUMENTS` - All arguments passed to the command
- Reference specific files or provide dynamic context

---

Delete this file once you've created your first real command.
