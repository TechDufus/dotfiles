#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
zsh_bin="${ZSH_BIN:-zsh}"

if ! command -v "$zsh_bin" >/dev/null; then
  echo "SKIP: zsh not installed"
  exit 0
fi
zsh_bin="$(command -v "$zsh_bin")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

bin_dir="$tmp_dir/bin"
calls="$tmp_dir/calls"
nvm_dir="$tmp_dir/nvm"
mkdir -p "$bin_dir" "$nvm_dir"
: > "$calls"

cat > "$bin_dir/kubectl" <<'KUBECTL'
#!/usr/bin/env sh
printf 'kubectl %s\n' "$*" >> "$TOOL_CALLS"
if [ "$1" = "completion" ] && [ "$2" = "zsh" ]; then
  printf '%s\n' '_kubectl() { print -r -- kubectl-completed >> "$TOOL_CALLS"; }'
fi
KUBECTL
cat > "$bin_dir/jj" <<'JJ'
#!/usr/bin/env sh
printf 'jj %s\n' "$*" >> "$TOOL_CALLS"
if [ "$1" = "util" ] && [ "$2" = "completion" ]; then
  printf '%s\n' '_jj() { print -r -- jj-completed >> "$TOOL_CALLS"; }'
fi
JJ
cat > "$nvm_dir/nvm.sh" <<'NVM'
printf 'nvm.sh sourced\n' >> "$TOOL_CALLS"
nvm() { :; }
nvm_find_nvmrc() { :; }
NVM
cat > "$bin_dir/kind" <<'KIND'
#!/usr/bin/env sh
printf 'kind %s\n' "$*" >> "$TOOL_CALLS"
if [ "$1" = "completion" ] && [ "$2" = "zsh" ]; then
  printf '%s\n' '_kind() { print -r -- kind-completed >> "$TOOL_CALLS"; }'
fi
KIND
cat > "$bin_dir/minikube" <<'MINIKUBE'
#!/usr/bin/env sh
printf 'minikube %s\n' "$*" >> "$TOOL_CALLS"
if [ "$1" = "completion" ] && [ "$2" = "zsh" ]; then
  printf '%s\n' '_minikube() { print -r -- minikube-completed >> "$TOOL_CALLS"; }'
fi
MINIKUBE
chmod +x "$bin_dir/kubectl" "$bin_dir/jj" "$bin_dir/kind" "$bin_dir/minikube"

TOOL_CALLS="$calls" \
PATH="$bin_dir:$PATH" \
NVM_DIR="$nvm_dir" \
REPO_ROOT="$repo_root" \
"$zsh_bin" -f <<'ZSH'
set -e
compdef() { :; }
source "$REPO_ROOT/roles/zsh/files/zsh/k8s_aliases.zsh"
source "$REPO_ROOT/roles/zsh/files/zsh/jj_completions.zsh"
source "$REPO_ROOT/roles/zsh/files/zsh/kind_functions.zsh"
source "$REPO_ROOT/roles/zsh/files/zsh/minikube_functions.zsh"
source "$REPO_ROOT/roles/zsh/files/zsh/nvm_config.zsh"
if [[ -s "$TOOL_CALLS" ]]; then
  print -ru2 "tools ran during source: $(<"$TOOL_CALLS")"
  exit 1
fi
_kubectl_lazy_completion
if [[ "$(<"$TOOL_CALLS")" != $'kubectl completion zsh\nkubectl-completed' ]]; then
  print -ru2 "unexpected kubectl lazy calls: $(<"$TOOL_CALLS")"
  exit 1
fi
ZSH
