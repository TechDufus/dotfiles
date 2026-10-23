#!/usr/bin/env bash
# Cursor Agent CLI statusline — 3-line Catppuccin Mocha dashboard.
# Reads Cursor's StatusLinePayload JSON on stdin. Requires jq.

RESET='\033[0m'
C_SEP='\033[38;2;108;112;134m'
C_DIR='\033[38;2;116;199;236m'
C_SUBDIR='\033[38;2;127;132;156m'
C_BRANCH='\033[38;2;166;227;161m'
C_STATUS='\033[38;2;249;226;175m'
C_STATE='\033[38;2;243;139;168m'
C_MODEL='\033[38;2;203;166;247m'
C_TIME='\033[38;2;186;194;222m'
C_CACHE='\033[38;2;148;226;213m'
C_ADD='\033[38;2;166;227;161m'
C_DEL='\033[38;2;243;139;168m'
C_BAR_EMPTY='\033[38;2;69;71;90m'
C_DIM='\033[38;2;127;132;156m'
C_YOLO='\033[38;2;250;179;135m'
C_ASK='\033[38;2;137;180;250m'
C_BAR_GREEN='\033[38;2;166;227;161m'
C_BAR_YELLOW='\033[38;2;249;226;175m'
C_BAR_PEACH='\033[38;2;250;179;135m'
C_BAR_RED='\033[38;2;243;139;168m'

if ! command -v jq >/dev/null 2>&1; then
  printf 'cursor statusline: jq is required\n'
  exit 0
fi

input=$(cat)
if ! parsed=$(echo "$input" | jq -r '
  @sh "CURRENT_DIR=\(.workspace.current_dir // .cwd // "")",
  @sh "PROJECT_DIR=\(.workspace.project_dir // "")",
  @sh "MODEL=\(.model.display_name // .model.id // "")",
  @sh "MODEL_ID=\(.model.id // "")",
  @sh "PARAM_SUMMARY=\(.model.param_summary // "")",
  @sh "MAX_MODE=\(if .model.max_mode == true then "1" else "0" end)",
  @sh "CONTEXT_PCT=\(.context_window.used_percentage // "")",
  @sh "REMAINING_PCT=\(.context_window.remaining_percentage // "")",
  @sh "CTX_SIZE=\(.context_window.context_window_size // "")",
  @sh "INPUT_TOKENS=\(.context_window.total_input_tokens // "")",
  @sh "OUTPUT_TOKENS=\(.context_window.total_output_tokens // "")",
  @sh "CU_CACHE_CREATE=\((.context_window.current_usage // {}).cache_creation_input_tokens // "")",
  @sh "CU_CACHE_READ=\((.context_window.current_usage // {}).cache_read_input_tokens // "")",
  @sh "AUTORUN=\(if .autorun == true then "1" else "0" end)",
  @sh "SESSION_NAME=\(.session_name // "")",
  @sh "VIM_MODE=\(.vim.mode // "")",
  @sh "WORKTREE_NAME=\(.worktree.name // "")",
  @sh "OUTPUT_STYLE=\(.output_style.name // "")",
  @sh "TERM_WIDTH=\(.render_width_chars // 0)"
' 2>/dev/null); then
  printf 'cursor statusline: invalid payload\n'
  exit 0
fi
eval "$parsed"

if [[ "${TERM_WIDTH:-0}" -lt 40 ]]; then
  TERM_WIDTH=${COLUMNS:-120}
fi

DIR=${CURRENT_DIR/#"$HOME"/\~}
DIR_INDICATOR=""
if [[ -n "$PROJECT_DIR" && "$CURRENT_DIR" != "$PROJECT_DIR" ]]; then
  DIR_INDICATOR="${C_SUBDIR}↳ "
fi

collect_git_info() {
  local repo=$1
  GIT_OPTIONAL_LOCKS=1
  export GIT_OPTIONAL_LOCKS
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local BRANCH REMOTE_URL REMOTE_ICON
  BRANCH=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$repo" describe --tags --exact-match 2>/dev/null \
    || git -C "$repo" rev-parse --short HEAD 2>/dev/null)
  REMOTE_URL=$(git -C "$repo" config --get remote.origin.url 2>/dev/null)
  REMOTE_ICON=""
  case "$REMOTE_URL" in
    *github.com*) REMOTE_ICON=" " ;;
    *gitlab.com*) REMOTE_ICON="󰮠 " ;;
    *bitbucket.org*) REMOTE_ICON="󰂨 " ;;
    "") ;;
    *) REMOTE_ICON=" " ;;
  esac

  local STAGED=0 MODIFIED=0 UNTRACKED=0 DELETED=0 RENAMED=0 CONFLICTED=0
  local line
  while IFS= read -r line; do
    [[ "$line" =~ ^[MADRCU][MD\ ] ]] && STAGED=$((STAGED + 1))
    [[ "$line" =~ ^.[MD] ]] && MODIFIED=$((MODIFIED + 1))
    [[ "$line" =~ ^\?\? ]] && UNTRACKED=$((UNTRACKED + 1))
    [[ "$line" =~ ^[DR] || "$line" =~ ^.[DR] ]] && DELETED=$((DELETED + 1))
    [[ "$line" =~ ^R ]] && RENAMED=$((RENAMED + 1))
    [[ "$line" =~ ^(DD|AU|UD|UA|DU|AA|UU) ]] && CONFLICTED=$((CONFLICTED + 1))
  done < <(git -C "$repo" status --porcelain 2>/dev/null)

  local STASHED STATUS_INDICATORS="" UPSTREAM="" GIT_DIR GIT_STATE=""
  STASHED=$(git -C "$repo" stash list 2>/dev/null | wc -l | tr -d ' ')
  [[ $CONFLICTED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} =${CONFLICTED}"
  [[ $STAGED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} *${STAGED}"
  [[ $MODIFIED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} ~${MODIFIED}"
  [[ $RENAMED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} »${RENAMED}"
  [[ $DELETED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} -${DELETED}"
  [[ $UNTRACKED -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} +${UNTRACKED}"
  [[ ${STASHED:-0} -gt 0 ]] && STATUS_INDICATORS="${STATUS_INDICATORS} ⚑${STASHED}"

  if git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    local AHEAD BEHIND
    AHEAD=$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null)
    BEHIND=$(git -C "$repo" rev-list --count 'HEAD..@{u}' 2>/dev/null)
    if [[ ${AHEAD:-0} -gt 0 && ${BEHIND:-0} -gt 0 ]]; then
      UPSTREAM=" ⇡${AHEAD}⇣${BEHIND}"
    elif [[ ${AHEAD:-0} -gt 0 ]]; then
      UPSTREAM=" ⇡${AHEAD}"
    elif [[ ${BEHIND:-0} -gt 0 ]]; then
      UPSTREAM=" ⇣${BEHIND}"
    fi
  fi

  GIT_DIR=$(git -C "$repo" rev-parse --git-dir 2>/dev/null)
  if [[ -d "${GIT_DIR}/rebase-merge" || -d "${GIT_DIR}/rebase-apply" ]]; then
    GIT_STATE=" REBASE"
  elif [[ -f "${GIT_DIR}/MERGE_HEAD" ]]; then
    GIT_STATE=" MERGE"
  elif [[ -f "${GIT_DIR}/CHERRY_PICK_HEAD" ]]; then
    GIT_STATE=" CHERRY-PICK"
  elif [[ -f "${GIT_DIR}/BISECT_LOG" ]]; then
    GIT_STATE=" BISECT"
  fi

  printf '%s|%s|%s|%s|%s\n' "$BRANCH" "$REMOTE_ICON" "$STATUS_INDICATORS" "$UPSTREAM" "$GIT_STATE"
}

GIT_INFO=""
if [[ -n "$CURRENT_DIR" ]]; then
  GIT_INFO=$(collect_git_info "$CURRENT_DIR")
fi

GIT_BRANCH=""
GIT_REMOTE_ICON=""
GIT_STATUS_INDICATORS=""
GIT_UPSTREAM=""
GIT_STATE=""
if [[ -n "$GIT_INFO" ]]; then
  IFS='|' read -r GIT_BRANCH GIT_REMOTE_ICON GIT_STATUS_INDICATORS GIT_UPSTREAM GIT_STATE <<<"$GIT_INFO"
fi

fmt_tokens() {
  local n=$1
  [[ -z "$n" || "$n" == "null" ]] && return
  if [[ $n -ge 1000000 ]]; then
    printf '%sM' "$(awk -v n="$n" 'BEGIN { printf "%.1f", n / 1000000 }')"
  elif [[ $n -ge 1000 ]]; then
    printf '%sk' "$(awk -v n="$n" 'BEGIN { printf "%.1f", n / 1000 }')"
  else
    printf '%s' "$n"
  fi
}

# Cursor's display_name often already includes effort (e.g. "Extra High").
param_is_new() {
  local model=$1 summary=$2
  local model_lc summary_lc
  [[ -z "$summary" ]] && return 1
  model_lc=$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')
  summary_lc=$(printf '%s' "$summary" | tr '[:upper:]' '[:lower:]' | tr -d '()')
  summary_lc="${summary_lc#"${summary_lc%%[![:space:]]*}"}"
  summary_lc="${summary_lc%"${summary_lc##*[![:space:]]}"}"
  [[ -z "$summary_lc" ]] && return 1
  case " ${model_lc} " in
    *" ${summary_lc} "*) return 1 ;;
  esac
  return 0
}

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

build_progress_bar() {
  local pct=$1
  local bar_width=$(((TERM_WIDTH - 36) / 2))
  [[ $bar_width -lt 8 ]] && bar_width=8
  [[ $bar_width -gt 24 ]] && bar_width=24

  local bar_color
  bar_color=$(get_bar_color "$pct")
  local filled_full=$((pct * bar_width / 100))
  local remainder=$(((pct * bar_width * 8 / 100) % 8))
  local partial_chars=("" "▏" "▎" "▍" "▌" "▋" "▊" "▉")
  local empty_count=$((bar_width - filled_full))
  if [[ $remainder -gt 0 && $empty_count -gt 0 ]]; then
    empty_count=$((empty_count - 1))
  fi

  local bar="" i
  for ((i = 0; i < filled_full; i++)); do
    bar="${bar}█"
  done
  if [[ $remainder -gt 0 ]]; then
    bar="${bar}${partial_chars[$remainder]}"
  fi

  local result="${bar_color}${bar}${C_BAR_EMPTY}"
  for ((i = 0; i < empty_count; i++)); do
    result="${result}░"
  done
  printf '%s%s' "$result" "$RESET"
}

CONTEXT_PCT=${CONTEXT_PCT%%.*}
REMAINING_PCT=${REMAINING_PCT%%.*}
CACHE_HIT=""
CACHE_TOTAL=$((${CU_CACHE_READ:-0} + ${CU_CACHE_CREATE:-0}))
if [[ "$CACHE_TOTAL" != "0" ]]; then
  CACHE_HIT=$((${CU_CACHE_READ:-0} * 100 / CACHE_TOTAL))
fi

L1="${C_DIM}╭ ${DIR_INDICATOR}${C_DIR}${DIR}"
if [[ -n "$GIT_BRANCH" ]]; then
  L1="${L1}${C_DIM} on ${C_BRANCH}${GIT_REMOTE_ICON}${GIT_BRANCH}"
  if [[ $TERM_WIDTH -ge 80 && -n "$GIT_STATUS_INDICATORS" ]]; then
    L1="${L1}${C_STATUS}${GIT_STATUS_INDICATORS}"
  fi
  if [[ $TERM_WIDTH -ge 100 && -n "$GIT_UPSTREAM" ]]; then
    L1="${L1}${C_STATUS}${GIT_UPSTREAM}"
  fi
  if [[ -n "$GIT_STATE" ]]; then
    L1="${L1}${C_STATE}${GIT_STATE}"
  fi
fi
if [[ -n "$WORKTREE_NAME" ]]; then
  L1="${L1} ${C_SEP}│ ${C_CACHE}wt ${WORKTREE_NAME}"
fi
if [[ -n "$SESSION_NAME" ]]; then
  L1="${L1} ${C_SEP}│ ${C_TIME}${SESSION_NAME}"
fi

L2="${C_DIM}├ "
if [[ -n "$CONTEXT_PCT" ]]; then
  BAR_STR=$(build_progress_bar "$CONTEXT_PCT")
  BAR_COLOR=$(get_bar_color "$CONTEXT_PCT")
  L2="${L2}${BAR_STR} ${BAR_COLOR}${CONTEXT_PCT}%"
  if [[ -n "$REMAINING_PCT" ]]; then
    L2="${L2}${C_DIM} left ${REMAINING_PCT}%"
  fi
else
  BAR_STR=$(build_progress_bar 0)
  L2="${L2}${BAR_STR} ${C_DIM}—%"
fi
if [[ -n "$INPUT_TOKENS" || -n "$CTX_SIZE" ]]; then
  IN_FMT=$(fmt_tokens "$INPUT_TOKENS")
  SIZE_FMT=$(fmt_tokens "$CTX_SIZE")
  if [[ -n "$IN_FMT" && -n "$SIZE_FMT" ]]; then
    L2="${L2} ${C_SEP}│ ${C_TIME}${IN_FMT}/${SIZE_FMT}"
  elif [[ -n "$SIZE_FMT" ]]; then
    L2="${L2} ${C_SEP}│ ${C_TIME}win ${SIZE_FMT}"
  fi
fi
if [[ -n "$OUTPUT_TOKENS" && "$OUTPUT_TOKENS" != "null" ]]; then
  OUT_FMT=$(fmt_tokens "$OUTPUT_TOKENS")
  [[ -n "$OUT_FMT" ]] && L2="${L2} ${C_SEP}│ ${C_CACHE}out ${OUT_FMT}"
fi
if [[ $TERM_WIDTH -ge 90 ]]; then
  if [[ -n "$CACHE_HIT" ]]; then
    L2="${L2} ${C_SEP}│ ${C_CACHE}⚡${CACHE_HIT}%"
  fi
fi

L3="${C_DIM}╰ ${C_MODEL}${MODEL:-unknown}"
if param_is_new "$MODEL" "$PARAM_SUMMARY"; then
  L3="${L3} ${C_DIM}${PARAM_SUMMARY}"
fi
if [[ "$MAX_MODE" == "1" ]]; then
  L3="${L3} ${C_YOLO}MAX"
fi
if [[ "$AUTORUN" == "1" ]]; then
  L3="${L3} ${C_SEP}│ ${C_YOLO}YOLO"
else
  L3="${L3} ${C_SEP}│ ${C_ASK}ASK"
fi
if [[ -n "$VIM_MODE" ]]; then
  L3="${L3} ${C_SEP}│ ${C_TIME}vim ${VIM_MODE}"
fi
if [[ -n "$OUTPUT_STYLE" && "$OUTPUT_STYLE" != "default" ]]; then
  L3="${L3} ${C_SEP}│ ${C_DIM}${OUTPUT_STYLE}"
fi
if [[ -n "$MODEL_ID" && $TERM_WIDTH -ge 140 ]]; then
  L3="${L3} ${C_SEP}│ ${C_DIM}${MODEL_ID}"
fi

printf '%b\n' "${L1}${RESET}"
printf '%b\n' "${L2}${RESET}"
printf '%b' "${L3}${RESET}"
