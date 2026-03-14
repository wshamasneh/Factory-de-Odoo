#Requires -Version 5.1
<#
.SYNOPSIS
    Lifecycle manager for Odoo 18 EE dev instance on Windows.
    Windows PowerShell equivalent of odoo-dev.sh.

.DESCRIPTION
    Manages a Docker Compose-based Odoo 18 + PostgreSQL 16 dev instance
    for local module testing on Windows.

    Prerequisites: Docker Desktop running with WSL2 backend.

.PARAMETER Command
    start  - Start the dev instance (init DB on first run)
    stop   - Stop the dev instance (data preserved)
    status - Show container status + XML-RPC connectivity check
    reset  - DESTROY all data and reset (irreversible)
    logs   - Tail Odoo container logs

.EXAMPLE
    .\scripts\odoo-dev.ps1 start
    .\scripts\odoo-dev.ps1 status
    .\scripts\odoo-dev.ps1 stop
    .\scripts\odoo-dev.ps1 reset
    .\scripts\odoo-dev.ps1 logs
#>

Param(
    [Parameter(Position=0)]
    [ValidateSet('start','stop','status','reset','logs','help')]
    [string]$Command = 'help'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent $ScriptDir
$ComposeFile = Join-Path $ProjectRoot 'docker\dev\docker-compose.yml'
$DbName      = if ($env:ODOO_DEV_DB) { $env:ODOO_DEV_DB } else { 'odoo_dev' }
$DevPort     = if ($env:ODOO_DEV_PORT) { $env:ODOO_DEV_PORT } else { '8069' }
$Modules     = 'base,mail,sale,purchase,hr,account'

# Enterprise addons path (set via env var)
$EnterprisePath = if ($env:ODOO_ENTERPRISE_PATH) { $env:ODOO_ENTERPRISE_PATH } else { $null }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Info { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Invoke-Compose {
    param([string[]]$Args)
    # Convert Windows paths to forward-slash for Docker Compose
    $env:MODULE_PATH = ($env:MODULE_PATH -replace '\\','/')
    if ($EnterprisePath) {
        $env:ODOO_ENTERPRISE_PATH = ($EnterprisePath -replace '\\','/')
    }
    docker compose -f $ComposeFile @Args
}

function Test-DbExists {
    $result = docker compose -f $ComposeFile exec -T db `
        psql -U odoo -tAc "SELECT 1 FROM pg_database WHERE datname='$DbName'" 2>$null
    return ($result -match '1')
}

function Initialize-Modules {
    Write-Info "Initializing database '$DbName' with modules: $Modules"
    Write-Info 'This may take a few minutes on first run...'
    Invoke-Compose @('run','--rm','-T','odoo','odoo',
        '-d',$DbName,
        '-i',$Modules,
        '--stop-after-init',
        '--no-http',
        '--log-level=warn')
    Write-Ok 'Module initialization complete.'
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
function Start-DevInstance {
    Write-Info 'Starting Odoo 18 EE dev instance...'
    if ($EnterprisePath) {
        Write-Info "Enterprise addons path: $EnterprisePath"
    } else {
        Write-Warn 'ODOO_ENTERPRISE_PATH not set. Enterprise modules will not be available.'
        Write-Warn 'Set it with: $env:ODOO_ENTERPRISE_PATH = "C:\odoo\enterprise"'
    }
    Invoke-Compose @('up','-d','--wait','db')
    if (-not (Test-DbExists)) {
        Initialize-Modules
    }
    Invoke-Compose @('up','-d','--wait')
    Write-Ok "Odoo 18 EE dev instance ready at http://localhost:$DevPort"
    Write-Ok 'Credentials: admin / admin'
}

function Stop-DevInstance {
    Write-Info 'Stopping Odoo dev instance...'
    Invoke-Compose @('down')
    Write-Ok 'Odoo dev instance stopped. Data preserved.'
}

function Get-DevStatus {
    Write-Info 'Container status:'
    Invoke-Compose @('ps')
    Write-Host ''
    Write-Info 'XML-RPC connectivity check:'
    $VerifyScript = Join-Path $ScriptDir 'verify-odoo-dev.py'
    if (Test-Path $VerifyScript) {
        python $VerifyScript 2>$null
    } else {
        Write-Warn 'verify-odoo-dev.py not found, skipping connectivity check.'
    }
}

function Reset-DevInstance {
    Write-Host ''
    Write-Host 'WARNING: This will DESTROY all dev instance data (database + filestore).' -ForegroundColor Red
    $confirm = Read-Host 'Type YES to confirm'
    if ($confirm -ne 'YES') {
        Write-Warn 'Reset cancelled.'
        return
    }
    Invoke-Compose @('down','-v')
    Write-Ok 'Dev instance data destroyed. Run: .\scripts\odoo-dev.ps1 start'
}

function Get-DevLogs {
    Invoke-Compose @('logs','-f','odoo')
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
switch ($Command) {
    'start'  { Start-DevInstance }
    'stop'   { Stop-DevInstance }
    'status' { Get-DevStatus }
    'reset'  { Reset-DevInstance }
    'logs'   { Get-DevLogs }
    default  {
        Write-Host 'Usage: .\scripts\odoo-dev.ps1 {start|stop|status|reset|logs}'
        Write-Host ''
        Write-Host 'Environment variables:'
        Write-Host '  ODOO_ENTERPRISE_PATH  Path to Odoo EE addons (e.g. C:\odoo\enterprise)'
        Write-Host '  ODOO_ENTERPRISE_CODE  Enterprise license key'
        Write-Host '  ODOO_DEV_PORT         Dev port (default: 8069)'
        Write-Host '  ODOO_DEV_DB           Database name (default: odoo_dev)'
    }
}
