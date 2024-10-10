#!/usr/bin/env zsh

gacp() {
  git add -A
  git commit -S -m "$*"
  # if signing fails, commit without signing
  if [ $? -ne 0 ]; then
    git commit -m "$*"
  fi
  git push -u origin $(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
}

gacpgh() {
  gacp "$*"
  gh pr create --fill
  gh pr review --approve
  gh pr merge -dm
}

parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ [\1]/'
}
