<#
.SYNOPSIS
    Shows how everyday terminal output looks with the current color scheme.

.DESCRIPTION
    Prints the 16 ANSI colors and realistic samples of daily use: PowerShell
    syntax highlighting, errors/warnings, file listings, git, logs, test
    results and JSON. Run it before and after changing the Windows Terminal
    scheme to compare.

    Everything here uses the 16 scheme colors, as do Starship and fastfetch:
    the last section shows the roles they give to each color.

.EXAMPLE
    ./tools/preview-terminal-colors.ps1
#>

$e = [char]27
$r = "$e[0m"
function C([string]$codes, [string]$text) { "$e[$($codes)m$text$r" }
function Section([string]$title) { "`n$(C '1' "== $title ==")" }

# --- Palette -----------------------------------------------------------------
Section 'Palette (16 ANSI colors)'
$names = 'black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white'
"  {0,-9} {1,-14} {2,-14} {3}" -f '', 'normal', 'bright', 'as background'
for ($i = 0; $i -lt 8; $i++) {
    $normal = C (30 + $i) ("{0,-14}" -f "$($names[$i]) ($(30 + $i))")
    $bright = C (90 + $i) ("{0,-14}" -f "bright ($(90 + $i))")
    $bg = (C (40 + $i) '  normal  ') + ' ' + (C (100 + $i) '  bright  ')
    "  {0,-9} {1} {2} {3}" -f $names[$i], $normal, $bright, $bg
}
"  default foreground on default background, " + (C '1' 'bold') + ', ' + (C '2' 'dim') + ', ' + (C '3' 'italic') + ', ' + (C '4' 'underline') + ', ' + (C '9' 'strikethrough') + ', ' + (C '7' 'inverse')

# --- PowerShell input --------------------------------------------------------
Section 'PowerShell input (PSReadLine syntax colors)'
$o = Get-PSReadLineOption
$tok = @{
    cmd = $o.CommandColor; par = $o.ParameterColor; str = $o.StringColor; var = $o.VariableColor
    op = $o.OperatorColor; num = $o.NumberColor; kw = $o.KeywordColor; com = $o.CommentColor
    typ = $o.TypeColor; mem = $o.MemberColor; def = $o.DefaultTokenColor
}
function T([string]$k, [string]$text) { "$($tok[$k])$text$r" }
'  ' + (T cmd 'Get-ChildItem') + ' ' + (T par '-Path') + ' ' + (T str '"D:\PROJECTS"') + ' ' + (T par '-Recurse') + ' ' + (T op '|') + ' ' + (T cmd 'Where-Object') + ' ' + (T def '{ ') + (T var '$_') + (T mem '.Length') + ' ' + (T op '-gt') + ' ' + (T num '1MB') + (T def ' }')
'  ' + (T kw 'foreach') + ' ' + (T def '(') + (T var '$file') + ' ' + (T kw 'in') + ' ' + (T var '$files') + (T def ') { ') + (T typ '[int]') + (T var '$size') + ' ' + (T op '=') + ' ' + (T var '$file') + (T mem '.Length') + (T def ' }') + '  ' + (T com '# a comment')
'  ' + (T cmd 'git') + ' ' + (T def 'commit') + ' ' + (T par '-m') + ' ' + (T str "'Fix the build'") + '   ' + "$($o.InlinePredictionColor)<- inline prediction$r"

# --- PowerShell output -------------------------------------------------------
Section 'PowerShell messages'
$f = $PSStyle.Formatting
"  $($f.Error)Write-Error: Cannot find path 'D:\missing' because it does not exist.$r"
"  $($f.Warning)WARNING: The command is deprecated, use Get-Thing instead.$r"
"  $($f.Verbose)VERBOSE: Loading module from D:\PROJECTS\module.psm1$r"
"  $($f.Debug)DEBUG: Request took 120 ms$r"
"  $($f.FeedbackName)Suggestion [general]:$r $($f.FeedbackText)The most similar command is 'Get-Process'.$r"

Section 'Tables and file listings (Get-ChildItem)'
"  $($f.TableHeader)Mode   LastWriteTime        Length Name$r"
"  $($f.TableHeader)----   -------------        ------ ----$r"
$fi = $PSStyle.FileInfo
"  d----  08/10/2026  12:00             $($fi.Directory)src$r"
"  d----  08/10/2026  12:00             $($fi.Directory)node_modules$r"
"  -a---  08/10/2026  12:00        2048 $($fi.Executable)build.ps1$r"
"  -a---  08/10/2026  12:00     1048576 $($fi.Extension['.zip'])release.zip$r"
"  la---  08/10/2026  12:00           0 $($fi.SymbolicLink)current -> v1.2.0$r"
"  -a---  08/10/2026  12:00         512 README.md"

# --- Git ---------------------------------------------------------------------
Section 'git status'
"  On branch $(C 1 'main')"
"  Your branch is ahead of '$(C 31 'origin/main')' by 2 commits."
"  Changes to be committed:"
"        $(C 32 'new file:   src/app.ts')"
"  Changes not staged for commit:"
"        $(C 31 'modified:   README.md')"
"  Untracked files:"
"        $(C 31 'notes.txt')"

Section 'git log --oneline --graph --decorate'
"  * $(C 33 'a422ed2') $(C 33 '(')$(C '1;36' 'HEAD -> ')$(C '1;32' 'main')$(C 33 ', ')$(C '1;31' 'origin/main')$(C 33 ')') Redesign Starship prompt"
"  * $(C 33 'cd21550') $(C 33 '(')$(C '1;33' 'tag: v1.0')$(C 33 ')') Add Starship config"
"  | * $(C 33 '7de8824') $(C 33 '(')$(C '1;32' 'feature/wsl')$(C 33 ')') Add WSL support"
"  |/"
"  * $(C 33 '928f57e') Use fastfetch's built-in OS icon"

Section 'git diff'
"  $(C 1 'diff --git a/config.toml b/config.toml')"
"  $(C 36 '@@ -1,4 +1,4 @@') [settings]"
"   name = `"aurora`""
"  $(C 31 '-color = `"#f44747`"')"
"  $(C 32 '+color = `"#ef596f`"')"

# --- Logs and tools ----------------------------------------------------------
Section 'Application logs'
"  $(C 90 '2026-10-08 12:00:01') $(C 36 'INFO ') Server listening on $(C 4 'http://localhost:3000')"
"  $(C 90 '2026-10-08 12:00:02') $(C 35 'DEBUG') Loaded 42 routes in 18 ms"
"  $(C 90 '2026-10-08 12:00:05') $(C 33 'WARN ') Slow query (1.2 s): SELECT * FROM users"
"  $(C 90 '2026-10-08 12:00:09') $(C 31 'ERROR') Connection refused: postgres://localhost:5432"
"  $(C 90 '2026-10-08 12:00:10') $(C 32 'OK   ') Reconnected to database"

Section 'Package manager / build'
"  $(C 32 '+') react 19.1.0 $(C 90 '(was 18.3.1)')"
"  $(C 33 'npm warn') deprecated inflight@1.0.6: This module is not supported"
"  $(C 31 'npm error') code ERESOLVE"
"  $(C '1;32' 'Compiled successfully') in $(C 1 '1.4s')"
"  $(C 4 'src/app.ts')$(C 90 ':12:5') - $(C 31 'error') $(C 90 'TS2304:') Cannot find name 'foo'."

Section 'Tests'
"  $(C 32 'PASS') src/utils.test.ts"
"  $(C 31 'FAIL') src/api.test.ts"
"    $(C 31 [char]0x2715) should return 200 $(C 90 '(32 ms)')"
"    $(C 32 [char]0x2713) should parse the body $(C 90 '(4 ms)')"
"  Tests: $(C '1;31' '1 failed'), $(C '1;32' '1 passed'), 2 total"

Section 'JSON (jq style)'
"  {"
"    $(C '1;34' '"name"'): $(C 32 '"aurora"'),"
"    $(C '1;34' '"version"'): $(C 37 '1.2'),"
"    $(C '1;34' '"dark"'): $(C 37 'true'),"
"    $(C '1;34' '"parent"'): $(C 90 'null')"
"  }"

# --- Prompt and fastfetch ----------------------------------------------------
Section 'Starship and fastfetch roles'
"  " + (C 97 'text (97)') + '  ' + (C 37 'value (37)') + '  ' + (C 90 'muted (90)') + '  ' + (C 94 'accent (94)') + '  ' + (C 95 'git status (95)') + '  ' + (C 96 'success (96)') + '  ' + (C 31 'error (31)')
""
