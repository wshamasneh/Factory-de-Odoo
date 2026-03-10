# Code Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 29 validated findings from the comprehensive code review across both orchestrator (Node.js CJS) and pipeline (Python 3.12) components.

**Architecture:** Fixes are grouped into 7 independent tasks by component and priority. Security fixes first, then bugs, then code quality. Each task produces a standalone commit.

**Tech Stack:** Node.js (CJS), Python 3.12, Jinja2, pytest, Node.js native test runner

---

## File Structure

### Orchestrator files to modify:
- `orchestrator/odoo-gsd/bin/lib/core.cjs` — Add `ensureWithinCwd()`, `atomicWriteFile()`, fix `isGitIgnored()`, fix `output()` temp file permissions
- `orchestrator/odoo-gsd/bin/lib/state.cjs` — Remove duplicate `stateExtractField`
- `orchestrator/odoo-gsd/bin/lib/init.cjs` — Replace `execSync('find ...')` with Node.js traversal
- `orchestrator/odoo-gsd/bin/lib/verify.cjs` — Add regex timeout/validation, use `ensureWithinCwd`
- `orchestrator/odoo-gsd/bin/lib/frontmatter.cjs` — Fix `Object.assign` mutation
- `orchestrator/odoo-gsd/bin/lib/config.cjs` — Fix nested mutation pattern
- `orchestrator/package.json` — Fix coverage threshold 70% -> 80%

### Pipeline files to modify:
- `pipeline/python/src/odoo_gen_utils/preprocessors/performance.py` — Add WHERE clause validation
- `pipeline/python/src/odoo_gen_utils/preprocessors/constraints.py` — Add AST validation for check_body
- `pipeline/python/src/odoo_gen_utils/renderer.py` — Add XML escaping, fix missing encoding
- `pipeline/python/src/odoo_gen_utils/search/fork.py` — Add input validation regex
- `pipeline/python/src/odoo_gen_utils/cli.py` — Replace bare `except Exception: pass` with logging
- `pipeline/python/src/odoo_gen_utils/spec_schema.py` — Replace print() with logger
- `pipeline/python/src/odoo_gen_utils/validation/docker_runner.py` — Remove redundant print()
- `pipeline/python/src/odoo_gen_utils/templates/shared/controller.py.j2` — Fix error message leakage
- `pipeline/python/src/odoo_gen_utils/templates/shared/portal_controller.py.j2` — Add sudo warning comment
- `pipeline/.mcp.json` — Remove hardcoded credentials
- `pipeline/python/src/odoo_gen_utils/verifier.py` — Remove default "admin" fallback

### Test files to create/modify:
- `orchestrator/tests/core-security.test.cjs` — Tests for `ensureWithinCwd`, `atomicWriteFile`
- `pipeline/python/tests/test_security_fixes.py` — Tests for WHERE validation, fork input validation, XML escaping

---

## Chunk 1: P0 Security — Generated Code Injection (S1, S2)

### Task 1: Fix SQL injection in composite index WHERE clause

**Files:**
- Modify: `pipeline/python/src/odoo_gen_utils/preprocessors/performance.py:168-191`
- Test: `pipeline/python/tests/test_security_fixes.py` (create)

- [ ] **Step 1: Write the failing test for WHERE clause validation**

```python
# pipeline/python/tests/test_security_fixes.py
"""Tests for security fixes across the pipeline."""
from __future__ import annotations

import pytest


class TestWhereClauseValidation:
    """S1: WHERE clause in composite index must be safe SQL predicates only."""

    def test_safe_where_clause_accepted(self):
        from odoo_gen_utils.preprocessors.performance import _validate_where_clause

        assert _validate_where_clause("active = True") is True
        assert _validate_where_clause("state != 'cancelled'") is True
        assert _validate_where_clause("amount > 0") is True
        assert _validate_where_clause("parent_id IS NOT NULL") is True
        assert _validate_where_clause("active = True AND state = 'confirmed'") is True

    def test_unsafe_where_clause_rejected(self):
        from odoo_gen_utils.preprocessors.performance import _validate_where_clause

        assert _validate_where_clause("1=1; DROP TABLE res_users; --") is False
        assert _validate_where_clause("active = True; DELETE FROM") is False
        assert _validate_where_clause("') OR 1=1 --") is False
        assert _validate_where_clause("active = True UNION SELECT * FROM") is False

    def test_empty_where_clause_accepted(self):
        from odoo_gen_utils.preprocessors.performance import _validate_where_clause

        assert _validate_where_clause("") is True
        assert _validate_where_clause(None) is True
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/pipeline/python && uv run pytest tests/test_security_fixes.py::TestWhereClauseValidation -v`
Expected: FAIL with "cannot import name '_validate_where_clause'"

- [ ] **Step 3: Implement WHERE clause validation in performance.py**

In `pipeline/python/src/odoo_gen_utils/preprocessors/performance.py`, add after the `_SAFE_IDENTIFIER` definition (around line 15):

```python
import re

_SAFE_IDENTIFIER = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")

# SQL keywords that are NEVER allowed in WHERE clauses for composite indexes
_DANGEROUS_SQL_KEYWORDS = re.compile(
    r"\b(DROP|DELETE|INSERT|UPDATE|ALTER|CREATE|TRUNCATE|EXEC|EXECUTE|"
    r"UNION|INTO|GRANT|REVOKE|COPY|pg_)\b",
    re.IGNORECASE,
)
# Only allow simple predicates: identifiers, operators, literals, AND/OR/NOT
_SAFE_WHERE_CHARS = re.compile(r"^[a-zA-Z0-9_\s=!<>().',\-]+$")


def _validate_where_clause(where_clause: str | None) -> bool:
    """Validate a WHERE clause contains only safe SQL predicates.

    Rejects clauses containing dangerous SQL keywords (DROP, DELETE, UNION, etc.)
    or suspicious characters (semicolons, double-dashes).
    """
    if not where_clause:
        return True
    if not isinstance(where_clause, str):
        return False
    clause = where_clause.strip()
    if not clause:
        return True
    # Reject dangerous keywords
    if _DANGEROUS_SQL_KEYWORDS.search(clause):
        return False
    # Reject semicolons (statement terminator)
    if ";" in clause:
        return False
    # Reject double-dash comments
    if "--" in clause:
        return False
    # Only allow safe characters
    if not _SAFE_WHERE_CHARS.match(clause):
        return False
    return True
```

Then update the index_hint processing (around line 179) to use the validator:

```python
where_clause = hint.get("where")
if where_clause and not isinstance(where_clause, str):
    logger.warning(
        "index_hint on model '%s' has non-string where clause -- skipping.",
        model.get("name", "?"),
    )
    continue
if not _validate_where_clause(where_clause):
    logger.warning(
        "index_hint on model '%s' has unsafe where clause %r -- skipping.",
        model.get("name", "?"),
        where_clause,
    )
    continue
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/pipeline/python && uv run pytest tests/test_security_fixes.py::TestWhereClauseValidation -v`
Expected: PASS

- [ ] **Step 5: Run existing tests to verify no regression**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/pipeline/python && uv run pytest tests/ -m "not docker and not e2e" --timeout=60 -q`
Expected: All existing tests PASS

- [ ] **Step 6: Commit**

```bash
cd /home/inshal-rauf/Factory-de-Odoo
git add pipeline/python/src/odoo_gen_utils/preprocessors/performance.py pipeline/python/tests/test_security_fixes.py
git commit -m "fix(security): validate WHERE clause in composite index to prevent SQL injection

Add _validate_where_clause() that rejects dangerous SQL keywords (DROP, DELETE,
UNION, etc.), semicolons, and double-dash comments. Unsafe WHERE clauses are
now skipped with a warning instead of being interpolated into generated code."
```

---

### Task 2: Add AST validation for constraint check_body/check_expr

**Files:**
- Modify: `pipeline/python/src/odoo_gen_utils/preprocessors/constraints.py`
- Modify: `pipeline/python/tests/test_security_fixes.py`

- [ ] **Step 1: Write the failing test for constraint validation**

Add to `pipeline/python/tests/test_security_fixes.py`:

```python
class TestConstraintCodeValidation:
    """S2: check_body/check_expr must not contain dangerous Python constructs."""

    def test_safe_check_expr_accepted(self):
        from odoo_gen_utils.preprocessors.constraints import _validate_generated_code

        assert _validate_generated_code("rec.date_start and rec.date_end and rec.date_start > rec.date_end") is True
        assert _validate_generated_code("rec.amount > 0") is True

    def test_import_statement_rejected(self):
        from odoo_gen_utils.preprocessors.constraints import _validate_generated_code

        assert _validate_generated_code("import os; os.system('rm -rf /')") is False
        assert _validate_generated_code("__import__('os').system('ls')") is False

    def test_exec_eval_rejected(self):
        from odoo_gen_utils.preprocessors.constraints import _validate_generated_code

        assert _validate_generated_code("exec('print(1)')") is False
        assert _validate_generated_code("eval('1+1')") is False

    def test_subprocess_rejected(self):
        from odoo_gen_utils.preprocessors.constraints import _validate_generated_code

        assert _validate_generated_code("subprocess.run(['ls'])") is False
        assert _validate_generated_code("os.system('whoami')") is False

    def test_multiline_check_body_validated(self):
        from odoo_gen_utils.preprocessors.constraints import _validate_generated_code

        safe_body = (
            "for rec in self:\n"
            "    if rec.amount < 0:\n"
            "        raise ValidationError(_('Amount must be positive'))\n"
        )
        assert _validate_generated_code(safe_body) is True

        unsafe_body = (
            "import subprocess\n"
            "subprocess.run(['rm', '-rf', '/'])\n"
        )
        assert _validate_generated_code(unsafe_body) is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/pipeline/python && uv run pytest tests/test_security_fixes.py::TestConstraintCodeValidation -v`
Expected: FAIL with "cannot import name '_validate_generated_code'"

- [ ] **Step 3: Implement AST-based code validation**

In `pipeline/python/src/odoo_gen_utils/preprocessors/constraints.py`, add:

```python
import ast
import logging

logger = logging.getLogger(__name__)

# Dangerous AST node types that should never appear in generated constraint code
_DANGEROUS_NODES = (ast.Import, ast.ImportFrom)
# Dangerous function names
_DANGEROUS_CALLS = frozenset({
    "exec", "eval", "compile", "__import__", "globals", "locals",
    "getattr", "setattr", "delattr", "breakpoint",
})
# Dangerous attribute access patterns
_DANGEROUS_ATTRS = frozenset({
    "system", "popen", "run", "call", "check_output", "check_call",
    "Popen",
})


def _validate_generated_code(code: str) -> bool:
    """Validate that generated Python code does not contain dangerous constructs.

    Parses the code as an AST and walks it to reject import statements,
    exec/eval calls, subprocess usage, and os.system calls.

    Returns True if the code is safe, False if dangerous constructs are found.
    """
    if not code or not code.strip():
        return True
    try:
        tree = ast.parse(code)
    except SyntaxError:
        return False
    for node in ast.walk(tree):
        # Reject import statements
        if isinstance(node, _DANGEROUS_NODES):
            return False
        # Reject dangerous function calls
        if isinstance(node, ast.Call):
            func = node.func
            if isinstance(func, ast.Name) and func.id in _DANGEROUS_CALLS:
                return False
            if isinstance(func, ast.Attribute) and func.attr in _DANGEROUS_ATTRS:
                return False
    return True
```

Then in `_enrich_constraint`, after building `check_expr` or `check_body`, validate:

```python
# After building enriched["check_expr"] or enriched["check_body"]:
code_to_validate = enriched.get("check_expr") or enriched.get("check_body", "")
if code_to_validate and not _validate_generated_code(code_to_validate):
    logger.warning(
        "Constraint '%s' contains dangerous code constructs -- skipping.",
        c.get("name", "unknown"),
    )
    return None  # Caller must handle None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/pipeline/python && uv run pytest tests/test_security_fixes.py::TestConstraintCodeValidation -v`
Expected: PASS

- [ ] **Step 5: Run existing tests**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/pipeline/python && uv run pytest tests/ -m "not docker and not e2e" --timeout=60 -q`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd /home/inshal-rauf/Factory-de-Odoo
git add pipeline/python/src/odoo_gen_utils/preprocessors/constraints.py pipeline/python/tests/test_security_fixes.py
git commit -m "fix(security): add AST validation for generated constraint code

Add _validate_generated_code() that walks the AST to reject import statements,
exec/eval calls, subprocess usage, and os.system calls in check_body/check_expr.
Prevents arbitrary Python injection via malicious module specs."
```

---

### Task 3: Fix hardcoded credentials (S3) and default admin fallback

**Files:**
- Modify: `pipeline/.mcp.json`
- Modify: `pipeline/python/src/odoo_gen_utils/verifier.py:320-327`

- [ ] **Step 1: Remove hardcoded credentials from .mcp.json**

Replace the full content of `pipeline/.mcp.json` with:

```json
{
  "mcpServers": {
    "odoo-introspection": {
      "type": "stdio",
      "command": "python3",
      "args": ["-m", "odoo_gen_utils.mcp.server"],
      "env": {
        "ODOO_URL": "http://localhost:8069",
        "ODOO_DB": "odoo_dev"
      }
    }
  }
}
```

Note: `ODOO_USER` and `ODOO_API_KEY` are removed — the MCP server already reads them from environment variables.

- [ ] **Step 2: Remove default "admin" fallback from verifier.py**

In `pipeline/python/src/odoo_gen_utils/verifier.py`, change lines 324-326 from:

```python
        db=os.environ.get("ODOO_DB", "odoo_dev"),
        username=os.environ.get("ODOO_USER", "admin"),
        api_key=os.environ.get("ODOO_API_KEY", "admin"),
```

To:

```python
        db=os.environ.get("ODOO_DB", "odoo_dev"),
        username=os.environ.get("ODOO_USER", ""),
        api_key=os.environ.get("ODOO_API_KEY", ""),
```

And add a guard after the config construction:

```python
    if not config.username or not config.api_key:
        logger.warning(
            "ODOO_USER and ODOO_API_KEY not set; environment verification disabled."
        )
        return None
```

- [ ] **Step 3: Run existing tests**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/pipeline/python && uv run pytest tests/ -m "not docker and not e2e" --timeout=60 -q`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
cd /home/inshal-rauf/Factory-de-Odoo
git add pipeline/.mcp.json pipeline/python/src/odoo_gen_utils/verifier.py
git commit -m "fix(security): remove hardcoded admin credentials

Remove ODOO_USER/ODOO_API_KEY from .mcp.json (server reads env vars directly).
Remove default 'admin' fallback from verifier.py -- now requires explicit env vars."
```

---

## Chunk 2: P0 Bug + P1 Orchestrator Security (B1, S4, S5, S6, S8, S9)

### Task 4: Fix orchestrator security issues and duplicate function

**Files:**
- Modify: `orchestrator/odoo-gsd/bin/lib/core.cjs`
- Modify: `orchestrator/odoo-gsd/bin/lib/state.cjs`
- Modify: `orchestrator/odoo-gsd/bin/lib/init.cjs`
- Modify: `orchestrator/odoo-gsd/bin/lib/verify.cjs`
- Create: `orchestrator/tests/core-security.test.cjs`

- [ ] **Step 1: Write tests for `ensureWithinCwd` utility**

Create `orchestrator/tests/core-security.test.cjs`:

```javascript
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');

// Will import after implementing
let ensureWithinCwd;

describe('ensureWithinCwd', () => {
  const cwd = '/home/user/project';

  it('accepts relative paths within cwd', () => {
    const { ensureWithinCwd } = require('../odoo-gsd/bin/lib/core.cjs');
    const result = ensureWithinCwd(cwd, 'src/file.js');
    assert.equal(result, path.resolve(cwd, 'src/file.js'));
  });

  it('accepts cwd itself', () => {
    const { ensureWithinCwd } = require('../odoo-gsd/bin/lib/core.cjs');
    const result = ensureWithinCwd(cwd, '.');
    assert.equal(result, path.resolve(cwd));
  });

  it('rejects paths traversing above cwd', () => {
    const { ensureWithinCwd } = require('../odoo-gsd/bin/lib/core.cjs');
    assert.throws(() => ensureWithinCwd(cwd, '../../../etc/passwd'), /outside the project/);
  });

  it('rejects absolute paths outside cwd', () => {
    const { ensureWithinCwd } = require('../odoo-gsd/bin/lib/core.cjs');
    assert.throws(() => ensureWithinCwd(cwd, '/etc/passwd'), /outside the project/);
  });

  it('accepts absolute paths within cwd', () => {
    const { ensureWithinCwd } = require('../odoo-gsd/bin/lib/core.cjs');
    const result = ensureWithinCwd(cwd, '/home/user/project/src/file.js');
    assert.equal(result, '/home/user/project/src/file.js');
  });
});

describe('hasSourceFiles (replacement for execSync find)', () => {
  const fs = require('fs');
  const os = require('os');

  it('detects .js files', () => {
    const { hasSourceFiles } = require('../odoo-gsd/bin/lib/core.cjs');
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'test-'));
    fs.writeFileSync(path.join(tmpDir, 'index.js'), '// test');
    assert.equal(hasSourceFiles(tmpDir), true);
    fs.rmSync(tmpDir, { recursive: true });
  });

  it('returns false for empty directory', () => {
    const { hasSourceFiles } = require('../odoo-gsd/bin/lib/core.cjs');
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'test-'));
    assert.equal(hasSourceFiles(tmpDir), false);
    fs.rmSync(tmpDir, { recursive: true });
  });

  it('ignores node_modules', () => {
    const { hasSourceFiles } = require('../odoo-gsd/bin/lib/core.cjs');
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'test-'));
    const nmDir = path.join(tmpDir, 'node_modules');
    fs.mkdirSync(nmDir);
    fs.writeFileSync(path.join(nmDir, 'index.js'), '// test');
    assert.equal(hasSourceFiles(tmpDir), false);
    fs.rmSync(tmpDir, { recursive: true });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/orchestrator && node --test tests/core-security.test.cjs`
Expected: FAIL (functions don't exist yet)

- [ ] **Step 3: Add `ensureWithinCwd` and `hasSourceFiles` to core.cjs**

In `orchestrator/odoo-gsd/bin/lib/core.cjs`, add before `module.exports`:

```javascript
/**
 * Ensure a file path resolves within the given cwd directory.
 * Prevents path traversal attacks (CWE-22).
 * @param {string} cwd - The project root directory
 * @param {string} filePath - The file path to validate
 * @returns {string} The resolved absolute path
 * @throws {Error} If the path escapes cwd
 */
function ensureWithinCwd(cwd, filePath) {
  const resolved = path.isAbsolute(filePath) ? filePath : path.join(cwd, filePath);
  const normalizedCwd = path.resolve(cwd);
  const normalizedTarget = path.resolve(resolved);
  if (normalizedTarget !== normalizedCwd && !normalizedTarget.startsWith(normalizedCwd + path.sep)) {
    throw new Error(`Path "${filePath}" is outside the project directory`);
  }
  return normalizedTarget;
}

/**
 * Check if a directory contains source code files (replaces shell find pipeline).
 * Searches up to 3 levels deep, ignoring node_modules and .git.
 * @param {string} dir - Directory to search
 * @returns {boolean} True if source files found
 */
function hasSourceFiles(dir) {
  const extensions = new Set(['.ts', '.js', '.py', '.go', '.rs', '.swift', '.java']);
  const ignore = new Set(['node_modules', '.git', '.venv', '__pycache__']);

  function scan(currentDir, depth) {
    if (depth > 3) return false;
    try {
      const entries = fs.readdirSync(currentDir, { withFileTypes: true });
      for (const entry of entries) {
        if (ignore.has(entry.name)) continue;
        if (entry.isFile() && extensions.has(path.extname(entry.name))) return true;
        if (entry.isDirectory() && scan(path.join(currentDir, entry.name), depth + 1)) return true;
      }
    } catch {}
    return false;
  }

  return scan(dir, 0);
}
```

Add `ensureWithinCwd` and `hasSourceFiles` to the `module.exports` object.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/orchestrator && node --test tests/core-security.test.cjs`
Expected: PASS

- [ ] **Step 5: Fix `isGitIgnored` to use execGit**

In `core.cjs`, replace the `isGitIgnored` function (lines 134-147):

```javascript
function isGitIgnored(cwd, targetPath) {
  try {
    const result = execGit(cwd, ['check-ignore', '-q', '--no-index', '--', targetPath]);
    return result.exitCode === 0;
  } catch {
    return false;
  }
}
```

Note: `execGit` already exists in the same file and handles argument escaping properly.

- [ ] **Step 6: Replace shell `find` pipeline in init.cjs**

In `orchestrator/odoo-gsd/bin/lib/init.cjs`, replace lines 170-180:

From:
```javascript
  let hasCode = false;
  let hasPackageFile = false;
  try {
    const files = execSync('find . -maxdepth 3 \\( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.swift" -o -name "*.java" \\) 2>/dev/null | grep -v node_modules | grep -v .git | head -5', {
      cwd,
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    hasCode = files.trim().length > 0;
  } catch {}
```

To:
```javascript
  let hasCode = false;
  let hasPackageFile = false;
  hasCode = hasSourceFiles(cwd);
```

Add `hasSourceFiles` to the require at top of init.cjs:

```javascript
const { escapeRegex, loadConfig, getMilestoneInfo, getMilestonePhaseFilter, output, error, hasSourceFiles } = require('./core.cjs');
```

Also remove the `execSync` import if it's only used for this `find` call. Check if `execSync` is used elsewhere in init.cjs first.

- [ ] **Step 7: Remove duplicate `stateExtractField` from state.cjs**

In `orchestrator/odoo-gsd/bin/lib/state.cjs`, delete the duplicate function at lines 184-194 (the one with inline regex escaping). Keep only the first definition at lines 12-20 (which correctly uses `escapeRegex()` from core.cjs).

The second definition's companion `stateReplaceField` at line 196 also uses inline regex — update it to use `escapeRegex()`:

```javascript
function stateReplaceField(content, fieldName, newValue) {
  const escaped = escapeRegex(fieldName);
  const boldPattern = new RegExp(`(\\*\\*${escaped}:\\*\\*\\s*)(.*)`, 'i');
  if (boldPattern.test(content)) {
    return content.replace(boldPattern, (_match, prefix) => `${prefix}${newValue}`);
  }
  const plainPattern = new RegExp(`(^${escaped}:\\s*)(.*)`, 'im');
  if (plainPattern.test(content)) {
    return content.replace(plainPattern, (_match, prefix) => `${prefix}${newValue}`);
  }
  return null;
}
```

- [ ] **Step 8: Add regex validation in verify.cjs**

In `orchestrator/odoo-gsd/bin/lib/verify.cjs`, replace the regex construction at line 359:

From:
```javascript
const regex = new RegExp(link.pattern);
```

To:
```javascript
// Validate regex pattern length and test with timeout protection
if (link.pattern.length > 500) {
  check.detail = 'Pattern too long (max 500 chars)';
} else {
  const regex = new RegExp(link.pattern);
  // Limit input size to prevent ReDoS on large files
  const testContent = sourceContent.slice(0, 100000);
  if (regex.test(testContent)) {
```

- [ ] **Step 9: Fix temp file permissions in core.cjs output()**

In `core.cjs`, change the temp file write (line 43-44):

From:
```javascript
const tmpPath = path.join(require('os').tmpdir(), `odoo-gsd-${Date.now()}.json`);
fs.writeFileSync(tmpPath, json, 'utf-8');
```

To:
```javascript
const tmpPath = path.join(require('os').tmpdir(), `odoo-gsd-${Date.now()}-${process.pid}.json`);
fs.writeFileSync(tmpPath, json, { encoding: 'utf-8', mode: 0o600 });
```

- [ ] **Step 10: Run all orchestrator tests**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/orchestrator && npm test`
Expected: All tests PASS

- [ ] **Step 11: Commit**

```bash
cd /home/inshal-rauf/Factory-de-Odoo
git add orchestrator/odoo-gsd/bin/lib/core.cjs orchestrator/odoo-gsd/bin/lib/state.cjs orchestrator/odoo-gsd/bin/lib/init.cjs orchestrator/odoo-gsd/bin/lib/verify.cjs orchestrator/tests/core-security.test.cjs
git commit -m "fix(security): add path confinement, replace shell find, fix duplicate function

- Add ensureWithinCwd() utility to prevent path traversal (S4)
- Add hasSourceFiles() pure Node.js replacement for execSync find pipeline (S3)
- Fix isGitIgnored to use execGit instead of raw shell concatenation (S6)
- Remove duplicate stateExtractField, keep version using escapeRegex (B1)
- Add regex length limit in verify.cjs to prevent ReDoS (S9)
- Set 0o600 permissions on temp files (S11)"
```

---

## Chunk 3: P1 Pipeline Security (S7, S8) + XML Escaping

### Task 5: Fix pipeline input validation and XML escaping

**Files:**
- Modify: `pipeline/python/src/odoo_gen_utils/search/fork.py`
- Modify: `pipeline/python/src/odoo_gen_utils/renderer.py`
- Modify: `pipeline/python/tests/test_security_fixes.py`

- [ ] **Step 1: Write tests for fork input validation and XML escaping**

Add to `pipeline/python/tests/test_security_fixes.py`:

```python
class TestForkInputValidation:
    """S8: repo_name, branch, module_name must match safe patterns."""

    def test_safe_repo_name_accepted(self):
        from odoo_gen_utils.search.fork import _validate_clone_inputs

        _validate_clone_inputs("sale-workflow", "sale_order_type", "17.0")  # no error

    def test_traversal_repo_name_rejected(self):
        from odoo_gen_utils.search.fork import _validate_clone_inputs

        with pytest.raises(ValueError, match="repo_name"):
            _validate_clone_inputs("../../evil-repo", "module", "17.0")

    def test_unsafe_branch_rejected(self):
        from odoo_gen_utils.search.fork import _validate_clone_inputs

        with pytest.raises(ValueError, match="branch"):
            _validate_clone_inputs("sale-workflow", "module", "--upload-pack=evil")

    def test_unsafe_module_rejected(self):
        from odoo_gen_utils.search.fork import _validate_clone_inputs

        with pytest.raises(ValueError, match="module_name"):
            _validate_clone_inputs("sale-workflow", "../etc/passwd", "17.0")


class TestXmlEscaping:
    """S7: XML special characters must be escaped in generated data files."""

    def test_name_with_ampersand_escaped(self):
        from odoo_gen_utils.renderer import _render_document_type_xml

        result = _render_document_type_xml(
            [{"name": "R&D Report", "code": "rd_report"}],
            "test_module",
        )
        assert "&amp;" in result
        assert "R&D" not in result  # raw & must not appear

    def test_name_with_angle_brackets_escaped(self):
        from odoo_gen_utils.renderer import _render_document_type_xml

        result = _render_document_type_xml(
            [{"name": "Form <draft>", "code": "form_draft"}],
            "test_module",
        )
        assert "&lt;" in result
        assert "&gt;" in result
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/pipeline/python && uv run pytest tests/test_security_fixes.py::TestForkInputValidation tests/test_security_fixes.py::TestXmlEscaping -v`
Expected: FAIL

- [ ] **Step 3: Add input validation to fork.py**

In `pipeline/python/src/odoo_gen_utils/search/fork.py`, add after imports:

```python
import re

_SAFE_REPO_NAME = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._-]*$")
_SAFE_BRANCH = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9./_-]*$")
_SAFE_MODULE_NAME = re.compile(r"^[a-zA-Z][a-zA-Z0-9_]*$")


def _validate_clone_inputs(repo_name: str, module_name: str, branch: str) -> None:
    """Validate inputs for clone_oca_module to prevent path traversal."""
    if not _SAFE_REPO_NAME.match(repo_name):
        raise ValueError(f"Unsafe repo_name: {repo_name!r}")
    if not _SAFE_MODULE_NAME.match(module_name):
        raise ValueError(f"Unsafe module_name: {module_name!r}")
    if not _SAFE_BRANCH.match(branch):
        raise ValueError(f"Unsafe branch: {branch!r}")
```

Then at the top of `clone_oca_module`, add:

```python
    _validate_clone_inputs(repo_name, module_name, branch)
```

- [ ] **Step 4: Add XML escaping to renderer.py**

In `pipeline/python/src/odoo_gen_utils/renderer.py`, add import at top:

```python
from markupsafe import escape as xml_escape
```

Then in `_render_document_type_xml`, replace the unescaped interpolations:

```python
    for dt in doc_types:
        code = xml_escape(dt.get("code", ""))
        xml_id = f"{module_name}.document_type_{code}"
        lines.append(f'        <record id="{xml_id}" model="document.type">')
        lines.append(f'            <field name="name">{xml_escape(dt.get("name", ""))}</field>')
        lines.append(f'            <field name="code">{code}</field>')
        if "required_for" in dt:
            lines.append(f'            <field name="required_for">{xml_escape(str(dt["required_for"]))}</field>')
        if "max_file_size" in dt:
            lines.append(f'            <field name="max_file_size" eval="{xml_escape(str(dt["max_file_size"]))}"/>')
        if "allowed_mime_types" in dt:
            lines.append(f'            <field name="allowed_mime_types">{xml_escape(str(dt["allowed_mime_types"]))}</field>')
```

- [ ] **Step 5: Fix missing encoding in renderer.py:837**

In `renderer.py`, change line 837:

From: `init_path.write_text(init_content)`
To: `init_path.write_text(init_content, encoding="utf-8")`

- [ ] **Step 6: Run tests**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/pipeline/python && uv run pytest tests/test_security_fixes.py -v && uv run pytest tests/ -m "not docker and not e2e" --timeout=60 -q`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
cd /home/inshal-rauf/Factory-de-Odoo
git add pipeline/python/src/odoo_gen_utils/search/fork.py pipeline/python/src/odoo_gen_utils/renderer.py pipeline/python/tests/test_security_fixes.py
git commit -m "fix(security): add fork input validation, XML escaping, fix encoding

- Add regex whitelist for repo_name/branch/module_name in clone_oca_module (S8)
- Use markupsafe.escape() in _render_document_type_xml to prevent XML injection (S7)
- Add missing encoding='utf-8' on write_text call (M4)"
```

---

## Chunk 4: P1 Tech Debt + P2 Orchestrator Quality (D4, D5, Q6, Q7)

### Task 6: Fix orchestrator tech debt and code quality

**Files:**
- Modify: `orchestrator/package.json`
- Modify: `orchestrator/odoo-gsd/bin/lib/frontmatter.cjs`
- Modify: `orchestrator/odoo-gsd/bin/lib/config.cjs`

- [ ] **Step 1: Fix coverage threshold from 70% to 80%**

In `orchestrator/package.json`, change line 46:

From: `"test:coverage": "c8 --check-coverage --lines 70 ...`
To: `"test:coverage": "c8 --check-coverage --lines 80 ...`

- [ ] **Step 2: Fix Object.assign mutation in frontmatter.cjs**

In `orchestrator/odoo-gsd/bin/lib/frontmatter.cjs`, replace line 270:

From:
```javascript
  Object.assign(fm, mergeData);
  const newContent = spliceFrontmatter(content, fm);
```

To:
```javascript
  const mergedFm = { ...fm, ...mergeData };
  const newContent = spliceFrontmatter(content, mergedFm);
```

- [ ] **Step 3: Fix nested mutation in config.cjs**

In `orchestrator/odoo-gsd/bin/lib/config.cjs`, replace the mutation loop (lines 184-193):

From:
```javascript
  const keys = keyPath.split('.');
  let current = config;
  for (let i = 0; i < keys.length - 1; i++) {
    const key = keys[i];
    if (current[key] === undefined || typeof current[key] !== 'object') {
      current[key] = {};
    }
    current = current[key];
  }
  current[keys[keys.length - 1]] = parsedValue;
```

To:
```javascript
  const keys = keyPath.split('.');
  // Immutable deep set: build new object tree
  function deepSet(obj, keyArr, value) {
    if (keyArr.length === 1) {
      return { ...obj, [keyArr[0]]: value };
    }
    const [head, ...rest] = keyArr;
    const child = (obj[head] !== undefined && typeof obj[head] === 'object') ? obj[head] : {};
    return { ...obj, [head]: deepSet(child, rest, value) };
  }
  config = deepSet(config, keys, parsedValue);
```

- [ ] **Step 4: Run all orchestrator tests**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/orchestrator && npm test`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd /home/inshal-rauf/Factory-de-Odoo
git add orchestrator/package.json orchestrator/odoo-gsd/bin/lib/frontmatter.cjs orchestrator/odoo-gsd/bin/lib/config.cjs
git commit -m "fix: enforce 80% coverage, fix mutation patterns in frontmatter and config

- Change c8 --lines from 70 to 80 to match project requirement (D4)
- Replace Object.assign mutation with spread in frontmatter merge (D5)
- Replace in-place nested traversal with immutable deepSet in config (D5)"
```

---

## Chunk 5: P2 Pipeline Quality (Q1, Q2, Q3) + Template Fixes (S12, S14)

### Task 7: Fix pipeline code quality and template security

**Files:**
- Modify: `pipeline/python/src/odoo_gen_utils/cli.py`
- Modify: `pipeline/python/src/odoo_gen_utils/spec_schema.py`
- Modify: `pipeline/python/src/odoo_gen_utils/validation/docker_runner.py`
- Modify: `pipeline/python/src/odoo_gen_utils/templates/shared/controller.py.j2`
- Modify: `pipeline/python/src/odoo_gen_utils/templates/shared/portal_controller.py.j2`

- [ ] **Step 1: Replace bare `except Exception: pass` with logging in cli.py**

In `pipeline/python/src/odoo_gen_utils/cli.py`, replace lines 617-620:

From:
```python
                except Exception:
                    pass  # Mermaid generation is best-effort
        except Exception:
            pass  # Registry update is best-effort, don't fail render
```

To:
```python
                except Exception:
                    _logger.debug("Mermaid diagram generation failed", exc_info=True)
        except Exception:
            _logger.debug("Registry update failed (non-blocking)", exc_info=True)
```

Ensure `_logger` is defined at the top of the file:
```python
import logging
_logger = logging.getLogger(__name__)
```

- [ ] **Step 2: Replace print() with logger in spec_schema.py**

In `pipeline/python/src/odoo_gen_utils/spec_schema.py`, replace line 600:

From:
```python
        print(formatted)
        raise
```

To:
```python
        logger.error(formatted)
        raise
```

Ensure logger is defined at top of module:
```python
import logging
logger = logging.getLogger(__name__)
```

- [ ] **Step 3: Remove redundant print() from docker_runner.py**

In `pipeline/python/src/odoo_gen_utils/validation/docker_runner.py`, remove lines 153-156 (the `print(...)` call) since `logger.error` on lines 149-152 already logs the same message. The function already has `logger` defined.

- [ ] **Step 4: Fix error message leakage in controller.py.j2**

In `pipeline/python/src/odoo_gen_utils/templates/shared/controller.py.j2`, replace lines 22-23:

From:
```jinja2
        except Exception as e:
            return {'status': 'error', 'message': str(e)}
```

To:
```jinja2
        except Exception:
            _logger.exception("Controller error in %s", request.httprequest.path)
            return {'status': 'error', 'message': 'An internal error occurred.'}
```

Also add the logger import at the top of the template:

```jinja2
{# controller.py.j2 -- HTTP controller with @http.route decorators #}
import logging

from odoo import http
from odoo.http import request

_logger = logging.getLogger(__name__)
```

- [ ] **Step 5: Add validation comment to portal_controller.py.j2**

In `pipeline/python/src/odoo_gen_utils/templates/shared/portal_controller.py.j2`, replace the `sudo().write()` line:

From:
```jinja2
            # --- BUSINESS LOGIC START ---
            # TODO: validate and write editable fields
            # --- BUSINESS LOGIC END ---
            {{ page.singular_name }}.sudo().write(vals)
```

To:
```jinja2
            # --- BUSINESS LOGIC START ---
            # SECURITY: Validate field values before writing.
            # .sudo() bypasses access rules -- ensure the portal user
            # is authorized to modify this specific record.
            # TODO: Add type coercion and domain-specific validation for each field.
            # --- BUSINESS LOGIC END ---
            {{ page.singular_name }}.sudo().write(vals)
```

- [ ] **Step 6: Run pipeline tests**

Run: `cd /home/inshal-rauf/Factory-de-Odoo/pipeline/python && uv run pytest tests/ -m "not docker and not e2e" --timeout=60 -q`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
cd /home/inshal-rauf/Factory-de-Odoo
git add pipeline/python/src/odoo_gen_utils/cli.py pipeline/python/src/odoo_gen_utils/spec_schema.py pipeline/python/src/odoo_gen_utils/validation/docker_runner.py pipeline/python/src/odoo_gen_utils/templates/shared/controller.py.j2 pipeline/python/src/odoo_gen_utils/templates/shared/portal_controller.py.j2
git commit -m "fix: replace bare exceptions with logging, fix template security

- Replace except Exception: pass with debug logging in cli.py (Q2)
- Replace print() with logger in spec_schema.py and docker_runner.py (Q1)
- Fix error message leakage in generated JSON controllers (S12)
- Add security comment for portal .sudo().write() (S13)"
```

---

## Execution Notes

**Total tasks:** 7
**Total commits:** 7
**Estimated independent groups for parallel execution:**
- Group A (Pipeline security): Tasks 1, 2, 3 (can run in parallel — different files)
- Group B (Orchestrator): Task 4 (depends on nothing)
- Group C (Pipeline validation): Task 5 (depends on Task 1 for shared test file)
- Group D (Orchestrator quality): Task 6 (independent)
- Group E (Pipeline quality): Task 7 (independent)

**Out of scope for this plan (requires structural refactoring):**
- D1: Splitting `bin/install.js` (2,464 lines) into modules
- D2: Addressing 67 empty catch blocks individually
- D3: Splitting 9 oversized files
- L1-L7: Function size, nesting depth, duplicate logic
- S10: Docker dev instance default credentials (operational, not code)
- Q4-Q5: Global mutable caches, private attribute access (architectural changes)
