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
mkdir -p "$bin_dir"

cat > "$bin_dir/uname" <<'UNAME'
#!/usr/bin/env sh
case "${1:-}" in
  ""|-s)
    printf '%s\n' "${FAKE_UNAME:-Darwin}"
    ;;
  *)
    exit 1
    ;;
esac
UNAME
chmod +x "$bin_dir/uname"

cat > "$bin_dir/podman" <<'PODMAN'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$PODMAN_CALLS"

machine_exists() {
  target="$1"
  while IFS= read -r machine || [ -n "$machine" ]; do
    [ "$machine" = "$target" ] && return 0
  done < "$PODMAN_EXISTING_FILE"
  return 1
}

add_machine() {
  target="$1"
  machine_exists "$target" && return 0
  printf '%s\n' "$target" >> "$PODMAN_EXISTING_FILE"
}

machine_vm_type() {
  target="$1"
  while IFS='	' read -r machine vm_type || [ -n "$machine" ]; do
    if [ "$machine" = "$target" ]; then
      printf '%s\n' "$vm_type"
      return 0
    fi
  done < "$PODMAN_VM_TYPES_FILE"
  return 1
}

list_libkrun_machines() {
  while IFS= read -r machine || [ -n "$machine" ]; do
    [ "$(machine_vm_type "$machine")" = "libkrun" ] && printf '%s\n' "$machine"
  done < "$PODMAN_EXISTING_FILE"
}

if [ "${1:-}" = "machine" ]; then
  case "${2:-}" in
    list)
      if [ "${3:-}" = "--format" ] && [ "${4#*VMType}" != "$4" ]; then
        list_libkrun_machines
      fi
      exit 0
      ;;
    inspect)
      machine_exists "${3:-}"
      exit $?
      ;;
    init)
      if [ "${3:-}" = "--provider" ]; then
        machine="${5:-}"
      else
        machine="${3:-}"
      fi

      if [ -z "$machine" ]; then
        exit 2
      fi

      if machine_exists "$machine"; then
        printf 'attempted to init existing machine: %s\n' "$machine" >&2
        exit 42
      fi

      add_machine "$machine"
      exit 0
      ;;
  esac
fi

exit 1
PODMAN
chmod +x "$bin_dir/podman"

run_p_setup() {
  local scenario_dir="$1"
  local fake_uname="$2"
  local podman_provider="$3"
  local containers_provider="$4"
  local existing_machines="$5"
  local vm_types="${6:-}"
  local krunkit_present="${7:-}"
  local scenario_bin="$scenario_dir/bin"

  mkdir -p "$scenario_bin"
  printf '%s' "$existing_machines" > "$scenario_dir/existing"
  printf '%s' "$vm_types" > "$scenario_dir/vm_types"
  : > "$scenario_dir/calls"

  if [[ "$krunkit_present" == "krunkit" ]]; then
    printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > "$scenario_bin/krunkit"
    chmod +x "$scenario_bin/krunkit"
  fi

  set +e
  PODMAN_CALLS="$scenario_dir/calls" \
  PODMAN_EXISTING_FILE="$scenario_dir/existing" \
  PODMAN_VM_TYPES_FILE="$scenario_dir/vm_types" \
  FAKE_UNAME="$fake_uname" \
  PODMAN_MACHINE_PROVIDER="$podman_provider" \
  CONTAINERS_MACHINE_PROVIDER="$containers_provider" \
  PODMAN_MACHINE_LOW_NAME="podman-low" \
  PODMAN_MACHINE_HIGH_NAME="podman-high" \
  PATH="$scenario_bin:$bin_dir:/usr/bin:/bin" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f <<'ZSH' > "$scenario_dir/output" 2>&1
set -e
source "$REPO_ROOT/roles/zsh/files/zsh/podman_functions.zsh"
p.setup
ZSH
  local status=$?
  set -e
  printf '%s\n' "$status" > "$scenario_dir/status"
}

count_call() {
  local calls_file="$1"
  local expected="$2"
  local count=0
  local call

  while IFS= read -r call || [[ -n "$call" ]]; do
    [[ "$call" == "$expected" ]] && count=$((count + 1))
  done < "$calls_file"

  printf '%s\n' "$count"
}

assert_success() {
  local scenario_dir="$1"
  local label="$2"

  if (( $(<"$scenario_dir/status") != 0 )); then
    printf '%s\n' "$label failed" >&2
    cat "$scenario_dir/output" >&2
    cat "$scenario_dir/calls" >&2
    exit 1
  fi
}

assert_failure() {
  local scenario_dir="$1"
  local label="$2"

  if (( $(<"$scenario_dir/status") == 0 )); then
    printf '%s\n' "$label succeeded unexpectedly" >&2
    cat "$scenario_dir/output" >&2
    cat "$scenario_dir/calls" >&2
    exit 1
  fi
}

assert_call_count() {
  local scenario_dir="$1"
  local expected="$2"
  local wanted="$3"
  local actual

  actual="$(count_call "$scenario_dir/calls" "$expected")"
  if [[ "$actual" != "$wanted" ]]; then
    printf 'expected %s occurrence(s) of %q in %s, got %s\n' "$wanted" "$expected" "$scenario_dir" "$actual" >&2
    cat "$scenario_dir/calls" >&2
    exit 1
  fi
}

assert_output_contains() {
  local scenario_dir="$1"
  local expected="$2"
  local output

  output="$(<"$scenario_dir/output")"
  case "$output" in
    *"$expected"*) ;;
    *)
      printf 'expected output to contain %q in %s\n' "$expected" "$scenario_dir" >&2
      printf '%s\n' "$output" >&2
      exit 1
      ;;
  esac
}

default_dir="$tmp_dir/default-darwin"
run_p_setup "$default_dir" Darwin "" "" ""
assert_success "$default_dir" "default Darwin provider scenario"
assert_call_count "$default_dir" 'machine init --provider applehv podman-low' 1
assert_call_count "$default_dir" 'machine init --provider applehv podman-high' 1
assert_output_contains "$default_dir" 'provider: applehv'

podman_env_dir="$tmp_dir/podman-provider-env"
run_p_setup "$podman_env_dir" Darwin libkrun applehv "" "" krunkit
assert_success "$podman_env_dir" "PODMAN_MACHINE_PROVIDER override scenario"
assert_call_count "$podman_env_dir" 'machine init --provider libkrun podman-low' 1
assert_call_count "$podman_env_dir" 'machine init --provider libkrun podman-high' 1
assert_call_count "$podman_env_dir" 'machine init --provider applehv podman-low' 0

missing_krunkit_dir="$tmp_dir/libkrun-missing-krunkit"
run_p_setup "$missing_krunkit_dir" Darwin libkrun "" ""
assert_failure "$missing_krunkit_dir" "missing krunkit libkrun provider scenario"
assert_output_contains "$missing_krunkit_dir" 'krunkit is missing'
assert_call_count "$missing_krunkit_dir" 'machine init --provider libkrun podman-low' 0

existing_missing_krunkit_dir="$tmp_dir/existing-libkrun-provider-missing-krunkit"
run_p_setup "$existing_missing_krunkit_dir" Darwin libkrun "" $'podman-low\npodman-high\n'
assert_success "$existing_missing_krunkit_dir" "existing machines with missing krunkit libkrun provider scenario"
assert_call_count "$existing_missing_krunkit_dir" 'machine init --provider libkrun podman-low' 0
assert_call_count "$existing_missing_krunkit_dir" 'machine init --provider libkrun podman-high' 0

mixed_missing_krunkit_dir="$tmp_dir/mixed-libkrun-provider-missing-krunkit"
run_p_setup "$mixed_missing_krunkit_dir" Darwin libkrun "" $'podman-low\n' $'podman-low	libkrun\n'
assert_failure "$mixed_missing_krunkit_dir" "mixed existing/missing machines with missing krunkit libkrun provider scenario"
assert_output_contains "$mixed_missing_krunkit_dir" 'Existing libkrun Podman machine(s) may not start'
assert_output_contains "$mixed_missing_krunkit_dir" 'Cannot create libkrun Podman machine because krunkit is missing'
assert_call_count "$mixed_missing_krunkit_dir" 'machine init --provider libkrun podman-low' 0
assert_call_count "$mixed_missing_krunkit_dir" 'machine init --provider libkrun podman-high' 0

mixed_high_missing_krunkit_dir="$tmp_dir/mixed-high-libkrun-provider-missing-krunkit"
run_p_setup "$mixed_high_missing_krunkit_dir" Darwin libkrun "" $'podman-high\n' $'podman-high	libkrun\n'
assert_failure "$mixed_high_missing_krunkit_dir" "mixed missing/existing machines with missing krunkit libkrun provider scenario"
assert_output_contains "$mixed_high_missing_krunkit_dir" 'Existing libkrun Podman machine(s) may not start'
assert_output_contains "$mixed_high_missing_krunkit_dir" 'Cannot create libkrun Podman machine because krunkit is missing'
assert_call_count "$mixed_high_missing_krunkit_dir" 'machine init --provider libkrun podman-low' 0
assert_call_count "$mixed_high_missing_krunkit_dir" 'machine init --provider libkrun podman-high' 0

containers_env_dir="$tmp_dir/containers-provider-env"
run_p_setup "$containers_env_dir" Darwin "" vfkit ""
assert_success "$containers_env_dir" "CONTAINERS_MACHINE_PROVIDER override scenario"
assert_call_count "$containers_env_dir" 'machine init --provider vfkit podman-low' 1
assert_call_count "$containers_env_dir" 'machine init --provider vfkit podman-high' 1

existing_dir="$tmp_dir/existing-low"
run_p_setup "$existing_dir" Darwin "" "" $'podman-low\n'
assert_success "$existing_dir" "existing machine scenario"
assert_call_count "$existing_dir" 'machine init --provider applehv podman-low' 0
assert_call_count "$existing_dir" 'machine init --provider applehv podman-high' 1

existing_libkrun_dir="$tmp_dir/existing-libkrun"
run_p_setup "$existing_libkrun_dir" Darwin "" "" $'podman-low\n' $'podman-low	libkrun\n'
assert_success "$existing_libkrun_dir" "existing libkrun warning scenario"
assert_output_contains "$existing_libkrun_dir" 'Existing libkrun Podman machine(s) may not start'
assert_output_contains "$existing_libkrun_dir" 'podman-low'

linux_dir="$tmp_dir/linux-no-provider"
run_p_setup "$linux_dir" Linux "" "" ""
assert_success "$linux_dir" "non-Darwin no-provider scenario"
assert_call_count "$linux_dir" 'machine init podman-low' 1
assert_call_count "$linux_dir" 'machine init podman-high' 1
assert_call_count "$linux_dir" 'machine init --provider applehv podman-low' 0
