# Full Project Restructure — Design Spec

**Date:** 2026-03-14
**Branch:** `factory-upgrades`
**Status:** Approved (design phase)

---

## Problem Statement

After the Python-first unification (CJS → Python), the directory structure no longer reflects the architecture:

- `orchestrator/` contains only markdown definitions (agents, commands, workflows) — no orchestrator logic
- `pipeline/` contains ALL Python code (including orchestrator logic) plus its own agents and knowledge files
- `install.py` only copies from `orchestrator/`, missing 9 pipeline agents and 12 knowledge files
- Users working from their own project directory (via global install) get an incomplete extension

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary distribution | Global install (`install.py` → `~/.claude/`) | Users work from their own ERP project, not inside Factory-de-Odoo |
| Repo layout | Mirror `~/.claude/` install layout | What you see in repo = what you get after install. No translation layer. |
| Python package location | `python/` at repo root | Honest name, 1 level of nesting, clear separation from Claude Code artifacts |
| Agent organization | All 28 in single `agents/` directory | No more split across orchestrator/pipeline — one flat directory |
| Knowledge files | Under `amil/knowledge/` (not root) | Agents reference `@~/.claude/amil/knowledge/`; keeping under `amil/` preserves all 40+ existing path references |

## Target Directory Structure

```
Factory-de-Odoo/
│
├── agents/                      # ALL 28 agents → ~/.claude/agents/
│   ├── amil-belt-executor.md       (orchestrator: plan execution via belt)
│   ├── amil-belt-verifier.md       (orchestrator: post-generation validation)
│   ├── amil-codebase-mapper.md     (orchestrator: codebase analysis)
│   ├── amil-debugger.md            (orchestrator: systematic debugging)
│   ├── amil-erp-decomposer.md      (orchestrator: PRD decomposition)
│   ├── amil-executor.md            (orchestrator: atomic plan execution)
│   ├── amil-extend.md              (pipeline: fork-and-extend modules)
│   ├── amil-integration-checker.md  (orchestrator: cross-phase verification)
│   ├── amil-logic-writer.md        (pipeline: business logic filling)
│   ├── amil-model-gen.md           (pipeline: model class generation)
│   ├── amil-module-questioner.md   (orchestrator: interactive Q&A)
│   ├── amil-module-researcher.md   (orchestrator: Odoo pattern research)
│   ├── amil-nyquist-auditor.md     (orchestrator: test gap filling)
│   ├── amil-phase-researcher.md    (orchestrator: phase research)
│   ├── amil-plan-checker.md        (orchestrator: plan verification)
│   ├── amil-planner.md             (orchestrator: plan creation)
│   ├── amil-project-researcher.md  (orchestrator: domain research)
│   ├── amil-research-synthesizer.md (orchestrator: research combining)
│   ├── amil-roadmapper.md          (orchestrator: roadmap creation)
│   ├── amil-scaffold.md            (pipeline: module scaffolding)
│   ├── amil-search.md              (pipeline: OCA semantic search)
│   ├── amil-security-gen.md        (pipeline: security generation)
│   ├── amil-spec-generator.md      (orchestrator: spec.json creation)
│   ├── amil-spec-reviewer.md       (orchestrator: coherence reporting)
│   ├── amil-test-gen.md            (pipeline: test generation)
│   ├── amil-validator.md           (pipeline: validation specialist)
│   ├── amil-verifier.md            (orchestrator: goal verification)
│   └── amil-view-gen.md            (pipeline: XML view generation)
│
├── amil/                        # Namespaced extension content → ~/.claude/amil/
│   ├── workflows/               # 41 workflow definitions
│   │   ├── add-phase.md
│   │   ├── add-tests.md
│   │   ├── add-todo.md
│   │   ├── audit-milestone.md
│   │   ├── autonomous-erp-loop.md  (RENAMED from ralph-loop.md)
│   │   ├── check-todos.md
│   │   ├── cleanup.md
│   │   ├── complete-milestone.md
│   │   ├── diagnose-issues.md
│   │   ├── discovery-phase.md
│   │   ├── discuss-module.md
│   │   ├── discuss-phase.md
│   │   ├── execute-phase.md
│   │   ├── execute-plan.md
│   │   ├── generate-module.md
│   │   ├── health.md
│   │   ├── help.md
│   │   ├── insert-phase.md
│   │   ├── list-phase-assumptions.md
│   │   ├── live-uat.md
│   │   ├── map-codebase.md
│   │   ├── new-erp.md
│   │   ├── new-milestone.md
│   │   ├── new-project.md
│   │   ├── pause-work.md
│   │   ├── plan-milestone-gaps.md
│   │   ├── plan-module.md
│   │   ├── plan-phase.md
│   │   ├── progress.md
│   │   ├── quick.md
│   │   ├── remove-phase.md
│   │   ├── research-phase.md
│   │   ├── resume-project.md
│   │   ├── run-prd.md
│   │   ├── set-profile.md
│   │   ├── settings.md
│   │   ├── transition.md
│   │   ├── update.md
│   │   ├── validate-phase.md
│   │   ├── verify-phase.md
│   │   └── verify-work.md
│   ├── knowledge/               # 13 Odoo knowledge files (12 + custom/README.md)
│   │   ├── MASTER.md
│   │   ├── actions.md
│   │   ├── controllers.md
│   │   ├── custom/
│   │   │   └── README.md
│   │   ├── data.md
│   │   ├── i18n.md
│   │   ├── inheritance.md
│   │   ├── manifest.md
│   │   ├── models.md
│   │   ├── security.md
│   │   ├── testing.md
│   │   ├── views.md
│   │   └── wizards.md
│   ├── references/              # 14 reference documents
│   │   ├── checkpoints.md
│   │   ├── continuation-format.md
│   │   ├── decimal-phase-calculation.md
│   │   ├── git-integration.md
│   │   ├── git-planning-commit.md
│   │   ├── model-profile-resolution.md
│   │   ├── model-profiles.md
│   │   ├── module-questions.json
│   │   ├── phase-argument-parsing.md
│   │   ├── planning-config.md
│   │   ├── questioning.md
│   │   ├── tdd.md
│   │   ├── ui-brand.md
│   │   └── verification-patterns.md
│   └── templates/               # 20+ document templates
│       ├── codebase/            # Codebase analysis templates
│       ├── research-project/    # Research templates
│       ├── config.json
│       ├── context.md
│       ├── continue-here.md
│       ├── debug.md             (RENAMED from DEBUG.md)
│       ├── debug-subagent-prompt.md
│       ├── discovery.md
│       ├── milestone-archive.md
│       ├── milestone.md
│       ├── phase-prompt.md
│       ├── planner-subagent-prompt.md
│       ├── project.md
│       ├── requirements.md
│       ├── research.md
│       ├── retrospective.md
│       ├── roadmap.md
│       ├── state.md
│       ├── summary-complex.md
│       ├── summary.md
│       ├── summary-minimal.md
│       ├── summary-standard.md
│       ├── uat.md               (RENAMED from UAT.md)
│       ├── user-setup.md
│       ├── validation.md        (RENAMED from VALIDATION.md)
│       └── verification-report.md
│
├── commands/                    # Slash commands → ~/.claude/commands/
│   └── amil/                    # 46 /amil:* commands
│
├── hooks/                       # 3 event hooks → ~/.claude/hooks/
│   ├── amil-check-update.py
│   ├── amil-context-monitor.py
│   └── amil-statusline.py
│
├── python/                      # Python package (pip install, NOT ~/.claude/)
│   ├── src/amil_utils/          # All source code
│   │   ├── __init__.py
│   │   ├── auto_fix.py
│   │   ├── cli.py               # Click CLI entry point
│   │   ├── context7.py
│   │   ├── edition.py
│   │   ├── hooks.py
│   │   ├── i18n_extractor.py
│   │   ├── kb_validator.py
│   │   ├── manifest.py
│   │   ├── mermaid.py
│   │   ├── migration_generator.py
│   │   ├── registry.py
│   │   ├── renderer.py
│   │   ├── renderer_context.py
│   │   ├── renderer_utils.py
│   │   ├── spec_differ.py
│   │   ├── spec_schema.py
│   │   ├── verifier.py
│   │   ├── commands/            # CLI command implementations
│   │   ├── data/                # Package data (docker-compose, JSON data)
│   │   ├── iterative/           # Iterative refinement
│   │   ├── logic_writer/        # Stub detection & logic filling
│   │   ├── mcp/                 # MCP server
│   │   ├── orchestrator/        # 27 orchestrator modules
│   │   ├── preprocessors/       # 20 domain preprocessors
│   │   ├── search/              # ChromaDB search
│   │   ├── templates/           # 60 Jinja2 code-generation templates
│   │   ├── utils/               # Utilities
│   │   └── validation/          # pylint + Docker validation
│   ├── tests/                   # All 2,953 tests
│   │   ├── __init__.py
│   │   ├── conftest.py
│   │   ├── orchestrator/        # 24 orchestrator tests
│   │   ├── fixtures/            # Test fixtures
│   │   └── test_*.py            # 73 pipeline tests
│   └── pyproject.toml
│
├── docker/                      # Dev instance
│   ├── dev/docker-compose.yml
│   └── odoo.conf
│
├── scripts/                     # Dev scripts
│   ├── odoo-dev.sh
│   └── verify-odoo-dev.py
│
├── assets/                      # Branding
│   └── factory-logo.svg
│
├── docs/                        # Project documentation
│   ├── USER-GUIDE.md
│   ├── context-monitor.md
│   └── superpowers/specs/       # Design specs
│
├── .github/                     # GitHub config
│   ├── CODEOWNERS
│   ├── FUNDING.yml
│   ├── ISSUE_TEMPLATE/
│   ├── pull_request_template.md
│   └── workflows/
│       ├── test.yml             # CI (paths need updating)
│       └── auto-label-issues.yml
│
├── install.py                   # Unified installer
├── CLAUDE.md                    # Merged project instructions
├── README.md                    # Project documentation (updated paths)
├── CONTRIBUTING.md              # Contribution guidelines
├── CONVENTIONS.md               # NEW: naming & structure rules
├── CHANGELOG.md                 # Version history
├── SECURITY.md                  # Security guidelines
├── LICENSE                      # MIT / LGPL-3
├── .mcp.json                    # MCP server config
└── .gitignore
```

## install.py Changes

### Updated Install Map

```python
INSTALL_DIRS = {
    "agents": "agents",           # All 28 agents
    "amil": "amil",               # workflows, references, templates, AND knowledge
    "commands": "commands",       # commands/amil/ (46 commands)
    "hooks": "hooks",             # 3 hooks
}
```

Note: `knowledge/` is now inside `amil/`, so the single `"amil": "amil"` entry installs
workflows, references, document templates, AND knowledge files together. This preserves
all 40+ `@~/.claude/amil/knowledge/` path references in agent files with zero rewrites.

### Updated Python Package Path

```python
SOURCE_ROOT = Path(__file__).resolve().parent
PIPELINE_PYTHON = SOURCE_ROOT / "python"
```

## Files to Delete

| Path | Reason |
|------|--------|
| `pipeline/.continue-here.md` | Stale state (Phase 4, 2026-03-01) — superseded by STATE.md |
| `pipeline/python/uni_fee/` | Misplaced sample diagrams (2 files, 24 lines) |
| `pipeline/bin/amil-utils` | Bash wrapper — unnecessary with pip install |
| `pipeline/VERSION` | Contains `0.1.0` — superseded by `pyproject.toml` version field |
| `orchestrator/install.py` | Replaced by updated root install.py |
| `pipeline/install.sh` | Replaced by updated root install.py |
| `orchestrator/README.md` | Merged into root README.md |
| `pipeline/README.md` | Merged into root README.md |
| `orchestrator/CLAUDE.md` | Merged into root CLAUDE.md |
| `pipeline/CLAUDE.md` | Merged into root CLAUDE.md |
| `orchestrator/.gitignore` | Legacy CJS/Node patterns — merged into root .gitignore |
| `pipeline/.gitignore` | Pipeline-specific patterns — merged into root .gitignore |

## Additional Moves Not Listed in Main Migration

| Current Path | New Path | Reason |
|---|---|---|
| `pipeline/knowledge/*` | `amil/knowledge/*` | Knowledge stays under amil/ namespace |
| `pipeline/defaults.json` | `python/src/amil_utils/data/defaults.json` | Package data, used by Python code |
| `pipeline/.mcp.json` | `.mcp.json` (root) | MCP server config, project-level |
| `orchestrator/docs/context-monitor.md` | `docs/context-monitor.md` | Real documentation file |
| `orchestrator/docs/USER-GUIDE.md` | `docs/USER-GUIDE.md` | Real documentation file |
| `pipeline/CONTRIBUTING.md` | `CONTRIBUTING.md` (root) | Project-level doc |

## Renames

| Old Name | New Name | Reason |
|----------|----------|--------|
| `orchestrator/amil/templates/DEBUG.md` | `amil/templates/debug.md` | Lowercase consistency with 20 peer templates |
| `orchestrator/amil/templates/UAT.md` | `amil/templates/uat.md` | Same |
| `orchestrator/amil/templates/VALIDATION.md` | `amil/templates/validation.md` | Same |
| `orchestrator/amil/workflows/ralph-loop.md` | `amil/workflows/autonomous-erp-loop.md` | Self-documenting name (file describes "Autonomous ERP Generation") |

## Content Updates Required

These files need internal path references updated after the move:

| File | Changes Needed |
|------|----------------|
| `install.py` | Update `INSTALL_DIRS`, `PIPELINE_PYTHON` path, `SOURCE_ROOT` logic, error messages (`pip install -e python`) |
| `CLAUDE.md` | Merge 3 CLAUDE.md files, update all path references |
| `README.md` | Update architecture tree, install paths, test paths, logo path |
| `CONTRIBUTING.md` | Update development setup paths |
| `python/pyproject.toml` | Verified: relative paths (`packages`, `testpaths`, `source`) unchanged — internal layout preserved. No changes needed. |
| `.gitignore` | Three-way merge: root + `orchestrator/.gitignore` + `pipeline/.gitignore`. Drop legacy CJS patterns, keep Python/Docker patterns, update paths. |
| All 28 agent files | Grep for `pipeline/`, `orchestrator/` path references (NOTE: `@~/.claude/amil/knowledge/` references are UNCHANGED) |
| All 46 command files | Grep for `pipeline/`, `orchestrator/` path references |
| All 41 workflow files | Same |
| `hooks/*.py` | Check for hardcoded paths |
| `.mcp.json` | Verify `python3 -m amil_utils.mcp.server` still resolves (module path, not filesystem — should work) |
| `scripts/odoo-dev.sh` | Update relative paths (docker-compose location) |
| `.github/workflows/*.yml` | Update test paths (e.g., `pipeline/python/` → `python/`) |

## .planning/ Directories

Three `.planning/` directories exist:
- `orchestrator/.planning/` — Factory-de-Odoo's own project state (STATE.md, ROADMAP.md, etc.)
- `pipeline/.planning/` — Pipeline milestone planning
- `pipeline/python/.planning/` — Python sub-project planning

These are **per-project ephemeral state** generated by the Amil workflow. They are NOT part of the restructure — they are gitignored artifacts that will be regenerated. The root `.planning/` directory (if present) is the canonical location for the Factory-de-Odoo project's own state.

## Verification Checklist

After all moves are complete, verify:

1. `cd python && uv venv --python 3.12 && uv pip install -e ".[dev]"` — package installs
2. `amil-utils --help` — CLI resolves
3. `amil-utils orch --help` — orchestrator subcommands resolve
4. `cd python && uv run pytest tests/ -m "not docker" -q` — all tests pass
5. `python install.py` — installs all dirs to `~/.claude/` (agents, amil, commands, hooks)
6. Verify `~/.claude/agents/` contains all 28 `amil-*.md` files
7. Verify `~/.claude/amil/knowledge/` contains all 13 knowledge files
8. Grep for `pipeline/` and `orchestrator/` across entire repo — zero remaining references
9. `CONVENTIONS.md` exists at root

## Rollback Plan

All changes are on the `factory-upgrades` branch. Rollback: `git reset --hard <pre-restructure-commit>`. No other branches or projects are affected.

## CONVENTIONS.md Content

Created at repo root documenting:

### Naming Rules
| Category | Convention | Example |
|----------|-----------|---------|
| Python modules | `snake_case.py` | `dependency_graph.py` |
| Classes | `PascalCase` | `GenerationManifest` |
| Constants | `UPPER_SNAKE_CASE` | `FIXABLE_PYLINT_CODES` |
| Python directories | `snake_case/` | `logic_writer/` |
| Non-Python directories | `kebab-case/` | n/a (none currently) |
| Agents | `amil-<purpose>.md` | `amil-scaffold.md` |
| Commands | `<command-name>.md` | `generate-module.md` |
| Workflows | `<verb-noun>.md` | `execute-phase.md` |
| Document templates | `<purpose>.md` (lowercase) | `debug.md` |
| Jinja2 templates | `<artifact>.{ext}.j2` | `model.py.j2` |
| Knowledge files | `<topic>.md` (lowercase) | `models.md` |
| Hooks | `amil-<purpose>.py` | `amil-statusline.py` |
| Tests | `test_<module>.py` | `test_registry.py` |

### Directory Rules
- Root-level directories mirror `~/.claude/` install layout
- `python/` is the only directory NOT installed to `~/.claude/`
- All Claude Code artifacts at root level
- Python internals follow standard `src/` layout

### File Size Limits
- Python files: 800 lines max
- Functions: 50 lines max
- Knowledge files: 500 lines max

## CLAUDE.md Merge Strategy

The merged CLAUDE.md combines content from all three existing files:

1. **Compact Instructions** — from current root (unchanged)
2. **Project** — repo URL, purpose, branch
3. **Architecture** — two-layer diagram (`amil_utils.orchestrator` brain + pipeline belt)
4. **Key Paths** — updated table:
   - Agents: `agents/`
   - Commands: `commands/amil/`
   - Workflows: `amil/workflows/`
   - Hooks: `hooks/`
   - Knowledge: `amil/knowledge/`
   - Python src: `python/src/amil_utils/`
   - Orchestrator src: `python/src/amil_utils/orchestrator/`
   - Tests: `python/tests/`
   - Templates (Jinja2): `python/src/amil_utils/templates/`
   - Templates (doc): `amil/templates/`
5. **Current State** — factory-upgrades branch status
6. **CLI** — `amil-utils` command reference
7. **Pipeline Agents** — 9-agent table with roles
8. **Odoo Patterns** — W8161, manifest load order, chatter flag, Python 3.12
9. **Rules** — sequential generation, atomic writes, immutable data, Python-first, zero Node.js, 80%+ coverage
10. **Development** — test commands: `cd python && uv run pytest tests/ -q`

## Summary

| Metric | Count |
|--------|-------|
| Files moved | ~180 |
| Files renamed | 4 |
| Files deleted | ~14 |
| Files needing content updates | ~12 core + grep across ~115 markdown files |
| New files created | 1 (CONVENTIONS.md) |
| Directories eliminated | 2 (`orchestrator/`, `pipeline/`) |
| Total agents after restructure | 28 (all in one directory, all installed) |
| Knowledge files installed | 13 (12 knowledge + custom/README.md) — via `amil/knowledge/` |
