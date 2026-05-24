#!/usr/bin/env zsh
# Worktrunk shell integration and thin OMP launch helpers.

# Worktrunk needs shell integration so `wt switch` can change the current shell's
# directory. Keep this repo-managed instead of letting `wt config shell install`
# mutate ~/.zshrc.
unalias wt wto wton 2>/dev/null || true
if [[ -n "${WORKTRUNK_BIN:-}" || -n "${commands[wt]:-}" ]]; then
  eval "$("${WORKTRUNK_BIN:-wt}" config shell init zsh)"
fi
_wt.require() {
  if ! command -v wt >/dev/null 2>&1; then
    echo "Error: wt command not found. Install Worktrunk first."
    return 127
  fi
}

_wt.wants-help() {
  [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]
}

wt.help() {
  print -r -- ""
  print -r -- "Worktrunk helpers"
  print -r -- ""
  print -r -- "  wt                 Worktrunk CLI. Run without args for the switch picker."
  print -r -- "  wt list            List worktrees. Add --full when you want CI/diff detail."
  print -r -- "  wt remove          Remove current worktree; delete branch when safe."
  print -r -- "  wt merge [target]  Rebase/merge current worktree, then clean it up."
  print -r -- ""
  print -r -- "  wto [branch] [-- prompt...]"
  print -r -- "                     Switch/pick a worktree and run: omp -c"
  print -r -- "  wton <branch> [-- prompt...]"
  print -r -- "                     Create a worktree and run: omp -c"
  print -r -- ""
  print -r -- "Examples:"
  print -r -- "  wton feat/auth -- 'Implement login flow'"
  print -r -- "  wto feat/auth"
  print -r -- "  wto"
  print -r -- ""
}

wt.omp() {
  if _wt.wants-help "$1"; then
    print -r -- "Usage: wto [branch|shortcut] [-- prompt...]"
    print -r -- ""
    print -r -- "Switch to an existing Worktrunk worktree, or open Worktrunk's picker,"
    print -r -- "then continue the latest OMP session there with: omp -c"
    print -r -- ""
    print -r -- "Examples:"
    print -r -- "  wto feat/auth"
    print -r -- "  wto pr:123"
    print -r -- "  wto"
    return 0
  fi

  _wt.require || return

  wt switch --execute='omp -c' "$@"
}

wt.omp-new() {
  if _wt.wants-help "$1"; then
    print -r -- "Usage: wton <branch> [-- prompt...]"
    print -r -- ""
    print -r -- "Create a new Worktrunk worktree and continue the latest OMP session"
    print -r -- "there with: omp -c"
    print -r -- ""
    print -r -- "Examples:"
    print -r -- "  wton feat/auth"
    print -r -- "  wton feat/auth -- 'Implement login flow'"
    return 0
  fi

  _wt.require || return

  if [[ $# -eq 0 || "$1" == "--" ]]; then
    echo "Usage: wt.omp-new <branch> [-- prompt...]"
    return 2
  fi

  wt switch --create --execute='omp -c' "$@"
}

wto() {
  wt.omp "$@"
}

wton() {
  wt.omp-new "$@"
}
