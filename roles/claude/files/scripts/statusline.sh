#!/bin/bash

# Claude Code custom statusline script
# This script generates a statusline with user, host, directory, git info, and model
#
# Expects JSON input from Claude Code hooks with this structure:
# {
#   "hook_event_name": "Status",
#   "session_id": "abc123...",
#   "transcript_path": "/path/to/transcript.json",
#   "cwd": "/current/working/directory",
#   "model": {
#     "id": "claude-opus-4-1",
#     "display_name": "Opus"
#   },
#   "workspace": {
#     "current_dir": "/current/working/directory",
#     "project_dir": "/original/project/directory"
#   }
# }

# Use 256-color codes for better compatibility
RESET='\033[0m'
BRIGHT_GREEN='\033[38;5;46m'    # Bright green (256-color)
BRIGHT_CYAN='\033[38;5;51m'     # Bright cyan (256-color)
BRIGHT_YELLOW='\033[38;5;226m'  # Bright yellow (256-color)
BRIGHT_MAGENTA='\033[38;5;201m' # Bright magenta (256-color)
BRIGHT_WHITE='\033[38;5;231m'   # Bright white (256-color)
GRAY='\033[38;5;244m'           # Light gray (256-color)

# Color assignments for statusline elements
DIR_COLOR="${BRIGHT_CYAN}"      # Bright cyan for directory
BRANCH_COLOR="${BRIGHT_GREEN}"  # Always bright green for branch
STATUS_COLOR="${BRIGHT_YELLOW}" # Bright yellow for status indicators
TEXT_DIM="${BRIGHT_WHITE}"      # Bright white for separators
ERROR_COLOR="${BRIGHT_MAGENTA}" # Bright magenta for errors
MODEL_COLOR="${BRIGHT_MAGENTA}" # Bright magenta for model
OS_ICON_COLOR="${BRIGHT_WHITE}" # Bright white for OS icon

input=$(cat)

# Model information
get_model_name() { echo "$input" | jq -r '.model.display_name // empty'; }
get_model_id() { echo "$input" | jq -r '.model.id // empty'; }

# Workspace information
get_current_dir() { echo "$input" | jq -r '.workspace.current_dir // empty'; }
get_project_dir() { echo "$input" | jq -r '.workspace.project_dir // empty'; }

# Session and hook information
get_session_id() { echo "$input" | jq -r '.session_id // empty'; }
get_hook_event() { echo "$input" | jq -r '.hook_event_name // empty'; }
get_transcript_path() { echo "$input" | jq -r '.transcript_path // empty'; }

# Working directory (legacy field)
get_cwd() { echo "$input" | jq -r '.cwd // empty'; }

# Version information (if available)
get_version() { echo "$input" | jq -r '.version // empty'; }

# Cost and usage information (new fields)
get_total_cost() { echo "$input" | jq -r '.cost.total_cost_usd // empty'; }
get_api_duration() { echo "$input" | jq -r '.cost.total_api_duration_ms // empty'; }
get_lines_added() { echo "$input" | jq -r '.cost.total_lines_added // empty'; }
get_lines_removed() { echo "$input" | jq -r '.cost.total_lines_removed // empty'; }
get_output_style() { echo "$input" | jq -r '.output_style.name // empty'; }

# Get Claude's current directory from the input JSON
CLAUDE_DIR=$(get_current_dir)
PROJECT_DIR=$(get_project_dir)
# Replace home directory with ~ for display
DIR=${CLAUDE_DIR/#$HOME/\~}

# Check if we're in a subdirectory of the project
DIR_INDICATOR=""
if [[ -n "$PROJECT_DIR" ]] && [[ "$CLAUDE_DIR" != "$PROJECT_DIR" ]]; then
  # Show a subdirectory indicator when not at project root
  DIR_INDICATOR="${GRAY}↳ "
fi

MODEL=$(get_model_name)

# Get cost and usage information
COST=$(get_total_cost)
API_DURATION=$(get_api_duration)
LINES_ADDED=$(get_lines_added)
LINES_REMOVED=$(get_lines_removed)

# Format cost display with color coding
COST_DISPLAY=""
if [[ -n "$COST" ]]; then
  # Format cost: $0.01 for < $1, $1.23 for >= $1
  if (( $(echo "$COST < 1" | bc -l) )); then
    COST_FORMATTED=$(printf "$%.2f" "$COST")
  else
    COST_FORMATTED=$(printf "$%.2f" "$COST")
  fi
  
  # Simple color for cost display (just for visibility, not warning)
  # Using cyan to match directory color - clean and informational
  COST_COLOR="${BRIGHT_CYAN}"
  
  COST_DISPLAY="${TEXT_DIM} | ${COST_COLOR}${COST_FORMATTED}"
fi

# Format API duration (convert ms to seconds)
API_TIME_DISPLAY=""
if [[ -n "$API_DURATION" ]]; then
  API_SECONDS=$(echo "scale=1; $API_DURATION / 1000" | bc)
  API_TIME_DISPLAY="${TEXT_DIM} | ${GRAY}${API_SECONDS}s"
fi

# Format code changes
CODE_CHANGES=""
if [[ -n "$LINES_ADDED" ]] || [[ -n "$LINES_REMOVED" ]]; then
  LINES_ADDED=${LINES_ADDED:-0}
  LINES_REMOVED=${LINES_REMOVED:-0}
  if [[ $LINES_ADDED -gt 0 ]] || [[ $LINES_REMOVED -gt 0 ]]; then
    CODE_CHANGES="${TEXT_DIM} | ${BRIGHT_GREEN}+${LINES_ADDED}${TEXT_DIM}/${BRIGHT_MAGENTA}-${LINES_REMOVED}"
  fi
fi

# Get terminal width for adaptive formatting
# Check COLUMNS env var first (for testing), then tput cols
TERM_WIDTH=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}

# Get OS icon (like P10k)
case "$(uname -s)" in
  Darwin)
    OS_ICON="" # Apple icon for macOS
    ;;
  Linux)
    # Check for specific distros
    if [[ -f /etc/os-release ]]; then
      . /etc/os-release
      case "$ID" in
        alpaquita) OS_ICON=" " ;;
        alpine) OS_ICON=" " ;;
        almalinux) OS_ICON=" " ;;
        amazon) OS_ICON=" " ;;
        android) OS_ICON=" " ;;
        arch) OS_ICON=" " ;;
        artix) OS_ICON=" " ;;
        centos) OS_ICON=" " ;;
        debian) OS_ICON=" " ;;
        dragonfly) OS_ICON=" " ;;
        emscripten) OS_ICON=" " ;;
        endeavouros) OS_ICON=" " ;;
        fedora) OS_ICON=" " ;;
        freebsd) OS_ICON=" " ;;
        garuda) OS_ICON="󰛓 " ;;
        gentoo) OS_ICON=" " ;;
        hardenedbsd) OS_ICON="󰞌 " ;;
        illumos) OS_ICON="󰈸 " ;;
        kali) OS_ICON=" " ;;
        linux) OS_ICON=" " ;;
        mabox) OS_ICON=" " ;;
        macos) OS_ICON=" " ;;
        manjaro) OS_ICON=" " ;;
        mariner) OS_ICON=" " ;;
        midnightbsd) OS_ICON=" " ;;
        mint) OS_ICON=" " ;;
        netbsd) OS_ICON=" " ;;
        nixos) OS_ICON=" " ;;
        openbsd) OS_ICON="󰈺 " ;;
        opensuse) OS_ICON=" " ;;
        oraclelinux) OS_ICON="󰌷 " ;;
        pop) OS_ICON=" " ;;
        raspbian) OS_ICON=" " ;;
        redhat) OS_ICON=" " ;;
        rhel) OS_ICON=" " ;;
        rockylinux) OS_ICON=" " ;;
        redox) OS_ICON="󰀘 " ;;
        solus) OS_ICON="󰠳 " ;;
        suse) OS_ICON=" " ;;
        ubuntu) OS_ICON=" " ;;
        void) OS_ICON=" " ;;
        windows) OS_ICON="󰍲 " ;;
        *) OS_ICON=" " ;;             # Generic Linux penguin
      esac
    else
      OS_ICON="" # Generic Linux penguin
    fi
    ;;
  FreeBSD)
    OS_ICON="" # FreeBSD icon
    ;;
  CYGWIN* | MINGW* | MSYS*)
    OS_ICON="󰍲 " # Windows icon
    ;;
  *)
    OS_ICON="" # Generic Unix icon
    ;;
esac

# Get git information for Claude's current directory
GIT_INFO=""
if [[ -n "$CLAUDE_DIR" ]] && cd "$CLAUDE_DIR" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Get branch name
  BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
  BRANCH_ICON=""

  # Get remote provider icon
  REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null)
  REMOTE_ICON=""
  if [[ -n "$REMOTE_URL" ]]; then
    case "$REMOTE_URL" in
      *github.com*) REMOTE_ICON=" " ;;   # GitHub
      *gitlab.com*) REMOTE_ICON="󰮠" ;;    # GitLab
      *bitbucket.org*) REMOTE_ICON="󰂨" ;; # Bitbucket
      *git.*) REMOTE_ICON="" ;;          # Generic git
      *) REMOTE_ICON="" ;;               # No icon for unknown
    esac
  fi

  # Count different types of changes
  MODIFIED=0
  STAGED=0
  UNTRACKED=0
  DELETED=0
  RENAMED=0
  CONFLICTED=0
  STASHED=0

  while IFS= read -r line; do
    if [[ "$line" =~ ^[MADRCU][MD\ ] ]]; then
      # Staged changes (first character is not space or ?)
      ((STAGED++))
    fi
    if [[ "$line" =~ ^.[MD] ]]; then
      # Modified but not staged (second character is M or D)
      ((MODIFIED++))
    fi
    if [[ "$line" =~ ^\?\? ]]; then
      # Untracked files
      ((UNTRACKED++))
    fi
    if [[ "$line" =~ ^[DR] ]] || [[ "$line" =~ ^.[DR] ]]; then
      # Deleted or removed files
      ((DELETED++))
    fi
    if [[ "$line" =~ ^R ]]; then
      # Renamed files
      ((RENAMED++))
    fi
    if [[ "$line" =~ ^(DD|AU|UD|UA|DU|AA|UU) ]]; then
      # Conflicted files
      ((CONFLICTED++))
    fi
  done < <(git status --porcelain 2>/dev/null)

  # Check for stashed changes
  STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
  [[ $STASH_COUNT -gt 0 ]] && STASHED=$STASH_COUNT

  # Build status indicators with starship icons
  STATUS_INDICATORS=""
  [[ $CONFLICTED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} 🏳${CONFLICTED}"
  [[ $STAGED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} +${STAGED}"
  [[ $MODIFIED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS}  ${MODIFIED}"
  [[ $RENAMED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} 襁${RENAMED}"
  [[ $DELETED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS}  ${DELETED}"
  [[ $UNTRACKED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS}  ${UNTRACKED}"
  [[ $STASHED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS}  ${STASHED}"

  # Count commits ahead/behind upstream (using starship format)
  UPSTREAM=""
  if git rev-parse --abbrev-ref @{u} >/dev/null 2>&1; then
    AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null)
    BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null)

    if [[ $AHEAD -gt 0 ]] && [[ $BEHIND -gt 0 ]]; then
      UPSTREAM=" ⇕⇡${AHEAD}⇣${BEHIND}"
    elif [[ $AHEAD -gt 0 ]]; then
      UPSTREAM=" ⇡${AHEAD}"
    elif [[ $BEHIND -gt 0 ]]; then
      UPSTREAM=" ⇣${BEHIND}"
    fi
  fi

  # Check for merge/rebase/cherry-pick in progress
  GIT_STATE=""
  if [[ -d .git/rebase-merge ]] || [[ -d .git/rebase-apply ]]; then
    GIT_STATE=" REBASE"
  elif [[ -f .git/MERGE_HEAD ]]; then
    GIT_STATE=" MERGE"
  elif [[ -f .git/CHERRY_PICK_HEAD ]]; then
    GIT_STATE=" CHERRY"
  elif [[ -f .git/BISECT_LOG ]]; then
    GIT_STATE=" BISECT"
  fi

  # Build colored git info (always green branch like your prompt)
  GIT_INFO="${TEXT_DIM} on ${BRANCH_COLOR}${REMOTE_ICON}${BRANCH_ICON} ${BRANCH}${STATUS_COLOR}${STATUS_INDICATORS}${STATUS_COLOR}${UPSTREAM}${ERROR_COLOR}${GIT_STATE}"
fi

# Build the statusline with P10k-inspired colors (two-line format)
# Line 1: Directory and git info (variable length)
# Line 2: Model and metrics (fixed positions)

# Use └─ as the line connector for the second line
CONNECTOR="${TEXT_DIM}└─ "

# Only adapt what metrics to show based on terminal width, not dir/git formatting
if [[ $TERM_WIDTH -gt 120 ]]; then
  # Full format: Show all metrics
  printf "${OS_ICON_COLOR}${OS_ICON} ${DIR_INDICATOR}${DIR_COLOR}${DIR}${GIT_INFO}${RESET}\n"
  printf "${CONNECTOR}${MODEL_COLOR}${MODEL}${COST_DISPLAY}${API_TIME_DISPLAY}${CODE_CHANGES}${RESET}"
elif [[ $TERM_WIDTH -gt 80 ]]; then
  # Medium format: Show dir, git, model, and cost only
  printf "${OS_ICON_COLOR}${OS_ICON} ${DIR_INDICATOR}${DIR_COLOR}${DIR}${GIT_INFO}${RESET}\n"
  printf "${CONNECTOR}${MODEL_COLOR}${MODEL}${COST_DISPLAY}${RESET}"
else
  # Compact format: Show dir, git, model, and cost only (same as medium)
  printf "${OS_ICON_COLOR}${OS_ICON} ${DIR_INDICATOR}${DIR_COLOR}${DIR}${GIT_INFO}${RESET}\n"
  printf "${CONNECTOR}${MODEL_COLOR}${MODEL}${COST_DISPLAY}${RESET}"
fi
