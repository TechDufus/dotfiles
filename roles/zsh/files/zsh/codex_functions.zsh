#!/usr/bin/env zsh
# Codex helper functions for quick session entry
# Note: Color variables are defined in vars.zsh which is sourced before this file

# Continue most recent Codex session with current working directory context.
# Falls back to starting a new Codex session when there is no resumable session.
c.continue() {
  local git_root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null)

  if [[ -z "$git_root" ]]; then
    codex resume --last 2>/dev/null || codex "$@"
    return
  fi

  pushd "$git_root" > /dev/null 2>&1
  codex resume --last 2>/dev/null || codex "$@"
  popd > /dev/null 2>&1
}

# Pick a previous Codex session to resume.
c.resume() {
  codex resume "$@"
}

# Start a new Codex interactive session.
c.new() {
  codex "$@"
}

# Run Codex non-interactively.
c.exec() {
  codex exec "$@"
}

# Run Codex review in the current repository.
c.review() {
  codex review "$@"
}

# Show all Codex functions.
c.help() {
  echo ""
  echo -e "  ${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_MID}${NC}  ${CAT_TEXT}Codex Helper Functions${NC}                                  ${CAT_SAPPHIRE}${BOX_MID}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  echo ""
  echo -e "  ${CAT_YELLOW}Quick Actions${NC}"
  echo -e "  ${CAT_GREEN}  c.continue${NC}          ${CAT_SURFACE2}│${NC} Resume latest Codex session (fallback: new session)"
  echo -e "  ${CAT_GREEN}  c.c${NC}                 ${CAT_SURFACE2}│${NC} Alias for c.continue ${CAT_OVERLAY0}(quick access)${NC}"
  echo -e "  ${CAT_GREEN}  c.resume${NC}            ${CAT_SURFACE2}│${NC} Pick a previous Codex session to resume"
  echo -e "  ${CAT_GREEN}  c.new${NC}               ${CAT_SURFACE2}│${NC} Start a new Codex interactive session"
  echo ""
  echo -e "  ${CAT_YELLOW}Automation${NC}"
  echo -e "  ${CAT_GREEN}  c.exec${NC}              ${CAT_SURFACE2}│${NC} Run Codex non-interactively"
  echo -e "  ${CAT_GREEN}  c.review${NC}            ${CAT_SURFACE2}│${NC} Run Codex code review mode"
  echo ""
  echo -e "  ${CAT_YELLOW}Help${NC}"
  echo -e "  ${CAT_GREEN}  c.help${NC}              ${CAT_SURFACE2}│${NC} Show this help message"
  echo ""
  echo -e "  ${CAT_SURFACE2}${DIVIDER}${NC}"
  echo -e "  ${CAT_MAUVE}Tip:${NC} Claude functions now live under ${CAT_GREEN}cc.*${NC}"
  echo ""
}

# Alias for common continue patterns.
alias c.c='c.continue'
