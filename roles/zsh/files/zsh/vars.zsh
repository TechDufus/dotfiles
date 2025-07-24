#!/usr/bin/env zsh

# Catppuccin Mocha color codes
export RESTORE='\033[0m'
export NC='\033[0m'
export BOLD='\033[1m'

# Catppuccin Mocha Base Colors
export CAT_ROSEWATER='\033[38;2;245;224;220m'  # #f5e0dc
export CAT_FLAMINGO='\033[38;2;242;205;205m'   # #f2cdcd
export CAT_PINK='\033[38;2;245;194;231m'       # #f5c2e7
export CAT_MAUVE='\033[38;2;203;166;247m'      # #cba6f7
export CAT_RED='\033[38;2;243;139;168m'        # #f38ba8
export CAT_MAROON='\033[38;2;235;160;172m'     # #eba0ac
export CAT_PEACH='\033[38;2;250;179;135m'      # #fab387
export CAT_YELLOW='\033[38;2;249;226;175m'     # #f9e2af
export CAT_GREEN='\033[38;2;166;227;161m'      # #a6e3a1
export CAT_TEAL='\033[38;2;148;226;213m'       # #94e2d5
export CAT_SKY='\033[38;2;137;220;235m'        # #89dceb
export CAT_SAPPHIRE='\033[38;2;116;199;236m'   # #74c7ec
export CAT_BLUE='\033[38;2;137;180;250m'       # #89b4fa
export CAT_LAVENDER='\033[38;2;180;190;254m'   # #b4befe
export CAT_TEXT='\033[38;2;205;214;244m'       # #cdd6f4
export CAT_SUBTEXT1='\033[38;2;186;194;222m'   # #bac2de
export CAT_SUBTEXT0='\033[38;2;166;173;200m'   # #a6adc8
export CAT_OVERLAY2='\033[38;2;147;153;178m'   # #9399b2
export CAT_OVERLAY1='\033[38;2;127;132;156m'   # #7f849c
export CAT_OVERLAY0='\033[38;2;108;112;134m'   # #6c7086
export CAT_SURFACE2='\033[38;2;88;91;112m'     # #585b70
export CAT_SURFACE1='\033[38;2;69;71;90m'      # #45475a
export CAT_SURFACE0='\033[38;2;49;50;68m'      # #313244
export CAT_BASE='\033[38;2;30;30;46m'          # #1e1e2e
export CAT_MANTLE='\033[38;2;24;24;37m'        # #181825
export CAT_CRUST='\033[38;2;17;17;27m'         # #11111b

# Legacy color mappings (for compatibility)
export BLACK="$CAT_CRUST"
export RED="$CAT_RED"
export GREEN="$CAT_GREEN"
export YELLOW="$CAT_YELLOW"
export BLUE="$CAT_BLUE"
export PURPLE="$CAT_MAUVE"
export CYAN="$CAT_TEAL"
export WHITE="$CAT_TEXT"
export LIGHTGRAY="$CAT_SUBTEXT0"

# Light/Bold variants
export LBLACK="$BOLD$CAT_SURFACE0"
export LRED="$BOLD$CAT_RED"
export LGREEN="$BOLD$CAT_GREEN"
export LYELLOW="$BOLD$CAT_YELLOW"
export LBLUE="$BOLD$CAT_BLUE"
export LPURPLE="$BOLD$CAT_MAUVE"
export LCYAN="$BOLD$CAT_TEAL"

# Additional legacy mappings
export ORANGE="$CAT_PEACH"

# Special
export SEA="$CAT_SAPPHIRE"
export OVERWRITE='\e[1A\e[K'

export COLOR_ESC=$(printf '\033')
export COLOR_BOLD=${COLOR_ESC}$(printf '[1m')

#emoji codes
export CHECK_MARK="${GREEN}\xE2\x9C\x93${NC}"
export X_MARK="${RED}\xE2\x9C\x96${NC}"
export PIN="${RED}\xF0\x9F\x93\x8C${NC}"
export CLOCK="${GREEN}\xE2\x8C\x9B${NC}"
export ARROW="${SEA}\xE2\x96\xB6${NC}"
export BOOK="${RED}\xF0\x9F\x93\x8B${NC}"
export HOT="${ORANGE}\xF0\x9F\x94\xA5${NC}"
export WARNING="${RED}\xF0\x9F\x9A\xA8${NC}"
export RIGHT_ANGLE="${GREEN}\xE2\x88\x9F${NC}"

export GH_DASH_CONFIG="$HOME/.config/gh-dash/config.yaml"

export DF_HOME="$HOME/dev/raft/data-fabric"
export RDP_HOME="$HOME/dev/raft/rdp"
export DF_INFRA_HOME="$HOME/dev/raft/df-infra"
export DFDEV_GIT_PROTOCOL="ssh"
export AWS_PROFILE="Raft"

# User
export DOTFILES="$HOME/.dotfiles"
export GOBIN="$HOME/.local/bin"
export BIN="$HOME/.local/bin"

# Claude
export CLAUDE_HOME="$HOME/.claude"
export CLAUDE_SETTINGS="$CLAUDE_HOME/settings.json"
export CLAUDE_MEMORY="$CLAUDE_HOME/CLAUDE.md"

# Additional color codes for formatting
export DIM="$CAT_OVERLAY0"
export LIGHT_GREEN="$CAT_GREEN"
export LIGHT_YELLOW="$CAT_YELLOW"
export LIGHT_RED="$CAT_RED"

# Box drawing characters
export BOX_TOP="╔══════════════════════════════════════════════════════════╗"
export BOX_MID="║"
export BOX_BOT="╚══════════════════════════════════════════════════════════╝"
export DIVIDER="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

