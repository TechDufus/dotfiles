# 🔧 Troubleshooting Guide

Having issues with your dotfiles setup? This guide covers the most common problems and their solutions.

## 🚨 Common Bootstrap Issues

### "Command not found: ansible"

**Problem**: The bootstrap script couldn't install Ansible.

**Solutions**:
```bash
# macOS - install Homebrew first
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install ansible

# Ubuntu - update package lists
sudo apt update
sudo apt install software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install ansible

# Fedora
sudo dnf install ansible

# Arch Linux
sudo pacman -S ansible
```

### "Permission denied" errors

**Problem**: Script needs elevated permissions.

**Solution**: Make sure you can run `sudo` commands:
```bash
sudo echo "Testing sudo access"
```

If this fails, contact your system administrator.

### "curl: command not found"

**Problem**: Your system doesn't have curl installed.

**Solutions**:
```bash
# macOS (install with Xcode tools)
xcode-select --install

# Ubuntu
sudo apt install curl

# Fedora
sudo dnf install curl

# Arch Linux
sudo pacman -S curl
```

## 🔑 1Password Integration Issues

### "op: command not found"

**Problem**: 1Password CLI is not installed or not in PATH.

**Solutions**:
```bash
# macOS
brew install --cask 1password-cli

# Ubuntu/Debian
curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install 1password-cli

# Fedora
sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://downloads.1password.com/linux/keys/1password.asc" > /etc/yum.repos.d/1password.repo'
sudo dnf install 1password-cli

# Arch Linux
yay -S 1password-cli  # or your preferred AUR helper
```

### "Authentication required"

**Problem**: Not signed into 1Password CLI.

**Solution**:
```bash
# Sign in to your account
op account add --address my.1password.com --email your-email@example.com

# Verify access
op vault list
```

### "Invalid vault reference"

**Problem**: Vault paths in your config don't exist in 1Password.

**Solution**:
1. Check your vault names: `op vault list`
2. Check your item names: `op item list --vault "Personal"`
3. Update your `~/.dotfiles/group_vars/all.yml` with correct paths

## 🐧 OS-Specific Issues

### macOS: "zsh: command not found: dotfiles"

**Problem**: The `dotfiles` command isn't in your PATH.

**Solution**:
```bash
# Add to your shell profile
echo 'export PATH="$HOME/.dotfiles/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Ubuntu: Package conflicts

**Problem**: Conflicting package versions.

**Solution**:
```bash
# Clean package cache
sudo apt clean
sudo apt autoremove

# Fix broken packages
sudo apt --fix-broken install

# Re-run dotfiles
cd ~/.dotfiles && ./bin/dotfiles
```

### Arch: Keyring issues

**Problem**: "signature from X is unknown trust"

**Solution**:
```bash
# Update keyring
sudo pacman -S archlinux-keyring
sudo pacman-key --refresh-keys

# Clear package cache if needed
sudo pacman -Scc
```

### Fedora: SELinux issues

**Problem**: "Permission denied" errors related to SELinux.

**Solution**:
```bash
# Check SELinux status
getenforce

# Temporarily set to permissive mode (for testing)
sudo setenforce 0

# If dotfiles work, update SELinux contexts
sudo restorecon -Rv ~/.dotfiles

# Re-enable SELinux
sudo setenforce 1
```

## ⚙️ Configuration Issues

### "Playbook failed" during run

**Problem**: Ansible playbook encountered an error.

**Debug steps**:
```bash
# Run with maximum verbosity
dotfiles -vvv

# Check the log
tail -50 ~/.dotfiles.log

# Run in check mode (dry run)
dotfiles --check
```

### "Role not found" errors

**Problem**: Ansible can't find required roles.

**Solution**:
```bash
# Update Ansible Galaxy requirements
cd ~/.dotfiles
ansible-galaxy install -r requirements/common.yml --force
```


## 🏃‍♂️ Performance Issues

### Installation takes too long

**Possible causes**:
- Slow internet connection
- Many roles enabled
- System update in progress

**Solutions**:
- Run during off-peak hours
- Install specific roles only: `dotfiles -t git,zsh`
- Check network connection

### Out of disk space

**Problem**: Installation fails due to disk space.

**Check space**:
```bash
df -h
```

**Free up space**:
```bash
# Clean package caches
# macOS
brew cleanup

# Ubuntu
sudo apt clean

# Fedora
sudo dnf clean all

# Arch
sudo pacman -Scc
```

## 🆘 Getting Help

### Debug Mode

Run dotfiles with maximum verbosity to see detailed output:
```bash
dotfiles -vvv 2>&1 | tee debug.log
```

### Check Logs

Look at the dotfiles log for errors:
```bash
tail -50 ~/.dotfiles.log
```

### System Information

Gather system info for bug reports:
```bash
# OS version
uname -a

# Ansible version
ansible --version

# Python version
python3 --version

# Available disk space
df -h
```

### Create a Bug Report

If you're still stuck, [create an issue](https://github.com/TechDufus/dotfiles/issues/new) with:

1. **Operating System**: `uname -a` output
2. **Error message**: Copy the exact error
3. **Steps to reproduce**: What did you do?
4. **Debug log**: Output from `dotfiles -vvv`

### Community Support

- 💬 **Discord**: [Join our community](https://discord.gg/5M4hjfyRBj)
- 🐛 **Issues**: [Report bugs](https://github.com/TechDufus/dotfiles/issues)

## 🔄 Recovery Options

### Reset Everything

If something is completely broken:

```bash
# Backup your config
cp ~/.dotfiles/group_vars/all.yml ~/all.yml.backup

# Remove dotfiles directory
rm -rf ~/.dotfiles

# Re-run installation
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TechDufus/dotfiles/main/bin/dotfiles)"

# Restore your config
cp ~/all.yml.backup ~/.dotfiles/group_vars/all.yml
dotfiles
```

### Disable Problematic Roles

If a specific role is causing issues:

```bash
# Edit your config
nvim ~/.dotfiles/group_vars/all.yml

# Comment out the problematic role
# - role: problematic-role  # disabled for now

# Re-run
dotfiles
```

---

**Still having issues?** Don't hesitate to [ask for help](https://github.com/TechDufus/dotfiles/issues/new) - we're here to help!