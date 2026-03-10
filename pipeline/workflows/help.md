# Help Workflow

Help content for the `/odoo-gen:help` command. Lists all available commands with status and usage examples.

---

## Available Commands

| Command | Description | Status | Phase |
|---------|-------------|--------|-------|
| `/odoo-gen:new` | Scaffold a new Odoo module from a natural language description | Active | 1 |
| `/odoo-gen:help` | Show this help | Active | 1 |
| `/odoo-gen:config` | View or edit Odoo-specific configuration | Active | 1 |
| `/odoo-gen:status` | Show current module generation status | Active | 1 |
| `/odoo-gen:resume` | Resume an interrupted module generation | Active | 1 |
| `/odoo-gen:phases` | Show generation phases and progress | Active | 1 |
| `/odoo-gen:validate` | Run pylint-odoo and Docker-based module validation | Planned | 3 |
| `/odoo-gen:research` | Research Odoo patterns and existing solutions | Planned | 2 |
| `/odoo-gen:plan` | Plan module architecture before generation | Planned | 4 |
| `/odoo-gen:search` | Semantically search GitHub/OCA for existing modules | Planned | 8 |
| `/odoo-gen:extend` | Fork and extend an existing Odoo module | Planned | 8 |
| `/odoo-gen:history` | Show generation history and past modules | Planned | 7 |

**Status Legend:**
- **Active** -- Fully implemented and ready to use
- **Planned** -- Registered but not yet implemented (see Phase column)

## Usage Examples

### Scaffold a new module

```
/odoo-gen:new "inventory tracking with stock moves and warehouse locations"
```

The system will:
1. Parse your description to infer a module specification
2. Present the spec (module name, models, fields, dependencies) for your review
3. On confirmation, generate a complete Odoo 17.0 module with OCA structure

### View or edit configuration

```
/odoo-gen:config
/odoo-gen:config odoo_version 17.0
/odoo-gen:config license LGPL-3
/odoo-gen:config author "My Company"
```

### Check generation status

```
/odoo-gen:status
```

### Resume interrupted generation

```
/odoo-gen:resume
```

### Show generation phases

```
/odoo-gen:phases
```

## Architecture

odoo-gen is a **GSD extension**. It inherits orchestration, state management, checkpoints, and agent coordination from GSD. All Odoo-specific logic lives in `~/.claude/odoo-gen/`.

### Extension Structure

```
~/.claude/odoo-gen/
  install.sh          # Extension installer
  VERSION             # Version tracking
  defaults.json       # Odoo-specific configuration
  bin/
    odoo-gen-utils    # Python CLI wrapper
  agents/
    odoo-scaffold.md  # Module scaffolding agent
    odoo-model-gen.md # Model generation specialist (Phase 5)
    odoo-view-gen.md  # View generation specialist (Phase 5)
    odoo-security-gen.md  # Security generation specialist (Phase 6)
    odoo-test-gen.md  # Test generation specialist (Phase 6)
    odoo-validator.md # Validation agent (Phase 3)
  commands/
    new.md, help.md, config.md, status.md, resume.md, phases.md
    validate.md, search.md, research.md, plan.md, extend.md, history.md
  workflows/
    scaffold.md       # End-to-end scaffold workflow
    help.md           # This file
  python/
    src/odoo_gen_utils/  # Python utility package
      cli.py           # Click CLI entry point
      renderer.py      # Jinja2 rendering engine
      templates/       # 15 Odoo 17.0 Jinja2 templates
```

### Key Technologies

- **Python 3.12** with uv for package management
- **Jinja2** for template rendering
- **Click** for CLI interface
- **Odoo 17.0** as the primary target

For GSD commands, use `/gsd:help`.
