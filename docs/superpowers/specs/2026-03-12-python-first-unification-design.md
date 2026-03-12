# Python-First Unification Design Spec

> **Date:** 2026-03-12
> **Status:** Approved
> **Branch:** `factory-upgrades`
> **Scope:** Merge orchestrator (Node.js CJS) and pipeline (Python 3.12) into a single Python codebase
> **Prerequisite:** Improvement Guide Tiers 0 and 1 completed; Tier 2 should execute before the port

---

## Problem Statement

Factory de Odoo has two codebases in two languages:

- **Orchestrator** (Node.js CJS): 23 modules, ~8,000 lines, zero npm deps. Manages state, phases, dependency graphs, coherence checks, and project lifecycle.
- **Pipeline** (Python 3.12): 68 modules, ~24,000 lines. Handles Jinja2 template rendering, Pydantic validation, pylint-odoo, Docker validation, ChromaDB search, and MCP server.

They communicate exclusively through JSON over stdout (the orchestrator spawns Claude agents that call `amil-utils` CLI commands via Bash). There is zero shared in-process state.

### Pain Points

1. **Installation complexity**: Two separate install commands (`node install.js` + `bash install.sh`), two runtimes, two package managers.
2. **Development friction**: Changes spanning both components require context-switching between JS and Python, two test suites, two coverage tools.
3. **Conceptual confusion**: New contributors must understand why a single system is split across two languages.
4. **Deployment/distribution**: Two packaging systems, two dependency graphs, two CI pipelines.

### Why the Split Exists

The orchestrator was originally built as a "Claude Code extension" — Claude Code runs on Node.js, so the tooling was written in Node.js. The pipeline requires Python for Jinja2, pylint-odoo, and Pydantic. However, Claude Code can call Python CLIs just as easily as Node.js CLIs. The split creates unnecessary friction with no technical benefit.

---

## Decision

**Port the orchestrator's 23 CJS modules (~8,000 lines) into a new `amil_utils/orchestrator/` Python subpackage.** One language, one install, one test suite, one CI pipeline.

### What Changes

- 23 CJS modules in `orchestrator/amil/bin/lib/` become ~20 Python modules in `pipeline/python/src/amil_utils/orchestrator/`
- The 700-line `amil-tools.cjs` switch/case router becomes Click commands under `amil-utils orch`
- Two install scripts merge into one `install.sh` at the repo root
- Two test suites merge into one `pytest` suite

### What Stays

- ~156 content files (46 commands, 19 agents, 41 workflows, 14 references, 36 templates) stay in `orchestrator/` as a content directory
- All pipeline Python code stays as-is
- All Jinja2 templates stay as-is
- The JSON-over-stdout interface contract stays identical

---

## Architecture

### Unified Directory Structure

```
Factory-de-Odoo/
├── pipeline/
│   └── python/
│       ├── pyproject.toml              # single package, unified entry point
│       ├── src/amil_utils/
│       │   ├── __init__.py
│       │   ├── cli.py                  # existing 18 pipeline commands + orch group
│       │   ├── orchestrator/           # NEW: ported from CJS
│       │   │   ├── __init__.py
│       │   │   ├── cli.py              # Click group: ~40 orchestrator commands
│       │   │   ├── core.py             # foundation: git ops, path utils, config loading
│       │   │   ├── state.py            # STATE.md parsing, patching, snapshots
│       │   │   ├── phase.py            # phase lifecycle (absorbs phase-complete)
│       │   │   ├── registry.py         # model registry read/write/rollback
│       │   │   ├── frontmatter.py      # YAML-like frontmatter extraction
│       │   │   ├── config.py           # project config management
│       │   │   ├── coherence.py        # cross-module coherence checks
│       │   │   ├── dependency_graph.py # topological sort via graphlib
│       │   │   ├── health.py           # health checks + verification (absorbs verify)
│       │   │   ├── init_commands.py    # context-loading commands
│       │   │   ├── module_status.py    # module lifecycle state machine
│       │   │   ├── roadmap.py          # ROADMAP.md parsing and analysis
│       │   │   ├── milestone.py        # milestone lifecycle
│       │   │   ├── decomposition.py    # merge parallel agent outputs
│       │   │   ├── template.py         # document template selection/filling
│       │   │   ├── commands.py         # misc utility commands (commit, scaffold, etc.)
│       │   │   ├── cycle_log.py        # generation cycle logging
│       │   │   ├── spec_completeness.py # spec scoring and discussion batching
│       │   │   ├── uat_checkpoint.py   # UAT checkpoint tracking
│       │   │   ├── provisional_registry.py # forward-reference resolution
│       │   │   └── circular_dep.py     # circular dependency analysis
│       │   │
│       │   ├── hooks/                   # NEW: ported from JS hooks
│       │   │   ├── __init__.py
│       │   │   ├── check_update.py     # from amil-check-update.js
│       │   │   ├── statusline.py       # from amil-statusline.js
│       │   │   └── context_monitor.py  # from amil-context-monitor.js
│       │   │
│       │   ├── renderer.py             # existing pipeline (unchanged)
│       │   ├── renderer_context.py     # existing pipeline (unchanged)
│       │   ├── spec_schema.py          # existing pipeline (unchanged)
│       │   ├── preprocessors/          # existing (21 files, unchanged)
│       │   ├── validation/             # existing (10 files, unchanged)
│       │   ├── search/                 # existing (7 files, unchanged)
│       │   ├── logic_writer/           # existing (5 files, unchanged)
│       │   ├── mcp/                    # existing (4 files, unchanged)
│       │   └── ...
│       └── tests/
│           ├── test_renderer.py        # existing 71 test files (unchanged)
│           ├── ...
│           └── orchestrator/           # NEW: ported from CJS tests
│               ├── conftest.py         # shared fixtures
│               ├── test_core.py
│               ├── test_state.py
│               ├── test_phase.py
│               ├── test_registry.py
│               ├── test_dependency_graph.py
│               ├── test_decomposition.py   # NEW (fulfills ORCH-02)
│               ├── test_circular_dep.py    # NEW (fulfills ORCH-02)
│               ├── test_cli_orch.py        # Click CLI integration tests
│               └── ...
│
├── orchestrator/                       # stays as CONTENT directory (markdown only)
│   ├── commands/amil/                  # 46 .md slash command definitions
│   ├── agents/                         # 19 .md agent definitions
│   └── amil/
│       ├── workflows/                  # 41 .md workflow definitions
│       ├── references/                 # 14 .md reference docs
│       └── templates/                  # 36 .md document templates
│
├── install.sh                          # NEW: single unified installer
└── CLAUDE.md
```

### Deleted After Port

- `orchestrator/amil/bin/amil-tools.cjs` (700-line router)
- `orchestrator/amil/bin/lib/*.cjs` (23 CJS modules)
- `orchestrator/amil/bin/install.js` (Node.js installer)
- `orchestrator/hooks/*.js` (3 hook scripts, ported to Python)
- `orchestrator/package.json`, `package-lock.json`
- `orchestrator/node_modules/`
- `pipeline/install.sh` (absorbed into unified installer)

### Hook Scripts (3 JS files → Python)

The `orchestrator/hooks/` directory contains 3 Claude Code hook scripts (337 lines total) that must also be ported:

| Hook | Lines | Type | Purpose |
|---|---|---|---|
| `amil-check-update.js` | 81 | SessionStart | Checks for Amil updates via npm, writes result to cache |
| `amil-statusline.js` | 115 | Statusline | Reads JSON from stdin, displays model/task/context in terminal statusbar |
| `amil-context-monitor.js` | 141 | PostToolUse | Reads context metrics from statusline bridge file, injects warnings when context is low |

These are small scripts that read JSON from stdin, do file I/O, and write JSON to stdout. They port directly to Python:

- `pipeline/python/src/amil_utils/hooks/check_update.py`
- `pipeline/python/src/amil_utils/hooks/statusline.py`
- `pipeline/python/src/amil_utils/hooks/context_monitor.py`

The Claude Code hook config (in `settings.json`) updates from `node hooks/amil-statusline.js` to `python -m amil_utils.hooks.statusline`.

After the port, the `orchestrator/hooks/` directory is deleted, achieving the "zero Node.js" acceptance criterion.

---

## CJS to Python Module Mapping

### Tier 0 — Foundation (zero internal deps)

| CJS Module (lines) | Python Module (est. lines) | Key Simplifications |
|---|---|---|
| `core.cjs` (522) | `core.py` (~400) | `subprocess.run` replaces `execSync` + shell escaping. `pathlib.Path` replaces path manipulation. |
| `frontmatter.cjs` (299) | `frontmatter.py` (~200) | `re` module + `dataclasses` for schemas. Consolidates 8-10 duplicated bold/plain regex patterns. |
| `cycle-log.cjs` (157) | `cycle_log.py` (~120) | Direct port, `json` stdlib. |
| `circular-dep-breaker.cjs` (120) | `circular_dep.py` (~90) | `graphlib.TopologicalSorter` replaces hand-rolled cycle detection. |
| `spec-completeness.cjs` (225) | `spec_completeness.py` (~170) | Pydantic available for structural spec validation. |
| `uat-checkpoint.cjs` (168) | `uat_checkpoint.py` (~130) | Direct port. |

### Tier 1 — Utilities (depend only on Tier 0)

| CJS Module (lines) | Python Module (est. lines) | Key Simplifications |
|---|---|---|
| `config.cjs` (245) | `config.py` (~180) | Pydantic `BaseSettings` for typed config. |
| `module-status.cjs` (205) | `module_status.py` (~160) | `Enum` for states, dict for valid transitions. Reuses pipeline's `spec_schema.py` states. |
| `roadmap.cjs` (298) | `roadmap.py` (~220) | Direct port with `re` module. |
| `template.cjs` (222) | `template.py` (~170) | Jinja2 already a dependency — native template rendering. |
| `coherence.cjs` (289) | `coherence.py` (~220) | Imports `spec_schema.py` models directly instead of manual JSON parsing. |

### Tier 2 — State & Graph (depend on Tiers 0-1)

| CJS Module (lines) | Python Module (est. lines) | Key Simplifications |
|---|---|---|
| `state.cjs` (709) | `state.py` (~500) | `StateDocument` dataclass with `parse()`/`serialize()` replaces scattered regex. |
| `dependency-graph.cjs` (201) | `dependency_graph.py` (~100) | `graphlib.TopologicalSorter` replaces hand-rolled topo sort + tier computation (~50% reduction). |
| `health.cjs` (307) | `health.py` (~250) | Direct port. |
| `provisional-registry.cjs` (361) | `provisional_registry.py` (~280) | Pydantic models for registry entries. |

### Tier 3 — Domain Logic (depend on Tiers 0-2)

| CJS Module (lines) | Python Module (est. lines) | Key Simplifications |
|---|---|---|
| `registry.cjs` (479) | `registry.py` (~350) | Shares validation with `spec_schema.py`. |
| `decomposition.cjs` (254) | `decomposition.py` (~200) | Uses `dependency_graph`. |

### Tier 4 — Phase Operations (depend on Tiers 0-3)

| CJS Module (lines) | Python Module (est. lines) | Key Simplifications |
|---|---|---|
| `phase.cjs` (711) | `phase.py` (~500) | Absorbs `phase-complete.cjs`. Phase-file-discovery written once (fixes ORCH-03). |
| `phase-complete.cjs` (205) | *(merged into phase.py)* | — |
| `milestone.cjs` (241) | `milestone.py` (~190) | Direct port. |

### Tier 5 — Commands & Init (depend on everything)

| CJS Module (lines) | Python Module (est. lines) | Key Simplifications |
|---|---|---|
| `commands.cjs` (548) | `commands.py` (~400) | `cmdCommit` bug (ORCH-06 equivalent) fixed in port. Todo scanning written once (fixes ORCH-04). |
| `init.cjs` (702) | `init_commands.py` (~500) | Context-loading commands. Deduplicated phase discovery (fixes ORCH-03). |
| `verify.cjs` (533) | *(merged into health.py)* | Verification and health are the same concern. |

### Totals

| Metric | CJS (current) | Python (projected) |
|---|---|---|
| Files | 23 | 20 (3 merges) |
| Lines of code | 8,001 | ~5,400 (~33% reduction) |
| New external deps | — | 0 (uses existing: Pydantic, pathlib, graphlib, subprocess) |

---

## CLI Unification

### Current State

Two separate CLIs:
- `node amil/bin/amil-tools.cjs <command> [args] [--raw] [--cwd <path>]` — 700-line switch/case router
- `amil-utils <command> [options]` — Click CLI with 18 commands

### Unified CLI

```
amil-utils                              # root Click group
├── render-module                       # existing pipeline commands (18)
├── validate
├── search-modules
├── ...
└── orch                                # NEW: orchestrator command group
    ├── state <action> [--field] [--value] [--cwd] [--raw]
    ├── phase <action> [args] [--cwd] [--raw]
    ├── registry <action> [args] [--cwd] [--raw]
    ├── dep-graph <action> [--cwd] [--raw]
    ├── module-status <action> [args] [--cwd] [--raw]
    ├── coherence [--cwd] [--raw]
    ├── frontmatter <action> [args] [--cwd] [--raw]
    ├── config <action> [args] [--cwd] [--raw]
    ├── roadmap <action> [args] [--cwd] [--raw]
    ├── health [--cwd] [--raw]
    ├── init <context> [args] [--cwd] [--raw]
    ├── commit [--message] [--cwd] [--raw]
    ├── scaffold [--cwd] [--raw]
    ├── template <action> [args] [--cwd] [--raw]
    ├── verify <type> [args] [--cwd] [--raw]
    ├── progress [--cwd] [--raw]
    ├── resolve-model [--model] [--cwd] [--raw]
    ├── decomposition [args] [--cwd] [--raw]
    ├── milestone <action> [args] [--cwd] [--raw]
    ├── spec-completeness [args] [--cwd] [--raw]
    └── cycle-log [args] [--cwd] [--raw]
```

### Output Format Compatibility

Workflows parse JSON output via `--raw`. The Python CLI emits identical JSON structures:

```python
def output(data: dict, raw: bool = False, label: str = ""):
    """Match the CJS output() format exactly."""
    if raw:
        click.echo(json.dumps(data))
    else:
        click.echo(json.dumps({"ok": True, "label": label, **data}, indent=2))
```

### Workflow File Updates

Mechanical find-and-replace across 41 workflow + 19 agent `.md` files:

```
Before: node amil/bin/amil-tools.cjs state load --cwd "$PROJECT_DIR" --raw
After:  amil-utils orch state load --cwd "$PROJECT_DIR" --raw
```

The `--raw` and `--cwd` flags keep the same semantics.

---

## Single Unified Installer

### Current State

Two install commands:
- `node orchestrator/amil/bin/install.js` — copies CJS + markdown to `~/.claude/`
- `bash pipeline/install.sh` — creates Python venv, installs `amil-utils`, symlinks agents/commands

### Unified Installer

`Factory-de-Odoo/install.sh`:

1. **Python environment**: Check for `uv`, create `.venv` with Python 3.12, install `amil-utils` package (now includes orchestrator module)
2. **CLI wrapper**: Create `~/.local/bin/amil-utils` wrapper or verify PATH
3. **Markdown assets**: Copy/symlink to `~/.claude/`:
   - `orchestrator/commands/amil/*.md` to `~/.claude/commands/amil/`
   - `orchestrator/agents/*.md` to `~/.claude/agents/`
   - `orchestrator/amil/workflows/` to `~/.claude/amil/workflows/`
   - `orchestrator/amil/references/` to `~/.claude/amil/references/`
   - `orchestrator/amil/templates/` to `~/.claude/amil/templates/`
4. **Knowledge base**: Symlink `pipeline/knowledge/` to `~/.claude/amil/knowledge/`
5. **Manifest**: Write `~/.claude/amil-manifest.json` with version, paths, installed assets
6. **Verify**: Run `amil-utils --version` and `amil-utils orch health` smoke tests

---

## Test Unification

### Current State

- Orchestrator: `npm test` (Node.js, c8 coverage, `tests/*.test.cjs`)
- Pipeline: `pytest` (Python, pytest-cov, 71 test files)

### Unified Suite

One `pytest` command: `pytest --cov=amil_utils`

```
pipeline/python/tests/
├── [existing 71 test files]            # pipeline tests (unchanged)
└── orchestrator/                       # NEW: ported from CJS
    ├── conftest.py                     # shared fixtures (temp dirs, sample STATE.md, etc.)
    ├── test_core.py
    ├── test_state.py
    ├── test_phase.py
    ├── test_registry.py
    ├── test_frontmatter.py
    ├── test_config.py
    ├── test_coherence.py
    ├── test_dependency_graph.py
    ├── test_module_status.py
    ├── test_health.py
    ├── test_decomposition.py           # NEW (fulfills ORCH-02)
    ├── test_circular_dep.py            # NEW (fulfills ORCH-02)
    ├── test_commands.py
    ├── test_init_commands.py
    └── test_cli_orch.py               # Click CLI integration tests
```

Coverage config (already in `pyproject.toml`):

```toml
[tool.coverage.run]
source = ["src/amil_utils"]  # covers pipeline AND orchestrator
omit = ["*/tests/*", "*/.venv/*", "*/fixtures/*"]

[tool.coverage.report]
fail_under = 80
```

---

## Migration Strategy

### Principle: Dual-Mode Transition

Both CLIs work simultaneously during the port. Workflows switch one command at a time.

### Phase 1: Scaffold (~1 session)

1. Create `amil_utils/orchestrator/__init__.py`
2. Create `amil_utils/orchestrator/cli.py` with empty Click group
3. Register `orch` subgroup in main `cli.py`
4. Verify: `amil-utils orch --help` shows empty group

Nothing breaks. CJS code continues running. No workflows change.

### Phase 2: Port Bottom-Up (~5-6 sessions)

Port modules by dependency tier. After each module, verify output parity against CJS:

| Session | Tier | Modules |
|---|---|---|
| 1 | 0 (Foundation) | core, frontmatter, cycle_log, circular_dep, spec_completeness, uat_checkpoint |
| 2 | 1 (Utilities) | config, module_status, roadmap, template, coherence |
| 3 | 2 (State & Graph) | state, dependency_graph, health, provisional_registry |
| 4 | 3 (Domain Logic) | registry, decomposition |
| 5 | 4 (Phase Ops) | phase (+ phase-complete), milestone |
| 6 | 5 (Commands) | commands, init_commands, CLI wiring |

**Parity verification script** (run after each session):

```bash
node amil/bin/amil-tools.cjs <cmd> --cwd /path --raw > /tmp/cjs.json
amil-utils orch <cmd> --cwd /path --raw > /tmp/py.json
diff /tmp/cjs.json /tmp/py.json
```

Formalized as `tests/orchestrator/test_parity.py`.

### Phase 3: Switch Workflows (~1-2 sessions)

Once all commands pass parity tests, mechanical replacement:

```bash
find orchestrator/ -name '*.md' -exec sed -i \
  's|node amil/bin/amil-tools.cjs|amil-utils orch|g' {} +
```

Single commit. Every workflow now calls Python.

### Phase 4: Cleanup (~1 session)

1. Delete `orchestrator/amil/bin/` (CJS code)
2. Delete `orchestrator/package.json`, `package-lock.json`, `node_modules/`
3. Create unified `install.sh` at repo root
4. Update `CLAUDE.md`

### Phase 5: Verify (~1 session)

1. Fresh install from unified `install.sh`
2. Full `pytest` suite (pipeline + orchestrator)
3. `/amil:health` on a test project
4. `/amil:generate-module` on a sample spec
5. Full belt: `planned` to `spec_approved` to `generated` to `checked`

### Rollback Safety

At every phase, CJS code still exists. If a ported command produces wrong output, the workflow file reverts to call CJS while the bug is fixed. Phase 3 (the `sed` replacement) is trivially reversible with `git checkout`.

---

## Interaction with Improvement Guide

The existing Improvement Guide (`IMPROVEMENT-GUIDE.md` in the Factory Upgrades documentation) has 47 tasks across 6 tiers (8+6+7+6+12+8). Here's how they interact with this unification:

### Completed

- **Tier 0** (BUG-01 to BUG-08): 8 bugs fixed
- **Tier 1** (INFRA-01 to INFRA-06): 6 infrastructure fixes applied

### Execute As-Is (27 tasks)

- **Tier 2** (PIPE-01 to PIPE-07): 7 pipeline architecture tasks. Execute before the port. PIPE-03 (extract CLI commands) directly prepares for the orchestrator commands joining the same Click app.
- **Tier 4** (TMPL-01 to TMPL-12): 12 template quality tasks. Can run in parallel with the port.
- **Tier 5** (NEW-01 to NEW-08): 8 new capability tasks. Execute after Tier 4.

Not a single line of these 27 tasks needs modification for the unification.

### Replaced by Port (6 tasks)

- **Tier 3** (ORCH-01 to ORCH-06): 6 orchestrator architecture tasks. All are CJS improvements that the Python port solves natively:

| Task | How the Port Solves It |
|---|---|
| ORCH-01 (parseNamedArgs) | Click handles argument parsing natively |
| ORCH-02 (tests for decomp/circular-dep) | Python tests written alongside the port |
| ORCH-03 (deduplicate phase discovery) | Phase discovery written once in `phase.py` |
| ORCH-04 (deduplicate todo listing) | Todo scanning written once in `commands.py` |
| ORCH-05 (consolidate stateExtractField) | State parsing written once in `state.py` |
| ORCH-06 (goal regex mismatch) | Fixed in Python `roadmap.py` |

### Execution Sequence

```
DONE  Tier 0 (Bugs, 8 tasks)
DONE  Tier 1 (Infrastructure, 6 tasks)
NEXT  Tier 2 (Pipeline Architecture, 7 tasks)
THEN  Python Port (replaces Tier 3, 5 migration phases)
THEN  Tier 4 (Template Quality, 12 tasks) — can overlap with port
THEN  Tier 5 (New Capabilities, 8 tasks)
```

---

## Acceptance Criteria

### Port Complete

- [ ] All 23 CJS modules have Python equivalents in `amil_utils/orchestrator/`
- [ ] `amil-utils orch <command>` produces identical JSON output to `node amil-tools.cjs <command>` for all commands
- [ ] All 41 workflow files and 19 agent files reference `amil-utils orch` instead of `node amil-tools.cjs`
- [ ] Zero Node.js code remains in the repository
- [ ] `pytest --cov=amil_utils` passes with 80%+ coverage

### Installer Complete

- [ ] Single `install.sh` at repo root installs everything
- [ ] `amil-utils --version` works after fresh install
- [ ] `amil-utils orch health --cwd <project> --raw` returns valid JSON
- [ ] All slash commands, agents, workflows, references, templates are installed to `~/.claude/`

### Backward Compatibility

- [ ] All 46 `/amil:` slash commands work identically
- [ ] All 19 agents work identically
- [ ] Module generation belt (`planned` to `shipped`) works end-to-end
- [ ] No changes required in any Jinja2 template
- [ ] No changes required in any preprocessor

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Subtle JSON output differences break workflows | High | Parity test suite compares output for every command |
| Python subprocess calls slower than Node.js execSync | Low | Orchestrator commands are IO-bound (git, file reads), not CPU-bound |
| Port introduces bugs in state management | High | State is the most critical module — port it with extensive tests and manual verification |
| Markdown asset paths break after restructure | Medium | Install script uses same `~/.claude/` destinations; only source paths change |
| CJS test coverage doesn't translate to Python | Medium | Port tests alongside modules, use ORCH-02 analysis as test specification |

---

## Out of Scope

- Changing the 46 slash command definitions (they're markdown instructions, not code)
- Changing the Jinja2 templates or preprocessors
- Changing the MCP server implementation
- Adding new orchestrator features (that's Tier 5 of the improvement guide)
- Changing the module lifecycle (`planned` to `shipped`) semantics
