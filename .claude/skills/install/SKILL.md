---
name: install
description: Set up this machine from the dotfiles repo (WSL/Linux and Windows), then verify that everything is configured.
argument-hint: "[linux|windows|all]"
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PROJECT_DIR}/scripts/linux.sh *)
---

Set up this machine from the repo at `${CLAUDE_PROJECT_DIR}` and prove the result. Requested targets: `$ARGUMENTS` (empty means the default below).

## 1. Pick the targets

Detect where you are running:

- **WSL**: `/proc/version` mentions `microsoft`. Default targets: `linux` and `windows` (the Windows host, through interop).
- **Linux** (not WSL): only `linux`.
- **Windows**: only `windows`. Report whether WSL is installed (the `check` output says so), but do not install it.

Run each target's script from the repo, never copies of it:

| Target | Command |
| --- | --- |
| linux | `${CLAUDE_PROJECT_DIR}/scripts/linux.sh <command>` |
| windows, from WSL | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w ${CLAUDE_PROJECT_DIR}/scripts/windows.ps1)" <command>` |
| windows, native | `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\windows.ps1 <command>` (`powershell.exe` when `pwsh` is missing) |

Every output line starts with a status: `ok`, `missing`, `differs`, `outdated`, `external`, `warn` or `changed`.

## 2. Check before changing anything

Run `check` for each target and summarize what is missing.

`install` overwrites config files that differ from the repo, so resolve every `differs` line first: show the diff between the file on the machine and the repo file, then ask the user which one wins.

- Repo wins: nothing to do, `install` copies it.
- Machine wins: copy the machine file over the repo file under `config/` and tell the user it is an uncommitted change in the repo.
- For Windows Terminal settings, show the keys that would change rather than a full diff; the merge only touches what `config/windows-terminal/settings.jsonc` lists.

## 3. Install

Run `install` for each target, `linux` first. Installs can take a few minutes; do not interrupt them.

## 4. Verify

Run `check` again for each target. The task is done only when every line is `ok` or `external`. For anything else, find the cause and fix it, or explain why it needs the user:

- `warn ... not in PATH` or a new-shell check failing right after installing tools: the current environment predates the install. Confirm the binary exists, then tell the user to open a new terminal.
- `warn ... lines added by chezmoi`: show those lines in `~/.bashrc` and offer to remove them (each is a comment ending in `(added by chezmoi)` plus the line after it).
- `warn` about WSL or Windows Terminal: tell the user the one command or action that fixes it (`wsl --install`, open Windows Terminal once and run `/install` again).
- A script error: read the error, fix the cause if it is in this repo's scripts, and run the step again. Do not work around a script by running its steps by hand.

## 5. Report

End with a short table per target: what changed, what was already in place, and anything left for the user (open a new terminal, restart Windows Terminal for a new font, uncommitted repo changes).

## Rules

- Never use `sudo`, and never install anything the scripts do not list. If the user wants a new tool, add it to the script's list and run `/install` again.
- Only change the files the scripts manage, plus the repo files the user chose in step 2.
- Do not run chezmoi, even if it is installed.
