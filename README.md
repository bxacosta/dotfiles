# BX's dotfiles

Windows 11 and WSL (Ubuntu) setup, managed with [chezmoi](https://www.chezmoi.io/).

![screenshot](./images/screenshot.png)

## Install

Windows (PowerShell):

```powershell
winget install twpayne.chezmoi
chezmoi init --apply bxacosta
```

WSL:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply bxacosta
```

Update later with `chezmoi update`.

## Contents

| Tool                    | Platform | Managed                                                       |
|-------------------------|----------|---------------------------------------------------------------|
| Windows Terminal        | Windows  | Merged: actions, keybindings, profile defaults, Aurora scheme |
| CaskaydiaMono Nerd Font | Windows  | Installed if missing (latest release)                         |
| Starship                | Both     | Installed (winget / GitHub release), config fully managed     |
| Fastfetch               | Both     | Installed (winget / GitHub release), config fully managed     |
| PowerShell profile      | Windows  | Starship line only                                            |
| `~/.bashrc`             | WSL      | Starship line only                                            |

Merged files keep everything not listed in the repo.

## Structure

```
home/                               chezmoi source (.chezmoiroot)
  .chezmoidata/                     data: terminal settings, fonts, packages
  .chezmoiscripts/windows/          font and winget installs
  .chezmoiexternal.toml.tmpl        Linux binaries (Starship, Fastfetch)
  AppData/.../settings.json         Windows Terminal merge template
  Documents/PowerShell/...          PowerShell profile template
  dot_config/                       Starship and Fastfetch config
  modify_dot_bashrc                 bashrc template
tools/preview-terminal-colors.ps1   color scheme preview (not installed)
```

## Colors

Defined once in the Windows Terminal `Aurora` scheme (`home/.chezmoidata/terminal.yaml`), based
on [aurora-theme](https://github.com/bxacosta/aurora-theme). Starship and Fastfetch use ANSI color names only.

## Notes

- PowerShell profile and `~/.bashrc` are created if missing.
- Starship must load first in PowerShell; loading it later overwrites existing prompt hooks.
- Paths assume packaged Windows Terminal (not Preview) and `Documents` not redirected to OneDrive.

## References

- https://github.com/LierB/fastfetch
- https://github.com/ChristianLempa/dotfiles-win
- https://github.com/Chick2D/neofetch-themes
