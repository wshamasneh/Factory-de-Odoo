# Amil — Odoo ERP Module Orchestrator

An orchestration system built on Claude Code for generating, validating, and shipping cross-module-consistent Odoo ERP modules.

## Architecture

### Core Value
Cross-module coherence: every generated Odoo module must be referentially consistent with all other modules in the project (model references, security rules, menu hierarchies, view inheritance).

### Module Lifecycle
```
planned -> spec_approved -> generated -> checked -> shipped
```
Modules progress through these states sequentially. Only one module generates at a time (the amil belt needs exclusive Docker access).

### State Files (.planning/)
| File | Purpose |
|------|---------|
| `config.json` | Profile, workflow toggles, branching strategy |
| `STATE.md` | Current position, decisions, blockers, session continuity |
| `ROADMAP.md` | Phase definitions, plan progress tables |
| `PROJECT.md` | Core value, key decisions, project identity |
| `REQUIREMENTS.md` | Requirement traceability with completion status |
| `model_registry.json` | Central registry of all Odoo models across modules |
| `module_status.json` | Per-module lifecycle state tracking |

### CLI Tool
```bash
amil-utils orch <command> [args] [--raw] [--cwd <path>]
```

Key commands: `state`, `resolve-model`, `find-phase`, `commit`, `roadmap`, `requirements`, `phase`, `validate`, `init`, `frontmatter`, `template`, `scaffold`, `progress`.

### Directory Structure
```
amil/
  bin/
    install.js         # npm-based installer
  workflows/           # Workflow definitions (execute-plan, plan-phase, etc.)
  references/          # Reference docs (checkpoints, git integration, etc.)
  templates/           # Document templates (summary, plan, project, etc.)
commands/amil/         # Slash commands (/amil:*)
agents/                # Agent definitions (amil-*.md)
hooks/                 # Hook scripts (amil-*.py)
install.py             # Python installer
```

### Python Implementation
```
pipeline/python/src/amil_utils/orchestrator/
  __init__.py          # Package init
  cli.py               # Click CLI (~60 commands)
  core.py              # Foundation: paths, slugs, timestamps, phase lookup
  state.py             # Session state management (691 lines equivalent)
  phase.py             # Phase operations, plan indexing
  roadmap.py           # Roadmap parsing and progress
  frontmatter.py       # YAML frontmatter extraction
  config.py            # Config management
  health.py            # Project health checks
  dependency_graph.py  # Phase dependency analysis
  registry.py          # Model registry operations
  milestone.py         # Milestone lifecycle
  commands.py          # Git commit, verify, summary-extract
  init_commands.py     # Workflow initialization commands
  ... (20+ modules total)
```

## Command Reference

All commands use the `/amil:` prefix (46 total):

### Project Lifecycle
| Command | Purpose |
|---------|---------|
| `/amil:new-project` | Initialize a new Amil project |
| `/amil:new-milestone` | Start a new milestone cycle |
| `/amil:complete-milestone` | Archive completed milestone |
| `/amil:audit-milestone` | Audit milestone completion |
| `/amil:plan-milestone-gaps` | Create phases for milestone gaps |

### Phase Workflow
| Command | Purpose |
|---------|---------|
| `/amil:research-phase` | Research before planning |
| `/amil:discuss-phase` | Gather context through questions |
| `/amil:plan-phase` | Create detailed phase plan |
| `/amil:execute-phase` | Execute phase plans |
| `/amil:validate-phase` | Validate phase consistency |
| `/amil:verify-work` | Verify completed work via UAT |
| `/amil:add-tests` | Generate tests for completed phase |

### Phase Management
| Command | Purpose |
|---------|---------|
| `/amil:add-phase` | Add phase to end of milestone |
| `/amil:insert-phase` | Insert urgent phase between existing |
| `/amil:remove-phase` | Remove future phase |
| `/amil:list-phase-assumptions` | Surface assumptions about a phase |

### ERP Module Generation
| Command | Purpose |
|---------|---------|
| `/amil:new-erp` | Initialize ERP project from PRD |
| `/amil:discuss-module` | Interactive module discussion |
| `/amil:plan-module` | Generate spec.json for module |
| `/amil:generate-module` | Generate module from spec.json |
| `/amil:validate-module` | pylint-odoo + Docker validation |
| `/amil:search-modules` | Semantic search for existing modules |
| `/amil:research-module` | Research patterns for module need |
| `/amil:extend-module` | Fork and extend existing module |
| `/amil:index-modules` | Build/update ChromaDB module index |

### Automation & Reporting
| Command | Purpose |
|---------|---------|
| `/amil:run-prd` | Full PRD-to-ERP generation cycle |
| `/amil:batch-discuss` | Auto-discuss underspecified modules |
| `/amil:coherence-report` | Cross-module coherence analysis |
| `/amil:live-uat` | Browser-based UAT verification |
| `/amil:module-history` | Generation history timeline |
| `/amil:phases` | Generation phases and progress |

### Utility
| Command | Purpose |
|---------|---------|
| `/amil:progress` | Show project progress |
| `/amil:quick` | Quick single-task execution |
| `/amil:health` | Check project health |
| `/amil:debug` | Systematic debugging |
| `/amil:map-codebase` | Analyze codebase with parallel agents |
| `/amil:cleanup` | Archive completed phase directories |
| `/amil:update` | Update Amil to latest version |
| `/amil:reapply-patches` | Reapply local modifications after update |
| `/amil:set-profile` | Switch model profile |
| `/amil:settings` | Configure workflow toggles |
| `/amil:help` | Show all commands |

### Session Management
| Command | Purpose |
|---------|---------|
| `/amil:pause-work` | Create context handoff |
| `/amil:resume-work` | Resume from previous session |
| `/amil:add-todo` | Capture task as todo |
| `/amil:check-todos` | List pending todos |

## Rules

1. **Sequential generation only** -- one module at a time through the belt
2. **All state changes through CLI subcommands** -- never edit STATE.md or config.json manually
3. **Atomic writes for JSON state** -- write complete files, never partial updates
4. **Immutable data patterns** -- create new objects, never mutate existing
5. **Python-first** -- all orchestrator logic lives in `amil_utils.orchestrator`
6. **Zero Node.js runtime dependency** -- Python 3.12 only at runtime

## Development

### Running Tests
```bash
cd pipeline/python
pytest tests/orchestrator/           # Run orchestrator tests (500+)
pytest tests/orchestrator/ --cov     # With coverage
pytest tests/                        # Full suite (2900+ tests)
```

### Test Structure
- Tests are in `pipeline/python/tests/orchestrator/`
- 500+ tests covering all modules
- Parity tests verify Python output matches original CJS behavior
- Tests create temp directories, never modify the real project

### Code Quality
- Functions under 50 lines
- Files under 800 lines
- No deep nesting (max 4 levels)
- No hardcoded secrets
- Proper error handling at every level
