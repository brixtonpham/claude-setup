#!/usr/bin/env bash
# Shell integration for Claude Code with CCP
# Source this from ~/.bashrc or ~/.zshrc

# Fix PATH on Windows (mise activate can clobber system bins)
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    [[ ":$PATH:" != *":/usr/bin:"* ]] && export PATH="/usr/bin:/bin:/mingw64/bin:$PATH"
    ;;
esac

# Ensure mise shims are in PATH (makes cli-proxy-api, claude, ccp available)
if [[ -d "${LOCALAPPDATA:-$HOME/AppData/Local}/mise/shims" ]]; then
  # Windows (Git Bash)
  export PATH="${LOCALAPPDATA:-$HOME/AppData/Local}/mise/shims:$PATH"
elif [[ -d "$HOME/.local/share/mise/shims" ]]; then
  # macOS / Linux
  export PATH="$HOME/.local/share/mise/shims:$PATH"
fi

# Only load if ccp is installed
if command -v ccp &> /dev/null; then
  # Claude alias - loads profile's CLAUDE.md and rules
  alias claude='CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 command claude --add-dir "${CLAUDE_CONFIG_DIR:-$(ccp which --path 2>/dev/null)}"'

  # Quick profile switch
  ccp-use() {
    ccp use "$@"
    # Reload mise env if available
    if command -v mise &> /dev/null && [[ -f mise.toml ]]; then
      eval "$(mise env)"
    fi
  }
fi
