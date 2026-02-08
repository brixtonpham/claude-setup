#!/usr/bin/env bash
#
# Claude Code Setup - chezmoi-style sync
#
# Fresh install:
#   curl -sL https://raw.githubusercontent.com/brixtonpham/claude-setup/main/setup.sh | bash
#
# Update/re-sync (already have ~/.ccp):
#   bash ~/.ccp/setup.sh
#
# Or the classic:
#   git clone https://github.com/brixtonpham/claude-setup ~/.ccp && bash ~/.ccp/setup.sh
#
set -euo pipefail

# Fix PATH on Windows (mise/winget can clobber it)
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) export PATH="/usr/bin:/bin:$PATH";;
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
  *)    SHELL_RC="$HOME/.bashrc";;
esac

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       Claude Code Setup (CCP)            ║"
echo "║       OS: $OS | Shell: $SHELL_NAME              ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────────────────────────────
# Step 0: Sync ~/.ccp from git (nuke old, pull fresh)
# ─────────────────────────────────────────────────────────────────────
log "Syncing CCP from git..."

if [[ -d "$CCP_DIR/.git" ]]; then
  # Already a git repo - hard reset to remote
  log "Existing repo found. Pulling latest..."
  cd "$CCP_DIR"
  git fetch origin main 2>/dev/null
  git reset --hard origin/main 2>/dev/null
  git clean -fd 2>/dev/null
  log "Synced to latest remote."
elif [[ -d "$CCP_DIR" ]]; then
  # Exists but not a git repo - backup and replace
  warn "~/.ccp exists but is not a git repo."
  BACKUP="$HOME/.ccp.bak.$(date +%s)"
  warn "Backing up to $BACKUP"
  mv "$CCP_DIR" "$BACKUP"
  git clone "$REPO" "$CCP_DIR"
  log "Fresh clone complete."
else
  # Fresh install
  git clone "$REPO" "$CCP_DIR"
  log "Cloned to $CCP_DIR"
fi

# ─────────────────────────────────────────────────────────────────────
# Step 1: mise
# ─────────────────────────────────────────────────────────────────────
log "Checking mise..."
if ! command -v mise &>/dev/null; then
  if [[ "$OS" == "windows" ]]; then
    if command -v winget &>/dev/null; then
      log "Installing mise via winget..."
      winget install jdx.mise --accept-source-agreements --accept-package-agreements 2>&1 || true
      # winget installs to Program Files or AppData - add common paths
      for p in \
        "$LOCALAPPDATA/Programs/mise" \
        "$HOME/AppData/Local/Programs/mise" \
        "/c/Program Files/mise/bin" \
        "$HOME/.local/bin"; do
        [[ -d "$p" ]] && export PATH="$p:$PATH"
      done
    else
      warn "winget not found. Trying GitHub release install..."
      # Direct download fallback for Windows without winget
      MISE_VERSION=$(curl -fsSL "https://api.github.com/repos/jdx/mise/releases/latest" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
      MISE_URL="https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-windows-x64.zip"
      MISE_DIR="$HOME/.local/bin"
      mkdir -p "$MISE_DIR"
      curl -fsSL "$MISE_URL" -o /tmp/mise.zip
      unzip -o /tmp/mise.zip -d "$MISE_DIR" 2>/dev/null || true
      rm -f /tmp/mise.zip
      export PATH="$MISE_DIR:$PATH"
    fi
  else
    curl -fsSL https://mise.jdx.dev/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi

if ! command -v mise &>/dev/null; then
  warn "mise not in PATH yet. You may need to restart your terminal."
  warn "Then re-run: bash ~/.ccp/setup.sh"
  # Continue anyway - other steps may still work
else
  log "mise: $(mise --version)"
fi

# ─────────────────────────────────────────────────────────────────────
# Step 2: mise config & tools
# ─────────────────────────────────────────────────────────────────────
log "Installing mise config & tools..."
mkdir -p "$HOME/.config/mise"
cp -f "$CCP_DIR/setup/mise-config.toml" "$HOME/.config/mise/config.toml"
mise install --yes 2>&1 | tail -3 || warn "Some tools may have failed. Run 'mise install' again later."

# Activate for rest of script
eval "$(mise activate bash 2>/dev/null || true)"
eval "$(mise env 2>/dev/null || true)"

# ─────────────────────────────────────────────────────────────────────
# Step 3: CCP profile
# ─────────────────────────────────────────────────────────────────────
log "Activating CCP profile..."
if command -v ccp &>/dev/null; then
  ccp use default
  log "Profile 'default' active."
else
  warn "ccp not in PATH. After restart: ccp use default"
fi

# ─────────────────────────────────────────────────────────────────────
# Step 4: External sources
# ─────────────────────────────────────────────────────────────────────
log "Installing external skill sources..."
if command -v ccp &>/dev/null; then
  for src in \
    "github:nextlevelbuilder/ui-ux-pro-max-skill" \
    "github:vercel-labs/next-skills" \
    "github:wshobson/agents" \
    "github:remorses/playwriter"; do
    ccp install "$src" 2>&1 || warn "Failed: $src"
  done
else
  warn "ccp not available. After restart, run:"
  warn '  ccp install github:nextlevelbuilder/ui-ux-pro-max-skill'
  warn '  ccp install github:vercel-labs/next-skills'
  warn '  ccp install github:wshobson/agents'
  warn '  ccp install github:remorses/playwriter'
fi

# ─────────────────────────────────────────────────────────────────────
# Step 5: MCP servers (~/.claude.json)
# ─────────────────────────────────────────────────────────────────────
log "Configuring MCP servers..."
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

# ─────────────────────────────────────────────────────────────────────
# Step 6: Shell integration (idempotent)
# ─────────────────────────────────────────────────────────────────────
log "Shell integration..."

add_line_if_missing() {
  local file="$1" marker="$2" line="$3"
  if [[ -f "$file" ]] && grep -qF "$marker" "$file" 2>/dev/null; then
    info "Already in $file: $marker"
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

# ─────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  Done! Restart terminal, then:           ║"
echo "║    cli-proxy-api &                       ║"
echo "║    claude                                ║"
echo "╚══════════════════════════════════════════╝"
echo ""
[[ "$OS" == "windows" ]] && info "PowerShell users also: . ~/.ccp/setup/shell-integration.ps1"
