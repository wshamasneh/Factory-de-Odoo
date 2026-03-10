# Prompt: Planning the odoo-gsd Fork

You have now mapped the entire GSD codebase. The next step is planning how to fork it into **odoo-gsd** — a specialized version that orchestrates Odoo ERP module generation at scale.

This prompt gives you the full context from our parallel chat where we designed the three-layer architecture and wrote the fork PRD. Read everything below carefully before responding.

---

## The Big Picture — Three Layers

We're building a system that takes a university ERP PRD and produces 20+ production-ready Odoo modules. Three layers:

```
LAYER 1: odoo-gsd (THIS FORK)
  → Reads PRD, decomposes into modules, decides order, drives the belt,
    talks to the human, maintains cross-module state

LAYER 2: Conveyor Belt (separate repo: Odoo-Development-Automation)
  → Takes a single module spec.json, runs multi-pass pipeline
    (Model Architect → Logic Writer → View Designer → Security Engineer
    → Report Builder → Test Writer → Validator), produces one Odoo module

LAYER 3: Checker (lives inside the belt repo)
  → Verifies what the belt produced — structural checks, cross-module
    coherence, spec coverage, integration testing
```

odoo-gsd is Layer 1. It doesn't generate Odoo code itself. It orchestrates: it breaks the PRD into module specs, feeds them one-by-one to the belt, collects results, runs the checker, maintains a model registry that grows with each module, and keeps the human in the loop at every checkpoint.

---

## What odoo-gsd Must Do (That GSD Doesn't)

GSD is a generic project orchestrator. odoo-gsd specializes it for Odoo ERP generation. Here's what's new:

### 1. Odoo-Specific Project Initialization (`/odoo-gsd:new-erp`)
Replaces `/odoo-gsd:new-project`. Instead of generic project questions, asks:
- Odoo version (17.0 / 18.0)
- Multi-company? (campuses as separate companies)
- Localization (pk / none / other)
- Module count estimate
- Existing Odoo modules being extended (payroll, purchase, accounting)
- LMS integration (Canvas / Moodle / none)
- Notification channels (email / whatsapp / sms)
- Deployment target (single university / multi-university platform)

Then spawns 4 parallel research agents to analyze the PRD:
- Agent 1: Module boundary analysis — where do model responsibilities split?
- Agent 2: OCA registry check — existing modules to extend vs build from scratch
- Agent 3: Cross-module dependency mapping
- Agent 4: Computation chain identification (CGPA chain, fee penalty chain, merit list chain)

Output: Module dependency graph with phased generation order (foundation → core academic → operations → communication), not a generic roadmap.

### 2. Model Registry (New State — `.planning/model_registry.json`)
This is the critical new concept. As each module is generated, its models get registered:

```json
{
  "uni.student": {
    "module": "uni_student",
    "fields": {
      "name": {"type": "Char", "required": true},
      "cgpa": {"type": "Float", "compute": "_compute_cgpa", "store": true}
    },
    "methods": ["_compute_cgpa"],
    "mail_thread": true,
    "security_groups": ["uni_core.group_registrar"]
  }
}
```

Every subsequent module generation gets the current registry injected so it knows what models/fields already exist. This prevents: duplicate model names, broken Many2one references, missing computed field dependencies, security group conflicts.

### 3. Odoo Codebase Scanning (`/odoo-gsd:map-erp`)
Replaces `/odoo-gsd:map-codebase`. Spawns 4 specialized agents:
- Manifest parser: reads all `__manifest__.py` → builds dependency graph
- Model AST analyzer: parses Python files → extracts fields, methods, inheritance → populates model registry
- Security scanner: reads `ir.model.access.csv` + record rules → maps security groups and ACLs
- View pattern detector: parses XML → detects tabs, smart buttons, kanban patterns

Output: `.planning/model_registry.json` + `.planning/erp_map.md`

### 4. Module-Specific Discussion (`/odoo-gsd:discuss-module`)
Replaces `/odoo-gsd:discuss-phase`. Instead of generic questions, asks module-type-specific questions. Example for a fee module: Monetary vs Float for amounts? Fee structure granularity? Penalty calculation method? Payment channels? Auto-generate vs manual trigger? Challan format? Partial payments? Waiver model? Scholarship integration?

Output: `{module}-CONTEXT.md` with implementation decisions.

### 5. Spec Generation with Coherence Check (`/odoo-gsd:plan-module`)
Replaces `/odoo-gsd:plan-phase`. Generates a `spec.json` that the belt consumes:

```json
{
  "module_name": "uni_fee",
  "models": [...],
  "business_rules": [...],
  "computation_chains": [...],
  "workflow": [...],
  "view_hints": [...],
  "reports": [...],
  "notifications": [...],
  "cron_jobs": [...],
  "security": [...],
  "portal": [...],
  "api_endpoints": [...],
  "_available_models": "<<injected from model registry>>"
}
```

Before human approval, runs a cross-module coherence check:
- All Many2one targets exist in the registry
- Computation chains have matching depends
- Security scope fields are present
- No duplicate model names

### 6. Belt Invocation (`/odoo-gsd:generate-module`)
Replaces `/odoo-gsd:execute-phase`. Loads spec.json, injects model registry, calls the belt as a subagent with fresh 200K context. Belt runs its multi-pass pipeline and returns a `generation_manifest.json`. On success: updates model registry, atomic git commit. On failure: presents errors with options (retry / manual fix / skip).

### 7. Checker Invocation (`/odoo-gsd:check-module`)
Replaces `/odoo-gsd:verify-work`. Runs the checker (4 levels):
- CHK-01: Structural (Many2one targets, ACLs, mail.thread rules, syntax)
- CHK-02: Cross-module (foreign keys, computed chains, security scopes, dependency graph)
- CHK-03: Spec coverage (compare manifest vs spec — what's implemented vs stubbed)
- CHK-04: Integration (Docker install, run tests across boundaries)

Presents structured pass/fail to human for sign-off.

### 8. Full ERP Audit (`/odoo-gsd:audit-erp`)
Replaces `/odoo-gsd:audit-milestone`. After ALL modules generated:
- Install all modules together in Docker
- Run all integration tests across module boundaries
- Trace all computation chains end-to-end
- Verify all security scopes
- Check portal route conflicts
- Validate cron jobs reference existing methods
- Generate production readiness checklist

---

## Command Mapping Summary

| GSD Command | odoo-gsd Command | Change Type |
|---|---|---|
| `/odoo-gsd:new-project` | `/odoo-gsd:new-erp` | Heavy rewrite — Odoo questions, module decomposition, 4 research agents |
| `/odoo-gsd:map-codebase` | `/odoo-gsd:map-erp` | Heavy rewrite — Odoo-specific AST scanning, model registry population |
| `/odoo-gsd:discuss-phase` | `/odoo-gsd:discuss-module` | Medium rewrite — module-type-specific question templates |
| `/odoo-gsd:plan-phase` | `/odoo-gsd:plan-module` | Heavy rewrite — spec.json generation, coherence checker |
| `/odoo-gsd:execute-phase` | `/odoo-gsd:generate-module` | Medium rewrite — belt invocation, registry update |
| `/odoo-gsd:verify-work` | `/odoo-gsd:check-module` | Medium rewrite — checker invocation, structured results |
| `/odoo-gsd:complete-milestone` | `/odoo-gsd:complete-phase` | Light rewrite — add registry archival, release tagging |
| `/odoo-gsd:progress` | `/odoo-gsd:progress` | Light rewrite — add module status, registry stats |
| `/odoo-gsd:quick` | `/odoo-gsd:quick` | Light rewrite — quick field/bug/view without full cycle |
| `/odoo-gsd:audit-milestone` | `/odoo-gsd:audit-erp` | Heavy rewrite — Docker install all, integration tests, production checklist |
| `/odoo-gsd:pause-work` | inherited | No change |
| `/odoo-gsd:resume-work` | inherited | No change |
| `/odoo-gsd:help` | inherited | No change (update help text) |
| `/odoo-gsd:add-todo` | inherited | No change |
| `/odoo-gsd:debug` | inherited | No change |
| `/odoo-gsd:settings` | inherited | No change (extend config schema) |
| `/odoo-gsd:set-profile` | inherited | No change |

---

## New State Files (Beyond GSD's Standard State)

GSD already manages: PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, `.planning/config.json`

odoo-gsd adds:
- `.planning/model_registry.json` — all models across all modules, updated after each generation
- `.planning/computation_chains.json` — cross-module chains with completion status
- `.planning/security_scope.json` — dynamic RBAC configuration
- `.planning/module_status.json` — per-module: planned / spec_approved / generated / checked / shipped
- `{module}-spec.json` — spec sent to belt
- `{module}-CONTEXT.md` — implementation decisions from discuss-module
- `{module}-RESEARCH.md` — research results
- `{module}-manifest.json` — generation manifest from belt
- `{module}-check.json` — checker results

---

## New Agent Prompts (in `agents/`)

GSD's subagent system needs Odoo-specialized agent prompts:
- `odoo-module-researcher.md` — Odoo pattern research, OCA repo queries
- `odoo-spec-generator.md` — spec.json format, Odoo model patterns, field types
- `odoo-coherence-checker.md` — cross-module reference validation
- `odoo-module-questioner.md` — module-type-specific questions (fee vs exam vs student)

GSD spawns these as subagents — we provide the prompts, GSD handles orchestration.

---

## Configuration Extension

GSD's `.planning/config.json` gets an `odoo` block:

```json
{
  "mode": "interactive",
  "depth": "standard",
  "profile": "balanced",
  "odoo": {
    "version": "17.0",
    "multi_company": true,
    "localization": "pk",
    "belt_repo_path": "../Odoo-Development-Automation",
    "default_depends": ["base", "mail"],
    "security_framework": "dynamic_rbac",
    "scope_levels": ["institution", "campus", "faculty", "department", "program"],
    "notification_channels": ["email", "whatsapp"],
    "canvas_integration": true
  }
}
```

---

## End-to-End Workflow

```bash
/odoo-gsd:new-erp                # Feed PRD → module decomposition → generation roadmap
# For each module in order:
/odoo-gsd:discuss-module uni_fee  # Odoo-specific implementation questions
/odoo-gsd:plan-module uni_fee     # Generate spec.json → coherence check → human approval
/odoo-gsd:generate-module uni_fee # Belt produces module → registry updated
/odoo-gsd:check-module uni_fee    # Checker verifies → human sign-off
# After all modules:
/odoo-gsd:audit-erp               # Full cross-project audit → production readiness → ship
```

Human in the loop at every checkpoint. Context stays fresh via GSD's subagent architecture. Model registry grows with each module. Cross-module coherence checked continuously.

---

## Your Task

Now that you understand both GSD's codebase AND what odoo-gsd needs to do, produce a **concrete fork plan** that maps the new requirements to specific files, functions, and patterns in the GSD codebase.

For each specialized command, identify:
1. Which GSD source file(s) it maps to
2. What can be kept as-is
3. What needs modification (and what the modification is)
4. What's entirely new code
5. Where the new agent prompts go and what format they follow (based on existing agent prompt patterns you've seen)
6. Where the new state files get read/written (based on how GSD currently manages state)
7. How the belt and checker get invoked as subagents (based on GSD's existing subagent spawning mechanism)

Also identify:
- Any GSD abstractions that need extending (e.g., does the command registry need changes to support dual prefixes?)
- Any hooks that need Odoo-specific behavior
- Any scripts that need modification
- Installation/setup changes

Ground every decision in the actual GSD code you've read. No guessing.
