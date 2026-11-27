# Shortcuts for OMP named profiles. Profiles are machine-local (~/.omp/profiles/<name>),
# so each shortcut refuses to run where its profile was never set up instead of
# letting omp create an empty one.

# Inkling 2 Mini on llm-1's llama.cpp server.
omp-inkling() {
  if [[ ! -f "$HOME/.omp/profiles/inkling/agent/models.yml" ]]; then
    print -ru2 "omp-inkling: no inkling profile on this machine (~/.omp/profiles/inkling/agent/models.yml)"
    return 1
  fi
  command omp --profile=inkling "$@"
}
