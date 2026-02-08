# PowerShell integration for Claude Code with CCP
# Add to your $PROFILE (run: notepad $PROFILE)

# Only load if ccp is available
if (Get-Command ccp -ErrorAction SilentlyContinue) {
    function Invoke-Claude {
        $ccpPath = ccp which --path 2>$null
        if (-not $ccpPath) { $ccpPath = "" }
        $env:CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD = "1"
        & claude --add-dir $ccpPath @args
    }
    Set-Alias -Name claude-ccp -Value Invoke-Claude

    function Switch-CcpProfile {
        param([string]$Profile)
        ccp use $Profile
        # Reload mise env if available
        if (Get-Command mise -ErrorAction SilentlyContinue) {
            mise activate pwsh | Invoke-Expression
        }
    }
    Set-Alias -Name ccp-use -Value Switch-CcpProfile
}
