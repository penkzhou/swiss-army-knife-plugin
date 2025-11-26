---
name: example-skill
description: Example skill template - skills are auto-activated based on task context matching this description
---

# Example Skill

This is a template for creating skills. Skills provide specialized knowledge and workflows that Claude automatically activates when relevant.

## Creating a New Skill

1. Create a new directory under `skills/` with a descriptive kebab-case name
2. Add a `SKILL.md` file inside that directory
3. Use YAML frontmatter to define `name` and `description`
4. The description is crucial - it determines when the skill activates

## Skill Best Practices

- Write clear, specific descriptions so the skill activates at the right time
- Include step-by-step workflows when applicable
- Add supporting files (scripts, references, examples) in the skill directory
- Reference files using `${CLAUDE_PLUGIN_ROOT}/skills/skill-name/...`

## Directory Structure

```
skills/
└── your-skill-name/
    ├── SKILL.md          # Required - skill definition
    ├── scripts/          # Optional - helper scripts
    ├── references/       # Optional - reference materials
    └── examples/         # Optional - usage examples
```

---

Delete this directory once you've created your first real skill.
