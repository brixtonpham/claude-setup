#!/usr/bin/env bash
#
# Claude Code Full Setup - One command to rule them all
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/brixtonpham/claude-setup/main/setup.sh | bash
#   bash ~/.ccp/setup.sh          # re-sync
#
set -euo pipefail

# Fix PATH on Windows (mise/winget can clobber it)
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) export PATH="/usr/bin:/bin:/mingw64/bin:$PATH";;
esac

REPO="https://github.com/brixtonpham/claude-setup.git"
CCP_DIR="$HOME/.ccp"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; exit 1; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

OS="unknown"
case "$(uname -s)" in
  Darwin*)  OS="mac";;
  Linux*)   OS="linux";;
  MINGW*|MSYS*|CYGWIN*) OS="windows";;
esac

SHELL_NAME="$(basename "${SHELL:-bash}")"
case "$SHELL_NAME" in
  zsh)  SHELL_RC="$HOME/.zshrc";;
  *)    SHELL_RC="$HOME/.bashrc"
        # Git Bash on Windows sources .bash_profile, not .bashrc
        if [[ "$OS" == "windows" ]]; then
          SHELL_RC="$HOME/.bash_profile"
        fi
        ;;
esac

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       Claude Code Setup (CCP)            ║"
echo "║       OS: $OS | Shell: $SHELL_NAME              ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Step 0: Sync ~/.ccp from git
# ═══════════════════════════════════════════════════════════════════════
log "Step 1/5: Syncing CCP from git..."

if [[ -d "$CCP_DIR/.git" ]]; then
  git -C "$CCP_DIR" fetch origin main 2>/dev/null
  git -C "$CCP_DIR" reset --hard origin/main 2>/dev/null
  git -C "$CCP_DIR" clean -fd 2>/dev/null
  log "Synced to latest remote."
elif [[ -d "$CCP_DIR" ]]; then
  BACKUP="$HOME/.ccp.bak.$(date +%s)"
  warn "Backing up existing ~/.ccp to $BACKUP"
  mv "$CCP_DIR" "$BACKUP"
  git clone "$REPO" "$CCP_DIR"
  log "Fresh clone complete."
else
  git clone "$REPO" "$CCP_DIR"
  log "Cloned to $CCP_DIR"
fi

# ═══════════════════════════════════════════════════════════════════════
# Step 1: Install mise
# ═══════════════════════════════════════════════════════════════════════
log "Step 2/5: Setting up mise..."

# Ensure LOCALAPPDATA is set (Git Bash may not have it)
if [[ -z "${LOCALAPPDATA:-}" && "$OS" == "windows" ]]; then
  export LOCALAPPDATA="$HOME/AppData/Local"
fi

# Try to find mise in common locations first
for p in \
  "${LOCALAPPDATA:-}/mise/bin" \
  "${LOCALAPPDATA:-}/Programs/mise" \
  "$HOME/AppData/Local/mise/bin" \
  "$HOME/.local/bin" \
  "$HOME/.local/bin/mise/bin"; do
  [[ -d "$p" ]] && export PATH="$p:$PATH"
done

if ! command -v mise &>/dev/null; then
  if [[ "$OS" == "windows" ]]; then
    # Try winget first (runs in cmd.exe, available even in Git Bash)
    if command -v winget.exe &>/dev/null || [[ -f "/c/Users/$(whoami)/AppData/Local/Microsoft/WindowsApps/winget.exe" ]]; then
      log "Installing mise via winget..."
      winget.exe install jdx.mise --accept-source-agreements --accept-package-agreements 2>&1 || true
      # Re-scan paths after winget install
      for p in "${LOCALAPPDATA:-}/mise/bin" "${LOCALAPPDATA:-}/Programs/mise" "$HOME/AppData/Local/mise/bin"; do
        [[ -d "$p" ]] && export PATH="$p:$PATH"
      done
    else
      log "Installing mise from GitHub releases..."
      MISE_VERSION=$(curl -fsSL "https://api.github.com/repos/jdx/mise/releases/latest" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
      MISE_DIR="$HOME/.local/bin"
      mkdir -p "$MISE_DIR"
      curl -fsSL "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-windows-x64.zip" -o /tmp/mise.zip
      unzip -o /tmp/mise.zip -d "$MISE_DIR" 2>/dev/null || true
      rm -f /tmp/mise.zip
      export PATH="$MISE_DIR:$MISE_DIR/mise/bin:$PATH"
    fi
  else
    curl -fsSL https://mise.jdx.dev/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi

if command -v mise &>/dev/null; then
  log "mise: $(mise --version)"
else
  warn "mise not in PATH yet. Will continue, but some steps may be skipped."
fi

# ═══════════════════════════════════════════════════════════════════════
# Step 2: Install tools via mise
# ═══════════════════════════════════════════════════════════════════════
log "Step 3/5: Installing tools via mise..."
if command -v mise &>/dev/null; then
  mkdir -p "$HOME/.config/mise"
  cp -f "$CCP_DIR/setup/mise-config.toml" "$HOME/.config/mise/config.toml"
  mise install --yes 2>&1 | tail -5 || warn "Some tools failed. Run 'mise install' later."

  # Save system PATH before mise activation (mise can clobber it on Windows)
  SYSTEM_PATH="/usr/bin:/bin:/mingw64/bin:/usr/sbin:/sbin"

  # Activate mise for rest of script
  eval "$(mise activate bash 2>/dev/null || true)"
  eval "$(mise env 2>/dev/null || true)"

  # Re-add system paths (mise activate can remove them on Windows/Git Bash)
  export PATH="$PATH:$SYSTEM_PATH"

  # Add shims to PATH
  if [[ -d "${LOCALAPPDATA:-}/mise/shims" ]]; then
    export PATH="${LOCALAPPDATA:-}/mise/shims:$PATH"
  elif [[ -d "$HOME/.local/share/mise/shims" ]]; then
    export PATH="$HOME/.local/share/mise/shims:$PATH"
  fi
  mise reshim 2>/dev/null || true
  log "Tools installed."
else
  warn "Skipping mise install (mise not available)."
fi

# ═══════════════════════════════════════════════════════════════════════
# Step 3: Install ProxyPal (desktop app for managing CLIProxyAPI)
# ═══════════════════════════════════════════════════════════════════════
log "Step 4/5: Setting up ProxyPal..."

install_proxypal() {
  local PROXYPAL_REPO="heyhuynhgiabuu/proxypal"
  local LATEST
  LATEST=$(curl -fsSL "https://api.github.com/repos/$PROXYPAL_REPO/releases/latest" 2>/dev/null | grep '"tag_name"' | head -1 | cut -d'"' -f4)

  if [[ -z "$LATEST" ]]; then
    warn "Could not fetch ProxyPal latest version."
    return 1
  fi
  # Strip 'v' prefix if present
  local VER="${LATEST#v}"

  case "$OS" in
    windows)
      local EXE_NAME="ProxyPal_${VER}_x64-setup.exe"
      local DL_URL="https://github.com/$PROXYPAL_REPO/releases/download/${LATEST}/${EXE_NAME}"
      local DL_PATH="/tmp/$EXE_NAME"

      log "Downloading ProxyPal $VER for Windows..."
      curl -fsSL "$DL_URL" -o "$DL_PATH" || { warn "Download failed: $DL_URL"; return 1; }
      log "Downloaded. Launching installer..."
      info "  Please complete the ProxyPal installer wizard."

      # Launch installer (runs in Windows, not Git Bash)
      cmd.exe /c "$(cygpath -w "$DL_PATH")" 2>/dev/null &
      ;;
    mac)
      local DMG_NAME="ProxyPal_${VER}_aarch64.dmg"
      local DL_URL="https://github.com/$PROXYPAL_REPO/releases/download/${LATEST}/${DMG_NAME}"
      local DL_PATH="/tmp/$DMG_NAME"

      log "Downloading ProxyPal $VER for macOS..."
      curl -fsSL "$DL_URL" -o "$DL_PATH" || { warn "Download failed"; return 1; }
      log "Downloaded. Opening installer..."
      open "$DL_PATH"
      ;;
    linux)
      local DEB_NAME="proxy-pal_${VER}_amd64.deb"
      local DL_URL="https://github.com/$PROXYPAL_REPO/releases/download/${LATEST}/${DEB_NAME}"
      local DL_PATH="/tmp/$DEB_NAME"

      log "Downloading ProxyPal $VER for Linux..."
      curl -fsSL "$DL_URL" -o "$DL_PATH" || { warn "Download failed"; return 1; }
      sudo dpkg -i "$DL_PATH" 2>/dev/null || sudo apt-get install -f -y 2>/dev/null
      ;;
  esac
}

# Check if ProxyPal is already installed
PROXYPAL_INSTALLED=false
case "$OS" in
  windows)
    { [[ -d "${LOCALAPPDATA:-}/ProxyPal" ]] || [[ -d "${APPDATA:-}/ProxyPal" ]] || \
      [[ -f "/c/Program Files/ProxyPal/ProxyPal.exe" ]]; } && PROXYPAL_INSTALLED=true
    ;;
  mac)
    { [[ -d "/Applications/ProxyPal.app" ]] || [[ -d "$HOME/Applications/ProxyPal.app" ]]; } && PROXYPAL_INSTALLED=true
    ;;
esac

if $PROXYPAL_INSTALLED; then
  log "ProxyPal already installed."
else
  install_proxypal || warn "ProxyPal install failed. Download manually: https://github.com/heyhuynhgiabuu/proxypal/releases"
fi

# Also install proxy config as fallback (for CLI usage without ProxyPal)
PROXY_CONFIG_DIR="$HOME/.cli-proxy-api"
PROXY_CONFIG="$PROXY_CONFIG_DIR/config.yaml"
mkdir -p "$PROXY_CONFIG_DIR"
if [[ ! -f "$PROXY_CONFIG" ]]; then
  cp "$CCP_DIR/setup/proxy-config.yaml" "$PROXY_CONFIG"
  log "CLI proxy config installed to $PROXY_CONFIG"
fi

# ═══════════════════════════════════════════════════════════════════════
# Step 4: MCP servers + Shell integration
# ═══════════════════════════════════════════════════════════════════════
log "Step 5/5: MCP servers & shell integration..."

# MCP servers
CLAUDE_JSON="$HOME/.claude.json"
if [[ ! -f "$CLAUDE_JSON" ]]; then
  cat > "$CLAUDE_JSON" <<'EOF'
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
EOF
  warn "Created $CLAUDE_JSON - update Stitch API key!"
else
  info "MCP config exists - keeping current $CLAUDE_JSON"
fi

# Shell integration
add_line_if_missing() {
  local file="$1" marker="$2" line="$3"
  if [[ -f "$file" ]] && grep -qF "$marker" "$file" 2>/dev/null; then
    return 0
  elif [[ -f "$file" ]] || touch "$file" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$file"
    log "Added to $file"
  fi
}

add_line_if_missing "$SHELL_RC" "ccp/setup/shell-integration" \
  '# CCP shell integration
source "$HOME/.ccp/setup/shell-integration.sh"'

add_line_if_missing "$SHELL_RC" "mise activate" \
  "# mise
eval \"\$(mise activate $SHELL_NAME)\""

# On Windows, mise activate clobbers system PATH - fix it after activation
if [[ "$OS" == "windows" ]]; then
  add_line_if_missing "$SHELL_RC" "mingw64/bin" \
    '# Fix PATH after mise activate (Windows/Git Bash)
[[ ":$PATH:" != *":/usr/bin:"* ]] && export PATH="/usr/bin:/bin:/mingw64/bin:$PATH"'
fi

log "Shell integration configured."

# ═══════════════════════════════════════════════════════════════════════
# Done!
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║            Setup Complete!               ║"
echo "╠══════════════════════════════════════════╣"
echo "║  1. Restart your terminal                ║"
echo "║  2. Open ProxyPal app → login providers  ║"
echo "║  3. Run: claude                          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

if [[ "$OS" == "windows" ]]; then
  info "Windows: ProxyPal installer should be running."
  info "After installing, open ProxyPal and login to your providers."
fi

info "ProxyPal runs CLIProxyAPI on port 8317 automatically."
info "Once ProxyPal is running, just type 'claude' to start."
echo ""
