# Shared bash setup, sourced from the end of ~/.bashrc (line added by scripts/linux.sh).

# 24-bit color for bat and others; Windows Terminal does not set it
[ -z "$COLORTERM" ] && export COLORTERM=truecolor

# mise first: Starship keeps hooks already in PROMPT_COMMAND (like mise's)
command -v mise >/dev/null && eval "$(mise activate bash)"
command -v starship >/dev/null && eval "$(starship init bash)"
