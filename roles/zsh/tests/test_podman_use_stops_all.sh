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

cat > "$bin_dir/podman" <<'PODMAN'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$PODMAN_CALLS"

remove_running_machine() {
  target="$1"
  tmp_file="$PODMAN_STATE_FILE.tmp"
  : > "$tmp_file"
  while IFS= read -r machine; do
    [ "$machine" = "$target" ] || printf '%s\n' "$machine" >> "$tmp_file"
  done < "$PODMAN_STATE_FILE"
  mv "$tmp_file" "$PODMAN_STATE_FILE"
}

add_running_machine() {
  target="$1"
  found=0
  while IFS= read -r machine; do
    [ "$machine" = "$target" ] && found=1
  done < "$PODMAN_STATE_FILE"
  [ "$found" = 1 ] || printf '%s\n' "$target" >> "$PODMAN_STATE_FILE"
}

if [ "$1" = "machine" ]; then
  case "$2" in
    list)
      if [ "${3:-}" = "--format" ]; then
        case "${4:-}" in
          *Running*) cat "$PODMAN_STATE_FILE" ;;
          *VMType*) cat "$PODMAN_VM_TYPES_FILE" ;;
          *Name*) printf '%s\n' podman-low podman-high stray-machine ;;
        esac
      else
        printf '%s\n' 'NAME VM TYPE CREATED LAST UP CPUS MEMORY DISK SIZE'
      fi
      exit 0
      ;;
    inspect)
      if [ "${3:-}" = "--format" ]; then
        case "${4:-}" in
          *Rootful*) printf '%s\n' false ;;
          *SSHConfig.Port*) printf '%s\n' 12345 ;;
          *SSHConfig.RemoteUsername*) printf '%s\n' core ;;
          *Resources.CPUs*) printf '%s\n' 4 ;;
          *Resources.Memory*) printf '%s\n' 8192 ;;
          *Resources.DiskSize*) printf '%s\n' 120 ;;
        esac
      fi
      exit 0
      ;;
    stop)
      if [ "${PODMAN_FAIL_STOP:-}" = "${3:-}" ]; then
        exit 17
      fi
      remove_running_machine "${3:-}"
      exit 0
      ;;
    start)
      target=
      for arg do
        target="$arg"
      done
      add_running_machine "$target"
      exit 0
      ;;
  esac
fi

if [ "$1" = "system" ] && [ "$2" = "connection" ]; then
  case "$3" in
    list)
      printf '%s\t%s\n' podman-low 'ssh://core@127.0.0.1:12345/run/user/502/podman/podman.sock'
      exit 0
      ;;
    default)
      printf '%s\n' "${4:-}" > "$PODMAN_DEFAULT_FILE"
      exit 0
      ;;
  esac
fi

exit 1
PODMAN
chmod +x "$bin_dir/podman"

run_p_use() {
  local scenario_dir="$1"
  local fail_stop="${2:-}"
  local vm_types="${3:-}"
  local running_state="${4:-}"

  mkdir -p "$scenario_dir"
  if [[ -n "$running_state" ]]; then
    printf '%s' "$running_state" > "$scenario_dir/state"
  else
    printf '%s\n' podman-high stray-machine > "$scenario_dir/state"
  fi
  if [[ -n "$vm_types" ]]; then
    printf '%s' "$vm_types" > "$scenario_dir/vm_types"
  else
    printf '%s\t%s\n' podman-low applehv podman-high applehv stray-machine applehv > "$scenario_dir/vm_types"
  fi
  : > "$scenario_dir/calls"
  : > "$scenario_dir/default"

  set +e
  PODMAN_CALLS="$scenario_dir/calls" \
  PODMAN_STATE_FILE="$scenario_dir/state" \
  PODMAN_DEFAULT_FILE="$scenario_dir/default" \
  PODMAN_VM_TYPES_FILE="$scenario_dir/vm_types" \
  PODMAN_FAIL_STOP="$fail_stop" \
  PATH="$bin_dir:/usr/bin:/bin" \
  REPO_ROOT="$repo_root" \
  "$zsh_bin" -f <<'ZSH' > "$scenario_dir/output" 2>&1
set -e
source "$REPO_ROOT/roles/zsh/files/zsh/podman_functions.zsh"
p.use low
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

  while IFS= read -r call; do
    [[ "$call" == "$expected" ]] && count=$((count + 1))
  done < "$calls_file"

  printf '%s\n' "$count"
}

assert_stops_before_start() {
  local calls_file="$1"
  local stopped_high=0
  local stopped_stray=0
  local call

  while IFS= read -r call; do
    case "$call" in
      'machine stop podman-high') stopped_high=1 ;;
      'machine stop stray-machine') stopped_stray=1 ;;
      'machine start --no-info --update-connection podman-low')
        if (( ! stopped_high || ! stopped_stray )); then
          printf '%s\n' 'podman-low started before all non-target machines stopped' >&2
          cat "$calls_file" >&2
          exit 1
        fi
        ;;
    esac
  done < "$calls_file"
}

success_dir="$tmp_dir/success"
run_p_use "$success_dir"

if (( $(<"$success_dir/status") != 0 )); then
  printf '%s\n' 'p.use failed in successful stop/start scenario' >&2
  cat "$success_dir/output" >&2
  exit 1
fi

if (( $(count_call "$success_dir/calls" 'machine stop podman-high') != 1 || \
      $(count_call "$success_dir/calls" 'machine stop stray-machine') != 1 || \
      $(count_call "$success_dir/calls" 'machine stop podman-low') != 0 || \
      $(count_call "$success_dir/calls" 'machine start --no-info --update-connection podman-low') != 1 || \
      $(count_call "$success_dir/calls" 'system connection default podman-low') != 1 )); then
  printf 'unexpected successful scenario calls:\n' >&2
  cat "$success_dir/calls" >&2
  exit 1
fi

assert_stops_before_start "$success_dir/calls"

success_output="$(<"$success_dir/output")"
case "$success_output" in
  *'Current Podman machine:'*'podman-low'*'Default connection:'*'podman-low'*) ;;
  *)
    printf 'unexpected successful scenario output:\n%s\n' "$success_output" >&2
    exit 1
    ;;
esac

failed_dir="$tmp_dir/failed-stop"
run_p_use "$failed_dir" podman-high

if (( $(<"$failed_dir/status") == 0 )); then
  printf '%s\n' 'p.use succeeded despite a failed non-target stop' >&2
  cat "$failed_dir/calls" >&2
  exit 1
fi

if (( $(count_call "$failed_dir/calls" 'machine stop podman-high') != 1 || \
      $(count_call "$failed_dir/calls" 'machine stop stray-machine') != 1 || \
      $(count_call "$failed_dir/calls" 'machine start --no-info --update-connection podman-low') != 0 || \
      $(count_call "$failed_dir/calls" 'system connection default podman-low') != 0 )); then
  printf 'unexpected failed-stop scenario calls:\n' >&2
  cat "$failed_dir/calls" >&2
  exit 1
fi

default_marker_dir="$tmp_dir/default-marker"
run_p_use "$default_marker_dir" "" "" $'podman-low*\npodman-high\n'

if (( $(<"$default_marker_dir/status") != 0 )); then
  printf '%s\n' 'p.use failed when running target name included Podman default marker' >&2
  cat "$default_marker_dir/output" >&2
  cat "$default_marker_dir/calls" >&2
  exit 1
fi

if (( $(count_call "$default_marker_dir/calls" 'machine stop podman-low*') != 0 || \
      $(count_call "$default_marker_dir/calls" 'machine stop podman-low') != 0 || \
      $(count_call "$default_marker_dir/calls" 'machine stop podman-high') != 1 || \
      $(count_call "$default_marker_dir/calls" 'machine start --no-info --update-connection podman-low') != 0 || \
      $(count_call "$default_marker_dir/calls" 'system connection default podman-low') != 1 )); then
  printf 'unexpected default-marker scenario calls:\n' >&2
  cat "$default_marker_dir/calls" >&2
  exit 1
fi

libkrun_missing_dir="$tmp_dir/libkrun-missing-krunkit"
run_p_use "$libkrun_missing_dir" "" $'podman-low	libkrun\npodman-high	applehv\nstray-machine	applehv\n'

if (( $(<"$libkrun_missing_dir/status") == 0 )); then
  printf '%s\n' 'p.use succeeded despite missing krunkit for target libkrun machine' >&2
  cat "$libkrun_missing_dir/output" >&2
  cat "$libkrun_missing_dir/calls" >&2
  exit 1
fi

case "$(<"$libkrun_missing_dir/output")" in
  *'Cannot start libkrun Podman machine because krunkit is missing:'*'podman-low'*) ;;
  *)
    printf 'unexpected libkrun missing output:\n' >&2
    cat "$libkrun_missing_dir/output" >&2
    exit 1
    ;;
esac

if (( $(count_call "$libkrun_missing_dir/calls" 'machine stop podman-high') != 0 || \
      $(count_call "$libkrun_missing_dir/calls" 'machine stop stray-machine') != 0 || \
      $(count_call "$libkrun_missing_dir/calls" 'machine start --no-info --update-connection podman-low') != 0 || \
      $(count_call "$libkrun_missing_dir/calls" 'system connection default podman-low') != 0 )); then
  printf 'unexpected libkrun missing calls:\n' >&2
  cat "$libkrun_missing_dir/calls" >&2
  exit 1
fi

running_libkrun_dir="$tmp_dir/running-libkrun-missing-krunkit"
run_p_use "$running_libkrun_dir" "" $'podman-low	libkrun\npodman-high	applehv\nstray-machine	applehv\n' $'podman-low\n'

if (( $(<"$running_libkrun_dir/status") != 0 )); then
  printf '%s\n' 'p.use failed for already-running libkrun target with missing krunkit' >&2
  cat "$running_libkrun_dir/output" >&2
  cat "$running_libkrun_dir/calls" >&2
  exit 1
fi

case "$(<"$running_libkrun_dir/output")" in
  *'Podman machine already running:'*'podman-low'*'Default connection:'*'podman-low'*) ;;
  *)
    printf 'unexpected running libkrun output:\n' >&2
    cat "$running_libkrun_dir/output" >&2
    exit 1
    ;;
esac

if (( $(count_call "$running_libkrun_dir/calls" 'machine stop podman-low') != 0 || \
      $(count_call "$running_libkrun_dir/calls" 'machine stop podman-high') != 0 || \
      $(count_call "$running_libkrun_dir/calls" 'machine stop stray-machine') != 0 || \
      $(count_call "$running_libkrun_dir/calls" 'machine start --no-info --update-connection podman-low') != 0 || \
      $(count_call "$running_libkrun_dir/calls" 'system connection default podman-low') != 1 )); then
  printf 'unexpected running libkrun calls:\n' >&2
  cat "$running_libkrun_dir/calls" >&2
  exit 1
fi
