#!/bin/bash
set -e

# Note: The system role should NOT delete itself when uninstalled
# It only removes the changes it made to the system

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Remove passwordless sudo configuration
    SUDOERS_FILE="/etc/sudoers.d/$USER"
    if [ -f "$SUDOERS_FILE" ]; then
      __task "Removing passwordless sudo configuration"
      _cmd "sudo rm -f $SUDOERS_FILE"
      _task_done
      echo -e "${YELLOW} [!]  ${WHITE}Passwordless sudo has been disabled${NC}"
    fi
    ;;
    
  Linux)
    # Remove passwordless sudo if it was added
    if sudo grep -q "^$USER.*NOPASSWD" /etc/sudoers 2>/dev/null; then
      __task "Removing passwordless sudo entry"
      _cmd "sudo sed -i '/^$USER.*NOPASSWD/d' /etc/sudoers"
      _task_done
    fi
    ;;
esac

# Restore original /etc/hosts if backup exists
if [ -f "/etc/hosts.dotfiles-backup" ]; then
  echo -e "${YELLOW} [?]  ${WHITE}Found backup of original /etc/hosts. Restore it?${NC}"
  read -p "$(echo -e ${YELLOW})Restore original /etc/hosts? (y/N) ${NC}" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    __task "Restoring original /etc/hosts"
    _cmd "sudo mv /etc/hosts.dotfiles-backup /etc/hosts"
    _task_done
  fi
elif grep -q "# Dotfiles managed entries" /etc/hosts 2>/dev/null; then
  echo -e "${YELLOW} [?]  ${WHITE}Remove custom entries from /etc/hosts?${NC}"
  read -p "$(echo -e ${YELLOW})Remove custom hosts entries? (y/N) ${NC}" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    __task "Removing custom hosts entries"
    # Remove everything between dotfiles markers
    _cmd "sudo sed -i '/# Dotfiles managed entries - START/,/# Dotfiles managed entries - END/d' /etc/hosts"
    _task_done
  fi
fi

# Note about keeping jq and other system packages
echo -e "${YELLOW} [!]  ${WHITE}Note: System packages (jq, etc.) were not removed as they may be used by other tools${NC}"
echo -e "${GREEN} [✓]  ${WHITE}System role configurations have been removed${NC}"