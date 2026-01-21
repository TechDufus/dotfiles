#!/usr/bin/env zsh
# OpenCode-related functions
# Note: Color variables are defined in vars.zsh which is sourced before this file

# Continue OpenCode session with current working directory context
o.continue() {
  # If in a git repo, go to the root
  local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  
  # Not in a git repo, just run opencode here
  if [[ -z "$git_root" ]]; then
    opencode --continue
    return
  fi
  
  # In a git repo, go to root first
  pushd "$git_root" > /dev/null 2>&1
  opencode --continue
  popd > /dev/null 2>&1
}

# Show all OpenCode functions
o.help() {
  echo ""
  echo -e "  ${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_MID}${NC}  🤖 ${CAT_TEXT}OpenCode Helper Functions${NC}                            ${CAT_SAPPHIRE}${BOX_MID}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  echo ""
  echo -e "  ${CAT_YELLOW}🚀 Quick Actions${NC}"
  echo -e "  ${CAT_GREEN}  o.continue${NC}          ${CAT_SURFACE2}│${NC} Continue last session in git root"
  echo -e "  ${CAT_GREEN}  o.c${NC}                 ${CAT_SURFACE2}│${NC} Alias for o.continue ${CAT_OVERLAY0}(quick access)${NC}"
  echo ""
  echo -e "  ${CAT_YELLOW}📚 Help${NC}"
  echo -e "  ${CAT_GREEN}  o.help${NC}              ${CAT_SURFACE2}│${NC} Show this help message"
  echo ""
  echo -e "  ${CAT_SURFACE2}${DIVIDER}${NC}"
  echo -e "  💡 ${CAT_MAUVE}Tip:${NC} Use ${CAT_PEACH}tab completion${NC} to discover all ${CAT_GREEN}o.*${NC} functions"
  echo ""
}

# Aliases for quick access
alias o.c='o.continue'
