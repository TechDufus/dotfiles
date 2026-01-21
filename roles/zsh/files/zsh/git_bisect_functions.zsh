#!/usr/bin/env zsh
# Git Bisect Functions - Enhanced git bisect with visual feedback and state management

# Main entry point for git bisect commands
gbisect() {
  case "$1" in
    start)
      shift
      gbisect-start "$@"
      ;;
    good)
      gbisect-good
      ;;
    bad)
      gbisect-bad
      ;;
    skip)
      gbisect-skip
      ;;
    reset)
      gbisect-reset
      ;;
    progress)
      gbisect-progress
      ;;
    log)
      gbisect-log
      ;;
    help)
      gbisect-help
      ;;
    save)
      gbisect-save
      ;;
    restore)
      gbisect-restore
      ;;
    status)
      gbisect-status
      ;;
    *)
      gbisect-help
      ;;
  esac
}

# Display help and quick reference for git bisect commands
gbisect-help() {
  echo ""
  echo -e "${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "${CAT_SAPPHIRE}${BOX_MID}${NC}  🔍 ${CAT_TEXT}Git Bisect Quick Reference${NC}                           ${CAT_SAPPHIRE}${BOX_MID}${NC}"
  echo -e "${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  echo ""

  echo -e "${BOLD}${CAT_GREEN}What is Git Bisect?${NC}"
  echo -e "  Git bisect uses binary search to find which commit introduced a bug."
  echo -e "  It helps you efficiently narrow down problematic commits."
  echo ""

  echo -e "${BOLD}${CAT_YELLOW}Basic Workflow:${NC}"
  echo -e "  1. ${CAT_BLUE}gbisect start${NC} [bad] [good]  - Start bisecting"
  echo -e "  2. Test the current commit"
  echo -e "  3. ${CAT_GREEN}gbisect good${NC}              - Mark commit as good"
  echo -e "     ${CAT_RED}gbisect bad${NC}               - Mark commit as bad"
  echo -e "     ${CAT_OVERLAY1}gbisect skip${NC}              - Skip untestable commit"
  echo -e "  4. Repeat until the bad commit is found"
  echo -e "  5. ${CAT_MAUVE}gbisect reset${NC}             - Exit bisect mode"
  echo ""

  echo -e "${BOLD}${CAT_SAPPHIRE}Enhanced Commands:${NC}"
  echo -e "  ${CAT_BLUE}gbisect progress${NC}  - Show visual progress bar"
  echo -e "  ${CAT_BLUE}gbisect log${NC}       - View enhanced bisect log"
  echo -e "  ${CAT_BLUE}gbisect status${NC}    - Show current bisect state"
  echo -e "  ${CAT_BLUE}gbisect save${NC}      - Save bisect state to file"
  echo -e "  ${CAT_BLUE}gbisect restore${NC}   - Restore saved bisect state"
  echo ""

  echo -e "${CAT_OVERLAY1}Tip: Use 'gbisect' or 'gbisect help' to see this reference${NC}"
  echo ""
}

# Start a git bisect session
gbisect-start() {
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo -e "${CAT_RED}✗ Error:${NC} Not in a git repository"
    return 1
  fi

  # Check if bisect is already in progress
  if [[ -f .git/BISECT_START ]]; then
    echo -e "${CAT_YELLOW}⚠ Warning:${NC} Bisect already in progress"
    echo -e "  Use ${CAT_MAUVE}gbisect reset${NC} to stop the current bisect session"
    return 1
  fi

  local bad_commit="${1:-HEAD}"
  local good_commit="$2"

  echo ""
  echo -e "${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "${CAT_SAPPHIRE}${BOX_MID}${NC}  🚀 ${CAT_TEXT}Starting Git Bisect${NC}                                  ${CAT_SAPPHIRE}${BOX_MID}${NC}"
  echo -e "${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  echo ""

  # If good commit not provided, prompt for it
  if [[ -z "$good_commit" ]]; then
    echo -e "${CAT_YELLOW}Enter good commit (or press Enter to select interactively):${NC}"
    read -r good_input

    if [[ -z "$good_input" ]]; then
      # Interactive selection using git log
      echo -e "${CAT_BLUE}Select a known good commit:${NC}"
      good_commit=$(git log --oneline -20 | fzf --height=40% --reverse --prompt="Select good commit> " | awk '{print $1}')

      if [[ -z "$good_commit" ]]; then
        echo -e "${CAT_RED}✗ Error:${NC} No commit selected"
        return 1
      fi
    else
      good_commit="$good_input"
    fi
  fi

  # Validate commits exist
  if ! git rev-parse --verify "$bad_commit" >/dev/null 2>&1; then
    echo -e "${CAT_RED}✗ Error:${NC} Bad commit '$bad_commit' not found"
    return 1
  fi

  if ! git rev-parse --verify "$good_commit" >/dev/null 2>&1; then
    echo -e "${CAT_RED}✗ Error:${NC} Good commit '$good_commit' not found"
    return 1
  fi

  echo -e "${CAT_GREEN}Starting bisect:${NC}"
  echo -e "  ${CAT_RED}Bad commit:${NC}  $bad_commit"
  echo -e "  ${CAT_GREEN}Good commit:${NC} $good_commit"
  echo ""

  # Start git bisect
  git bisect start "$bad_commit" "$good_commit"

  # Show initial progress
  echo ""
  gbisect-progress
}

# Mark current commit as good
gbisect-good() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${CAT_RED}✗ Error:${NC} No bisect in progress"
    echo -e "  Use ${CAT_BLUE}gbisect start${NC} to begin bisecting"
    return 1
  fi

  local commit=$(git rev-parse --short HEAD)
  echo -e "${CAT_GREEN}✓ Marking commit ${commit} as good${NC}"

  git bisect good

  # Check if bisect is complete
  if [[ ! -f .git/BISECT_START ]]; then
    echo ""
    echo -e "${CAT_GREEN}✨ Bisect complete!${NC}"
    echo -e "The first bad commit has been found."
  else
    echo ""
    gbisect-progress
  fi
}

# Mark current commit as bad
gbisect-bad() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${CAT_RED}✗ Error:${NC} No bisect in progress"
    echo -e "  Use ${CAT_BLUE}gbisect start${NC} to begin bisecting"
    return 1
  fi

  local commit=$(git rev-parse --short HEAD)
  echo -e "${CAT_RED}✗ Marking commit ${commit} as bad${NC}"

  git bisect bad

  # Check if bisect is complete
  if [[ ! -f .git/BISECT_START ]]; then
    echo ""
    echo -e "${CAT_GREEN}✨ Bisect complete!${NC}"
    echo -e "The first bad commit has been found."
  else
    echo ""
    gbisect-progress
  fi
}

# Skip current commit
gbisect-skip() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${CAT_RED}✗ Error:${NC} No bisect in progress"
    echo -e "  Use ${CAT_BLUE}gbisect start${NC} to begin bisecting"
    return 1
  fi

  local commit=$(git rev-parse --short HEAD)
  echo -e "${CAT_YELLOW}⊘ Skipping commit ${commit}${NC}"

  git bisect skip

  echo ""
  gbisect-progress
}

# Reset bisect state
gbisect-reset() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${CAT_YELLOW}⚠ No bisect in progress${NC}"
    return 0
  fi

  echo -e "${CAT_MAUVE}Resetting bisect state...${NC}"
  git bisect reset
  echo -e "${CAT_GREEN}✓ Bisect session ended${NC}"
}

# Show visual progress of bisect
gbisect-progress() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${CAT_YELLOW}No bisect in progress${NC}"
    return 1
  fi

  # Get total remaining commits
  local total=$(git bisect visualize --oneline 2>/dev/null | wc -l | tr -d ' ')

  if [[ $total -eq 0 ]]; then
    echo -e "${CAT_GREEN}✨ Bisect complete!${NC}"
    return 0
  fi

  # Calculate revisions left and steps
  local left=$(( (total - 1) / 2 ))
  local steps=0

  # Calculate log2 for steps remaining (bash doesn't have log, so we approximate)
  local temp=$total
  while [[ $temp -gt 1 ]]; do
    temp=$(( temp / 2 ))
    steps=$(( steps + 1 ))
  done

  # Try to get original range for percentage calculation
  local percent=0
  if [[ -f .git/BISECT_GOOD && -f .git/BISECT_BAD ]]; then
    local good_ref=$(cat .git/BISECT_GOOD | head -1)
    local bad_ref=$(cat .git/BISECT_BAD | head -1)
    local original=$(git rev-list --count ${good_ref}..${bad_ref} 2>/dev/null)

    if [[ -n "$original" && $original -gt 0 ]]; then
      percent=$(( 100 - (100 * total / original) ))
    fi
  fi

  # Draw progress bar
  local bar_width=30
  local filled=$(( percent * bar_width / 100 ))
  local empty=$(( bar_width - filled ))

  echo -e "${BOLD}${CAT_SAPPHIRE}Bisect Progress${NC}"
  echo -e "${CAT_SURFACE2}${DIVIDER}${NC}"

  # Progress bar
  echo -ne "${CAT_GREEN}["
  for ((i=0; i<filled; i++)); do
    echo -ne "█"
  done
  echo -ne "${CAT_OVERLAY0}"
  for ((i=0; i<empty; i++)); do
    echo -ne "░"
  done
  echo -e "${CAT_GREEN}]${NC} ${CAT_YELLOW}${percent}%${NC}"

  echo ""
  echo -e "${CAT_TEXT}Commits to test:${NC} ${CAT_YELLOW}$total${NC}"
  echo -e "${CAT_TEXT}Revisions left:${NC}  ${CAT_BLUE}$left${NC}"
  echo -e "${CAT_TEXT}Steps remaining:${NC} ${CAT_GREEN}~$steps${NC}"

  # Show current commit being tested
  echo ""
  echo -e "${CAT_TEXT}Currently testing:${NC}"
  git log -1 --format="  ${CAT_YELLOW}%h${NC} - %s ${CAT_OVERLAY1}(%cr)${NC}" HEAD

  echo -e "${CAT_SURFACE2}${DIVIDER}${NC}"
}

# Enhanced bisect log viewer
gbisect-log() {
  if [[ ! -f .git/BISECT_LOG ]]; then
    echo -e "${CAT_YELLOW}No bisect log available${NC}"
    echo -e "  Start a bisect session with ${CAT_BLUE}gbisect start${NC}"
    return 1
  fi

  echo ""
  echo -e "${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "${CAT_SAPPHIRE}${BOX_MID}${NC}  📋 ${CAT_TEXT}Git Bisect Log${NC}                                       ${CAT_SAPPHIRE}${BOX_MID}${NC}"
  echo -e "${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  echo ""

  # Parse and colorize the bisect log
  while IFS= read -r line; do
    case "$line" in
      *"git bisect start"*)
        echo -e "${CAT_BLUE}🚀 $line${NC}"
        ;;
      *"# good:"*)
        echo -e "${CAT_GREEN}✓ $line${NC}"
        ;;
      *"# bad:"*)
        echo -e "${CAT_RED}✗ $line${NC}"
        ;;
      *"# skip:"*)
        echo -e "${CAT_YELLOW}⊘ $line${NC}"
        ;;
      *"git bisect good"*)
        echo -e "  ${CAT_GREEN}$line${NC}"
        ;;
      *"git bisect bad"*)
        echo -e "  ${CAT_RED}$line${NC}"
        ;;
      *"git bisect skip"*)
        echo -e "  ${CAT_YELLOW}$line${NC}"
        ;;
      *)
        echo -e "  ${CAT_OVERLAY1}$line${NC}"
        ;;
    esac
  done < .git/BISECT_LOG

  echo ""
}

# Save bisect state
gbisect-save() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${CAT_RED}✗ Error:${NC} No bisect in progress to save"
    return 1
  fi

  # Create state directory
  local state_dir="$HOME/.local/state/git-bisect"
  mkdir -p "$state_dir"

  # Get repository name for state file
  local repo_name=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)
  if [[ -z "$repo_name" ]]; then
    repo_name="unknown"
  fi

  local timestamp=$(date +%Y%m%d_%H%M%S)
  local state_file="$state_dir/${repo_name}_${timestamp}.state"

  echo -e "${CAT_BLUE}Saving bisect state...${NC}"

  # Save all BISECT files
  tar czf "$state_file" .git/BISECT_* 2>/dev/null

  if [[ $? -eq 0 ]]; then
    echo -e "${CAT_GREEN}✓ Bisect state saved to:${NC}"
    echo -e "  ${CAT_OVERLAY1}$state_file${NC}"

    # Create a symlink to latest state
    ln -sf "$state_file" "$state_dir/${repo_name}_latest.state"
  else
    echo -e "${CAT_RED}✗ Error:${NC} Failed to save bisect state"
    return 1
  fi
}

# Restore bisect state
gbisect-restore() {
  local state_dir="$HOME/.local/state/git-bisect"

  # Check if state directory exists
  if [[ ! -d "$state_dir" ]]; then
    echo -e "${CAT_YELLOW}No saved bisect states found${NC}"
    return 1
  fi

  # Get repository name
  local repo_name=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)
  if [[ -z "$repo_name" ]]; then
    repo_name="unknown"
  fi

  # Look for latest state file
  local latest_state="$state_dir/${repo_name}_latest.state"

  if [[ ! -f "$latest_state" ]]; then
    # Try to find any state file for this repo
    local state_files=($state_dir/${repo_name}_*.state(N))

    if [[ ${#state_files[@]} -eq 0 ]]; then
      echo -e "${CAT_YELLOW}No saved states found for this repository${NC}"
      return 1
    fi

    # Use fzf to select if multiple states exist
    if [[ ${#state_files[@]} -gt 1 ]]; then
      echo -e "${CAT_BLUE}Select a state to restore:${NC}"
      local selected=$(printf '%s\n' "${state_files[@]}" | fzf --height=40% --reverse --prompt="Select state> ")

      if [[ -z "$selected" ]]; then
        echo -e "${CAT_YELLOW}No state selected${NC}"
        return 1
      fi
      latest_state="$selected"
    else
      latest_state="${state_files[1]}"
    fi
  fi

  # Check if already in bisect
  if [[ -f .git/BISECT_START ]]; then
    echo -e "${CAT_YELLOW}⚠ Warning:${NC} Bisect already in progress"
    echo -ne "  Overwrite current bisect state? (y/N): "
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo -e "${CAT_YELLOW}Restore cancelled${NC}"
      return 1
    fi
  fi

  echo -e "${CAT_BLUE}Restoring bisect state from:${NC}"
  echo -e "  ${CAT_OVERLAY1}$latest_state${NC}"

  # Extract state files
  tar xzf "$latest_state" 2>/dev/null

  if [[ $? -eq 0 ]]; then
    echo -e "${CAT_GREEN}✓ Bisect state restored${NC}"
    echo ""
    gbisect-status
  else
    echo -e "${CAT_RED}✗ Error:${NC} Failed to restore bisect state"
    return 1
  fi
}

# Show current bisect status
gbisect-status() {
  echo ""
  echo -e "${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "${CAT_SAPPHIRE}${BOX_MID}${NC}  📊 ${CAT_TEXT}Git Bisect Status${NC}                                    ${CAT_SAPPHIRE}${BOX_MID}${NC}"
  echo -e "${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  echo ""

  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${CAT_OVERLAY1}No bisect in progress${NC}"
    echo ""
    echo -e "${CAT_TEXT}Start bisecting with:${NC} ${CAT_BLUE}gbisect start [bad] [good]${NC}"
  else
    echo -e "${CAT_GREEN}✓ Bisect in progress${NC}"
    echo ""

    # Show good/bad commits
    if [[ -f .git/BISECT_GOOD ]]; then
      local good_ref=$(cat .git/BISECT_GOOD | head -1)
      echo -e "${CAT_TEXT}Good commit:${NC}"
      git log -1 --format="  ${CAT_GREEN}%h${NC} - %s ${CAT_OVERLAY1}(%cr)${NC}" "$good_ref" 2>/dev/null
    fi

    if [[ -f .git/BISECT_BAD ]]; then
      local bad_ref=$(cat .git/BISECT_BAD | head -1)
      echo -e "${CAT_TEXT}Bad commit:${NC}"
      git log -1 --format="  ${CAT_RED}%h${NC} - %s ${CAT_OVERLAY1}(%cr)${NC}" "$bad_ref" 2>/dev/null
    fi

    echo ""
    echo -e "${CAT_TEXT}Current HEAD:${NC}"
    git log -1 --format="  ${CAT_YELLOW}%h${NC} - %s ${CAT_OVERLAY1}(%cr)${NC}" HEAD

    echo ""

    # Show remaining commits count
    local total=$(git bisect visualize --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [[ $total -gt 0 ]]; then
      echo -e "${CAT_TEXT}Commits left to test:${NC} ${CAT_YELLOW}$total${NC}"
    fi
  fi

  echo ""
}

# Add aliases for convenience
alias gbs='gbisect start'
alias gbg='gbisect good'
alias gbb='gbisect bad'
alias gbr='gbisect reset'
alias gbp='gbisect progress'
alias gbl='gbisect log'
alias gbst='gbisect status'