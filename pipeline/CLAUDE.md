# Odoo Module Automation — Pipeline Component

## Architecture

Pipeline is a **pure library** — no user-facing commands. All user interaction flows through the orchestrator's `/amil:` commands.

```
Layer 1: Orchestrator (Factory de Odoo)
  Context management, state, phases, agents, checkpoints, git
  All /amil: commands live here

Layer 2: Pipeline (THIS COMPONENT)
  Agents, templates, knowledge base — invoked by orchestrator

Layer 3: Python Utilities (amil-utils)
  Jinja2 rendering, pylint-odoo, Docker validation, ChromaDB search
```

## Pipeline Agents

Invoked by orchestrator commands, not directly by users:

| Agent | Invoked By | Purpose |
|-------|-----------|---------|
| `amil-scaffold` | `amil:generate-module` | Quick-mode module scaffolding |
| `amil-validator` | `amil:validate-module` | pylint-odoo + Docker validation |
| `amil-model-gen` | `amil:generate-module` | OCA-compliant model methods |
| `amil-view-gen` | `amil:generate-module` | Form/list/search XML views |
| `amil-security-gen` | `amil:generate-module` | Security CSV + record rules |
| `amil-test-gen` | `amil:generate-module` | Unit/integration tests |
| `amil-search` | `amil:search-modules` | Semantic OCA/GitHub search |
| `amil-extend` | `amil:extend-module` | Fork-and-extend with _inherit |
| `amil-logic-writer` | `amil:generate-module` | Business logic implementation |

## Python Utilities (amil-utils)

```bash
python -m amil_utils <subcommand>
```

Key subcommands: `render-module`, `validate`, `index-oca`, `search`, `auto-fix`

**Package:** `pipeline/python/src/amil_utils/`
**Config:** `pipeline/python/pyproject.toml`
**Tests:** `pipeline/python/tests/` (70+ test files)

## Key Decisions
| Decision | Rationale | Status |
|----------|-----------|--------|
| Pure library — no user-facing commands | All interaction through orchestrator /amil: commands | Decided |
| Odoo 19.0 primary target | Latest stable, backward compatible with 17.0/18.0 | Decided |
| Fork-and-extend strategy | Leverage existing OCA/GitHub modules | Decided |
| Semantic search (ChromaDB + ONNX) | Intent-based matching | Decided |
| Python 3.12 | Odoo 17.0-19.0 supports 3.10-3.12 | Decided |
| Docker for validation | Only way to truly verify installs/tests | Decided |
| OCA quality bar | pylint-odoo, i18n, full security, tests | Decided |

## Development

```bash
cd pipeline/python
pytest                          # Run all tests
pytest --cov=amil_utils         # With coverage
```

---
*Pipeline is a library component of Factory de Odoo. See orchestrator/CLAUDE.md for the full command reference.*
