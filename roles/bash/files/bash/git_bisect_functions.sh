#!/usr/bin/env bash
# Git Bisect Functions for Bash - Enhanced git bisect with visual feedback

# Color definitions for bash (simplified)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}    Git Bisect Quick Reference${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  echo -e "${BOLD}${GREEN}What is Git Bisect?${NC}"
  echo "  Git bisect uses binary search to find which commit introduced a bug."
  echo "  It helps you efficiently narrow down problematic commits."
  echo ""

  echo -e "${BOLD}${YELLOW}Basic Workflow:${NC}"
  echo -e "  1. ${BLUE}gbisect start${NC} [bad] [good]  - Start bisecting"
  echo "  2. Test the current commit"
  echo -e "  3. ${GREEN}gbisect good${NC}              - Mark commit as good"
  echo -e "     ${RED}gbisect bad${NC}               - Mark commit as bad"
  echo -e "     ${GRAY}gbisect skip${NC}              - Skip untestable commit"
  echo "  4. Repeat until the bad commit is found"
  echo -e "  5. ${PURPLE}gbisect reset${NC}             - Exit bisect mode"
  echo ""

  echo -e "${BOLD}${CYAN}Enhanced Commands:${NC}"
  echo -e "  ${BLUE}gbisect progress${NC}  - Show visual progress"
  echo -e "  ${BLUE}gbisect log${NC}       - View bisect log"
  echo -e "  ${BLUE}gbisect status${NC}    - Show current state"
  echo -e "  ${BLUE}gbisect save${NC}      - Save bisect state"
  echo -e "  ${BLUE}gbisect restore${NC}   - Restore saved state"
  echo ""

  echo -e "${GRAY}Tip: Use 'gbisect' or 'gbisect help' to see this reference${NC}"
  echo ""
}

# Start a git bisect session
gbisect-start() {
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    return 1
  fi

  # Check if bisect is already in progress
  if [[ -f .git/BISECT_START ]]; then
    echo -e "${YELLOW}Warning: Bisect already in progress${NC}"
    echo -e "  Use ${PURPLE}gbisect reset${NC} to stop the current bisect session"
    return 1
  fi

  local bad_commit="${1:-HEAD}"
  local good_commit="$2"

  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}    Starting Git Bisect${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  # If good commit not provided, prompt for it
  if [[ -z "$good_commit" ]]; then
    echo -e "${YELLOW}Enter good commit:${NC}"
    read -r good_commit

    if [[ -z "$good_commit" ]]; then
      echo -e "${RED}Error: Good commit required${NC}"
      return 1
    fi
  fi

  # Validate commits exist
  if ! git rev-parse --verify "$bad_commit" >/dev/null 2>&1; then
    echo -e "${RED}Error: Bad commit '$bad_commit' not found${NC}"
    return 1
  fi

  if ! git rev-parse --verify "$good_commit" >/dev/null 2>&1; then
    echo -e "${RED}Error: Good commit '$good_commit' not found${NC}"
    return 1
  fi

  echo -e "${GREEN}Starting bisect:${NC}"
  echo -e "  ${RED}Bad commit:${NC}  $bad_commit"
  echo -e "  ${GREEN}Good commit:${NC} $good_commit"
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
    echo -e "${RED}Error: No bisect in progress${NC}"
    echo -e "  Use ${BLUE}gbisect start${NC} to begin bisecting"
    return 1
  fi

  local commit=$(git rev-parse --short HEAD)
  echo -e "${GREEN}✓ Marking commit ${commit} as good${NC}"

  git bisect good

  # Check if bisect is complete
  if [[ ! -f .git/BISECT_START ]]; then
    echo ""
    echo -e "${GREEN}Bisect complete!${NC}"
    echo "The first bad commit has been found."
  else
    echo ""
    gbisect-progress
  fi
}

# Mark current commit as bad
gbisect-bad() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${RED}Error: No bisect in progress${NC}"
    echo -e "  Use ${BLUE}gbisect start${NC} to begin bisecting"
    return 1
  fi

  local commit=$(git rev-parse --short HEAD)
  echo -e "${RED}✗ Marking commit ${commit} as bad${NC}"

  git bisect bad

  # Check if bisect is complete
  if [[ ! -f .git/BISECT_START ]]; then
    echo ""
    echo -e "${GREEN}Bisect complete!${NC}"
    echo "The first bad commit has been found."
  else
    echo ""
    gbisect-progress
  fi
}

# Skip current commit
gbisect-skip() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${RED}Error: No bisect in progress${NC}"
    echo -e "  Use ${BLUE}gbisect start${NC} to begin bisecting"
    return 1
  fi

  local commit=$(git rev-parse --short HEAD)
  echo -e "${YELLOW}Skipping commit ${commit}${NC}"

  git bisect skip

  echo ""
  gbisect-progress
}

# Reset bisect state
gbisect-reset() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${YELLOW}No bisect in progress${NC}"
    return 0
  fi

  echo -e "${PURPLE}Resetting bisect state...${NC}"
  git bisect reset
  echo -e "${GREEN}✓ Bisect session ended${NC}"
}

# Show progress of bisect
gbisect-progress() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${YELLOW}No bisect in progress${NC}"
    return 1
  fi

  # Get total remaining commits
  local total=$(git bisect visualize --oneline 2>/dev/null | wc -l | tr -d ' ')

  if [[ $total -eq 0 ]]; then
    echo -e "${GREEN}Bisect complete!${NC}"
    return 0
  fi

  # Calculate revisions left and steps
  local left=$(( (total - 1) / 2 ))
  local steps=0

  # Calculate log2 for steps remaining
  local temp=$total
  while [[ $temp -gt 1 ]]; do
    temp=$(( temp / 2 ))
    steps=$(( steps + 1 ))
  done

  # Try to get original range for percentage
  local percent=0
  if [[ -f .git/BISECT_GOOD && -f .git/BISECT_BAD ]]; then
    local good_ref=$(head -1 .git/BISECT_GOOD)
    local bad_ref=$(head -1 .git/BISECT_BAD)
    local original=$(git rev-list --count ${good_ref}..${bad_ref} 2>/dev/null)

    if [[ -n "$original" && $original -gt 0 ]]; then
      percent=$(( 100 - (100 * total / original) ))
    fi
  fi

  # Draw simple progress bar
  local bar_width=20
  local filled=$(( percent * bar_width / 100 ))
  local empty=$(( bar_width - filled ))

  echo -e "${BOLD}${CYAN}Bisect Progress${NC}"
  echo "----------------------------------------"

  # Progress bar
  echo -n "["
  for ((i=0; i<filled; i++)); do
    echo -n "#"
  done
  for ((i=0; i<empty; i++)); do
    echo -n "-"
  done
  echo "] ${percent}%"

  echo ""
  echo -e "Commits to test: ${YELLOW}$total${NC}"
  echo -e "Revisions left:  ${BLUE}$left${NC}"
  echo -e "Steps remaining: ${GREEN}~$steps${NC}"

  # Show current commit being tested
  echo ""
  echo "Currently testing:"
  git log -1 --format="  %h - %s (%cr)" HEAD

  echo "----------------------------------------"
}

# View bisect log
gbisect-log() {
  if [[ ! -f .git/BISECT_LOG ]]; then
    echo -e "${YELLOW}No bisect log available${NC}"
    echo -e "  Start a bisect session with ${BLUE}gbisect start${NC}"
    return 1
  fi

  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}    Git Bisect Log${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  # Display the bisect log with basic coloring
  while IFS= read -r line; do
    case "$line" in
      *"git bisect start"*)
        echo -e "${BLUE}$line${NC}"
        ;;
      *"# good:"*)
        echo -e "${GREEN}$line${NC}"
        ;;
      *"# bad:"*)
        echo -e "${RED}$line${NC}"
        ;;
      *"# skip:"*)
        echo -e "${YELLOW}$line${NC}"
        ;;
      *)
        echo "  $line"
        ;;
    esac
  done < .git/BISECT_LOG

  echo ""
}

# Save bisect state
gbisect-save() {
  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${RED}Error: No bisect in progress to save${NC}"
    return 1
  fi

  # Create state directory
  local state_dir="$HOME/.local/state/git-bisect"
  mkdir -p "$state_dir"

  # Get repository name
  local repo_name=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)
  if [[ -z "$repo_name" ]]; then
    repo_name="unknown"
  fi

  local timestamp=$(date +%Y%m%d_%H%M%S)
  local state_file="$state_dir/${repo_name}_${timestamp}.state"

  echo -e "${BLUE}Saving bisect state...${NC}"

  # Save all BISECT files
  tar czf "$state_file" .git/BISECT_* 2>/dev/null

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Bisect state saved to:${NC}"
    echo "  $state_file"

    # Create symlink to latest
    ln -sf "$state_file" "$state_dir/${repo_name}_latest.state"
  else
    echo -e "${RED}Error: Failed to save bisect state${NC}"
    return 1
  fi
}

# Restore bisect state
gbisect-restore() {
  local state_dir="$HOME/.local/state/git-bisect"

  # Check if state directory exists
  if [[ ! -d "$state_dir" ]]; then
    echo -e "${YELLOW}No saved bisect states found${NC}"
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
    echo -e "${YELLOW}No saved states found for this repository${NC}"
    return 1
  fi

  # Check if already in bisect
  if [[ -f .git/BISECT_START ]]; then
    echo -e "${YELLOW}Warning: Bisect already in progress${NC}"
    echo -n "  Overwrite current bisect state? (y/N): "
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo -e "${YELLOW}Restore cancelled${NC}"
      return 1
    fi
  fi

  echo -e "${BLUE}Restoring bisect state from:${NC}"
  echo "  $latest_state"

  # Extract state files
  tar xzf "$latest_state" 2>/dev/null

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Bisect state restored${NC}"
    echo ""
    gbisect-status
  else
    echo -e "${RED}Error: Failed to restore bisect state${NC}"
    return 1
  fi
}

# Show current bisect status
gbisect-status() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}    Git Bisect Status${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  if [[ ! -f .git/BISECT_START ]]; then
    echo -e "${GRAY}No bisect in progress${NC}"
    echo ""
    echo -e "Start bisecting with: ${BLUE}gbisect start [bad] [good]${NC}"
  else
    echo -e "${GREEN}✓ Bisect in progress${NC}"
    echo ""

    # Show good/bad commits
    if [[ -f .git/BISECT_GOOD ]]; then
      local good_ref=$(head -1 .git/BISECT_GOOD)
      echo "Good commit:"
      git log -1 --format="  %h - %s (%cr)" "$good_ref" 2>/dev/null
    fi

    if [[ -f .git/BISECT_BAD ]]; then
      local bad_ref=$(head -1 .git/BISECT_BAD)
      echo "Bad commit:"
      git log -1 --format="  %h - %s (%cr)" "$bad_ref" 2>/dev/null
    fi

    echo ""
    echo "Current HEAD:"
    git log -1 --format="  %h - %s (%cr)" HEAD

    echo ""

    # Show remaining commits count
    local total=$(git bisect visualize --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [[ $total -gt 0 ]]; then
      echo -e "Commits left to test: ${YELLOW}$total${NC}"
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