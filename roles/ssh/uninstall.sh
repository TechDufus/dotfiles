#!/bin/bash
set -e

# The SSH role only manages SSH keys from 1Password
# We should remove only the keys it deployed, not the entire .ssh directory

echo -e "${YELLOW} [!]  ${WHITE}This will remove SSH keys that were deployed from 1Password${NC}"
echo -e "${YELLOW}      ${WHITE}Your .ssh directory and config will be preserved${NC}"

# List of common key names that might have been deployed
# You may need to adjust this based on your specific setup
DEPLOYED_KEYS=(
  "id_rsa"
  "id_rsa.pub"
  "id_ed25519"
  "id_ed25519.pub"
  "github"
  "github.pub"
)

# Check if any deployed keys exist
FOUND_KEYS=()
for key in "${DEPLOYED_KEYS[@]}"; do
  if [ -f "$HOME/.ssh/$key" ]; then
    FOUND_KEYS+=("$key")
  fi
done

if [ ${#FOUND_KEYS[@]} -eq 0 ]; then
  echo -e "${YELLOW} [!]  ${WHITE}No deployed SSH keys found${NC}"
else
  echo -e "${YELLOW} [?]  ${WHITE}Found the following SSH keys:${NC}"
  for key in "${FOUND_KEYS[@]}"; do
    echo -e "      ${WHITE}- $key${NC}"
  done
  
  read -p "$(echo -e ${YELLOW})Remove these SSH keys? (y/N) ${NC}" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    __task "Removing deployed SSH keys"
    for key in "${FOUND_KEYS[@]}"; do
      _cmd "rm -f $HOME/.ssh/$key"
    done
    _task_done
    
    # Update SSH agent if running
    if [ -n "$SSH_AUTH_SOCK" ]; then
      __task "Removing keys from SSH agent"
      for key in "${FOUND_KEYS[@]}"; do
        if [[ "$key" != *.pub ]]; then
          ssh-add -d "$HOME/.ssh/$key" 2>/dev/null || true
        fi
      done
      _task_done
    fi
  fi
fi

# Check for SSH config managed by dotfiles
if [ -f "$HOME/.ssh/config" ] && grep -q "# Managed by dotfiles" "$HOME/.ssh/config" 2>/dev/null; then
  echo -e "${YELLOW} [?]  ${WHITE}Remove SSH config entries managed by dotfiles?${NC}"
  read -p "$(echo -e ${YELLOW})Remove managed SSH config entries? (y/N) ${NC}" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    __task "Removing managed SSH config entries"
    # This is a simple implementation - you may need to adjust based on your config structure
    _cmd "sed -i.bak '/# Managed by dotfiles - START/,/# Managed by dotfiles - END/d' $HOME/.ssh/config"
    
    # Remove backup if sed succeeded
    if [ $? -eq 0 ]; then
      rm -f "$HOME/.ssh/config.bak"
    fi
    _task_done
  fi
fi

echo -e "${GREEN} [✓]  ${WHITE}SSH keys and configurations have been cleaned up${NC}"
echo -e "${YELLOW} [!]  ${WHITE}Note: Your .ssh directory was preserved${NC}"