# Generate OMP completions only when completing `omp`, so shell startup stays cheap.
_omp_lazy_completion() {
  local script
  script="$(command omp completions zsh 2>/dev/null)" || return
  eval "$script"
  (( $+functions[_omp] )) && _omp "$@"
}

if command -v omp >/dev/null 2>&1 && (( $+functions[compdef] )); then
  compdef _omp_lazy_completion omp
fi
