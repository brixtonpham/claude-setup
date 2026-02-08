#!/usr/bin/env bash
#
# Claude Code Full Setup Script
# Run after: git clone https://github.com/brixtonpham/claude-setup ~/.ccp
#
# Usage:
#   bash ~/.ccp/setup.sh
#
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

# Detect OS
OS="unknown"
case "$(uname -s)" in
  Darwin*)  OS="mac";;
  Linux*)   OS="linux";;
  MINGW*|MSYS*|CYGWIN*) OS="windows";;
esac

SHELL_RC=""
case "$(basename "${SHELL:-bash}")" in
  zsh)  SHELL_RC="$HOME/.zshrc";;
  bash) SHELL_RC="$HOME/.bashrc";;
  *)    SHELL_RC="$HOME/.bashrc";;
esac

echo ""
echo "============================================"
echo "  Claude Code Setup"
echo "  OS: $OS | Shell: $(basename "${SHELL:-bash}")"
echo "============================================"
echo ""

# ─── Step 1: Install mise ───────────────────────────────────────────
log "Step 1/7: Checking mise..."
if command -v mise &>/dev/null; then
  log "mise already installed: $(mise --version)"
else
  warn "mise not found. Installing..."
  if [[ "$OS" == "windows" ]]; then
    err "On Windows, install mise manually:"
    err "  winget install jdx.mise"
    err "  OR: https://mise.jdx.dev/getting-started/"
    exit 1
  else
    curl https://mise.jdx.dev/install.sh | sh
  fi

  # Add mise to current shell
  if [[ -f "$HOME/.local/bin/mise" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
  fi

  if ! command -v mise &>/dev/null; then
    err "mise installation failed. Install manually: https://mise.jdx.dev"
    exit 1
  fi
  log "mise installed: $(mise --version)"
fi

# ─── Step 2: Copy mise config ──────────────────────────────────────
log "Step 2/7: Setting up mise config..."
mkdir -p "$HOME/.config/mise"

if [[ -f "$HOME/.config/mise/config.toml" ]]; then
  warn "Existing mise config found. Backing up to config.toml.bak"
  cp "$HOME/.config/mise/config.toml" "$HOME/.config/mise/config.toml.bak"
fi

cp "$HOME/.ccp/setup/mise-config.toml" "$HOME/.config/mise/config.toml"
log "Mise config installed."

# ─── Step 3: Install tools via mise ────────────────────────────────
log "Step 3/7: Installing tools via mise (this may take a while)..."
mise install --yes 2>&1 | tail -5
log "Tools installed. Key tools:"
info "  claude-code: $(mise which claude 2>/dev/null && echo 'OK' || echo 'pending')"
info "  ccp:         $(command -v ccp 2>/dev/null && echo 'OK' || echo 'pending')"
info "  node:        $(mise exec -- node --version 2>/dev/null || echo 'pending')"

# Ensure mise shims are in PATH for the rest of the script
eval "$(mise activate bash 2>/dev/null || true)"
eval "$(mise env 2>/dev/null || true)"

# ─── Step 4: Activate CCP profile ─────────────────────────────────
log "Step 4/7: Activating CCP default profile..."
if command -v ccp &>/dev/null; then
  ccp use default
  log "CCP profile 'default' activated."
else
  warn "ccp not in PATH yet. Run after restarting shell:"
  warn "  ccp use default"
fi

# ─── Step 5: Install CCP external sources ─────────────────────────
log "Step 5/7: Installing external skill sources..."
if command -v ccp &>/dev/null; then
  ccp install github:nextlevelbuilder/ui-ux-pro-max-skill 2>&1 || warn "Failed: ui-ux-pro-max-skill"
  ccp install github:vercel-labs/next-skills 2>&1              || warn "Failed: next-skills"
  ccp install github:wshobson/agents 2>&1                      || warn "Failed: agents"
  ccp install github:remorses/playwriter 2>&1                  || warn "Failed: playwriter"
  log "External sources installed."
else
  warn "ccp not available. Install sources after restarting shell:"
  warn "  ccp install github:nextlevelbuilder/ui-ux-pro-max-skill"
  warn "  ccp install github:vercel-labs/next-skills"
  warn "  ccp install github:wshobson/agents"
  warn "  ccp install github:remorses/playwriter"
fi

# ─── Step 6: Setup MCP servers ────────────────────────────────────
log "Step 6/7: Configuring MCP servers..."
CLAUDE_JSON="$HOME/.claude.json"

# Build MCP config
if [[ ! -f "$CLAUDE_JSON" ]] || ! python3 -c "import json; json.load(open('$CLAUDE_JSON'))" 2>/dev/null; then
  # Create new file
  cat > "$CLAUDE_JSON" <<'MCPEOF'
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
MCPEOF
  warn "MCP servers configured in $CLAUDE_JSON"
  warn "  >> IMPORTANT: Replace REPLACE_WITH_YOUR_STITCH_API_KEY with your actual key"
else
  info "MCP config already exists at $CLAUDE_JSON - skipping"
fi

# ─── Step 7: Shell integration ────────────────────────────────────
log "Step 7/7: Setting up shell integration..."

INTEGRATION_LINE='# CCP shell integration
source "$HOME/.ccp/setup/shell-integration.sh"'

if [[ -n "$SHELL_RC" ]] && [[ -f "$SHELL_RC" ]]; then
  if grep -q "ccp/setup/shell-integration" "$SHELL_RC" 2>/dev/null; then
    info "Shell integration already in $SHELL_RC"
  else
    echo "" >> "$SHELL_RC"
    echo "$INTEGRATION_LINE" >> "$SHELL_RC"
    log "Added shell integration to $SHELL_RC"
  fi
else
  warn "Shell RC not found. Add this to your shell config manually:"
  echo "  $INTEGRATION_LINE"
fi

# Also add mise activation if not present
if [[ -n "$SHELL_RC" ]] && [[ -f "$SHELL_RC" ]]; then
  if ! grep -q "mise activate" "$SHELL_RC" 2>/dev/null; then
    SHELL_NAME="$(basename "${SHELL:-bash}")"
    echo "" >> "$SHELL_RC"
    echo "# mise" >> "$SHELL_RC"
    echo "eval \"\$(mise activate $SHELL_NAME)\"" >> "$SHELL_RC"
    log "Added mise activation to $SHELL_RC"
  fi
fi

# ─── Done ─────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
log "Next steps:"
info "  1. Restart your terminal (or: source $SHELL_RC)"
info "  2. Start proxy:     cli-proxy-api"
info "  3. Run Claude:      claude"
echo ""

if [[ "$OS" == "windows" ]]; then
  warn "Windows notes:"
  info "  - Use Git Bash for hooks (they need bash)"
  info "  - PowerShell: also run:  . ~/.ccp/setup/shell-integration.ps1"
fi

warn "Don't forget:"
info "  - Update Stitch API key in $CLAUDE_JSON"
info "  - Run 'gh auth login' if not already authenticated"
echo ""
