#!/bin/sh
# Linux (WSL) setup: tools from GitHub releases, config files and the ~/.bashrc line.
#
# Usage: scripts/linux.sh <command>
#   check     report what is missing or differs from the repo (offline, changes nothing)
#   install   install missing tools, copy config files, add the ~/.bashrc line
#   outdated  report tools with a newer GitHub release (changes nothing)
#   upgrade   update tools to their latest GitHub release
#
# Every line of output starts with a status: ok, missing, differs, outdated,
# external, warn, changed or error. check and outdated exit with 1 when
# something needs attention.
set -eu

repo=$(cd "$(dirname "$0")/.." && pwd)
bin_dir="$HOME/.local/bin"

# Tools installed into ~/.local/bin (no sudo) from their latest GitHub release.
# A tool already found elsewhere in PATH (apt, brew...) is left to that package
# manager and reported as external.
#   command  repo  release asset for x86_64  release asset for aarch64
# {tag} in an asset name is replaced by the release tag (e.g. v1.2.3).
tools='
mise      jdx/mise                mise-{tag}-linux-x64-musl.tar.gz            mise-{tag}-linux-arm64-musl.tar.gz
starship  starship/starship       starship-x86_64-unknown-linux-musl.tar.gz   starship-aarch64-unknown-linux-musl.tar.gz
fastfetch fastfetch-cli/fastfetch fastfetch-linux-amd64.tar.gz                fastfetch-linux-aarch64.tar.gz
bat       sharkdp/bat             bat-{tag}-x86_64-unknown-linux-musl.tar.gz  bat-{tag}-aarch64-unknown-linux-musl.tar.gz
'

# Config files copied as is: source in config/, target in $HOME.
files='
starship.toml              .config/starship.toml
fastfetch/config.jsonc     .config/fastfetch/config.jsonc
mise/dotfiles.toml         .config/mise/conf.d/dotfiles.toml
bat/config                 .config/bat/config
bat/themes/Aurora.tmTheme  .config/bat/themes/Aurora.tmTheme
bash/dotfiles.sh           .config/bash/dotfiles.sh
'

# Appended to ~/.bashrc; everything else in the file is left alone.
bashrc_comment='# Shared setup: mise, Starship, COLORTERM (bxacosta/dotfiles)'
bashrc_line='[ -f ~/.config/bash/dotfiles.sh ] && . ~/.config/bash/dotfiles.sh'

attention=0

report() {
    printf '%-9s %s\n' "$1" "$2"
    case $1 in ok|external|changed) ;; *) attention=1 ;; esac
}

arch_column() {
    case $(uname -m) in
        x86_64|amd64) echo 3 ;;
        aarch64|arm64) echo 4 ;;
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
    esac
}

# latest_tag REPO: the latest release's tag, read from the redirect of a
# latest/download URL (no GitHub API, so no rate limit)
latest_tag() {
    url=$(curl -fsS -o /dev/null -w '%{redirect_url}' "https://github.com/$1/releases/latest/download/x")
    tag=${url%/x}
    tag=${tag##*/}
    [ -n "$tag" ] || { echo "No release found for $1" >&2; return 1; }
    echo "$tag"
}

# version_of FILE: first version number printed by FILE --version
version_of() {
    "$1" --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1
}

# install_release COMMAND REPO ASSET TAG: extracts the executable named COMMAND
# from the release archive into ~/.local/bin
install_release() {
    asset=$(echo "$3" | sed "s/{tag}/$4/g")
    tmp=$(mktemp -d)
    curl -fsSL "https://github.com/$2/releases/download/$4/$asset" | tar -xz -C "$tmp"
    file=$(find "$tmp" -type f -name "$1" -perm -u+x | head -n 1)
    [ -n "$file" ] || { rm -rf "$tmp"; echo "$1 not found in $asset" >&2; return 1; }
    mkdir -p "$bin_dir"
    install -m 755 "$file" "$bin_dir/$1"
    rm -rf "$tmp"
}

# for_each_tool FUNCTION: calls FUNCTION COMMAND REPO ASSET for each tool
for_each_tool() {
    col=$(arch_column)
    while read -r cmd repo_name amd64 arm64; do
        [ -n "$cmd" ] || continue
        if [ "$col" = 3 ]; then asset=$amd64; else asset=$arm64; fi
        "$1" "$cmd" "$repo_name" "$asset"
    done <<EOF
$tools
EOF
}

# tool_state COMMAND: managed (in ~/.local/bin), external or missing
tool_state() {
    if [ -x "$bin_dir/$1" ]; then echo managed
    elif command -v "$1" >/dev/null 2>&1; then echo external
    else echo missing
    fi
}

check_tool() {
    case $(tool_state "$1") in
        managed) report ok "$1 $(version_of "$bin_dir/$1")" ;;
        external) report external "$1 $(version_of "$(command -v "$1")") at $(command -v "$1"), not updated by this repo" ;;
        missing) report missing "$1" ;;
    esac
}

install_tool() {
    [ "$(tool_state "$1")" = missing ] || return 0
    tag=$(latest_tag "$2")
    install_release "$1" "$2" "$3" "$tag"
    report changed "$1 $tag installed"
}

outdated_tool() {
    case $(tool_state "$1") in
        external) report external "$1 at $(command -v "$1"): update it with its package manager"; return 0 ;;
        missing) report missing "$1"; return 0 ;;
    esac
    current=$(version_of "$bin_dir/$1")
    tag=$(latest_tag "$2")
    if [ "$current" = "${tag#v}" ]; then
        report ok "$1 $current"
    else
        report outdated "$1 $current -> ${tag#v}"
    fi
}

upgrade_tool() {
    [ "$(tool_state "$1")" = managed ] || return 0
    current=$(version_of "$bin_dir/$1")
    tag=$(latest_tag "$2")
    [ "$current" != "${tag#v}" ] || return 0
    install_release "$1" "$2" "$3" "$tag"
    report changed "$1 $current -> ${tag#v}"
}

# for_each_file FUNCTION: calls FUNCTION SOURCE TARGET for each config file
for_each_file() {
    while read -r src target; do
        [ -n "$src" ] || continue
        "$1" "$repo/config/$src" "$HOME/$target"
    done <<EOF
$files
EOF
}

check_file() {
    name="~/${2#"$HOME"/}"
    if [ ! -f "$2" ]; then report missing "$name"
    elif cmp -s "$1" "$2"; then report ok "$name"
    else report differs "$name (repo: ${1#"$repo"/})"
    fi
}

copy_file() {
    cmp -s "$1" "$2" 2>/dev/null && return 0
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
    report changed "~/${2#"$HOME"/}"
    case $2 in *.tmTheme) theme_changed=1 ;; esac
}

check_bashrc() {
    if grep -qxF "$bashrc_line" "$HOME/.bashrc" 2>/dev/null; then
        report ok "~/.bashrc sources ~/.config/bash/dotfiles.sh"
    else
        report missing "~/.bashrc line: $bashrc_line"
    fi
    if grep -q '(added by chezmoi)' "$HOME/.bashrc" 2>/dev/null; then
        report warn "~/.bashrc still has lines added by chezmoi; they duplicate ~/.config/bash/dotfiles.sh"
    fi
}

add_bashrc_line() {
    grep -qxF "$bashrc_line" "$HOME/.bashrc" 2>/dev/null && return 0
    {
        # a blank line before ours, and a newline if the file does not end with one
        if [ -s "$HOME/.bashrc" ]; then
            [ -z "$(tail -c 1 "$HOME/.bashrc")" ] || echo
            echo
        fi
        echo "$bashrc_comment"
        echo "$bashrc_line"
    } >>"$HOME/.bashrc"
    report changed "~/.bashrc line added"
}

bat_has_aurora() {
    command -v bat >/dev/null 2>&1 && bat --list-themes 2>/dev/null | grep -qx 'Aurora'
}

# A new interactive bash, as a new terminal would start it
check_shell() {
    case :$PATH: in
        *:"$bin_dir":*) ;;
        *) report warn "$bin_dir is not in PATH; open a new terminal (Ubuntu's ~/.profile adds it once it exists)" ;;
    esac
    out=$(bash -ic 'echo "${STARSHIP_SHELL:-}|${MISE_SHELL:-}|${COLORTERM:-}"' 2>/dev/null </dev/null || true)
    out=$(echo "$out" | tail -n 1)
    [ "${out%%|*}" = bash ] && report ok "new shell: Starship prompt" || report missing "new shell: Starship prompt not active"
    rest=${out#*|}
    [ "${rest%%|*}" = bash ] && report ok "new shell: mise activated" || report missing "new shell: mise not activated"
    [ -n "${rest#*|}" ] && report ok "new shell: COLORTERM=${rest#*|}" || report missing "new shell: COLORTERM not set"
    if command -v bat >/dev/null 2>&1; then
        bat_has_aurora && report ok "bat Aurora theme" || report missing "bat Aurora theme (run: bat cache --build)"
    fi
}

case ${1:-} in
    check)
        for_each_tool check_tool
        for_each_file check_file
        check_bashrc
        check_shell
        exit $attention
        ;;
    install)
        for_each_tool install_tool
        theme_changed=0
        for_each_file copy_file
        add_bashrc_line
        if [ $theme_changed = 1 ] || ! bat_has_aurora; then
            # bat may be installed but not yet in PATH
            bat=$(command -v bat || echo "$bin_dir/bat")
            if [ -x "$bat" ]; then
                "$bat" cache --build >/dev/null
                report changed "bat cache rebuilt"
            fi
        fi
        ;;
    outdated)
        for_each_tool outdated_tool
        exit $attention
        ;;
    upgrade)
        for_each_tool upgrade_tool
        ;;
    *)
        sed -n '4,9p' "$0" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
