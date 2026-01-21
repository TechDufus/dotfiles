#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall AWS CLI v2
    if [ -d "/usr/local/aws-cli" ]; then
      __task "Removing AWS CLI v2"
      _cmd "sudo rm -rf /usr/local/aws-cli"
      _cmd "sudo rm -f /usr/local/bin/aws /usr/local/bin/aws_completer"
      _task_done
    fi
    
    # Uninstall via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list awscli >/dev/null 2>&1; then
      __task "Removing AWS CLI via Homebrew"
      _cmd "brew uninstall awscli"
      _task_done
    fi
    ;;
    
  Linux)
    # Check for AWS CLI v2 installation
    if [ -d "/usr/local/aws-cli" ]; then
      __task "Removing AWS CLI v2"
      _cmd "sudo rm -rf /usr/local/aws-cli"
      _cmd "sudo rm -f /usr/local/bin/aws /usr/local/bin/aws_completer"
      _task_done
    fi
    
    # Check for pip installation
    if pip3 list 2>/dev/null | grep -q awscli; then
      __task "Removing AWS CLI installed via pip"
      _cmd "pip3 uninstall -y awscli"
      _task_done
    fi
    
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  awscli"; then
            __task "Removing AWS CLI via apt"
            _cmd "sudo apt-get remove -y awscli"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove AWS configuration and credentials
echo -e "${YELLOW} [?]  ${WHITE}Remove AWS configuration and credentials?${NC}"
echo -e "${YELLOW}      ${WHITE}This includes ~/.aws/config and ~/.aws/credentials${NC}"
read -p "$(echo -e ${YELLOW})Remove AWS config? (y/N) ${NC}" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  __task "Removing AWS configuration"
  _cmd "rm -rf $HOME/.aws"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}AWS CLI has been uninstalled${NC}"