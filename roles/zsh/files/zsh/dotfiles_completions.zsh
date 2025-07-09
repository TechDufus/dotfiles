#!/usr/bin/env zsh
#
# Dotfiles Tab Completion
#
# This file provides tab completion for the dotfiles command.
# It includes special handling for tmux environments where the completion
# system initialization timing can cause registration failures.
#
# THE TMUX TIMING PROBLEM:
# =======================
# In regular terminals, the ZSH initialization sequence is predictable:
#   Terminal → .zshrc → compinit → custom completions → shell ready
#
# In tmux panes, the sequence can have timing issues:
#   tmux → new PTY → .zshrc → compinit (async?) → custom completions → FAIL
#
# This happens because:
# 1. tmux spawns shells differently with faster initialization
# 2. Multiple panes starting simultaneously can cause race conditions  
# 3. The _comps array (created by compinit) might not exist when we try to use it
#
# THE SOLUTION:
# ============
# We defer completion registration in tmux using the precmd hook:
#
# REGULAR TERMINAL:                    TMUX PANE:
# ─────────────────                    ──────────
# 1. Source this file                  1. Source this file
# 2. Register immediately ✓            2. Set up precmd hook
# 3. Tab completion works              3. Shell finishes init
#                                      4. First prompt appears
#                                      5. precmd runs → register ✓
#                                      6. Tab completion works
#
# The precmd hook guarantees the shell is fully initialized before
# we attempt to register completions, solving the timing issue.

DOTFILES_ROLES_DIR="$HOME/.dotfiles/roles"

# Function to handle tab completion for dotfiles command
__dotfiles_completion() {
    local -a roles uninstallable_roles
    local curcontext="$curcontext" state line
    typeset -A opt_args

    # Define the command line options
    _arguments -C \
        '-t[Run specific roles]:role:->roles' \
        '--skip-tags[Skip specific roles]:role:->roles' \
        '--uninstall[Uninstall a role]:role:->uninstall' \
        '--delete[Uninstall and delete a role]:role:->delete' \
        '--check[Run in check mode (dry run)]' \
        '--list-tags[List all available tags]' \
        '-v[Verbose mode (can be specified multiple times)]' \
        '-vv[More verbose output]' \
        '-vvv[Most verbose output]' \
        '*:argument:->args'

    case $state in
        roles)
            # Get list of roles from the roles directory
            roles=(${(f)"$(find $DOTFILES_ROLES_DIR -maxdepth 1 -type d -exec basename {} \; | grep -v '^roles$' | sort)"})

            # Support comma-separated values
            if [[ -n "${words[CURRENT]}" && "${words[CURRENT]}" == *,* ]]; then
                # Handle comma-separated completions
                local prefix="${words[CURRENT]%,*},"
                local suffix="${words[CURRENT]##*,}"
                _describe -t roles 'role' roles -P "$prefix" -S ','
            else
                _describe -t roles 'role' roles -S ','
            fi
            ;;
        uninstall)
            # Get only roles with uninstall.sh scripts
            uninstallable_roles=(${(f)"$(find $DOTFILES_ROLES_DIR -maxdepth 1 -type d -exec test -f {}/uninstall.sh \; -print | xargs -n1 basename | sort)"})
            _describe -t roles 'uninstallable role' uninstallable_roles
            ;;
        delete)
            # Get all roles (delete works with or without uninstall.sh)
            roles=(${(f)"$(find $DOTFILES_ROLES_DIR -maxdepth 1 -type d -exec basename {} \; | grep -v '^roles$' | sort)"})
            _describe -t roles 'role' roles
            ;;
    esac
}

# Register the completion function
# Simple registration - same as Fedora system
compdef __dotfiles_completion dotfiles

# COMMENTED OUT FOR TESTING - Complex tmux timing fix
# If completions work after reboot, this whole section can be removed
# () {
#     # Helper function to register the completion
#     local register_completion() {
#         compdef __dotfiles_completion dotfiles
#     }
#
#     if [[ -n "$TMUX" ]]; then
#         # In tmux: defer registration until shell is interactive
#         # This uses ZSH's hook system to run code before the first prompt
#         autoload -Uz add-zsh-hook
#         
#         # Define a function that will run once at the first prompt
#         local _register_dotfiles_completion() {
#             register_completion
#             # Remove this hook after running once (-d flag)
#             # This prevents the registration from running on every prompt
#             add-zsh-hook -d precmd _register_dotfiles_completion
#         }
#         
#         # Add our function to the precmd hook list
#         add-zsh-hook precmd _register_dotfiles_completion
#     else
#         # Regular terminal: register immediately
#         # No timing issues here, so we can register right away
#         register_completion
#     fi
# }

