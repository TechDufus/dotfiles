#!/usr/bin/env zsh
#
# Tab completion for the dotfiles command.
# Register after compinit in ~/.zshrc. Herdr panes are normal interactive
# zsh sessions, so no multiplexer-specific deferral is required.

DOTFILES_ROLES_DIR="$HOME/.dotfiles/roles"

__dotfiles_completion() {
    local -a roles uninstallable_roles
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        '-h[Show help message]' \
        '--help[Show help message]' \
        '--version[Show version information]' \
        '-t[Run specific roles]:role:->roles' \
        '--skip-tags[Skip specific roles]:role:->roles' \
        '--uninstall[Uninstall a role]:role:->uninstall' \
        '--delete[Uninstall and delete a role]:role:->delete' \
        '--check[Run in check mode (dry run)]' \
        '--list-tags[List all available tags]' \
        '-v[Verbose mode (passed to ansible-playbook)]' \
        '-vv[More verbose output]' \
        '-vvv[Most verbose output]' \
        '*:argument:->args'

    case $state in
        roles)
            roles=(${(f)"$(find $DOTFILES_ROLES_DIR -maxdepth 1 -type d -exec basename {} \; | grep -v '^roles$' | sort)"})

            if [[ -n "${words[CURRENT]}" && "${words[CURRENT]}" == *,* ]]; then
                local prefix="${words[CURRENT]%,*},"
                _describe -t roles 'role' roles -P "$prefix" -S ','
            else
                _describe -t roles 'role' roles -S ','
            fi
            ;;
        uninstall)
            uninstallable_roles=(${(f)"$(find $DOTFILES_ROLES_DIR -maxdepth 1 -type d -exec test -f {}/uninstall.sh \; -print | xargs -n1 basename | sort)"})
            _describe -t roles 'uninstallable role' uninstallable_roles
            ;;
        delete)
            roles=(${(f)"$(find $DOTFILES_ROLES_DIR -maxdepth 1 -type d -exec basename {} \; | grep -v '^roles$' | sort)"})
            _describe -t roles 'role' roles
            ;;
    esac
}

compdef __dotfiles_completion dotfiles
