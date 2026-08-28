#!/usr/bin/env zsh

# Catppuccin Mocha color codes. Keep these shell-local so agent subprocesses
# do not inherit a pile of prompt/theme variables.
typeset -g RESTORE=$'\033[0m'
typeset -g NC=$'\033[0m'
typeset -g BOLD=$'\033[1m'

typeset -g CAT_ROSEWATER=$'\033[38;2;245;224;220m'  # #f5e0dc
typeset -g CAT_FLAMINGO=$'\033[38;2;242;205;205m'   # #f2cdcd
typeset -g CAT_PINK=$'\033[38;2;245;194;231m'       # #f5c2e7
typeset -g CAT_MAUVE=$'\033[38;2;203;166;247m'      # #cba6f7
typeset -g CAT_RED=$'\033[38;2;243;139;168m'        # #f38ba8
typeset -g CAT_MAROON=$'\033[38;2;235;160;172m'     # #eba0ac
typeset -g CAT_PEACH=$'\033[38;2;250;179;135m'      # #fab387
typeset -g CAT_YELLOW=$'\033[38;2;249;226;175m'     # #f9e2af
typeset -g CAT_GREEN=$'\033[38;2;166;227;161m'      # #a6e3a1
typeset -g CAT_TEAL=$'\033[38;2;148;226;213m'       # #94e2d5
typeset -g CAT_SKY=$'\033[38;2;137;220;235m'        # #89dceb
typeset -g CAT_SAPPHIRE=$'\033[38;2;116;199;236m'   # #74c7ec
typeset -g CAT_BLUE=$'\033[38;2;137;180;250m'       # #89b4fa
typeset -g CAT_LAVENDER=$'\033[38;2;180;190;254m'   # #b4befe
typeset -g CAT_TEXT=$'\033[38;2;205;214;244m'       # #cdd6f4
typeset -g CAT_SUBTEXT1=$'\033[38;2;186;194;222m'   # #bac2de
typeset -g CAT_SUBTEXT0=$'\033[38;2;166;173;200m'   # #a6adc8
typeset -g CAT_OVERLAY2=$'\033[38;2;147;153;178m'   # #9399b2
typeset -g CAT_OVERLAY1=$'\033[38;2;127;132;156m'   # #7f849c
typeset -g CAT_OVERLAY0=$'\033[38;2;108;112;134m'   # #6c7086
typeset -g CAT_SURFACE2=$'\033[38;2;88;91;112m'     # #585b70
typeset -g CAT_SURFACE1=$'\033[38;2;69;71;90m'      # #45475a
typeset -g CAT_SURFACE0=$'\033[38;2;49;50;68m'      # #313244
typeset -g CAT_BASE=$'\033[38;2;30;30;46m'          # #1e1e2e
typeset -g CAT_MANTLE=$'\033[38;2;24;24;37m'        # #181825
typeset -g CAT_CRUST=$'\033[38;2;17;17;27m'         # #11111b

typeset -g BLACK="$CAT_CRUST"
typeset -g RED="$CAT_RED"
typeset -g GREEN="$CAT_GREEN"
typeset -g YELLOW="$CAT_YELLOW"
typeset -g BLUE="$CAT_BLUE"
typeset -g PURPLE="$CAT_MAUVE"
typeset -g CYAN="$CAT_TEAL"
typeset -g WHITE="$CAT_TEXT"
typeset -g LIGHTGRAY="$CAT_SUBTEXT0"

typeset -g LBLACK="$BOLD$CAT_SURFACE0"
typeset -g LRED="$BOLD$CAT_RED"
typeset -g LGREEN="$BOLD$CAT_GREEN"
typeset -g LYELLOW="$BOLD$CAT_YELLOW"
typeset -g LBLUE="$BOLD$CAT_BLUE"
typeset -g LPURPLE="$BOLD$CAT_MAUVE"
typeset -g LCYAN="$BOLD$CAT_TEAL"

typeset -g ORANGE="$CAT_PEACH"
typeset -g SEA="$CAT_SAPPHIRE"
typeset -g OVERWRITE=$'\e[1A\e[K'

typeset -g COLOR_ESC=$'\033'
typeset -g COLOR_BOLD="${COLOR_ESC}[1m"

typeset -g CHECK_MARK="${GREEN}\xE2\x9C\x93${NC}"
typeset -g X_MARK="${RED}\xE2\x9C\x96${NC}"
typeset -g PIN="${RED}\xF0\x9F\x93\x8C${NC}"
typeset -g CLOCK="${GREEN}\xE2\x8C\x9B${NC}"
typeset -g ARROW="${SEA}\xE2\x96\xB6${NC}"
typeset -g BOOK="${RED}\xF0\x9F\x93\x8B${NC}"
typeset -g HOT="${ORANGE}\xF0\x9F\x94\xA5${NC}"
typeset -g WARNING="${RED}\xF0\x9F\x9A\xA8${NC}"
typeset -g RIGHT_ANGLE="${GREEN}\xE2\x88\x9F${NC}"

export GH_DASH_CONFIG="$HOME/.config/gh-dash/config.yaml"

export DOTFILES="$HOME/.dotfiles"
export GOBIN="$HOME/.local/bin"
export BIN="$HOME/.local/bin"

export OTEL_EXPORTER_OTLP_PROTOCOL="http/json"
export OTEL_EXPORTER_OTLP_LOGS_PROTOCOL="http/json"

# Corporate policies may restrict /tmp; only needed when tmux is actually present.
if command -v tmux >/dev/null 2>&1; then
  mkdir -p "$HOME/tmp/tmux"
  export TMUX_TMPDIR="$HOME/tmp/tmux"
fi

export CLAUDE_HOME="$HOME/.claude"
export CLAUDE_SETTINGS="$CLAUDE_HOME/settings.json"
export CLAUDE_MEMORY="$CLAUDE_HOME/AGENTS.md"

typeset -g DIM="$CAT_OVERLAY0"
typeset -g LIGHT_GREEN="$CAT_GREEN"
typeset -g LIGHT_YELLOW="$CAT_YELLOW"
typeset -g LIGHT_RED="$CAT_RED"

typeset -g BOX_TOP="╔══════════════════════════════════════════════════════════╗"
typeset -g BOX_MID="║"
typeset -g BOX_BOT="╚══════════════════════════════════════════════════════════╝"
typeset -g DIVIDER="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
