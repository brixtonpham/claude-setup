#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code Full Setup for Windows (PowerShell)

.DESCRIPTION
    One command to set up Claude Code with mise, ProxyPal, and shell integration.

.EXAMPLE
    # Fresh install:
    irm https://raw.githubusercontent.com/brixtonpham/claude-setup/main/setup.ps1 | iex

    # Re-sync:
    & "$env:USERPROFILE\.ccp\setup.ps1"
#>

$ErrorActionPreference = "Continue"
$Repo = "https://github.com/brixtonpham/claude-setup.git"
$CcpDir = Join-Path $env:USERPROFILE ".ccp"

# ── Helpers ──────────────────────────────────────────────────────────
function Log($msg)  { Write-Host "[+] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Info($msg) { Write-Host "[i] $msg" -ForegroundColor Cyan }
function Err($msg)  { Write-Host "[x] $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor White
Write-Host "║       Claude Code Setup (CCP)            ║" -ForegroundColor White
Write-Host "║       OS: Windows | Shell: PowerShell    ║" -ForegroundColor White
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor White
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════
# Step 1: Sync ~/.ccp from git
# ═══════════════════════════════════════════════════════════════════════
Log "Step 1/5: Syncing CCP from git..."

if (Test-Path (Join-Path $CcpDir ".git")) {
    Push-Location $CcpDir
    git fetch origin main 2>$null
    git reset --hard origin/main 2>$null
    git clean -fd 2>$null
    Pop-Location
    Log "Synced to latest remote."
} elseif (Test-Path $CcpDir) {
    $backup = "$CcpDir.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Warn "Backing up existing ~/.ccp to $backup"
    Move-Item $CcpDir $backup
    git clone $Repo $CcpDir
    Log "Fresh clone complete."
} else {
    git clone $Repo $CcpDir
    Log "Cloned to $CcpDir"
}

# ═══════════════════════════════════════════════════════════════════════
# Step 2: Install mise
# ═══════════════════════════════════════════════════════════════════════
Log "Step 2/5: Setting up mise..."

# Add mise to PATH if installed
$misePaths = @(
    "$env:LOCALAPPDATA\mise\bin",
    "$env:LOCALAPPDATA\Programs\mise",
    "$env:USERPROFILE\.local\bin"
)
foreach ($p in $misePaths) {
    if (Test-Path $p) {
        $env:PATH = "$p;$env:PATH"
    }
}

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "Installing mise via winget..."
        winget install jdx.mise --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        # Refresh PATH
        foreach ($p in $misePaths) {
            if (Test-Path $p) { $env:PATH = "$p;$env:PATH" }
        }
    } else {
        Warn "winget not found. Install mise manually: https://mise.jdx.dev"
    }
}

if (Get-Command mise -ErrorAction SilentlyContinue) {
    Log "mise: $(mise --version)"
} else {
    Warn "mise not in PATH. Restart terminal after install."
}

# ═══════════════════════════════════════════════════════════════════════
# Step 3: Install tools via mise
# ═══════════════════════════════════════════════════════════════════════
Log "Step 3/5: Installing tools via mise..."

if (Get-Command mise -ErrorAction SilentlyContinue) {
    $miseConfigDir = Join-Path $env:USERPROFILE ".config\mise"
    New-Item -ItemType Directory -Path $miseConfigDir -Force | Out-Null
    Copy-Item -Force (Join-Path $CcpDir "setup\mise-config.toml") (Join-Path $miseConfigDir "config.toml")
    mise install --yes 2>&1 | Select-Object -Last 5
    mise reshim 2>$null

    # Add shims to PATH
    $shimsDir = "$env:LOCALAPPDATA\mise\shims"
    if (Test-Path $shimsDir) {
        $env:PATH = "$shimsDir;$env:PATH"
    }
    Log "Tools installed."
} else {
    Warn "Skipping (mise not available)."
}

# ═══════════════════════════════════════════════════════════════════════
# Step 4: Install ProxyPal
# ═══════════════════════════════════════════════════════════════════════
Log "Step 4/5: Setting up ProxyPal..."

$proxypalInstalled = (Test-Path "$env:LOCALAPPDATA\ProxyPal") -or
                     (Test-Path "$env:APPDATA\ProxyPal") -or
                     (Test-Path "C:\Program Files\ProxyPal\ProxyPal.exe")

if ($proxypalInstalled) {
    Log "ProxyPal already installed."
} else {
    try {
        $release = Invoke-RestMethod "https://api.github.com/repos/heyhuynhgiabuu/proxypal/releases/latest" -ErrorAction Stop
        $ver = $release.tag_name -replace '^v', ''
        $exeName = "ProxyPal_${ver}_x64-setup.exe"
        $dlUrl = "https://github.com/heyhuynhgiabuu/proxypal/releases/download/$($release.tag_name)/$exeName"
        $dlPath = Join-Path $env:TEMP $exeName

        Log "Downloading ProxyPal $ver..."
        Invoke-WebRequest -Uri $dlUrl -OutFile $dlPath -UseBasicParsing
        Log "Downloaded. Launching installer..."
        Start-Process -FilePath $dlPath
        Info "  Please complete the ProxyPal installer wizard."
    } catch {
        Warn "ProxyPal download failed. Get it from: https://github.com/heyhuynhgiabuu/proxypal/releases"
    }
}

# Install CLI proxy config as fallback
$proxyConfigDir = Join-Path $env:USERPROFILE ".cli-proxy-api"
$proxyConfig = Join-Path $proxyConfigDir "config.yaml"
New-Item -ItemType Directory -Path $proxyConfigDir -Force | Out-Null
if (-not (Test-Path $proxyConfig)) {
    Copy-Item (Join-Path $CcpDir "setup\proxy-config.yaml") $proxyConfig
    Log "CLI proxy config installed to $proxyConfig"
}

# ═══════════════════════════════════════════════════════════════════════
# Step 5: MCP servers + Shell integration
# ═══════════════════════════════════════════════════════════════════════
Log "Step 5/5: MCP servers & shell integration..."

# MCP servers
$claudeJson = Join-Path $env:USERPROFILE ".claude.json"
if (-not (Test-Path $claudeJson)) {
    @'
{
  "mcpServers": {
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"],
      "env": {}
    },
    "grep": {
      "type": "http",
      "url": "https://mcp.grep.app"
    },
    "stitch": {
      "type": "http",
      "url": "https://stitch.googleapis.com/mcp",
      "headers": {
        "x-goog-api-key": "REPLACE_WITH_YOUR_STITCH_API_KEY"
      }
    }
  }
}
'@ | Set-Content $claudeJson -Encoding UTF8
    Warn "Created $claudeJson - update Stitch API key!"
} else {
    Info "MCP config exists - keeping current $claudeJson"
}

# PowerShell profile integration
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
$shellIntegration = @'

# ── Claude Code (CCP) shell integration ──
# mise
if (Get-Command mise -ErrorAction SilentlyContinue) {
    mise activate pwsh | Invoke-Expression
}

# mise shims
$miseShims = "$env:LOCALAPPDATA\mise\shims"
if (Test-Path $miseShims) {
    $env:PATH = "$miseShims;$env:PATH"
}

# Claude alias with CCP
function Invoke-Claude {
    $ccpPath = if (Get-Command ccp -ErrorAction SilentlyContinue) {
        ccp which --path 2>$null
    } else { "" }
    $env:CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD = "1"
    & claude --add-dir $ccpPath @args
}
Set-Alias -Name claude-ccp -Value Invoke-Claude
'@

if ($profileContent -notmatch 'Claude Code.*CCP.*shell integration') {
    Add-Content -Path $PROFILE -Value $shellIntegration
    Log "Added shell integration to $PROFILE"
} else {
    Info "Shell integration already in $PROFILE"
}

Log "Shell integration configured."

# ═══════════════════════════════════════════════════════════════════════
# Done!
# ═══════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║            Setup Complete!               ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║  1. Restart your terminal                ║" -ForegroundColor Green
Write-Host "║  2. Open ProxyPal app → login providers  ║" -ForegroundColor Green
Write-Host "║  3. Run: claude                          ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Info "ProxyPal runs CLIProxyAPI on port 8317 automatically."
Info "Once ProxyPal is running, just type 'claude' to start."
Write-Host ""
