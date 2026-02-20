#!/usr/bin/env zsh
# Claude-related functions for managing settings and dotfiles integration
# Note: Color variables are defined in vars.zsh which is sourced before this file

# Show current status of Claude settings file in dotfiles
cc.settings-status() {
  pushd ~/.dotfiles > /dev/null 2>&1
  echo ""
  echo -e "  ${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_MID}${NC}  📊 ${CAT_TEXT}Claude Settings Status${NC}                               ${CAT_SAPPHIRE}${BOX_MID}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  echo ""

  if git diff --quiet roles/claude/files/settings.json; then
    echo -e "  ${CAT_GREEN}✅ Status:${NC} ${CAT_TEXT}No changes detected${NC}"
    echo ""
    echo -e "  ${CAT_OVERLAY1}Your Claude settings are in sync with dotfiles${NC}"
  else
    echo -e "  ${CAT_PEACH}⚡ Status:${NC} ${CAT_YELLOW}Local changes detected${NC}"
    echo ""

    # Get stats
    local changes=$(git diff --shortstat roles/claude/files/settings.json)
    echo -e "  ${CAT_OVERLAY1}$changes${NC}"
    echo ""

    # Show preview of changes
    echo -e "  ${CAT_MAUVE}📝 Preview of changes:${NC}"
    echo -e "  ${CAT_SURFACE2}${DIVIDER}${NC}"
    git diff --color=always roles/claude/files/settings.json | head -15 | sed 's/^/  /'
    echo -e "  ${CAT_SURFACE2}${DIVIDER}${NC}"
    echo ""
    echo -e "  💡 ${CAT_MAUVE}Tip:${NC} Run ${CAT_GREEN}cc.settings-save${NC} to commit these changes"
  fi
  echo ""
  popd > /dev/null 2>&1
}

# Save current Claude settings to dotfiles
cc.settings-save() {
  pushd ~/.dotfiles > /dev/null 2>&1
  echo ""
  echo -e "  ${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_MID}${NC}  💾 ${CAT_TEXT}Save Claude Settings${NC}                                 ${CAT_SAPPHIRE}${BOX_MID}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  echo ""

  if git diff --quiet roles/claude/files/settings.json; then
    echo -e "  ${CAT_GREEN}✅ Status:${NC} ${CAT_TEXT}No changes to save${NC}"
    echo ""
    echo -e "  ${CAT_OVERLAY1}Your Claude settings are already in sync with dotfiles${NC}"
    echo ""
    popd > /dev/null 2>&1
    return 0
  fi

  echo -e "  ${CAT_PEACH}⚡ Action:${NC} ${CAT_YELLOW}Committing settings changes...${NC}"
  echo ""

  # Show what's being committed
  local changes=$(git diff --shortstat roles/claude/files/settings.json)
  echo -e "  ${CAT_OVERLAY1}$changes${NC}"
  echo ""

  git add roles/claude/files/settings.json
  git commit -m "feat: update claude settings

Updated settings.json with latest preferences" > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo -e "  ${CAT_GREEN}✅ Success:${NC} ${CAT_TEXT}Settings saved to dotfiles!${NC}"
    echo ""
    echo -e "  💡 ${CAT_MAUVE}Next step:${NC} Run ${CAT_GREEN}git push${NC} when ready to sync"
  else
    echo -e "  ${CAT_RED}❌ Error:${NC} ${CAT_MAROON}Failed to commit changes${NC}"
  fi
  echo ""
  popd > /dev/null 2>&1
}

# Generate Claude usage report
cc.usage-report() {
  bunx ccusage "$@"
}

# Check Claude usage statistics with live updates
cc.usage() {
  bunx ccusage blocks --live
}

# Pick a previous Claude session to resume
cc.resume() {
  claude --resume
}

# Show all Claude functions
cc.help() {
  echo ""
  echo -e "  ${CAT_SAPPHIRE}${BOX_TOP}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_MID}${NC}  🤖 ${CAT_TEXT}Claude Helper Functions${NC}                              ${CAT_SAPPHIRE}${BOX_MID}${NC}"
  echo -e "  ${CAT_SAPPHIRE}${BOX_BOT}${NC}"
  echo ""
  echo -e "  ${CAT_YELLOW}📊 Settings Management${NC}"
  echo -e "  ${CAT_GREEN}  cc.settings-status${NC}  ${CAT_SURFACE2}│${NC} Show if Claude settings changed in dotfiles"
  echo -e "  ${CAT_GREEN}  cc.settings-save${NC}    ${CAT_SURFACE2}│${NC} Commit Claude settings changes to dotfiles"
  echo ""
  echo -e "  ${CAT_YELLOW}🚀 Quick Actions${NC}"
  echo -e "  ${CAT_GREEN}  cc.continue${NC}         ${CAT_SURFACE2}│${NC} Continue last Claude session with workspace context"
  echo -e "  ${CAT_GREEN}  cc.c${NC}                ${CAT_SURFACE2}│${NC} Alias for cc.continue ${CAT_OVERLAY0}(quick access)${NC}"
  echo -e "  ${CAT_GREEN}  cc.resume${NC}           ${CAT_SURFACE2}│${NC} Pick a previous Claude session to resume"
  echo -e "  ${CAT_GREEN}  cc.usage${NC}            ${CAT_SURFACE2}│${NC} Live Claude usage blocks monitoring"
  echo -e "  ${CAT_GREEN}  cc.usage-report${NC}     ${CAT_SURFACE2}│${NC} Generate Claude usage statistics report"
  echo ""
  echo -e "  ${CAT_YELLOW}📚 Help${NC}"
  echo -e "  ${CAT_GREEN}  cc.help${NC}             ${CAT_SURFACE2}│${NC} Show this help message"
  echo ""
  echo -e "  ${CAT_SURFACE2}${DIVIDER}${NC}"
  echo -e "  💡 ${CAT_MAUVE}Tip:${NC} Use ${CAT_PEACH}tab completion${NC} to discover all ${CAT_GREEN}cc.*${NC} functions"
  echo ""
}

# Continue Claude session with current working directory context
cc.continue() {
  # If in a git repo, go to the root
  local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  
  # Not in a git repo, just run claude here
  if [[ -z "$git_root" ]]; then
    claude --continue
    return
  fi
  
  # In a git repo, go to root first
  pushd "$git_root" > /dev/null 2>&1
  claude --continue
  popd > /dev/null 2>&1
}

# Alias for common continue patterns
alias cc.c='cc.continue'
