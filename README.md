

![dotfiles-logo](https://github.com/TechDufus/dotfiles/assets/46715299/6c1d626d-28d2-41e3-bde5-981d9bf93462)
<p align="center">
    <a href="https://github.com/TechDufus/dotfiles/actions/workflows/ansible-lint.yml"><img align="center" src="https://github.com/TechDufus/dotfiles/actions/workflows/ansible-lint.yml/badge.svg"/></a>
    <a href="https://github.com/TechDufus/dotfiles/issues"><img align="center" src="https://img.shields.io/github/issues/techdufus/dotfiles"/></a>
    <a href="https://github.com/sponsors/TechDufus"><img align="center" src="https://img.shields.io/github/sponsors/techdufus"/></a>
    <a href="https://discord.gg/5M4hjfyRBj"><img align="center" src="https://img.shields.io/discord/905178979844116520.svg?label=&logo=discord&logoColor=ffffff&color=7389D8&labelColor=6A7EC2"/></a>
    <a href="https://github.com/TechDufus/dotfiles/commits/main"><img align="center" src="https://img.shields.io/github/commit-activity/m/techdufus/dotfiles" alt="commit frequency"></a>
</p>

---
Fully automated development environment for [TechDufus](https://www.twitch.tv/TechDufus) on Twitch.

You can watch a quick 'tour' (pre-1Password integration) here on YouTube:

<a href="https://youtu.be/hPPIScBt4Gw">
    <img src="https://github.com/TechDufus/dotfiles/assets/46715299/b114ea0c-b67b-437b-87d3-7c7732aeccf8" alt="Automating your Dotfiles with Ansible: A Showcase" style="width:60%;"/>
</a>

This repo is heavily influenced by [ALT-F4-LLC](https://github.com/ALT-F4-LLC/dotfiles)'s repo. Go check it out!

## 📋 Table of Contents

- [📋 Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [🎯 Goals](#goals)
- [⚙️ Requirements](#requirements)
- [🔧 Setup](#setup)
- [📖 Usage](#usage)
- [📚 Documentation](#documentation)
- [⭐ Star History](#-star-history)

## 📋 Prerequisites

### macOS Users
Before starting, install [Homebrew](https://brew.sh/) (macOS package manager):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Other Operating Systems
No prerequisites needed - the bootstrap script handles everything automatically.

## 🚀 Quick Start

**New to dotfiles?** → [Complete Beginner Guide](docs/QUICKSTART.md)

**Want it fast?** Run this one command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TechDufus/dotfiles/main/bin/dotfiles)"
```

**What happens:**
1. **Prerequisites** - Installs Ansible and bootstrap dependencies for your OS
2. **Bootstrap** - Clones or updates this repo at `~/.dotfiles`
3. **Configure** - Uses `~/.dotfiles/group_vars/all.yml` for your local role and secret references
4. **Apply** - Runs `ansible-playbook` with your selected roles

**Next steps:**
- Copy `~/.dotfiles/group_vars/all.yml.example` to `~/.dotfiles/group_vars/all.yml` if a local config does not exist yet
- Set up [1Password CLI integration](#1password-integration) if you use secret-backed roles or values
- Customize your setup by editing `~/.dotfiles/group_vars/all.yml`
- Run `dotfiles` anytime to pull repo updates and apply your environment

---

## 🎯 Goals

Provide fully automated multiple-OS development environment that is easy to set up and maintain.

### Why Ansible?

Ansible replicates what we would do to set up a development environment pretty well. There are many automation solutions out there - I happen to enjoy using Ansible.

## ⚙️ Requirements

### Operating System

This Ansible playbook only supports multiple OS's on a per-role basis. This gives a high level of flexibility to each role.

This means that you can run a role, and it will only run if your current OS is configured for that role.

This is accomplished with this `template` `main.yml` task in each role:
```yaml
---
- name: "{{ role_name }} | Checking for Distribution Config: {{ ansible_facts['distribution'] }}"
  ansible.builtin.stat:
    path: "{{ role_path }}/tasks/{{ ansible_facts['distribution'] }}.yml"
  register: distribution_config

- name: "{{ role_name }} | Run Tasks: {{ ansible_facts['distribution'] }}"
  ansible.builtin.include_tasks: "{{ ansible_facts['distribution'] }}.yml"
  when: distribution_config.stat.exists
```
The first task checks for the existence of a `roles/<target role>/tasks/<current_distro>.yml` file. If that file exists (example `current_distro:MacOSX` and a `MacOSX.yml` file exists) it will be run automatically. This keeps roles from breaking if you run a role that isn't yet supported or configured for the system you are running `dotfiles` on.

Currently configured 'bootstrap-able' OS's:
- Ubuntu
- Fedora
- Archlinux (btw)
- MacOSX (darwin)

`bootstrap-able` means the pre-dotfiles setup is configured and performed automatically by this project. For example, before we can run this ansible project, we must first install ansible on each OS type.

To see details, see the `__task "Loading Setup for detected OS: $ID"` section of the `bin/dotfiles` script to see how each OS type is being handled.

### System Upgrade

Verify your `supported OS` installation has all latest packages installed before running the playbook.

```
# Ubuntu
sudo apt-get update && sudo apt-get upgrade -y
# Fedora
sudo dnf update && sudo dnf upgrade -y
# Arch
sudo pacman -Syu
# MacOSX (brew)
brew update && brew upgrade
```

> [!NOTE]
> This may take some time...

## 🔧 Setup

### Local configuration

Your machine-specific configuration lives in `~/.dotfiles/group_vars/all.yml`.
Start from the checked-in example if you do not already have a local config:

```bash
cp ~/.dotfiles/group_vars/all.yml.example ~/.dotfiles/group_vars/all.yml
nvim ~/.dotfiles/group_vars/all.yml
```

The example file is the source of truth for role selection and common variables:

- `default_roles`: roles that run when you execute `dotfiles`
- `git_user_name`: name used by git and other developer tooling
- `keyboard`: Linux/X11 keyboard model, layout, variant, and options
- role-specific variables such as `k8s.repo.version`, `helm.repos`, and `go.packages`

For the compact reference, see [docs/CONFIGURATION.md](docs/CONFIGURATION.md).
For larger examples, see [docs/EXAMPLES.md](docs/EXAMPLES.md).
For tool-specific behavior, prefer the README and defaults inside each role directory.

### 1Password Integration

1Password is recommended for secret-backed configuration, but the whole playbook no longer hard-fails just because 1Password is missing or locked. The bootstrap detects whether `op` is installed and authenticated; roles that need secrets should skip or warn when secrets are unavailable.

The default 1Password account used by current tasks is `my.1password.com` unless a role documents otherwise.

#### Git identity and SSH signing

The git role can read your commit email and allowed signers file from 1Password:

```yaml
op:
  git:
    user:
      email: "op://Personal/GitHub/email"
    allowed_signers: "op://Personal/GitHub SSH/allowed_signers"
```

`op.git.allowed_signers` should point to a field whose value is one or more lines in git's SSH allowed signers format:

```text
<email> namespaces="git" <algo-type> <ssh public key>
```

Example:

```text
you@example.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...
```

#### SSH keys

The ssh role deploys every key listed under `op.ssh.github` groups:

```yaml
op:
  ssh:
    github:
      personal:
        - name: id_ed25519
          vault_path: "op://Personal/GitHub SSH"
      work:
        - name: work_key
          vault_path: "op://Work/GitHub SSH"
```

Each vault item must expose `private_key` and `public_key` fields.

## 📖 Usage

### Install

This playbook includes a custom shell script located at `bin/dotfiles`. This script is added to your $PATH after installation and can be run multiple times while making sure any Ansible dependencies are installed and updated.

This shell script is also used to initialize your environment after bootstrapping your `supported-OS` and performing a full system upgrade as mentioned above.

> [!NOTE]
> You must follow required steps before running this command or things may become unusable until fixed.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TechDufus/dotfiles/main/bin/dotfiles)"
```

If you want to run only specific roles, pass Ansible tags through the launcher:
```bash
dotfiles -t comma,separated,tags
```

Common examples:

```bash
dotfiles                    # Pull latest repo changes and run default_roles
dotfiles -t tmux -vvv       # Run one role with Ansible verbosity
dotfiles --check            # Dry run
dotfiles --list-tags        # List available role tags
dotfiles --uninstall neovim # Run a role uninstall script, if present
dotfiles --delete old_role  # Uninstall, remove from all.yml, and delete the role directory
```

`--uninstall` and `--delete` prompt before making destructive changes.

## 📚 Documentation

- [📖 Complete Beginner Guide](docs/QUICKSTART.md) - Step-by-step setup for new users
- [🔧 Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [📋 Configuration Examples](docs/EXAMPLES.md) - Sample setups for different use cases

## 🌟 Star History

<a href="https://github.com/techdufus/dotfiles/stargazers" target="_blank" style="display: block" align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=techdufus/dotfiles&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=techdufus/dotfiles&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=techdufus/dotfiles&type=Date" />
  </picture>
</a>
