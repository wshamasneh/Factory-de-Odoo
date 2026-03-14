#Requires -Version 5.1
<#
.SYNOPSIS
    odoo-gen Pipeline Installer for Windows (native PowerShell)
    Installs the Factory de Odoo pipeline for Odoo 18 Enterprise on Windows.

.DESCRIPTION
    This script is the Windows-native alternative to install.sh.
    It sets up the Python venv, installs odoo-gen-utils, registers commands,
    copies agents, and writes the installation manifest.

    Prerequisites:
        - Python 3.12 (https://www.python.org/downloads/)
        - uv  (winget install astral-sh.uv  OR  pip install uv)
        - Node.js 20+ (https://nodejs.org/)
        - Docker Desktop with WSL2 backend (https://www.docker.com/products/docker-desktop/)

.EXAMPLE
    # Run from the pipeline directory:
    cd C:\odoo\Factory-de-Odoo\pipeline
    .\install.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Info   { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok     { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn   { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err    { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$OdooGenDir   = $ScriptDir
$VersionFile  = Join-Path $OdooGenDir 'VERSION'
$Version      = if (Test-Path $VersionFile) { (Get-Content $VersionFile).Trim() } else { 'unknown' }

$ClaudeDir       = Join-Path $env:USERPROFILE '.claude'
$CommandsTarget  = Join-Path $ClaudeDir 'commands\odoo-gen'
$AgentsTarget    = Join-Path $ClaudeDir 'agents'
$KbTarget        = Join-Path $ClaudeDir 'odoo-gen\knowledge'
$ManifestFile    = Join-Path $ClaudeDir 'odoo-gen-manifest.json'
$VenvDir         = Join-Path $OdooGenDir '.venv'
$BinDir          = Join-Path $OdooGenDir 'bin'

Write-Host ''
Write-Host '============================================' -ForegroundColor Cyan
Write-Host '  Factory de Odoo - Windows Installer' -ForegroundColor Cyan
Write-Host "  Target: Odoo 18.0 Enterprise" -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan
Write-Host ''

# ---------------------------------------------------------------------------
# Step 1: Check Prerequisites
# ---------------------------------------------------------------------------
Write-Info 'Checking prerequisites...'

# uv
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Err 'uv not found. Install it with:'
    Write-Err '  winget install astral-sh.uv'
    Write-Err '  -- OR --'
    Write-Err '  pip install uv'
    Write-Err 'Then restart PowerShell and re-run this script.'
    exit 1
}
Write-Ok "uv found: $(uv --version)"

# Python 3.12
try {
    $py312 = (uv python find 3.12 2>&1)
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Err 'Python 3.12 not found. Install it with:'
    Write-Err '  uv python install 3.12'
    exit 1
}
Write-Ok "Python 3.12 found: $py312"

# Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Warn 'Docker not found. Module validation will be unavailable.'
    Write-Warn 'Install Docker Desktop: https://www.docker.com/products/docker-desktop/'
} else {
    Write-Ok "Docker found: $(docker --version)"
}

# Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Warn 'Node.js not found. Orchestrator will be unavailable.'
    Write-Warn 'Install Node.js 20+: https://nodejs.org/'
} else {
    Write-Ok "Node.js found: $(node --version)"
}

# ---------------------------------------------------------------------------
# Step 2: Create Python Virtual Environment
# ---------------------------------------------------------------------------
Write-Info 'Creating Python virtual environment...'

if (Test-Path $VenvDir) {
    Write-Warn "Existing venv found at $VenvDir -- recreating..."
    Remove-Item -Recurse -Force $VenvDir
}

uv venv $VenvDir --python 3.12
if ($LASTEXITCODE -ne 0) { Write-Err 'Failed to create venv'; exit 1 }
Write-Ok "Python venv created at $VenvDir"

# ---------------------------------------------------------------------------
# Step 3: Install Python Package
# ---------------------------------------------------------------------------
Write-Info 'Installing odoo-gen-utils Python package...'

$PythonDir = Join-Path $OdooGenDir 'python'
if (-not (Test-Path $PythonDir)) {
    Write-Err "Python package directory not found at $PythonDir"
    Write-Err 'The repository may be incomplete. Try re-cloning.'
    exit 1
}

$env:VIRTUAL_ENV = $VenvDir
uv pip install -e $PythonDir
if ($LASTEXITCODE -ne 0) { Write-Err 'Failed to install odoo-gen-utils'; exit 1 }
Write-Ok 'odoo-gen-utils package installed'

# ---------------------------------------------------------------------------
# Step 4: Create Wrapper Script (.cmd for Windows)
# ---------------------------------------------------------------------------
Write-Info 'Creating wrapper script...'

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$WrapperCmd = Join-Path $BinDir 'odoo-gen-utils.cmd'
@"
@echo off
"%~dp0..\.venv\Scripts\odoo-gen-utils.exe" %*
"@ | Set-Content -Path $WrapperCmd -Encoding ASCII
Write-Ok "Wrapper script created at $WrapperCmd"

# ---------------------------------------------------------------------------
# Step 5: Register Commands
# ---------------------------------------------------------------------------
Write-Info 'Registering odoo-gen commands...'

New-Item -ItemType Directory -Force -Path $CommandsTarget | Out-Null
$CommandsSource = Join-Path $OdooGenDir 'commands'
$CommandCount = 0
if (Test-Path $CommandsSource) {
    $mdFiles = Get-ChildItem -Path $CommandsSource -Filter '*.md'
    foreach ($f in $mdFiles) {
        Copy-Item $f.FullName -Destination $CommandsTarget -Force
        $CommandCount++
    }
    Write-Ok "Registered $CommandCount command(s) to $CommandsTarget"
} else {
    Write-Warn 'No commands directory found -- skipping'
}

# ---------------------------------------------------------------------------
# Step 6: Copy Agent Files (Windows: copy instead of symlink)
# ---------------------------------------------------------------------------
Write-Info 'Copying agent files...'

New-Item -ItemType Directory -Force -Path $AgentsTarget | Out-Null
$AgentsSource = Join-Path $OdooGenDir 'agents'
$AgentCount = 0
if (Test-Path $AgentsSource) {
    $agentFiles = Get-ChildItem -Path $AgentsSource -Filter '*.md'
    foreach ($f in $agentFiles) {
        Copy-Item $f.FullName -Destination $AgentsTarget -Force
        $AgentCount++
    }
    Write-Ok "Copied $AgentCount agent(s) to $AgentsTarget"
} else {
    Write-Warn 'No agents directory found -- skipping'
}

# ---------------------------------------------------------------------------
# Step 7: Install Knowledge Base
# ---------------------------------------------------------------------------
Write-Info 'Installing knowledge base...'

$KbSource = Join-Path $OdooGenDir 'knowledge'
if (Test-Path $KbSource) {
    New-Item -ItemType Directory -Force -Path (Split-Path $KbTarget) | Out-Null
    if (Test-Path $KbTarget) { Remove-Item -Recurse -Force $KbTarget }
    # Copy (Windows: no symlinks without admin)
    Copy-Item -Recurse $KbSource $KbTarget
    New-Item -ItemType Directory -Force -Path (Join-Path $KbTarget 'custom') | Out-Null
    $KbCount = (Get-ChildItem -Path $KbTarget -Filter '*.md').Count
    Write-Ok "Knowledge base installed: $KbTarget ($KbCount files)"
} else {
    Write-Warn 'No knowledge directory found -- skipping'
}

# ---------------------------------------------------------------------------
# Step 8: Write Manifest
# ---------------------------------------------------------------------------
Write-Info 'Writing installation manifest...'

$manifest = @{
    extension       = 'odoo-gen'
    version         = $Version
    odoo_version    = '18.0'
    edition         = 'enterprise'
    platform        = 'Windows'
    installed_at    = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    source_dir      = $OdooGenDir
    venv_dir        = $VenvDir
    wrapper_script  = $WrapperCmd
    commands_dir    = $CommandsTarget
    manifest_version = 1
}
New-Item -ItemType Directory -Force -Path (Split-Path $ManifestFile) | Out-Null
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestFile -Encoding UTF8
Write-Ok "Manifest written to $ManifestFile"

# ---------------------------------------------------------------------------
# Step 9: Verify Installation
# ---------------------------------------------------------------------------
Write-Info 'Verifying installation...'

$VenvExe = Join-Path $VenvDir 'Scripts\odoo-gen-utils.exe'
if (Test-Path $VenvExe) {
    Write-Ok "odoo-gen-utils verified at $VenvExe"
} else {
    Write-Warn 'odoo-gen-utils.exe not found in venv Scripts. Verify manually.'
}

# ---------------------------------------------------------------------------
# Step 10: Success Summary
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '============================================' -ForegroundColor Green
Write-Host "  odoo-gen v$Version installed successfully!" -ForegroundColor Green
Write-Host '  Target: Odoo 18.0 Enterprise on Windows'    -ForegroundColor Green
Write-Host '============================================' -ForegroundColor Green
Write-Host ''
Write-Host '  Next steps:' -ForegroundColor White
Write-Host '    1. Set your enterprise addons path environment variable:'
Write-Host '       $env:ODOO_ENTERPRISE_PATH = "C:\odoo\enterprise"'
Write-Host '    2. (Optional) Set your enterprise license key:'
Write-Host '       $env:ODOO_ENTERPRISE_CODE = "your-license-key"'
Write-Host '    3. Open Claude Code and run:'
Write-Host '       /odoo-gen:new "your module description"'
Write-Host ''
Write-Host '  Windows Tips:' -ForegroundColor Yellow
Write-Host '    - Docker Desktop must be running before module validation'
Write-Host '    - Use forward slashes in MODULE_PATH: C:/odoo/addons/mymodule'
Write-Host '    - To start dev instance: .\scripts\odoo-dev.ps1 start'
Write-Host ''
