{{- /* chezmoi:modify-template */ -}}
{{- /*
  Only makes sure the PowerShell profile starts Starship. The rest of the file
  (machine-specific setup, blocks written by installers such as coreutils) is
  left untouched. A line added earlier by this template (found by its comment)
  is kept up to date; a Starship init written by hand is left alone.

  The line goes first: tools like `mise activate` wrap the existing prompt, so
  Starship has to be set before them. Added after, it would replace their hook.
  A UTF-8 BOM, if present, stays at the very start of the file.

  The double .ps1 is on purpose: on Windows chezmoi strips one interpreter
  extension from modify_ scripts, so a single .ps1 would target a file
  named "Microsoft.PowerShell_profile".
*/ -}}
{{- $comment := "# Starship prompt (added by chezmoi)" -}}
{{- /* also matches older wordings of the comment, e.g. "(added by chezmoi, ...)" */ -}}
{{- $ours := `# Starship prompt \(added by chezmoi[^)\r\n]*\)(\r?\n)[^\r\n]*` -}}
{{- $line := "if (Get-Command starship -ErrorAction Ignore) { Invoke-Expression (&starship init powershell) }" -}}
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
{{-   $content = replaceAllRegex $ours (printf "%s${1}%s" $comment $line) $content -}}
{{- else if not (contains "starship init powershell" $content) -}}
{{-   $sep := "" -}}
{{-   if $content -}}
{{-     $sep = $nl -}}
{{-   end -}}
{{-   $content = printf "%s%s%s%s%s%s" $comment $nl $line $nl $sep $content -}}
{{- end -}}
{{- $bom }}{{ $content -}}
