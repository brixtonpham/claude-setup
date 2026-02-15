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

## Setup (One Command)

### Bash (macOS / Linux / Git Bash on Windows)

**Fresh install:**
```bash
curl -sL https://raw.githubusercontent.com/brixtonpham/claude-setup/main/setup.sh | bash
```

**Or with git clone:**
```bash
git clone https://github.com/brixtonpham/claude-setup ~/.ccp && bash ~/.ccp/setup.sh
```

**Update / re-sync:**
```bash
bash ~/.ccp/setup.sh
```

### PowerShell (Windows native)

**Fresh install:**
```powershell
irm https://raw.githubusercontent.com/brixtonpham/claude-setup/main/setup.ps1 | iex
```

**Or with git clone:**
```powershell
git clone https://github.com/brixtonpham/claude-setup "$env:USERPROFILE\.ccp"
& "$env:USERPROFILE\.ccp\setup.ps1"
```

**Update / re-sync:**
```powershell
& "$env:USERPROFILE\.ccp\setup.ps1"
```

The script auto-detects your situation:
- No `~/.ccp` → fresh clone
- `~/.ccp` is a git repo → `git fetch + reset --hard` (like chezmoi)
- `~/.ccp` exists but not git → backup to `~/.ccp.bak.*`, then fresh clone

Then it installs everything: mise, tools, CCP profile, external sources, MCP servers, shell integration.

After setup, restart your terminal and run:
```bash
cli-proxy-api &   # Start proxy in background
claude            # Launch Claude Code
```

## Manual Setup (Step by Step)

<details>
<summary>Click to expand manual steps</summary>

### Prerequisites

```bash
# Windows
winget install Git.Git GitHub.cli jdx.mise

# macOS
brew install mise gh

# Then authenticate GitHub
gh auth login
```

### Install Tools & Activate Profile

```bash
mkdir -p ~/.config/mise
cp ~/.ccp/setup/mise-config.toml ~/.config/mise/config.toml
mise install
ccp use default
```

### Install External Skill Sources

```bash
ccp install github:nextlevelbuilder/ui-ux-pro-max-skill
ccp install github:vercel-labs/next-skills
ccp install github:wshobson/agents
ccp install github:remorses/playwriter
```

### Shell Integration

**Bash/Zsh**: Add to `~/.bashrc` or `~/.zshrc`:
```bash
source "$HOME/.ccp/setup/shell-integration.sh"
```

**PowerShell**: Add to `$PROFILE`:
```powershell
. ~/.ccp/setup/shell-integration.ps1
```

### MCP Servers

The setup script creates `~/.claude.json` with MCP configs. Update the Stitch API key:
```bash
# Edit ~/.claude.json and replace REPLACE_WITH_YOUR_STITCH_API_KEY
```

</details>

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
| `ANTHROPIC_MODEL` | `gemini-claude-opus-4-6-thinking` |
| Default Haiku | `gemini-2.5-flash-lite` |
| Default Sonnet | `gemini-claude-sonnet-4-5-thinking` |
| Default Opus | `gemini-claude-opus-4-6-thinking` |

## Verification Checklist

- [ ] `mise doctor` shows no errors
- [ ] `ccp which` shows `default` profile
- [ ] `cli-proxy-api` starts on port 8317
- [ ] `claude` command launches Claude Code
- [ ] Claude Code connects through proxy (check model name in session)
- [ ] Hooks fire on session start
- [ ] MCP servers respond (test with `/mcp` in Claude Code)

## Updating

Re-run the setup script - it pulls latest and re-applies everything:
```bash
bash ~/.ccp/setup.sh
```

Or manual pull:
```bash
cd ~/.ccp && git pull && ccp use default
```
