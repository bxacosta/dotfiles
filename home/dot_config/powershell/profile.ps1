# Shared PowerShell profile, loaded from $PROFILE (see the modify_ template).
# Runs before the rest of $PROFILE.

# Start in $HOME instead of System32 (e.g. when launched elevated or from Win+R)
if ($PWD.Path -ieq "$env:SystemRoot\System32") {
    Set-Location $HOME
}

# Starship prompt. First, so tools that wrap the prompt (loaded later) keep their hook.
if (Get-Command starship -ErrorAction Ignore) { Invoke-Expression (&starship init powershell) }

# mise wraps the prompt, so it goes after Starship
if (Get-Command mise -ErrorAction Ignore) { (&mise activate pwsh) | Out-String | Invoke-Expression }

function Copy-WorkingDirectory {
    (Get-Location).Path | Set-Clipboard
    Write-Host "Working directory copied to clipboard"
}
Set-Alias -Name cwd -Value Copy-WorkingDirectory

# Prefer the winget Microsoft Edit over the older one shipped in System32
Get-Item "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Microsoft.Edit_*\edit-*\edit.exe" -ErrorAction Ignore |
    Select-Object -Last 1 | ForEach-Object { Set-Alias -Name edit -Value $_.FullName }
