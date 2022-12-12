#!/usr/bin/env bash

alias yolo="git push origin master --force --no-verify"
alias g='git'
alias gs='git status'
alias gcane='git commit --amend --no-edit'
alias gc="git checkout"

alias ggl='git log --oneline --graph'
alias gcb="git checkout -b"
__git_complete gc _git_checkout
__git_complete gcb _git_checkout

alias gp="git push"
alias gpf="git push --force-with-lease"
__git_complete gp _git_push
