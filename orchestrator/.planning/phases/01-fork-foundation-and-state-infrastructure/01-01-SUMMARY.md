---
phase: 01-fork-foundation-and-state-infrastructure
plan: 01
subsystem: infra
tags: [cli, rename, fork, installer, claude-code]

requires: []
provides:
  - "odoo-gsd directory structure and CLI entry point"
  - "odoo-gsd-tools.cjs renamed CLI with all internal references updated"
  - "32 slash commands with /odoo-gsd: prefix"
  - "12 agent definitions with odoo-gsd- prefix"
  - "Claude-Code-only install.js with odoo-gen and Python checks"
  - "CLAUDE.md project context document"
affects: [01-02, 01-03, 02, 03, 04, 05]

tech-stack:
  added: []
  patterns: [odoo-gsd-* naming convention, .odoo-gsd/ config directory]

key-files:
  created:
    - odoo-gsd/bin/install.js
    - CLAUDE.md
  modified:
    - odoo-gsd/bin/odoo-gsd-tools.cjs
    - odoo-gsd/bin/lib/core.cjs
    - odoo-gsd/bin/lib/config.cjs
    - tests/helpers.cjs
    - package.json

key-decisions:
  - "Renamed all gsd- prefixes to odoo-gsd- for full identity separation"
  - "Changed config directory from .gsd/ to .odoo-gsd/"
  - "Rewrote install.js from 2464 to 407 lines, Claude-Code-only"
  - "Updated branch templates from gsd/ to odoo-gsd/ prefix"

patterns-established:
  - "odoo-gsd-* prefix: all agent names, hook names, and CLI references use this prefix"
  - "/odoo-gsd: command prefix: all slash commands use this namespace"
  - "Claude-Code-only: no multi-runtime support in install or config paths"

requirements-completed: [FORK-01, FORK-02, FORK-03, FORK-04, FORK-05, FORK-06, FORK-07, FORK-08, FORK-09, FORK-10, TEST-05]

duration: 8min
completed: 2026-03-05
---

# Phase 1 Plan 1: Fork Rename and Identity Summary

**Complete rename of GSD fork to odoo-gsd identity with zero old references, all 535 tests passing, and Claude-Code-only installer**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-05T16:35:24Z
- **Completed:** 2026-03-05T16:43:30Z
- **Tasks:** 2
- **Files modified:** 164

## Accomplishments
- Renamed entire codebase from get-shit-done/gsd to odoo-gsd identity (directories, files, internal references)
- Zero remaining old references across all .cjs, .md, .js, .json files
- All 535 tests pass after rename
- Rewrote install.js from 2464 lines to 407 lines, Claude-Code-only with odoo-gen and Python 3.8+ checks
- Created CLAUDE.md documenting odoo-gsd architecture, commands, rules, and development workflow

## Task Commits

Each task was committed atomically:

1. **Task 1: Rename directory structure and all internal references** - `b1b1021` (feat)
2. **Task 2: Rewrite install.js and CLAUDE.md** - `aaf6da7` (feat)

## Files Created/Modified
- `odoo-gsd/bin/odoo-gsd-tools.cjs` - Renamed CLI entry point
- `odoo-gsd/bin/lib/core.cjs` - MODEL_PROFILES with odoo-gsd-* keys
- `odoo-gsd/bin/lib/config.cjs` - .odoo-gsd/ config directory paths
- `odoo-gsd/bin/install.js` - New Claude-Code-only installer (407 LOC)
- `commands/odoo-gsd/` - 32 command files with /odoo-gsd: prefix
- `agents/odoo-gsd-*.md` - 12 renamed agent definitions
- `hooks/odoo-gsd-*.js` - 3 renamed hook files
- `tests/helpers.cjs` - Updated TOOLS_PATH and temp dir prefix
- `package.json` - odoo-gsd name, description, keywords
- `CLAUDE.md` - Odoo ERP orchestrator context document

## Decisions Made
- Renamed config directory from ~/.gsd/ to ~/.odoo-gsd/ for full identity separation
- Updated git branch templates from gsd/ to odoo-gsd/ prefix
- Stripped all multi-runtime support (OpenCode, Gemini, Codex) from install.js
- Set package version to 1.0.0 (fresh fork identity)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed double-rename issue during sed replacement**
- **Found during:** Task 1 (Layer 4 internal reference updates)
- **Issue:** Sequential sed replacements caused "odoo-odoo-gsd" double-prefixes when gsd-tools matched inside already-renamed odoo-gsd-tools
- **Fix:** Added a cleanup pass to replace odoo-odoo-gsd with odoo-gsd, then switched to perl negative lookbehind for remaining replacements
- **Files modified:** All .cjs, .md, .js, .json files
- **Verification:** grep confirmed zero odoo-odoo-gsd matches
- **Committed in:** b1b1021 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Auto-fix was necessary to prevent broken references. No scope creep.

## Issues Encountered
- CLAUDE.md was in .gitignore; required `git add -f` to commit
- Pre-existing test failure (config-get model_profile expected 'balanced' but ~/.gsd/defaults.json had 'quality') self-resolved after renaming config dir to .odoo-gsd/

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- odoo-gsd identity fully established as foundation for all Phase 1 work
- All subsequent plans can use /odoo-gsd: commands and odoo-gsd-tools.cjs paths
- install.js ready for odoo-gen integration when belt is available (Phase 5)

---
*Phase: 01-fork-foundation-and-state-infrastructure*
*Completed: 2026-03-05*
