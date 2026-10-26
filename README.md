# BX's dotfiles

Windows 11 and WSL (Ubuntu) setup: plain config files, two setup scripts, and Claude Code
commands that run them and verify the result.

![screenshot](./images/screenshot.png)

## Install

Clone the repo (in WSL it covers both WSL and the Windows host) and open Claude Code in it:

```sh
git clone https://github.com/bxacosta/dotfiles ~/dotfiles
cd ~/dotfiles && claude
```

Then run:

- `/install`: checks the machine, asks before overwriting files edited locally, installs what is
  missing and checks again that every item is in place (including that a new shell loads
  Starship and mise).
- `/upgrade`: updates the installed tools and checks they still work. On WSL this is how the
  tools get updated, since they come from GitHub releases rather than a package manager.

Both take an optional target: `linux`, `windows` or `all`. From WSL the default is both;
elsewhere, the current system. Inside this repo `/upgrade` replaces Claude Code's built-in
`/upgrade` (the plan upgrade page).

Without Claude Code, run the scripts directly:

```sh
scripts/linux.sh check      # or install, outdated, upgrade
```

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows.ps1 check
```

`check` and `outdated` change nothing; every output line starts with a status (`ok`, `missing`,
`differs`, `outdated`, `external`, `warn`, `changed`).

## Contents

| Tool                      | Platform | Managed                                                            |
|---------------------------|----------|--------------------------------------------------------------------|
| Windows Terminal          | Windows  | Merged: actions, keybindings, profile defaults, Aurora scheme      |
| CaskaydiaMono Nerd Font   | Windows  | Installed if missing (latest release, checksum verified)           |
| Starship                  | Both     | Installed (winget / GitHub release), config copied                 |
| Fastfetch                 | Both     | Installed (winget / GitHub release), config copied                 |
| bat                       | Both     | Installed (winget / GitHub release), Aurora theme                  |
| PowerShell 7              | Windows  | Installed (winget), first package                                  |
| mise                      | Both     | Installed (winget / GitHub release), activated by the shells       |
| Microsoft Edit            | Windows  | Installed (winget), preferred over the System32 copy               |
| PowerShell profile        | Windows  | One line that loads the shared profile                             |
| Shared PowerShell profile | Windows  | Copied: Starship, mise, Terminal integration, aliases              |
| mise config               | Both     | `conf.d/dotfiles.toml` only (env); `config.toml` unmanaged         |
| `~/.bashrc`               | WSL      | One line that loads `~/.config/bash/dotfiles.sh` (mise, Starship) |

Tools already installed by another package manager (for example bat from apt) are left alone
and reported as `external`.

## Structure

```
config/                          files copied to the machine as is
  windows-terminal/settings.jsonc  merged into Windows Terminal's settings.json instead
scripts/linux.sh                 WSL/Linux: GitHub release tools, config files, ~/.bashrc line
scripts/windows.ps1              Windows: winget, fonts, config files, $PROFILE line, Terminal
.claude/skills/                  /install and /upgrade
CLAUDE.md                        rules for Claude Code when changing this repo
tools/preview-terminal-colors.ps1  color scheme preview (not installed)
```

## Colors

Defined once in the Windows Terminal `Aurora` scheme (`config/windows-terminal/settings.jsonc`),
based on [aurora-theme](https://github.com/bxacosta/aurora-theme). Starship and Fastfetch use
ANSI color names only.

## Notes

- The shared profile must load first in PowerShell; loading Starship later overwrites existing prompt hooks.
- Windows Terminal paths assume the packaged version (not Preview).
- Moving from the chezmoi version: `/install` reports the lines chezmoi added to `~/.bashrc` and
  offers to remove them. The old chezmoi source in `~/.local/share/chezmoi` can be deleted.

## References

- https://github.com/LierB/fastfetch
- https://github.com/ChristianLempa/dotfiles-win
- https://github.com/Chick2D/neofetch-themes
