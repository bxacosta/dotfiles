# Shared PowerShell profile, loaded from the first line of $PROFILE (added by scripts/windows.ps1).
# Runs before the rest of $PROFILE.

# Start in $HOME instead of System32 (e.g. when launched elevated or from Win+R)
if ($PWD.Path -ieq "$env:SystemRoot\System32") {
    Set-Location $HOME
}

# Starship prompt. First, so tools that wrap the prompt (loaded later) keep their hook.
if (Get-Command starship -ErrorAction Ignore) { Invoke-Expression (&starship init powershell) }

# Windows Terminal shell integration: OSC 133 marks the end of the previous command
# (with its exit code) and the prompt; OSC 9;9 reports the cwd, so duplicated
# panes and tabs open in it. Starship calls this before writing every prompt.
$Global:__LastHistoryId = -1
function Invoke-Starship-PreCommand {
    $esc = [char]27
    # $origDollarQuestion and $origLastExitCode are Starship's prompt variables,
    # read from the calling scope: $? is already reset in here
    $lastCmd = Get-History -Count 1
    $lastId = if ($lastCmd) { $lastCmd.Id } else { 0 }
    if ($Global:__LastHistoryId -ne -1) {
        if ($lastId -eq $Global:__LastHistoryId) {
            # No new command (empty Enter, Ctrl+C): no exit code
            $Host.UI.Write("$esc]133;D$esc\")
        } else {
            $code = if ($origDollarQuestion) { 0 }
                elseif ($Error[0].InvocationInfo.HistoryId -eq $lastId) { 1 }
                else { $origLastExitCode }
            $Host.UI.Write("$esc]133;D;$code$esc\")
        }
    }
    $Global:__LastHistoryId = $lastId

    $Host.UI.Write("$esc]133;A$esc\")
    $loc = $ExecutionContext.SessionState.Path.CurrentLocation
    if ($loc.Provider.Name -eq "FileSystem") {
        $Host.UI.Write("$esc]9;9;`"$($loc.ProviderPath)`"$esc\")
    }
}

# mise wraps the prompt, so it goes after Starship
if (Get-Command mise -ErrorAction Ignore) { (&mise activate pwsh) | Out-String | Invoke-Expression }

# Mark the end of the prompt (OSC 133;B) after the prompt text. Wraps the final
# prompt, so it goes last; calling it first thing keeps $? intact for Starship.
$Global:__PromptWithoutMarks = $function:prompt
function global:prompt { "$(& $Global:__PromptWithoutMarks)$([char]27)]133;B$([char]27)\" }

# Windows Terminal supports 24-bit color but does not say so; without this, bat
# and others fall back to 256 colors and miss the exact Aurora colors
if (-not $env:COLORTERM) { $env:COLORTERM = "truecolor" }

function Copy-WorkingDirectory {
    (Get-Location).Path | Set-Clipboard
    Write-Host "Working directory copied to clipboard"
}
Set-Alias -Name cwd -Value Copy-WorkingDirectory

# Prefer the winget Microsoft Edit over the older one shipped in System32
Get-Item "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Microsoft.Edit_*\edit-*\edit.exe" -ErrorAction Ignore |
    Select-Object -Last 1 | ForEach-Object { Set-Alias -Name edit -Value $_.FullName }
