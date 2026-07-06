#!/usr/bin/env zsh

export PODMAN_MACHINE_LOW_NAME="${PODMAN_MACHINE_LOW_NAME:-podman-low}"
export PODMAN_MACHINE_HIGH_NAME="${PODMAN_MACHINE_HIGH_NAME:-podman-high}"

function __pm_usage() {
  echo -e "${BOLD}${CAT_BLUE}Podman Machine Helpers${NC}"
  echo -e "${DIM}Named machine switching for host-specific low/high Podman profiles.${NC}"
  echo ""
  echo -e "${BOLD}${CAT_TEAL}Commands${NC}"
  echo -e "  ${CAT_YELLOW}p.low${NC}      ${CAT_SUBTEXT0}Stop other running machines, start ${PODMAN_MACHINE_LOW_NAME}, and make it active${NC}"
  echo -e "  ${CAT_YELLOW}p.high${NC}     ${CAT_SUBTEXT0}Stop other running machines, start ${PODMAN_MACHINE_HIGH_NAME}, and make it active${NC}"
  echo -e "  ${CAT_YELLOW}p.use${NC}      ${CAT_SUBTEXT0}Switch to any existing machine/profile after stopping other running machines${NC}"
  echo -e "  ${CAT_YELLOW}p.off${NC}      ${CAT_SUBTEXT0}Stop the currently running Podman machine${NC}"
  echo -e "  ${CAT_YELLOW}p.stop${NC}     ${CAT_SUBTEXT0}Stop every running Podman machine${NC}"
  echo -e "  ${CAT_YELLOW}p.current${NC}  ${CAT_SUBTEXT0}Show the active machine, resources, and default connection${NC}"
  echo -e "  ${CAT_YELLOW}p.status${NC}   ${CAT_SUBTEXT0}Show machine list plus current active machine details${NC}"
  echo -e "  ${CAT_YELLOW}p.setup${NC}    ${CAT_SUBTEXT0}Ensure missing low/high machines exist; macOS defaults new machines to applehv${NC}"
  echo -e "  ${CAT_YELLOW}p.help${NC}     ${CAT_SUBTEXT0}Show this help${NC}"
  echo ""
  echo -e "${BOLD}${CAT_TEAL}Profiles${NC}"
  echo -e "  ${CAT_GREEN}low${NC}   ${CAT_SUBTEXT0}->${NC} ${CAT_YELLOW}${PODMAN_MACHINE_LOW_NAME}${NC}"
  echo -e "  ${CAT_GREEN}high${NC}  ${CAT_SUBTEXT0}->${NC} ${CAT_YELLOW}${PODMAN_MACHINE_HIGH_NAME}${NC}"
  echo ""
  echo -e "${BOLD}${CAT_TEAL}Examples${NC}"
  echo -e "  ${CAT_SAPPHIRE}p.setup${NC}"
  echo -e "  ${CAT_SAPPHIRE}PODMAN_MACHINE_PROVIDER=<provider> p.setup${NC}"
  echo ""
  echo -e "${DIM}p.setup creates missing machines only; existing machines are not changed.${NC}"
  echo -e "${DIM}Provider order for new machines: PODMAN_MACHINE_PROVIDER, CONTAINERS_MACHINE_PROVIDER, then applehv on macOS.${NC}"
}

function __pm_require_podman() {
  if ! command -v podman >/dev/null 2>&1; then
    echo -e "${WARNING}${RED} podman is not installed${NC}"
    return 1
  fi
}

function __pm_resolve_machine_name() {
  case "$1" in
  low)
    print -r -- "$PODMAN_MACHINE_LOW_NAME"
    ;;
  high)
    print -r -- "$PODMAN_MACHINE_HIGH_NAME"
    ;;
  *)
    print -r -- "$1"
    ;;
  esac
}

function __pm_running_machines() {
  emulate -L zsh

  local -a running_machines
  running_machines=(${(f)"$(podman machine list --format '{{range .}}{{if .Running}}{{.Name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null)"})
  running_machines=(${running_machines/%\*/})
  print -r -- ${(F)running_machines}
}

function __pm_running_machine() {
  __pm_running_machines | head -n 1
}

function __pm_machine_exists() {
  podman machine inspect "$1" >/dev/null 2>&1
}

function __pm_machine_provider() {
  if [[ -n "${PODMAN_MACHINE_PROVIDER:-}" ]]; then
    print -r -- "$PODMAN_MACHINE_PROVIDER"
    return 0
  fi

  if [[ -n "${CONTAINERS_MACHINE_PROVIDER:-}" ]]; then
    print -r -- "$CONTAINERS_MACHINE_PROVIDER"
    return 0
  fi

  if [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
    print -r -- "applehv"
  fi
}

function __pm_validate_machine_provider() {
  local provider="$1"

  if [[ "$provider" == "libkrun" && "$(uname -s 2>/dev/null)" == "Darwin" ]] && ! command -v krunkit >/dev/null 2>&1; then
    echo -e "${WARNING}${RED} Cannot create libkrun Podman machine because krunkit is missing${NC}"
    echo -e "${DIM}Use the default applehv provider, set PODMAN_MACHINE_PROVIDER=applehv, or install a Podman backend that provides krunkit.${NC}"
    return 1
  fi

  return 0
}

function __pm_machine_vm_type() {
  emulate -L zsh

  local machine="$1"
  local name vm_type

  while IFS=$'\t' read -r name vm_type; do
    name="${name%\*}"
    if [[ "$name" == "$machine" ]]; then
      print -r -- "$vm_type"
      return 0
    fi
  done < <(podman machine list --format '{{range .}}{{.Name}}{{"\t"}}{{.VMType}}{{"\n"}}{{end}}' 2>/dev/null)
}

function __pm_validate_machine_startable() {
  local machine="$1"
  local vm_type="$(__pm_machine_vm_type "$machine")"

  if [[ "$vm_type" == "libkrun" && "$(uname -s 2>/dev/null)" == "Darwin" ]] && ! command -v krunkit >/dev/null 2>&1; then
    echo -e "${WARNING}${RED} Cannot start libkrun Podman machine because krunkit is missing:${NC} ${YELLOW}${machine}${NC}"
    echo -e "${DIM}Recreate this machine with --provider applehv to migrate; recreating removes VM-stored images, containers, and volumes.${NC}"
    return 1
  fi

  return 0
}

function __pm_warn_missing_krunkit_for_libkrun() {
  emulate -L zsh

  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] || return 0
  command -v krunkit >/dev/null 2>&1 && return 0

  local -a libkrun_machines
  libkrun_machines=(${(f)"$(podman machine list --format '{{range .}}{{if eq .VMType "libkrun"}}{{.Name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null)"})
  libkrun_machines=(${libkrun_machines/%\*/})
  (( ${#libkrun_machines[@]} > 0 )) || return 0

  echo -e "${WARNING}${YELLOW} Existing libkrun Podman machine(s) may not start because krunkit is missing:${NC} ${YELLOW}${(j:, :)libkrun_machines}${NC}"
  echo -e "${DIM}p.setup only creates missing machines. Recreate affected machines with --provider applehv to migrate; recreating removes VM-stored images, containers, and volumes.${NC}"
}

function __pm_ensure_machine_exists() {
  emulate -L zsh

  local machine="$1"
  local provider="$(__pm_machine_provider)"

  if __pm_machine_exists "$machine"; then
    echo -e "${CHECK_MARK} ${GREEN}Podman machine already exists:${NC} ${YELLOW}${machine}${NC}"
    return 0
  fi

  __pm_validate_machine_provider "$provider" || return 1

  if [[ -n "$provider" ]]; then
    echo -e "${ARROW} ${GREEN}Creating Podman machine with default settings (provider: ${provider}):${NC} ${YELLOW}${machine}${NC}"
    podman machine init --provider "$provider" "$machine" || return 1
  else
    echo -e "${ARROW} ${GREEN}Creating Podman machine with default settings:${NC} ${YELLOW}${machine}${NC}"
    podman machine init "$machine" || return 1
  fi

  echo -e "${CHECK_MARK} ${GREEN}Created Podman machine:${NC} ${YELLOW}${machine}${NC}"
}

function __pm_machine_rootful() {
  podman machine inspect --format '{{.Rootful}}' "$1" 2>/dev/null
}

function __pm_machine_port() {
  podman machine inspect --format '{{.SSHConfig.Port}}' "$1" 2>/dev/null
}

function __pm_machine_user() {
  podman machine inspect --format '{{.SSHConfig.RemoteUsername}}' "$1" 2>/dev/null
}

function __pm_format_mib() {
  local mib="$1"
  if [[ -z "$mib" ]]; then
    print -r -- "unknown"
    return 0
  fi

  if (( mib >= 1024 )); then
    print -r -- "$((mib / 1024))GiB"
    return 0
  fi

  print -r -- "${mib}MiB"
}

function __pm_connection_name_for_machine() {
  local machine="$1"
  local rootful="$(__pm_machine_rootful "$machine")"
  local port="$(__pm_machine_port "$machine")"
  local remote_user="$(__pm_machine_user "$machine")"
  local ssh_user="$remote_user"
  local connection=""

  if [[ "$rootful" == "true" ]]; then
    ssh_user="root"
  fi

  connection=$(
    podman system connection list --format '{{range .}}{{.Name}}{{"\t"}}{{.URI}}{{"\n"}}{{end}}' 2>/dev/null |
      awk -F '\t' -v port="$port" -v ssh_user="$ssh_user" '
        $2 ~ ("ssh://" ssh_user "@") && $2 ~ (":" port "/") { print $1; exit }
      '
  )

  if [[ -n "$connection" ]]; then
    print -r -- "$connection"
    return 0
  fi

  if [[ "$rootful" == "true" ]]; then
    print -r -- "${machine}-root"
    return 0
  fi

  print -r -- "$machine"
}

function _p.use() {
  emulate -L zsh

  local -a machine_names suggestions
  machine_names=()
  suggestions=(
    "low:${PODMAN_MACHINE_LOW_NAME}"
    "high:${PODMAN_MACHINE_HIGH_NAME}"
  )

  if command -v podman >/dev/null 2>&1; then
    machine_names=(${(f)"$(podman machine list --format '{{.Name}}' 2>/dev/null)"})
    machine_names=(${machine_names%\*})
    machine_names=(${machine_names:#$PODMAN_MACHINE_LOW_NAME})
    machine_names=(${machine_names:#$PODMAN_MACHINE_HIGH_NAME})
  fi

  _describe -t podman-profiles 'podman profile' suggestions
  (( ${#machine_names[@]} > 0 )) && _describe -t podman-machines 'podman machine' machine_names
}

function p.use() {
  emulate -L zsh

  __pm_require_podman || return 1

  if [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]]; then
    __pm_usage
    return 0
  fi

  local target="$(__pm_resolve_machine_name "$1")"
  local connection=""
  local -a running_machines
  local machine target_running=0 stop_status=0

  running_machines=(${(f)"$(__pm_running_machines)"})

  if ! __pm_machine_exists "$target"; then
    echo -e "${WARNING}${RED} Podman machine not found: ${YELLOW}${target}${NC}"
    __pm_usage
    return 1
  fi

  for machine in "${running_machines[@]}"; do
    if [[ "$machine" == "$target" ]]; then
      target_running=1
      break
    fi
  done

  if (( ! target_running )); then
    __pm_validate_machine_startable "$target" || return 1
  fi

  for machine in "${running_machines[@]}"; do
    [[ "$machine" == "$target" ]] && continue

    echo -e "${ARROW} ${GREEN}Stopping Podman machine:${NC} ${YELLOW}${machine}${NC}"
    podman machine stop "$machine" || stop_status=1
  done

  if (( stop_status != 0 )); then
    return "$stop_status"
  fi

  if (( ! target_running )); then
    echo -e "${ARROW} ${GREEN}Starting Podman machine:${NC} ${YELLOW}${target}${NC}"
    podman machine start --no-info --update-connection "$target" || return 1
  else
    echo -e "${ARROW} ${GREEN}Podman machine already running:${NC} ${YELLOW}${target}${NC}"
  fi

  connection="$(__pm_connection_name_for_machine "$target")"
  if [[ -z "$connection" ]]; then
    echo -e "${WARNING}${RED} Could not determine Podman connection for:${NC} ${YELLOW}${target}${NC}"
    return 1
  fi

  podman system connection default "$connection" >/dev/null || return 1
  echo -e "${CHECK_MARK} ${GREEN}Default Podman connection:${NC} ${YELLOW}${connection}${NC}"

  p.current
}

function p.low() {
  p.use low
}

function p.high() {
  p.use high
}

function p.off() {
  emulate -L zsh

  __pm_require_podman || return 1

  local running="$(__pm_running_machine)"
  if [[ -z "$running" ]]; then
    echo -e "${ARROW} ${GREEN}No Podman machine is running${NC}"
    return 0
  fi

  echo -e "${ARROW} ${GREEN}Stopping Podman machine:${NC} ${YELLOW}${running}${NC}"
  podman machine stop "$running"
}

function p.stop() {
  emulate -L zsh

  __pm_require_podman || return 1

  local -a running_machines
  local machine stop_status=0

  running_machines=(${(f)"$(__pm_running_machines)"})
  if (( ${#running_machines[@]} == 0 )); then
    echo -e "${ARROW} ${GREEN}No Podman machines are running${NC}"
    return 0
  fi

  for machine in "${running_machines[@]}"; do
    echo -e "${ARROW} ${GREEN}Stopping Podman machine:${NC} ${YELLOW}${machine}${NC}"
    podman machine stop "$machine" || stop_status=1
  done

  return "$stop_status"
}

function p.current() {
  emulate -L zsh

  __pm_require_podman || return 1

  local running="$(__pm_running_machine)"
  if [[ -z "$running" ]]; then
    echo -e "${ARROW} ${GREEN}No Podman machine is running${NC}"
    return 0
  fi

  local cpus="$(podman machine inspect --format '{{.Resources.CPUs}}' "$running" 2>/dev/null)"
  local memory="$(podman machine inspect --format '{{.Resources.Memory}}' "$running" 2>/dev/null)"
  local disk_size="$(podman machine inspect --format '{{.Resources.DiskSize}}' "$running" 2>/dev/null)"
  local rootful="$(__pm_machine_rootful "$running")"
  local connection="$(__pm_connection_name_for_machine "$running")"
  local profile="custom"

  if [[ "$running" == "$PODMAN_MACHINE_LOW_NAME" ]]; then
    profile="low"
  elif [[ "$running" == "$PODMAN_MACHINE_HIGH_NAME" ]]; then
    profile="high"
  fi

  echo -e "${ARROW} ${GREEN}Current Podman machine:${NC} ${YELLOW}${running}${NC} (${profile})"
  echo -e "${ARROW} ${GREEN}Resources:${NC} ${YELLOW}${cpus}${NC} CPU, ${YELLOW}$(__pm_format_mib "$memory")${NC} RAM, ${YELLOW}${disk_size}GiB${NC} disk"
  echo -e "${ARROW} ${GREEN}Mode:${NC} ${YELLOW}${rootful}${NC}"
  echo -e "${ARROW} ${GREEN}Default connection:${NC} ${YELLOW}${connection}${NC}"
}

function p.status() {
  emulate -L zsh

  __pm_require_podman || return 1

  podman machine list
  echo ""
  p.current
}

function p.setup() {
  emulate -L zsh

  __pm_require_podman || return 1

  if [[ -n "$1" && "$1" != "-h" && "$1" != "--help" ]]; then
    echo -e "${WARNING}${RED} p.setup does not take arguments${NC}"
    __pm_usage
    return 1
  fi

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    __pm_usage
    return 0
  fi


  echo -e "${BOLD}${CAT_BLUE}Ensuring Podman profile machines exist${NC}"
  echo -e "${DIM}Missing machines are created with Podman defaults. On macOS, new machines use applehv unless a provider env var is set.${NC}"
  echo ""
  __pm_warn_missing_krunkit_for_libkrun

  __pm_ensure_machine_exists "$PODMAN_MACHINE_LOW_NAME" || return 1
  __pm_ensure_machine_exists "$PODMAN_MACHINE_HIGH_NAME" || return 1

  echo ""
  echo -e "${CHECK_MARK} ${GREEN}Profile machines are ready:${NC} ${YELLOW}${PODMAN_MACHINE_LOW_NAME}${NC}, ${YELLOW}${PODMAN_MACHINE_HIGH_NAME}${NC}"
  echo -e "${DIM}Existing machines are unchanged. Recreate manually for custom CPU/RAM/disk/provider; that removes VM-stored images, containers, and volumes.${NC}"
}

function p.help() {
  __pm_usage
}

if [[ -n "$ZSH_VERSION" ]] && [[ -n "${functions[compdef]}" ]]; then
  compdef _p.use p.use
fi
