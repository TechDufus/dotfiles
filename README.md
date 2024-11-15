

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

## Goals

Provide fully automated multiple-OS development environment that is easy to set up and maintain.

### Why Ansible?

Ansible replicates what we would do to set up a development environment pretty well. There are many automation solutions out there - I happen to enjoy using Ansible.

## Requirements

### Operating System

This Ansible playbook only supports multiple OS's on a per-role basis. This gives a high level of flexibility to each role.

This means that you can run a role, and it will only run if your current OS is configured for that role.

This is accomplished with this `template` `main.yml` task in each role:
```yaml
---
- name: "{{ role_name }} | Checking for Distribution Config: {{ ansible_distribution }}"
  ansible.builtin.stat:
    path: "{{ role_path }}/tasks/{{ ansible_distribution }}.yml"
  register: distribution_config

- name: "{{ role_name }} | Run Tasks: {{ ansible_distribution }}"
  ansible.builtin.include_tasks: "{{ ansible_distribution }}.yml"
  when: distribution_config.stat.exists
```
The first task checks for the existence of a `roles/<target role>/tasks/<current_distro>.yml` file. If that file exists (example `current_distro:MacOSX` and a `MacOSX.yml` file exists) it will be run automatically. This keeps roles from breaking if you run a role that isn't yet supported or configured for the system you are running `dotfiles` on.

Currently configured 'bootstrap-able' OS's:
- Ubuntu
- Archlinux (btw)
- MacOSX (darwin)

`bootstrap-able` means the pre-dotfiles setup is configured and performed automatically by this project. For example, before we can run this ansible project, we must first install ansible on each OS type.

To see details, see the `__task "Loading Setup for detected OS: $ID"` section of the `bin/dotfiles` script to see how each OS type is being handled.

### System Upgrade

Verify your `supported OS` installation has all latest packages installed before running the playbook.

```
# Ubuntu
sudo apt-get update && sudo apt-get upgrade -y
# Arch
sudo pacman -Syu
# MacOSX (brew)
brew update && brew upgrade
```

> [!NOTE]
> This may take some time...

## Setup

### all.yml values file

The `all.yml` file allows you to personalize your setup to your needs. This file will be created in the file located at `~/.dotfiles/group_vars/all.yaml` after you [Install this dotfiles](#install) and include your desired settings.

Below is a list of all available values. Not all are required but incorrect values will break the playbook if not properly set.

| Name             | Type                                   | Required |
| ---------------- | -------------------------------------- | -------- |
| git_user_name    | string                                 | yes      |
| op               | object `(see OP Variable below)`       | yes      |
| go.packages      | list `(for extra go bin installs)`     | no       |
| helm.repos       | list `(add extra helm repos)`          | no       |
| k8s.repo.version | string `(specify kubectl bin version)` | no       |
### 1Password Integration

This project depends on a 1Password vault. This means you must have a setup and authenticated `op-cli` for CLI access to your vault. This can be done by installing the 1Password desktop application **OR** can be setup with the `op` cli only, but it a bit more annoying that way since the CLI tool can directly integrate with the Desktop application.

The initial run of `dotfiles` on a new system **should** error without 1Password being setup and having access to a vault (currently defaults to `my.1password.com`)

##### Deprecated `vault.secret` / `ansible-vault` method

The original method for deploying secrets was to create `ansible-vault` encrypted strings, which would be decrypted by the secret in `~/.ansible-vault/vault.secret`. This method no longer is supported, in favor of a more secure and flexible 1Password vault.

It is more flexible in the sense that rotating secrets is just updating the 1Password item, instead of needing to re-encrypt a string and commit it to github. The more you mess with encrypting / decrypting / commiting to Github, the higher the risk of a real secret being exposed.

Additionally, if the original `vault.secret` value was ever discovered, even though it's no longer being used by this project, could still be used to get the encrypted strings via the git history of this project and decrypted. That `vault.secret` password has been scorched from the earth. 🔥
#### OP (1Password) Variable

Manage environment-critical items without needing `ansible-vault`, by using your `1Password` vault.

> [!NOTE]
> Currently, unless an `account` value is specified, the following `op` vaults assume `my.1password.com` vault.
##### op.git

`op.git` is where you will store any git-related vault paths. All values must be paths to vault.

###### op.git.user
This variable stores `email` which is as `string` of your vault path to you github account email.

Example `op.git.user` config:
```yaml
op:
  git:
    user:
      email: "op://Personal/Github/email"
```

###### op.git.allowed_signers
This variable stores the `string` to your allowed signers value. This value should be in the following format:
```
<email> namespaces="git" <algo-type[ssh-ed25519]> <ssh public key>
```

Example `op.git.allowed_signers` config:
```yaml
op:
  git:
    allowed_signers: "op://Personal/Github/allowed_signers"
```

Example full `op.git` config:
```yaml
op:
  git:
    user:
      email: "op://Personal/Github/email"
      allowed_signers: "op://Personal/Github/allowed_signers"
```
##### op.ssh
`op.ssh` stores references to ssh keys that will be deployed to your local `~/.ssh` directory.

###### op.ssh.github.techdufus
This variable stores a list of items containing `name:<string> vault_path:<string>`. This list will be looped over and the accompanying ssh pub/private keys will be created with the `name` value you provide.

EXAMPLE: If `name: dufus` is provided, it will extract the values from the `vault_path` and create the `~/.ssh/dufus.pub` and `~/ssh/dufus` ssh keys.

> [!NOTE]
> This variable can be called anything. Currently it is called `techdufus` just for my brain to know these are associated with my `techdufus` github user account. But if you were in multiple github orgs/users and you wanted a key associated ONLY with your account for that org/user, you would create another `op.ssh.github.some_org_user_here` and list your keys in that var, promoting organizational awareness at a glance of the config.

Example `op.ssh.github.techdufus` config:
```yaml
op:
  ssh:
    github:
      techdufus:
        - name: github_key
          vault_path: "op://Personal/github_key SSH"
```
##### op.system.hosts

> [!WARNING]
> `op.system.hosts` is not implemented yet, but the information is the target implementation structure.

`op.system.hosts` is a list of vault `<string>` entries that will become a single line in your `/etc/hosts` file.

Example `op.system.hosts` config:
```yaml
op:
  system:
    hosts:
      - vault_path: op://Hosts/k8s-ingress
        account: some-other-account.1password.com
      - vault_path: op://Hosts/k8s-api
        account: some-other-account.1password.com
```

Example full `op` config:
```yaml
op:
  git:
    user:
      email: "op://Personal/Github/email"
  ssh:
    github:
      techdufus:
        - name: github_key
          vault_path: "op://Personal/github_key SSH"
  system:
    hosts:
      - vault_path: op://Hosts/k8s-ingress
        account: some-other-account.1password.com
      - vault_path: op://Hosts/k8s-api
        account: some-other-account.1password.com
```

## Usage

### Install

This playbook includes a custom shell script located at `bin/dotfiles`. This script is added to your $PATH after installation and can be run multiple times while making sure any Ansible dependencies are installed and updated.

This shell script is also used to initialize your environment after bootstrapping your `supported-OS` and performing a full system upgrade as mentioned above.

> [!NOTE]
> You must follow required steps before running this command or things may become unusable until fixed.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TechDufus/dotfiles/main/bin/dotfiles)"
```

If you want to run only a specific role, you can specify the following bash command:
```bash
curl -fsSL https://raw.githubusercontent.com/TechDufus/dotfiles/main/bin/dotfiles | bash -s -- --tags comma,seperated,tags
```

### Update

This repository is continuously updated with new features and settings which become available to you when updating.

To update your environment run the `dotfiles` command in your shell:

```bash
dotfiles
```

This will handle the following tasks:

- Verify Ansible is up-to-date
- Clone this repository locally to `~/.dotfiles`
- Verify any `ansible-galaxy` plugins are updated
- Run this playbook with the values in `~/.config/dotfiles/group_vars/all.yaml`

This `dotfiles` command is available to you after the first use of this repo, as it adds this repo's `bin` directory to your path, allowing you to call `dotfiles` from anywhere.

Any flags or arguments you pass to the `dotfiles` command are passed as-is to the `ansible-playbook` command.

For Example: Running the tmux tag with verbosity
```bash
dotfiles -t tmux -vvv
```

As an added bonus, the tags have tab completion!
```bash
dotfiles -t <tab><tab>
dotfiles -t t<tab>
dotfiles -t ne<tab>
```

## 🌟 Star History

<a href="https://github.com/techdufus/dotfiles/stargazers" target="_blank" style="display: block" align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=techdufus/dotfiles&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=techdufus/dotfiles&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=techdufus/dotfiles&type=Date" />
  </picture>
</a>
