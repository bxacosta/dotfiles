{{- /* chezmoi:modify-template */ -}}
{{- /*
  Only makes sure the PowerShell profile loads the shared profile
  (dot_config/powershell/profile.ps1). The rest of the file (machine-specific
  setup, blocks written by installers such as coreutils) is left untouched.
  A line added earlier by this template (found by its comment, including the
  older Starship one) is kept up to date.

  The line goes first: the shared profile starts Starship, which has to be set
  before tools that wrap the prompt (e.g. `mise activate`).
  A UTF-8 BOM, if present, stays at the very start of the file.

  The double .ps1 is on purpose: on Windows chezmoi strips one interpreter
  extension from modify_ scripts, so a single .ps1 would target a file
  named "Microsoft.PowerShell_profile".
*/ -}}
{{- $comment := "# Shared profile (added by chezmoi)" -}}
{{- $line := `. "$HOME\.config\powershell\profile.ps1"` -}}
{{- $ours := `# (?:Shared profile|Starship prompt) \(added by chezmoi[^)\r\n]*\)(\r?\n)[^\r\n]*` -}}
{{- $content := .chezmoi.stdin -}}
{{- $bom := "" -}}
{{- if hasPrefix "﻿" $content -}}
{{-   $bom = "﻿" -}}
{{-   $content = trimPrefix "﻿" $content -}}
{{- end -}}
{{- $nl := "\n" -}}
{{- if contains "\r\n" $content -}}
{{-   $nl = "\r\n" -}}
{{- end -}}
{{- if regexMatch $ours $content -}}
{{-   $content = replaceAllRegex $ours (printf "%s${1}%s" $comment (replace "$" "$$" $line)) $content -}}
{{- else if not (contains $line $content) -}}
{{-   $sep := "" -}}
{{-   if $content -}}
{{-     $sep = $nl -}}
{{-   end -}}
{{-   $content = printf "%s%s%s%s%s%s" $comment $nl $line $nl $sep $content -}}
{{- end -}}
{{- $bom }}{{ $content -}}
