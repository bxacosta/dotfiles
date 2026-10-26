# Windows setup: winget packages, fonts, config files, the $PROFILE line and
# Windows Terminal settings.
#
# Usage: scripts\windows.ps1 <command>
#   check     report what is missing or differs from the repo (changes nothing)
#   install   install missing packages and fonts, copy config files, merge settings
#   outdated  report winget packages with a newer version (changes nothing)
#   upgrade   update winget packages to their latest version
#
# Every line of output starts with a status: ok, missing, differs, outdated,
# warn or changed. check and outdated exit with 1 when something needs
# attention. Starts in Windows PowerShell 5.1 too: check and install install
# PowerShell 7 if needed and continue there.
param(
    [ValidateSet('check', 'install', 'outdated', 'upgrade')]
    [string]$Command
)
$ErrorActionPreference = 'Stop'

$repo = Split-Path $PSScriptRoot -Parent

# winget packages, installed in list order when missing.
#   Command: executable used to detect an existing install
#   Path:    file glob used instead of Command
$packages = @(
    # PowerShell 7 first: the rest of the setup targets it
    @{ Id = 'Microsoft.PowerShell';    Command = 'pwsh' }
    @{ Id = 'jdx.mise';                Command = 'mise' }
    @{ Id = 'Fastfetch-cli.Fastfetch'; Command = 'fastfetch' }
    @{ Id = 'Starship.Starship';       Command = 'starship' }
    @{ Id = 'sharkdp.bat';             Command = 'bat' }
    # An older edit.exe ships in System32, so the winget one is found by path
    @{ Id = 'Microsoft.Edit'; Path = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Microsoft.Edit_*\edit-*\edit.exe" }
)

# Fonts installed for the current user (no admin) when missing, verified
# against the release's checksums file.
#   FilePattern: files to install, also used to detect an existing install
$fonts = @(
    # Only the regular family: the Mono variant shrinks icons, Propo is not monospaced.
    @{
        Name        = 'CaskaydiaMono Nerd Font'
        Url         = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaMono.zip'
        Checksums   = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SHA-256.txt'
        FilePattern = 'CaskaydiaMonoNerdFont-*.ttf'
    }
)

# Config files copied as is: source in config\, target on this machine.
$files = @(
    @{ Source = 'starship.toml';             Target = "$HOME\.config\starship.toml" }
    @{ Source = 'fastfetch\config.jsonc';    Target = "$HOME\.config\fastfetch\config.jsonc" }
    @{ Source = 'mise\dotfiles.toml';        Target = "$HOME\.config\mise\conf.d\dotfiles.toml" }
    # bat reads its config from %APPDATA%\bat on Windows
    @{ Source = 'bat\config';                Target = "$env:APPDATA\bat\config" }
    @{ Source = 'bat\themes\Aurora.tmTheme'; Target = "$env:APPDATA\bat\themes\Aurora.tmTheme" }
    @{ Source = 'powershell\profile.ps1';    Target = "$HOME\.config\powershell\profile.ps1" }
)

# First line of $PROFILE; the rest of the file is left alone. It goes first: the
# shared profile starts Starship, which has to be set before tools that wrap
# the prompt.
$profileComment = '# Shared profile (bxacosta/dotfiles)'
$profileLine = '. "$HOME\.config\powershell\profile.ps1"'

# Packaged Windows Terminal (not Preview)
$terminalDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$terminalSettings = Join-Path $terminalDir 'settings.json'
$terminalManaged = Join-Path $repo 'config\windows-terminal\settings.jsonc'

$script:attention = $false

function Write-Status([string]$Status, [string]$Message) {
    Write-Host ('{0,-9} {1}' -f $Status, $Message)
    if ($Status -notin 'ok', 'changed') { $script:attention = $true }
}

function Show-Usage {
    Get-Content $PSCommandPath | Select-Object -Skip 3 -First 5 | ForEach-Object { $_ -replace '^# ?', '' }
}

# A terminal opened before an install still has the old PATH
function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Find-Pwsh {
    $cmd = Get-Command pwsh -ErrorAction Ignore
    if ($cmd) { return $cmd.Source }
    $default = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    if (Test-Path $default) { return $default }
}

# --- winget packages ---------------------------------------------------------

# 0x8A150061: package already installed; 0x8A15002B: no applicable upgrade
$wingetOk = @(0, 0x8A150061, 0x8A15002B) | ForEach-Object { [int32]$_ }

function Test-Package($Package) {
    if ($Package.Path) { return Test-Path $Package.Path }
    return [bool](Get-Command $Package.Command -ErrorAction Ignore)
}

function Install-Package([string]$Id) {
    winget install --id $Id --exact --source winget --silent --disable-interactivity --accept-package-agreements --accept-source-agreements | Out-Host
    if ($LASTEXITCODE -notin $wingetOk) { throw "winget failed to install $Id (exit code $LASTEXITCODE)" }
    Write-Status changed "$Id installed"
}

function Get-OutdatedPackage([string]$Id) {
    # Exits with 0 and lists the package only when an upgrade is available
    $out = winget list --id $Id --exact --upgrade-available --source winget --accept-source-agreements --disable-interactivity 2>$null
    if ($LASTEXITCODE -ne 0) { return }
    $line = $out | Where-Object { $_ -match [regex]::Escape($Id) } | Select-Object -First 1
    if ($line) { return ($line -replace '\s+', ' ').Trim() }
    return $Id
}

function Update-Package([string]$Id) {
    winget upgrade --id $Id --exact --source winget --silent --disable-interactivity --accept-package-agreements --accept-source-agreements | Out-Host
    if ($LASTEXITCODE -notin $wingetOk) { throw "winget failed to upgrade $Id (exit code $LASTEXITCODE)" }
}

# --- fonts -------------------------------------------------------------------

function Test-Font($Font) {
    (Test-Path (Join-Path "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" $Font.FilePattern)) -or
        (Test-Path (Join-Path "$env:WINDIR\Fonts" $Font.FilePattern))
}

function Install-Font($Font) {
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $regKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        $zipName = Split-Path $Font.Url -Leaf
        $zip = Join-Path $tmp $zipName
        Invoke-WebRequest -Uri $Font.Url -OutFile $zip -UseBasicParsing
        $checksums = (Invoke-WebRequest -Uri $Font.Checksums -UseBasicParsing).Content
        if ($checksums -is [byte[]]) { $checksums = [Text.Encoding]::UTF8.GetString($checksums) }
        $expected = $checksums -split '\r?\n' |
            Where-Object { $_ -match "^([0-9a-f]{64})\s+$([regex]::Escape($zipName))$" } |
            ForEach-Object { $Matches[1] }
        if (-not $expected) { throw "No checksum for $zipName in $($Font.Checksums)" }
        $hash = (Get-FileHash $zip -Algorithm SHA256).Hash
        if ($hash -ne $expected) { throw "SHA256 mismatch for $($Font.Name): $hash" }

        Expand-Archive -Path $zip -DestinationPath $tmp
        foreach ($file in Get-ChildItem $tmp -Filter $Font.FilePattern) {
            $target = Join-Path $fontDir $file.Name
            Copy-Item $file.FullName $target -Force
            New-ItemProperty -Path $regKey -Name "$($file.BaseName) (TrueType)" -Value $target -PropertyType String -Force | Out-Null
        }
        Write-Status changed "$($Font.Name) installed (restart Windows Terminal to use it)"
    } finally {
        Remove-Item $tmp -Recurse -Force
    }
}

# --- config files ------------------------------------------------------------

function Test-SameFile([string]$Source, [string]$Target) {
    (Test-Path $Target) -and ((Get-FileHash $Source).Hash -eq (Get-FileHash $Target).Hash)
}

function Test-ConfigFile($File) {
    $source = Join-Path $repo "config\$($File.Source)"
    if (-not (Test-Path $File.Target)) { Write-Status missing $File.Target }
    elseif (Test-SameFile $source $File.Target) { Write-Status ok $File.Target }
    else { Write-Status differs "$($File.Target) (repo: config\$($File.Source))" }
}

# Returns $true when the file was written
function Copy-ConfigFile($File) {
    $source = Join-Path $repo "config\$($File.Source)"
    if (Test-SameFile $source $File.Target) { return $false }
    New-Item -ItemType Directory -Path (Split-Path $File.Target) -Force | Out-Null
    Copy-Item $source $File.Target -Force
    Write-Status changed $File.Target
    return $true
}

function Test-BatTheme {
    [bool](Get-Command bat -ErrorAction Ignore) -and ((bat --list-themes) -contains 'Aurora')
}

# --- $PROFILE ----------------------------------------------------------------

function Get-ProfilePath { $PROFILE.CurrentUserCurrentHost }

function Test-ProfileLine {
    $path = Get-ProfilePath
    (Test-Path $path) -and ([IO.File]::ReadAllText($path).Contains($profileLine))
}

function Add-ProfileLine {
    if (Test-ProfileLine) { return }
    $path = Get-ProfilePath
    $text = ''
    $bom = $false
    if (Test-Path $path) {
        $bytes = [IO.File]::ReadAllBytes($path)
        $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $text = [IO.File]::ReadAllText($path)
    }
    $nl = if ($text.Contains("`n") -and -not $text.Contains("`r`n")) { "`n" } else { "`r`n" }
    $new = $profileComment + $nl + $profileLine + $nl
    if ($text) { $new += $nl + $text }
    New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
    [IO.File]::WriteAllText($path, $new, (New-Object Text.UTF8Encoding $bom))
    Write-Status changed "$path line added"
}

# --- Windows Terminal --------------------------------------------------------

# Merges $Wanted into $Current, matching items by $Key. Keeps the existing order
# (Windows Terminal reorders lists when saving from its UI): managed items are
# replaced in place, duplicates dropped, and missing ones appended.
function Merge-List($Current, $Wanted, [scriptblock]$Key) {
    $byKey = [ordered]@{}
    foreach ($item in $Wanted) { $byKey[(& $Key $item)] = $item }
    $seen = @{}
    $result = New-Object Collections.Generic.List[object]
    foreach ($item in $Current) {
        $k = & $Key $item
        if ($null -eq $k -or -not $byKey.Contains($k)) { $result.Add($item) }
        elseif (-not $seen.ContainsKey($k)) { $result.Add($byKey[$k]); $seen[$k] = $true }
    }
    foreach ($k in $byKey.Keys) { if (-not $seen.ContainsKey($k)) { $result.Add($byKey[$k]) } }
    , $result.ToArray()
}

# Sets a dot-notation path ("font.face") in nested dictionaries
function Set-JsonPath($Node, [string]$Path, $Value) {
    $parts = $Path.Split('.')
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        if ($Node[$parts[$i]] -isnot [Collections.IDictionary]) { $Node[$parts[$i]] = [ordered]@{} }
        $Node = $Node[$parts[$i]]
    }
    $Node[$parts[-1]] = $Value
}

# Removes a dot-notation path, and its parent when that leaves it empty
function Remove-JsonPath($Node, [string]$Path) {
    $parts = $Path.Split('.')
    $parent = $null
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        if ($Node[$parts[$i]] -isnot [Collections.IDictionary]) { return }
        $parent = $Node
        $Node = $Node[$parts[$i]]
    }
    $Node.Remove($parts[-1])
    if ($parent -and $Node.Count -eq 0) { $parent.Remove($parts[-2]) }
}

function Read-TerminalSettings {
    $raw = if (Test-Path $terminalSettings) { [string](Get-Content -Raw $terminalSettings) } else { '' }
    if ($raw.Trim()) { return $raw | ConvertFrom-Json -AsHashtable }
    return [ordered]@{}
}

# The current settings.json with config\windows-terminal\settings.jsonc merged in
function Get-MergedTerminalSettings {
    $wt = Get-Content -Raw $terminalManaged | ConvertFrom-Json -AsHashtable
    $s = Read-TerminalSettings

    $s['actions'] = Merge-List $s['actions'] $wt.actions { param($a) $a['id'] }
    $s['keybindings'] = Merge-List $s['keybindings'] $wt.keybindings {
        param($b) if ($b['keys'] -is [string]) { $b['keys'].ToLower() }
    }
    $s['schemes'] = Merge-List $s['schemes'] $wt.schemes { param($c) $c['name'] }

    foreach ($key in $wt.profileDefaults.Keys) {
        Set-JsonPath $s "profiles.defaults.$key" $wt.profileDefaults[$key]
    }

    # Drop per-profile overrides so every profile inherits from defaults, then
    # apply per-profile settings: every key in `match` must equal the profile's value
    if ($s['profiles'] -is [Collections.IDictionary] -and $s['profiles']['list']) {
        foreach ($p in $s['profiles']['list']) {
            foreach ($path in $wt.enforceOnAllProfiles) { Remove-JsonPath $p $path }
            foreach ($rule in $wt.profiles) {
                $isMatch = $true
                foreach ($k in $rule.match.Keys) {
                    if ([string]$p[$k] -ne [string]$rule.match[$k]) { $isMatch = $false }
                }
                if ($isMatch) {
                    foreach ($k in $rule.set.Keys) { Set-JsonPath $p $k $rule.set[$k] }
                }
            }
        }
    }
    return $s
}

function ConvertTo-SettingsJson($Settings) { $Settings | ConvertTo-Json -Depth 100 }

# Returns 'missing' (no settings.json yet), 'differs' or 'ok'
function Get-TerminalState {
    if (-not (Test-Path $terminalSettings)) { return 'missing' }
    $merged = ConvertTo-SettingsJson (Get-MergedTerminalSettings)
    $current = ConvertTo-SettingsJson (Read-TerminalSettings)
    if ($merged -eq $current) { return 'ok' }
    return 'differs'
}

function Update-TerminalSettings {
    if (-not (Test-Path $terminalDir)) {
        Write-Status warn 'Windows Terminal is not installed (or has never been opened); settings not merged'
        return
    }
    $state = Get-TerminalState
    if ($state -eq 'ok') { return }
    if ($state -eq 'differs') { Copy-Item $terminalSettings "$terminalSettings.bak" -Force }
    $json = ConvertTo-SettingsJson (Get-MergedTerminalSettings)
    [IO.File]::WriteAllText($terminalSettings, $json + "`n", (New-Object Text.UTF8Encoding $false))
    Write-Status changed "$terminalSettings merged (previous copy: settings.json.bak)"
}

# --- checks of the result ----------------------------------------------------

# A new pwsh session with the profile, as a new terminal would start it
function Test-NewShell {
    $pwsh = Find-Pwsh
    if (-not $pwsh) { Write-Status missing 'PowerShell 7'; return }
    $out = & $pwsh -NoLogo -Command 'Write-Output "$env:STARSHIP_SHELL|$env:MISE_SHELL|$env:COLORTERM"' 2>$null |
        Select-Object -Last 1
    $parts = "$out|||".Split('|')
    if ($parts[0]) { Write-Status ok 'new shell: Starship prompt' } else { Write-Status missing 'new shell: Starship prompt not active' }
    if ($parts[1]) { Write-Status ok 'new shell: mise activated' } else { Write-Status missing 'new shell: mise not activated' }
    if ($parts[2]) { Write-Status ok "new shell: COLORTERM=$($parts[2])" } else { Write-Status missing 'new shell: COLORTERM not set' }
}

# WSL is not set up from here, only reported
function Test-Wsl {
    if (-not (Get-Command wsl.exe -ErrorAction Ignore)) {
        Write-Status warn 'WSL is not installed (wsl --install)'
        return
    }
    $distros = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction Ignore |
        ForEach-Object { $_.GetValue('DistributionName') } | Where-Object { $_ }
    if ($distros) { Write-Status ok "WSL distributions: $($distros -join ', ')" }
    else { Write-Status warn 'WSL has no distribution (wsl --install -d Ubuntu)' }
}

# --- commands ----------------------------------------------------------------

function Invoke-Check {
    foreach ($p in $packages) {
        if (Test-Package $p) { Write-Status ok $p.Id } else { Write-Status missing $p.Id }
    }
    foreach ($f in $fonts) {
        if (Test-Font $f) { Write-Status ok $f.Name } else { Write-Status missing $f.Name }
    }
    foreach ($f in $files) { Test-ConfigFile $f }

    if (Test-ProfileLine) { Write-Status ok "$(Get-ProfilePath) loads the shared profile" }
    else { Write-Status missing "$(Get-ProfilePath) line: $profileLine" }

    if (-not (Test-Path $terminalDir)) { Write-Status warn 'Windows Terminal is not installed (or has never been opened)' }
    else {
        $state = Get-TerminalState
        if ($state -eq 'ok') { Write-Status ok 'Windows Terminal settings' }
        else { Write-Status $state "Windows Terminal settings ($terminalSettings)" }
    }

    Test-NewShell
    if (Get-Command bat -ErrorAction Ignore) {
        if (Test-BatTheme) { Write-Status ok 'bat Aurora theme' } else { Write-Status missing 'bat Aurora theme (run: bat cache --build)' }
    }
    Test-Wsl
}

function Invoke-Install {
    $installed = $false
    foreach ($p in $packages) {
        if (-not (Test-Package $p)) { Install-Package $p.Id; $installed = $true }
    }
    if ($installed) { Update-SessionPath }
    foreach ($f in $fonts) {
        if (-not (Test-Font $f)) { Install-Font $f }
    }
    $themeChanged = $false
    foreach ($f in $files) {
        if ((Copy-ConfigFile $f) -and $f.Source -like '*.tmTheme') { $themeChanged = $true }
    }
    Add-ProfileLine
    Update-TerminalSettings
    if ((Get-Command bat -ErrorAction Ignore) -and ($themeChanged -or -not (Test-BatTheme))) {
        bat cache --build | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "bat cache --build failed (exit code $LASTEXITCODE)" }
        Write-Status changed 'bat cache rebuilt'
    }
    if ($installed) { Write-Host 'Open a new terminal to pick up PATH changes.' }
}

function Invoke-Outdated {
    foreach ($p in $packages) {
        if (-not (Test-Package $p)) { Write-Status missing $p.Id; continue }
        $outdated = Get-OutdatedPackage $p.Id
        if ($outdated) { Write-Status outdated $outdated } else { Write-Status ok $p.Id }
    }
}

function Invoke-Upgrade {
    foreach ($p in $packages) {
        if (-not (Test-Package $p)) { continue }
        $outdated = Get-OutdatedPackage $p.Id
        if (-not $outdated) { continue }
        Update-Package $p.Id
        Write-Status changed "$outdated (upgraded)"
    }
}

# Not run when dot-sourced (to test the functions)
if ($MyInvocation.InvocationName -eq '.') { return }

if (-not $Command) { Show-Usage; exit 2 }
Update-SessionPath

# check and install need PowerShell 7 (JSONC parsing, the pwsh $PROFILE)
if ($PSVersionTable.PSVersion.Major -lt 7 -and $Command -in 'check', 'install') {
    $pwsh = Find-Pwsh
    if (-not $pwsh -and $Command -eq 'install') {
        Install-Package 'Microsoft.PowerShell'
        Update-SessionPath
        $pwsh = Find-Pwsh
    }
    if (-not $pwsh) { Write-Status missing 'PowerShell 7 (run install)'; exit 1 }
    & $pwsh -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath $Command
    exit $LASTEXITCODE
}

switch ($Command) {
    'check'    { Invoke-Check; if ($script:attention) { exit 1 } }
    'install'  { Invoke-Install }
    'outdated' { Invoke-Outdated; if ($script:attention) { exit 1 } }
    'upgrade'  { Invoke-Upgrade }
}
