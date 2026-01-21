#!/bin/bash
set -e

# Detect OS
case "$(uname -s)" in
  Darwin)
    # Uninstall kubectl via Homebrew
    if command -v brew >/dev/null 2>&1 && brew list kubectl >/dev/null 2>&1; then
      __task "Removing kubectl via Homebrew"
      _cmd "brew uninstall kubectl"
      _task_done
    fi
    
    # Uninstall kubectx/kubens
    if command -v brew >/dev/null 2>&1 && brew list kubectx >/dev/null 2>&1; then
      __task "Removing kubectx/kubens via Homebrew"
      _cmd "brew uninstall kubectx"
      _task_done
    fi
    ;;
    
  Linux)
    # Remove kubectl binary
    if [ -f "/usr/local/bin/kubectl" ]; then
      __task "Removing kubectl binary"
      _cmd "sudo rm -f /usr/local/bin/kubectl"
      _task_done
    fi
    
    # Check distribution
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        ubuntu|debian)
          if dpkg -l | grep -q "^ii  kubectl"; then
            __task "Removing kubectl via apt"
            _cmd "sudo apt-get remove -y kubectl"
            _task_done
          fi
          ;;
      esac
    fi
    ;;
esac

# Remove kubeconfig
echo -e "${YELLOW} [?]  ${WHITE}Remove Kubernetes configuration?${NC}"
echo -e "${YELLOW}      ${WHITE}This includes ~/.kube/config and all cluster configurations${NC}"
read -p "$(echo -e ${YELLOW})Remove kubeconfig? (y/N) ${NC}" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  __task "Removing Kubernetes configuration"
  _cmd "rm -rf $HOME/.kube"
  _task_done
fi

# Remove k8s config from dotfiles
if [ -d "$HOME/.config/k8s" ]; then
  __task "Removing k8s dotfiles configuration"
  _cmd "rm -rf $HOME/.config/k8s"
  _task_done
fi

echo -e "${GREEN} [✓]  ${WHITE}Kubernetes tools have been uninstalled${NC}"