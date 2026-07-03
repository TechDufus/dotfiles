# Generate pnpm completions only when completing `pnpm`, so shell startup stays cheap.
_pnpm_lazy_completion() {
  if (( $+functions[_pnpm_completion] )); then
    _pnpm_completion "$@"
    return
  fi

  local script
  script="$(command pnpm completion zsh 2>/dev/null)" || return
  eval "$script"

  (( $+functions[_pnpm_completion] )) && compdef _pnpm_completion pnpm 2>/dev/null
}

if command -v pnpm >/dev/null 2>&1 && (( $+functions[compdef] )); then
  compdef _pnpm_lazy_completion pnpm
fi
