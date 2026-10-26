---
name: upgrade
description: Update the tools this dotfiles repo installs (GitHub releases on WSL/Linux, winget on Windows) and verify they still work.
argument-hint: "[linux|windows|all]"
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PROJECT_DIR}/scripts/linux.sh *)
---

Update the tools installed by the repo at `${CLAUDE_PROJECT_DIR}`. Requested targets: `$ARGUMENTS` (empty means the default below).

## 1. Pick the targets

Same as `/install`:

- **WSL** (`/proc/version` mentions `microsoft`): `linux` and `windows`.
- **Linux** (not WSL): `linux`. **Windows**: `windows`.

| Target | Command |
| --- | --- |
| linux | `${CLAUDE_PROJECT_DIR}/scripts/linux.sh <command>` |
| windows, from WSL | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w ${CLAUDE_PROJECT_DIR}/scripts/windows.ps1)" <command>` |
| windows, native | `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\windows.ps1 <command>` (`powershell.exe` when `pwsh` is missing) |

## 2. See what is outdated

Run `outdated` for each target and show the list (`outdated` lines show current and latest versions).

- `missing` tools: suggest `/install`; do not install them here.
- `external` tools (installed by apt or another package manager, not by this repo): list them with the command that would update them, but do not run it, since it needs `sudo`.

If nothing is outdated, say so and stop.

## 3. Upgrade

Run `upgrade` for each target with something outdated. On WSL/Linux it replaces the binaries in `~/.local/bin` with the latest GitHub release, which is the only way they get updated there. On Windows it runs `winget upgrade` for each outdated package.

If the PowerShell upgrade fails because PowerShell is in use, tell the user to run `winget upgrade Microsoft.PowerShell` from a Windows Terminal tab that is not PowerShell 7 (cmd or Windows PowerShell).

## 4. Verify

- Run `outdated` again: every managed tool must be `ok`.
- Run `check` for each target: the new-shell lines must still be `ok`, which proves the upgraded Starship and mise still load in a fresh shell.

If a check fails, find the cause (a release that renamed its archive, a binary that does not start) and fix it in the script, or report it with the error.

## 5. Report

End with a table of each upgraded tool, from and to version, and anything left for the user.
