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

## Quick Setup (One Command)

```bash
git clone https://github.com/brixtonpham/claude-setup ~/.ccp && bash ~/.ccp/setup.sh
```

This single command will:
1. Install mise (if missing)
2. Copy mise config & install all tools (node, python, claude-code, ccp, CLIProxyAPI, etc.)
3. Activate the `default` CCP profile
4. Install external skill sources (vercel-labs, wshobson, etc.)
5. Configure MCP servers (context7, grep, stitch)
6. Add shell integration to your `.bashrc`/`.zshrc`

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
