#!/usr/bin/env bash

# Claude Code custom statusline — 3-line truecolor dashboard
# Catppuccin Mocha palette with box-drawing frame, progress bar, and derived metrics.
#
# Expects JSON input from Claude Code hooks (piped via stdin).
# Layout:
#   ╭  ~/.dotfiles on  main *2 +3 ~1 ⇡1
#   ├ ██████████████▌░░░░░░░░░░ 54% │ ⚡87% │ 󰓅 142t/s │ +156 -23
#   ╰  Opus │ $0.12 │ ⏱2.3s │ 󱑃 45s

# ─── Catppuccin Mocha truecolor palette ────────────────────────────────────────
RESET='\033[0m'
C_SEP='\033[38;2;108;112;134m'        # Overlay 0  — separators │
C_OS='\033[38;2;137;180;250m'         # Blue       — OS icon
C_DIR='\033[38;2;116;199;236m'        # Sapphire   — directory path
C_SUBDIR='\033[38;2;127;132;156m'     # Overlay 1  — ↳ indicator
C_BRANCH='\033[38;2;166;227;161m'     # Green      — git branch
C_STATUS='\033[38;2;249;226;175m'     # Yellow     — git status indicators
C_STATE='\033[38;2;243;139;168m'      # Red        — git state (REBASE etc)
C_MODEL='\033[38;2;203;166;247m'      # Mauve      — model name
C_COST='\033[38;2;250;179;135m'       # Peach      — cost
C_TIME='\033[38;2;186;194;222m'       # Subtext 1  — timing/duration
C_CACHE='\033[38;2;148;226;213m'      # Teal       — cache/velocity
C_ADD='\033[38;2;166;227;161m'        # Green      — code additions
C_DEL='\033[38;2;243;139;168m'        # Red        — code deletions
C_BAR_EMPTY='\033[38;2;69;71;90m'     # Surface 1  — bar empty fill ░
C_DIM='\033[38;2;127;132;156m'        # Overlay 1  — dim text ("on", "│")

# Progress bar color thresholds
C_BAR_GREEN='\033[38;2;166;227;161m'  # < 50%
C_BAR_YELLOW='\033[38;2;249;226;175m' # 50-70%
C_BAR_PEACH='\033[38;2;250;179;135m'  # 70-85%
C_BAR_RED='\033[38;2;243;139;168m'    # > 85%

# ─── Read JSON input once ──────────────────────────────────────────────────────
input=$(cat)

# ─── Single jq parse ───────────────────────────────────────────────────────────
# shellcheck disable=SC2046
eval "$(echo "$input" | jq -r '
  @sh "CURRENT_DIR=\(.workspace.current_dir // "")",
  @sh "PROJECT_DIR=\(.workspace.project_dir // "")",
  @sh "MODEL=\(.model.display_name // "")",
  @sh "COST=\(.cost.total_cost_usd // "")",
  @sh "API_DURATION=\(.cost.total_api_duration_ms // "")",
  @sh "TOTAL_DURATION=\(.cost.total_duration_ms // "")",
  @sh "LINES_ADDED=\(.cost.total_lines_added // "")",
  @sh "LINES_REMOVED=\(.cost.total_lines_removed // "")",
  @sh "CONTEXT_SIZE=\(.context_window.context_window_size // "")",
  @sh "TOTAL_OUTPUT_TOKENS=\(.context_window.total_output_tokens // "")",
  @sh "CU_INPUT=\(.context_window.current_usage.input_tokens // "")",
  @sh "CU_CACHE_CREATE=\(.context_window.current_usage.cache_creation_input_tokens // "")",
  @sh "CU_CACHE_READ=\(.context_window.current_usage.cache_read_input_tokens // "")"
')"

# ─── Terminal width ────────────────────────────────────────────────────────────
TERM_WIDTH=${COLUMNS:-200}

# ─── Path display ──────────────────────────────────────────────────────────────
DIR=${CURRENT_DIR/#"$HOME"/\~}
DIR_INDICATOR=""
if [[ -n "$PROJECT_DIR" ]] && [[ "$CURRENT_DIR" != "$PROJECT_DIR" ]]; then
  DIR_INDICATOR="${C_SUBDIR}↳ "
fi

# ─── OS icon ───────────────────────────────────────────────────────────────────
case "$(uname -s)" in
  Darwin)
    OS_ICON="" # Apple icon for macOS
    ;;
  Linux)
    if [[ -f /etc/os-release ]]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      case "$ID" in
        alpaquita) OS_ICON=" " ;;
        alpine) OS_ICON=" " ;;
        almalinux) OS_ICON=" " ;;
        amazon) OS_ICON=" " ;;
        android) OS_ICON=" " ;;
        arch) OS_ICON=" " ;;
        artix) OS_ICON=" " ;;
        centos) OS_ICON=" " ;;
        debian) OS_ICON=" " ;;
        dragonfly) OS_ICON=" " ;;
        emscripten) OS_ICON=" " ;;
        endeavouros) OS_ICON=" " ;;
        fedora) OS_ICON=" " ;;
        freebsd) OS_ICON=" " ;;
        garuda) OS_ICON="󰛓 " ;;
        gentoo) OS_ICON=" " ;;
        hardenedbsd) OS_ICON="󰞌 " ;;
        illumos) OS_ICON="󰈸 " ;;
        kali) OS_ICON=" " ;;
        linux) OS_ICON=" " ;;
        mabox) OS_ICON=" " ;;
        macos) OS_ICON=" " ;;
        manjaro) OS_ICON=" " ;;
        mariner) OS_ICON=" " ;;
        midnightbsd) OS_ICON=" " ;;
        mint) OS_ICON=" " ;;
        netbsd) OS_ICON=" " ;;
        nixos) OS_ICON=" " ;;
        openbsd) OS_ICON="󰈺 " ;;
        opensuse) OS_ICON=" " ;;
        oraclelinux) OS_ICON="󰌷 " ;;
        pop) OS_ICON=" " ;;
        raspbian) OS_ICON=" " ;;
        redhat) OS_ICON=" " ;;
        rhel) OS_ICON=" " ;;
        rockylinux) OS_ICON=" " ;;
        redox) OS_ICON="󰀘 " ;;
        solus) OS_ICON="󰠳 " ;;
        suse) OS_ICON=" " ;;
        ubuntu) OS_ICON=" " ;;
        void) OS_ICON=" " ;;
        windows) OS_ICON="󰍲 " ;;
        *) OS_ICON=" " ;;
      esac
    else
      OS_ICON=""
    fi
    ;;
  FreeBSD)
    OS_ICON=""
    ;;
  CYGWIN* | MINGW* | MSYS*)
    OS_ICON="󰍲 "
    ;;
  *)
    OS_ICON=""
    ;;
esac

# ─── Git information (subshell to contain cd) ─────────────────────────────────
GIT_INFO=""
if [[ -n "$CURRENT_DIR" ]]; then
  GIT_INFO=$(
    cd "$CURRENT_DIR" 2>/dev/null || exit 0
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

    # Branch name
    BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)

    # Remote provider icon
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
        ((STAGED++))
      fi
      if [[ "$line" =~ ^.[MD] ]]; then
        ((MODIFIED++))
      fi
      if [[ "$line" =~ ^\?\? ]]; then
        ((UNTRACKED++))
      fi
      if [[ "$line" =~ ^[DR] ]] || [[ "$line" =~ ^.[DR] ]]; then
        ((DELETED++))
      fi
      if [[ "$line" =~ ^R ]]; then
        ((RENAMED++))
      fi
      if [[ "$line" =~ ^(DD|AU|UD|UA|DU|AA|UU) ]]; then
        ((CONFLICTED++))
      fi
    done < <(git status --porcelain 2>/dev/null)

    # Stashed changes
    STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
    [[ $STASH_COUNT -gt 0 ]] && STASHED=$STASH_COUNT

    # Build status indicators
    STATUS_INDICATORS=""
    [[ $CONFLICTED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} =${CONFLICTED}"
    [[ $STAGED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} *${STAGED}"
    [[ $MODIFIED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} ~${MODIFIED}"
    [[ $RENAMED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} »${RENAMED}"
    [[ $DELETED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} -${DELETED}"
    [[ $UNTRACKED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} +${UNTRACKED}"
    [[ $STASHED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} ⚑${STASHED}"

    # Upstream ahead/behind
    UPSTREAM=""
    if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
      AHEAD=$(git rev-list --count '@{u}..HEAD' 2>/dev/null)
      BEHIND=$(git rev-list --count 'HEAD..@{u}' 2>/dev/null)

      if [[ $AHEAD -gt 0 ]] && [[ $BEHIND -gt 0 ]]; then
        UPSTREAM=" ⇡${AHEAD}⇣${BEHIND}"
      elif [[ $AHEAD -gt 0 ]]; then
        UPSTREAM=" ⇡${AHEAD}"
      elif [[ $BEHIND -gt 0 ]]; then
        UPSTREAM=" ⇣${BEHIND}"
      fi
    fi

    # Git state detection (rebase, merge, cherry-pick, bisect)
    GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
    GIT_STATE=""
    if [[ -d "${GIT_DIR}/rebase-merge" ]] || [[ -d "${GIT_DIR}/rebase-apply" ]]; then
      GIT_STATE=" REBASE"
    elif [[ -f "${GIT_DIR}/MERGE_HEAD" ]]; then
      GIT_STATE=" MERGE"
    elif [[ -f "${GIT_DIR}/CHERRY_PICK_HEAD" ]]; then
      GIT_STATE=" CHERRY-PICK"
    elif [[ -f "${GIT_DIR}/BISECT_LOG" ]]; then
      GIT_STATE=" BISECT"
    fi

    # Emit pipe-delimited string for the parent shell to split
    # Fields: branch | remote_icon | status_indicators | upstream | git_state
    echo "${BRANCH}|${REMOTE_ICON}|${STATUS_INDICATORS}|${UPSTREAM}|${GIT_STATE}"
  )
fi

# Parse git subshell output
GIT_BRANCH=""
GIT_REMOTE_ICON=""
GIT_STATUS_INDICATORS=""
GIT_UPSTREAM=""
GIT_STATE=""
if [[ -n "$GIT_INFO" ]]; then
  IFS='|' read -r GIT_BRANCH GIT_REMOTE_ICON GIT_STATUS_INDICATORS GIT_UPSTREAM GIT_STATE <<< "$GIT_INFO"
fi

# ─── Derived metrics ──────────────────────────────────────────────────────────

# Context percentage
CONTEXT_PCT=""
if [[ -n "$CONTEXT_SIZE" ]] && [[ "$CONTEXT_SIZE" != "0" ]]; then
  CU_INPUT=${CU_INPUT:-0}
  CU_CACHE_CREATE=${CU_CACHE_CREATE:-0}
  CU_CACHE_READ=${CU_CACHE_READ:-0}
  TOTAL_CONTEXT=$((CU_INPUT + CU_CACHE_CREATE + CU_CACHE_READ))
  CONTEXT_PCT=$(( TOTAL_CONTEXT * 100 / CONTEXT_SIZE ))
fi

# Cache hit percentage
CACHE_HIT=""
CACHE_TOTAL=$(( ${CU_CACHE_READ:-0} + ${CU_CACHE_CREATE:-0} ))
if [[ "$CACHE_TOTAL" != "0" ]]; then
  CACHE_HIT=$(( ${CU_CACHE_READ:-0} * 100 / CACHE_TOTAL ))
else
  CACHE_HIT=""
fi

# Token velocity (tokens per second)
TOKEN_VELOCITY=""
if [[ -n "$API_DURATION" ]] && [[ "$API_DURATION" != "0" ]] && [[ -n "$TOTAL_OUTPUT_TOKENS" ]]; then
  TOKEN_VELOCITY=$(( TOTAL_OUTPUT_TOKENS * 1000 / API_DURATION ))
fi

# Cost formatted
COST_FMT=""
if [[ -n "$COST" ]]; then
  COST_FMT=$(printf "\$%.2f" "$COST")
fi

# Format a duration in ms to human-readable (Xm Xs or Xs)
fmt_duration() {
  local ms=$1
  local total_secs=$((ms / 1000))
  local days=$((total_secs / 86400))
  local hours=$(( (total_secs % 86400) / 3600 ))
  local mins=$(( (total_secs % 3600) / 60 ))
  local secs=$((total_secs % 60))
  local out=""
  [[ $days -gt 0 ]] && out="${days}d "
  [[ $hours -gt 0 ]] && out="${out}${hours}h "
  [[ $mins -gt 0 ]] && out="${out}${mins}m "
  out="${out}${secs}s"
  echo "$out"
}

# API duration formatted
API_FMT=""
if [[ -n "$API_DURATION" ]] && [[ "$API_DURATION" != "0" ]]; then
  API_FMT=$(fmt_duration "$API_DURATION")
fi

# Session duration formatted
SESSION_FMT=""
if [[ -n "$TOTAL_DURATION" ]] && [[ "$TOTAL_DURATION" != "0" ]]; then
  SESSION_FMT=$(fmt_duration "$TOTAL_DURATION")
fi

# ─── Bar color helper ─────────────────────────────────────────────────────────
get_bar_color() {
  local pct=$1
  if [[ $pct -lt 50 ]]; then
    echo "$C_BAR_GREEN"
  elif [[ $pct -le 70 ]]; then
    echo "$C_BAR_YELLOW"
  elif [[ $pct -le 85 ]]; then
    echo "$C_BAR_PEACH"
  else
    echo "$C_BAR_RED"
  fi
}

# ─── Progress bar builder ─────────────────────────────────────────────────────
build_progress_bar() {
  local pct=$1
  # Adaptive bar width: max(5, min(25, (TERM_WIDTH - 30) / 2))
  local bar_width=$(( (TERM_WIDTH - 30) / 2 ))
  [[ $bar_width -lt 5 ]] && bar_width=5
  [[ $bar_width -gt 25 ]] && bar_width=25

  local bar_color
  bar_color=$(get_bar_color "$pct")

  # Sub-character precision
  local filled_full=$((pct * bar_width / 100))
  local remainder=$(((pct * bar_width * 8 / 100) % 8))
  local partial_chars=("" "▏" "▎" "▍" "▌" "▋" "▊" "▉")
  local empty_count=$((bar_width - filled_full))

  # If there's a partial character, subtract one from empty
  if [[ $remainder -gt 0 ]] && [[ $empty_count -gt 0 ]]; then
    empty_count=$((empty_count - 1))
  fi

  # Build the bar string
  local bar=""
  # Filled portion
  local i
  for ((i = 0; i < filled_full; i++)); do
    bar="${bar}█"
  done
  # Partial character
  if [[ $remainder -gt 0 ]]; then
    bar="${bar}${partial_chars[$remainder]}"
  fi

  # Compose with colors
  local result="${bar_color}${bar}${C_BAR_EMPTY}"
  for ((i = 0; i < empty_count; i++)); do
    result="${result}░"
  done
  result="${result}${RESET}"

  echo "${result}"
}

# ─── Build LINE 1: directory + git ─────────────────────────────────────────────
L1="${C_OS}${OS_ICON} ${DIR_INDICATOR}${C_DIR}${DIR}"

if [[ -n "$GIT_BRANCH" ]]; then
  L1="${L1}${C_DIM} on ${C_BRANCH}${GIT_REMOTE_ICON} ${GIT_BRANCH}"

  if [[ $TERM_WIDTH -ge 80 ]]; then
    if [[ -n "$GIT_STATUS_INDICATORS" ]]; then
      L1="${L1}${C_STATUS}${GIT_STATUS_INDICATORS}"
    fi
  fi

  if [[ $TERM_WIDTH -ge 100 ]]; then
    if [[ -n "$GIT_UPSTREAM" ]]; then
      L1="${L1}${C_STATUS}${GIT_UPSTREAM}"
    fi
  fi

  if [[ -n "$GIT_STATE" ]]; then
    L1="${L1}${C_STATE}${GIT_STATE}"
  fi

  # Code changes on line 1, after git info
  LINES_ADDED=${LINES_ADDED:-0}
  LINES_REMOVED=${LINES_REMOVED:-0}
  if [[ $TERM_WIDTH -ge 80 ]]; then
    if [[ "$LINES_ADDED" != "0" ]] || [[ "$LINES_REMOVED" != "0" ]]; then
      L1="${L1} ${C_SEP}│ ${C_ADD}+${LINES_ADDED} ${C_DEL}-${LINES_REMOVED}"
    fi
  fi
fi

# ─── Build LINE 2: progress bar + derived metrics ──────────────────────────────
L2=""

if [[ -n "$CONTEXT_PCT" ]]; then
  BAR_STR=$(build_progress_bar "$CONTEXT_PCT")

  local_bar_text_color=$(get_bar_color "$CONTEXT_PCT")

  L2="${L2}${BAR_STR} ${local_bar_text_color}${CONTEXT_PCT}%"

  # Cache hit
  if [[ $TERM_WIDTH -ge 100 ]]; then
    if [[ -n "$CACHE_HIT" ]]; then
      L2="${L2} ${C_SEP}│ ${C_CACHE}⚡${CACHE_HIT}%"
    else
      L2="${L2} ${C_SEP}│ ${C_CACHE}⚡—"
    fi
  fi

  # Token velocity
  if [[ $TERM_WIDTH -ge 140 ]]; then
    if [[ -n "$TOKEN_VELOCITY" ]]; then
      L2="${L2} ${C_SEP}│ ${C_CACHE}󰓅 ${TOKEN_VELOCITY}t/s"
    else
      L2="${L2} ${C_SEP}│ ${C_CACHE}󰓅 —"
    fi
  fi
else
  BAR_STR=$(build_progress_bar 0)
  L2="${L2}${BAR_STR} ${C_DIM}—%"
fi

# ─── Build LINE 3: model + cost + timing ───────────────────────────────────────
L3=""

if [[ -n "$MODEL" ]]; then
  L3="${L3}${C_MODEL} ${MODEL}"
fi

if [[ -n "$COST_FMT" ]]; then
  L3="${L3} ${C_SEP}│ ${C_COST}${COST_FMT}"
fi

if [[ $TERM_WIDTH -ge 100 ]]; then
  if [[ -n "$API_FMT" ]]; then
    L3="${L3} ${C_SEP}│ ${C_TIME}⏱ ${API_FMT}"
  fi
fi

if [[ $TERM_WIDTH -ge 120 ]]; then
  if [[ -n "$SESSION_FMT" ]]; then
    L3="${L3} ${C_SEP}│ ${C_TIME}󱑃 ${SESSION_FMT}"
  fi
fi

# ─── Output ────────────────────────────────────────────────────────────────────
printf '%b\n' "${L1}${RESET}"
printf '%b\n' "${L2}${RESET}"
printf '%b' "${L3}${RESET}"
