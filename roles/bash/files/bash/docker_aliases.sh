#!/usr/bin/env bash

alias dprune='docker rmi $(docker images --filter "dangling=true" -q --no-trunc)'
alias dsysprune='docker system prune -af'
