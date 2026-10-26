# Dotfiles

Windows 11 and WSL (Ubuntu) setup. Config files live in `config/` as plain files; two scripts
put them in place and install the tools. Claude Code drives the scripts through the `/install`
and `/upgrade` skills in `.claude/skills/`, but the scripts work on their own too.

## Layout

- `config/`: files copied as is to the machine. Targets are listed in each script (`files` in
  `scripts/linux.sh`, `$files` in `scripts/windows.ps1`).
- `config/windows-terminal/settings.jsonc`: not copied, merged into Windows Terminal's
  `settings.json` by `scripts/windows.ps1` (the rules are in the file's comments).
- `config/bash/dotfiles.sh` and `config/powershell/profile.ps1`: loaded by one line the scripts add
  to `~/.bashrc` and `$PROFILE`. Everything else in those two files belongs to the machine.
- `scripts/linux.sh`, `scripts/windows.ps1`: `check`, `install`, `outdated`, `upgrade`.

## Rules for changes

- The repo is the source of truth. Change a config in `config/`, then run `/install` to copy it.
  If a file was edited on the machine, `check` reports `differs`: ask which version wins.
- Keep the scripts readable top to bottom, without templating. `linux.sh` is POSIX `sh`
  without `sudo`; `windows.ps1` must parse in Windows PowerShell 5.1 (no `??`, `&&` or ternaries),
  since it starts there on a new machine.
- Script output keeps its contract: one line per item, starting with a status
  (`ok`, `missing`, `differs`, `outdated`, `external`, `warn`, `changed`). The skills rely on it.
- A new tool goes in the tool list of each script that should install it, and in the README table.
- Test `scripts/linux.sh` against a throwaway home (`HOME=$(mktemp -d) scripts/linux.sh install`,
  then `check`) before running it on the real one.
