#!/usr/bin/env bash

alias kctx='kubectl config use-context $(kubectl config get-contexts -o name | fzf)'
