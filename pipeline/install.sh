#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# odoo-gen Pipeline Installer
# Sets up the odoo-gen pipeline (Python venv, commands, agents, knowledge).
#
# Usage (Linux / macOS / WSL2 on Windows):
#   git clone <repo> ~/.claude/odoo-gen
#   cd ~/.claude/odoo-gen
#   bash install.sh
#
# Windows native users: use install.ps1 instead.
# ==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Detect if running inside WSL2 on Windows
IS_WSL=false
if grep -qEi '(Microsoft|WSL)' /proc/version 2>/dev/null; then
    IS_WSL=true
fi

# Determine script directory (the cloned repo root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ODOO_GEN_DIR="$SCRIPT_DIR"
VERSION=$(cat "$ODOO_GEN_DIR/VERSION" 2>/dev/null || echo "unknown")

# Helpers
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

if [ "$IS_WSL" = true ]; then
    info "Detected WSL2 environment on Windows. Proceeding with bash installer."
fi

# ==============================================================================
# Step 1: Check Prerequisites
# ==============================================================================

info "Checking prerequisites..."

# Check uv is installed
if ! command -v uv &>/dev/null; then
    error "uv (Python package manager) not found."
    error ""
    if [ "$IS_WSL" = true ]; then
        error "Install uv inside WSL2:"
        error "  curl -LsSf https://astral.sh/uv/install.sh | sh"
        error "  source ~/.bashrc  # reload PATH"
    else
        error "Install uv:"
        error "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi
    error ""
    error "More info: https://docs.astral.sh/uv/#getting-started"
    exit 1
fi
success "uv found: $(uv --version)"

# Check Python 3.12 (Odoo 18 supports 3.10-3.12)
if ! uv python find 3.12 &>/dev/null; then
    error "Python 3.12 not found."
    error "Odoo 18.0 requires Python 3.10-3.12 (3.13+ not supported)."
    error ""
    error "Install Python 3.12:"
    error "  uv python install 3.12"
    exit 1
fi
success "Python 3.12 found: $(uv python find 3.12)"

# Check Docker (optional but warn if missing)
if ! command -v docker &>/dev/null; then
    if [ "$IS_WSL" = true ]; then
        warn "Docker not found in WSL2. Ensure Docker Desktop is running on Windows"
        warn "and 'Enable WSL2 integration' is enabled in Docker Desktop settings."
    else
        warn "Docker not found. Module validation via Docker will be unavailable."
    fi
else
    success "Docker found: $(docker --version)"
fi

# ==============================================================================
# Step 2: Create Python Virtual Environment
# ==============================================================================

info "Creating Python virtual environment..."

if [ -d "$ODOO_GEN_DIR/.venv" ]; then
    warn "Existing venv found at $ODOO_GEN_DIR/.venv/ -- recreating..."
    rm -rf "$ODOO_GEN_DIR/.venv"
fi

uv venv "$ODOO_GEN_DIR/.venv" --python 3.12
success "Python venv created at $ODOO_GEN_DIR/.venv/"

# ==============================================================================
# Step 3: Install Python Package
# ==============================================================================

info "Installing odoo-gen-utils Python package..."

if [ ! -d "$ODOO_GEN_DIR/python" ]; then
    error "Python package directory not found at $ODOO_GEN_DIR/python/"
    error "The repository may be incomplete. Try re-cloning."
    exit 1
fi

VIRTUAL_ENV="$ODOO_GEN_DIR/.venv" uv pip install -e "$ODOO_GEN_DIR/python/"
success "odoo-gen-utils package installed"

# ==============================================================================
# Step 4: Create Wrapper Script
# ==============================================================================

info "Creating wrapper script..."

mkdir -p "$ODOO_GEN_DIR/bin"
cat > "$ODOO_GEN_DIR/bin/odoo-gen-utils" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# Thin wrapper that runs odoo-gen-utils from the extension's venv.
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$SCRIPT_DIR/.venv/bin/odoo-gen-utils" "$@"
WRAPPER_EOF
chmod +x "$ODOO_GEN_DIR/bin/odoo-gen-utils"
success "Wrapper script created at $ODOO_GEN_DIR/bin/odoo-gen-utils"

# ==============================================================================
# Step 5: Register Commands
# ==============================================================================

info "Registering odoo-gen commands..."

COMMANDS_TARGET="$HOME/.claude/commands/odoo-gen"
mkdir -p "$COMMANDS_TARGET"

if [ -d "$ODOO_GEN_DIR/commands" ] && ls "$ODOO_GEN_DIR/commands/"*.md &>/dev/null; then
    cp "$ODOO_GEN_DIR/commands/"*.md "$COMMANDS_TARGET/"
    COMMAND_COUNT=$(ls "$COMMANDS_TARGET/"*.md 2>/dev/null | wc -l)
    success "Registered $COMMAND_COUNT command(s) to $COMMANDS_TARGET/"
else
    warn "No command .md files found in $ODOO_GEN_DIR/commands/ -- skipping"
fi

# ==============================================================================
# Step 6: Symlink Agent Files
# ==============================================================================

info "Symlinking agent files..."

AGENTS_TARGET="$HOME/.claude/agents"
mkdir -p "$AGENTS_TARGET"

AGENT_COUNT=0
if [ -d "$ODOO_GEN_DIR/agents" ] && ls "$ODOO_GEN_DIR/agents/"*.md &>/dev/null; then
    for f in "$ODOO_GEN_DIR/agents/"*.md; do
        ln -sf "$f" "$AGENTS_TARGET/$(basename "$f")"
        AGENT_COUNT=$((AGENT_COUNT + 1))
    done
    success "Symlinked $AGENT_COUNT agent(s) to $AGENTS_TARGET/"
else
    warn "No agent .md files found -- skipping"
fi

# ==============================================================================
# Step 7: Install Knowledge Base
# ==============================================================================

info "Installing knowledge base..."

KB_SOURCE="$ODOO_GEN_DIR/knowledge"
KB_TARGET="$HOME/.claude/odoo-gen/knowledge"

if [ -d "$KB_SOURCE" ]; then
    if [ -L "$KB_TARGET" ] || [ -d "$KB_TARGET" ]; then
        rm -rf "$KB_TARGET"
    fi
    mkdir -p "$(dirname "$KB_TARGET")"
    ln -sf "$KB_SOURCE" "$KB_TARGET"
    mkdir -p "$KB_SOURCE/custom"
    KB_FILE_COUNT=$(ls "$KB_SOURCE/"*.md 2>/dev/null | wc -l)
    success "Knowledge base installed: $KB_TARGET/ ($KB_FILE_COUNT shipped files)"
else
    warn "No knowledge/ directory found -- skipping"
fi

# ==============================================================================
# Step 8: Write Manifest for Tracking
# ==============================================================================

info "Writing installation manifest..."

MANIFEST_FILE="$HOME/.claude/odoo-gen-manifest.json"

MANIFEST_COMMANDS="[]"
if [ -d "$COMMANDS_TARGET" ] && ls "$COMMANDS_TARGET/"*.md &>/dev/null; then
    MANIFEST_COMMANDS=$(printf '%s\n' "$COMMANDS_TARGET/"*.md | python3 -c "
import sys, json
files = [line.strip() for line in sys.stdin if line.strip()]
print(json.dumps(files))
")
fi

MANIFEST_AGENTS="[]"
if [ "$AGENT_COUNT" -gt 0 ]; then
    MANIFEST_AGENTS=$(for f in "$ODOO_GEN_DIR/agents/"*.md; do
        echo "$AGENTS_TARGET/$(basename "$f")"
    done | python3 -c "
import sys, json
files = [line.strip() for line in sys.stdin if line.strip()]
print(json.dumps(files))
")
fi

cat > "$MANIFEST_FILE" << MANIFEST_EOF
{
  "extension": "odoo-gen",
  "version": "$VERSION",
  "odoo_version": "18.0",
  "edition": "enterprise",
  "platform": "$(uname -s)$([ "$IS_WSL" = true ] && echo '-WSL2' || true)",
  "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source_dir": "$ODOO_GEN_DIR",
  "venv_dir": "$ODOO_GEN_DIR/.venv",
  "wrapper_script": "$ODOO_GEN_DIR/bin/odoo-gen-utils",
  "commands_dir": "$COMMANDS_TARGET",
  "commands": $MANIFEST_COMMANDS,
  "agents": $MANIFEST_AGENTS,
  "manifest_version": 1
}
MANIFEST_EOF

success "Manifest written to $MANIFEST_FILE"

# ==============================================================================
# Step 9: Verify Installation
# ==============================================================================

info "Verifying installation..."

if "$ODOO_GEN_DIR/bin/odoo-gen-utils" --version &>/dev/null; then
    INSTALLED_VERSION=$("$ODOO_GEN_DIR/bin/odoo-gen-utils" --version 2>&1)
    success "odoo-gen-utils verified: $INSTALLED_VERSION"
else
    error "odoo-gen-utils verification failed!"
    error "Try running manually: $ODOO_GEN_DIR/.venv/bin/odoo-gen-utils --version"
    exit 1
fi

# ==============================================================================
# Step 10: Success Summary
# ==============================================================================

echo ""
echo -e "${GREEN}${BOLD}============================================${NC}"
echo -e "${GREEN}${BOLD}  odoo-gen v${VERSION} installed successfully!${NC}"
echo -e "${GREEN}${BOLD}  Target: Odoo 18.0 Enterprise${NC}"
if [ "$IS_WSL" = true ]; then
echo -e "${GREEN}${BOLD}  Platform: Windows (WSL2)${NC}"
fi
echo -e "${GREEN}${BOLD}============================================${NC}"
echo ""
echo -e "  ${BOLD}Extension:${NC}  $ODOO_GEN_DIR"
echo -e "  ${BOLD}Venv:${NC}       $ODOO_GEN_DIR/.venv"
echo -e "  ${BOLD}Wrapper:${NC}    $ODOO_GEN_DIR/bin/odoo-gen-utils"
echo -e "  ${BOLD}Manifest:${NC}   $MANIFEST_FILE"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    1. Set your enterprise addons path:"
echo -e "       export ODOO_ENTERPRISE_PATH=/path/to/odoo/enterprise"
echo -e "    2. Open Claude Code and run:"
echo -e "       ${BOLD}/odoo-gen:new \"your module description\"${NC}"
echo ""
if [ "$IS_WSL" = true ]; then
echo -e "  ${YELLOW}${BOLD}WSL2 Tips:${NC}"
echo -e "    - Ensure Docker Desktop is running on Windows"
echo -e "    - Enable WSL2 integration in Docker Desktop settings"
echo -e "    - Your Windows addons path is accessible at /mnt/c/..."
echo ""
fi
