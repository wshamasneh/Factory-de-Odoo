---
name: odoo-gen:help
description: Show all available odoo-gen commands and usage
---
<objective>
Display the complete odoo-gen command reference.

Output ONLY the reference content below. Do NOT add project-specific analysis, git status, or commentary beyond the reference.
</objective>

<process>
Output the following command reference directly.

# odoo-gen Command Reference

An Odoo 17.0 module development automation tool built as a GSD extension.

## Usage

```
/odoo-gen:<command> [arguments]
```

## Commands

| Command | Description | Status | Phase |
|---------|-------------|--------|-------|
| `new` | Scaffold a new Odoo 17.0 module from a natural language description | Active | 1 |
| `help` | Show all available odoo-gen commands and usage | Active | 1 |
| `config` | View or edit Odoo-specific configuration (odoo_version, edition, output_dir) | Wrapper | 1 |
| `status` | Show current Odoo module generation status | Wrapper | 1 |
| `resume` | Resume an interrupted Odoo module generation session | Wrapper | 1 |
| `phases` | Show Odoo module generation phases and progress | Wrapper | 1 |
| `validate` | Run pylint-odoo and Docker-based validation on an Odoo module | Stub | 3 |
| `research` | Research Odoo patterns and existing solutions for a module need | Stub | 2 |
| `plan` | Plan module architecture before generation | Stub | 4 |
| `search` | Semantically search GitHub/OCA for existing Odoo modules | Stub | 8 |
| `extend` | Fork and extend an existing Odoo module | Stub | 8 |
| `history` | Show generation history and past modules | Stub | 7 |

**Status Legend:**
- **Active** -- Fully implemented and ready to use
- **Wrapper** -- Provides Odoo-specific context on top of GSD equivalents
- **Stub** -- Registered but not yet implemented (see Phase column for activation)

## Examples

### Scaffold a new module
```
/odoo-gen:new "inventory tracking with stock moves and warehouse locations"
```

### Check available commands
```
/odoo-gen:help
```

### View Odoo configuration
```
/odoo-gen:config
```

### Check generation status
```
/odoo-gen:status
```

## Architecture

odoo-gen is a GSD extension. It inherits orchestration, state management, checkpoints, and agent coordination from GSD. All Odoo-specific logic lives in `~/.claude/odoo-gen/`.

For GSD commands, use `/gsd:help`.
</process>
