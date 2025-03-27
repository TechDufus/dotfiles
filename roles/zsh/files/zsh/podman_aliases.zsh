#!/usr/bin/env zsh

alias docker=podman

alias pprune='podman rmi $(podman images --filter "dangling=true" -q --no-trunc)'
alias psysprune='podman system prune -af'
