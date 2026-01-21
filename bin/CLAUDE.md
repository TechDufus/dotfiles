# bin/ Directory

Bootstrap and runner scripts for dotfiles.

## Main Script: dotfiles

The `dotfiles` script is the main entry point that bootstraps prerequisites, manages the dotfiles repository, and executes ansible-playbook. It auto-detects the OS and installs Ansible, Python, and package managers as needed before running the playbook.

## Flow
1. Parse early flags (`--help`, `--version`) before any setup
2. Detect OS via `/etc/os-release` and run OS-specific setup (install Ansible, Python, etc.)
3. Clone or update the dotfiles repository from GitHub
4. Parse remaining args (`--uninstall`, `--delete`, or pass-through to ansible)
5. Install Ansible Galaxy dependencies from `requirements/`
6. Execute `ansible-playbook main.yml` with remaining arguments

## Key Functions
- `detect_os`: Returns OS identifier (ubuntu, arch, fedora, darwin)
- `*_setup` (ubuntu/arch/fedora/macos): OS-specific prerequisite installation
- `__task`: Starts a spinner with task description
- `_task_done`: Stops spinner and shows success checkmark
- `_cmd`: Executes commands with error handling and logging to `~/.dotfiles.log`
- `run_uninstall_script`: Exports colors/functions and runs role's `uninstall.sh`
- `update_ansible_galaxy`: Installs common and OS-specific Galaxy requirements

## Visual Feedback
Uses a braille character spinner (`_spinner`) running in a background process. The spinner cycles through `chars` array while displaying the current task. Colors use the Catppuccin Mocha palette via ANSI escape codes. Cursor visibility is controlled via `tput civis/cnorm`.

## Gotchas
- Requires `tput` (ncurses) - exits immediately if not found
- First successful run creates `~/.dotfiles_run` marker to suppress welcome message
- All command output is hidden; errors are logged to `~/.dotfiles.log` and displayed on failure
- Exports functions/colors to child uninstall scripts via `export -f`
