# Claude Code Setup (CCP)

Complete Claude Code environment with profiles, skills, agents, hooks, and proxy config.
Managed by [CCP (Claude Code Profile)](https://github.com/samhvw8/claude-code-profile).

## What's Included

| Component | Description |
|-----------|-------------|
| **Profiles** | `default` (full), `coding` (minimal), `minimal` (env only), `nextjs` |
| **Skills** | 30 skills (planning, frontend, backend, databases, git, etc.) |
| **Agents** | 31 agents (debugger, architect, reviewer, scout, etc.) |
| **Hooks** | 5 hooks (session-start, agent-skills-eval, websearch, etc.) |
| **Settings** | Proxy config, model routing, permissions, plugins |

## Setup on New Machine (Windows)

### Prerequisites

```powershell
# 1. Install Git for Windows (includes Git Bash)
winget install Git.Git

# 2. Install GitHub CLI
winget install GitHub.cli
gh auth login

# 3. Install mise
# See: https://mise.jdx.dev/getting-started/
winget install jdx.mise

# 4. Add mise to your shell
# PowerShell: Add to $PROFILE
# Git Bash: Add to ~/.bashrc
eval "$(mise activate bash)"   # bash
eval "$(mise activate zsh)"    # zsh
# For PowerShell, see: https://mise.jdx.dev/getting-started/#powershell
```

### Install Core Tools

```powershell
# Copy mise config to your machine
mkdir -p ~/.config/mise
cp setup/mise-config.toml ~/.config/mise/config.toml

# Install all tools (node, python, go, claude-code, CLIProxyAPI, ccp, etc.)
mise install
```

### Clone & Activate CCP

```bash
# Clone this repo as your CCP directory
git clone https://github.com/<your-username>/claude-setup ~/.ccp

# Activate the default profile
ccp use default
```

### Install External Skill Sources

These are git-cloned by CCP and excluded from this repo:

```bash
ccp install github:nextlevelbuilder/ui-ux-pro-max-skill
ccp install github:vercel-labs/next-skills
ccp install github:wshobson/agents
ccp install github:remorses/playwriter
```

### Start the Proxy

```bash
# CLIProxyAPI runs on port 8317
cli-proxy-api
```

### Shell Integration

**Git Bash** (`~/.bashrc`):
```bash
# Source the provided shell integration
source ~/.ccp/setup/shell-integration.sh
```

**PowerShell** (`$PROFILE`):
```powershell
# Source the provided PowerShell integration
. ~/.ccp/setup/shell-integration.ps1
```

### MCP Servers

Add MCP servers after Claude Code is running:

```bash
# Context7 - Library documentation
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest

# Grep - GitHub search
claude mcp add grep -- npx -y @anthropic/grep-mcp

# Stitch - UI generation
claude mcp add stitch -- npx -y @anthropic/stitch-mcp
```

## Windows-Specific Notes

1. **Hooks use bash** - Git Bash provides `/usr/bin/bash` on Windows. Make sure Git Bash is in your PATH.

2. **Path separators** - CCP handles path normalization, but custom hooks may need adjustment if they use hardcoded `/` paths.

3. **Status line** - The status line hook uses `node` and `ls -td`. On Windows, `ls` is available via Git Bash. If running from PowerShell directly, you may need to adjust the command.

4. **`$HOME` paths** - Work in Git Bash. In PowerShell, use `$env:USERPROFILE` or `$HOME`.

5. **CLIProxyAPI** - Runs the same way. Ensure port 8317 is not blocked by Windows Firewall.

## Proxy Configuration

The proxy routes requests through CLIProxyAPI on `localhost:8317`:

| Setting | Value |
|---------|-------|
| `ANTHROPIC_BASE_URL` | `http://127.0.0.1:8317` |
| `ANTHROPIC_AUTH_TOKEN` | `proxypal-local` |
| `ANTHROPIC_MODEL` | `gemini-claude-opus-4-5-thinking` |
| Default Haiku | `gemini-2.5-flash-lite` |
| Default Sonnet | `gemini-claude-sonnet-4-5-thinking` |
| Default Opus | `gemini-claude-opus-4-5-thinking` |

## Verification Checklist

- [ ] `mise doctor` shows no errors
- [ ] `ccp which` shows `default` profile
- [ ] `cli-proxy-api` starts on port 8317
- [ ] `claude` command launches Claude Code
- [ ] Claude Code connects through proxy (check model name in session)
- [ ] Hooks fire on session start
- [ ] MCP servers respond (test with `/mcp` in Claude Code)

## Updating

```bash
cd ~/.ccp
git pull
ccp use default  # Re-apply profile after pulling changes
```
