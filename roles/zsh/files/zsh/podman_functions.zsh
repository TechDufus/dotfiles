#!/usr/bin/env zsh

export PODMAN_MACHINE_LOW_NAME="${PODMAN_MACHINE_LOW_NAME:-podman-low}"
export PODMAN_MACHINE_HIGH_NAME="${PODMAN_MACHINE_HIGH_NAME:-podman-high}"

function __pm_usage() {
  echo -e "${BOLD}${CAT_BLUE}Podman Machine Helpers${NC}"
  echo -e "${DIM}Named machine switching for host-specific low/high Podman profiles.${NC}"
  echo ""
  echo -e "${BOLD}${CAT_TEAL}Commands${NC}"
  echo -e "  ${CAT_YELLOW}p.low${NC}      ${CAT_SUBTEXT0}Start ${PODMAN_MACHINE_LOW_NAME} and make it the active connection${NC}"
  echo -e "  ${CAT_YELLOW}p.high${NC}     ${CAT_SUBTEXT0}Start ${PODMAN_MACHINE_HIGH_NAME} and make it the active connection${NC}"
  echo -e "  ${CAT_YELLOW}p.use${NC}      ${CAT_SUBTEXT0}Switch to any existing machine name or logical profile${NC}"
  echo -e "  ${CAT_YELLOW}p.off${NC}      ${CAT_SUBTEXT0}Stop the currently running Podman machine${NC}"
  echo -e "  ${CAT_YELLOW}p.stop${NC}     ${CAT_SUBTEXT0}Stop every running Podman machine${NC}"
  echo -e "  ${CAT_YELLOW}p.current${NC}  ${CAT_SUBTEXT0}Show the active machine, resources, and default connection${NC}"
  echo -e "  ${CAT_YELLOW}p.status${NC}   ${CAT_SUBTEXT0}Show machine list plus current active machine details${NC}"
  echo -e "  ${CAT_YELLOW}p.setup${NC}    ${CAT_SUBTEXT0}Ensure the low/high profile machines exist with Podman defaults${NC}"
  echo -e "  ${CAT_YELLOW}p.help${NC}     ${CAT_SUBTEXT0}Show this help${NC}"
  echo ""
  echo -e "${BOLD}${CAT_TEAL}Profiles${NC}"
  echo -e "  ${CAT_GREEN}low${NC}   ${CAT_SUBTEXT0}->${NC} ${CAT_YELLOW}${PODMAN_MACHINE_LOW_NAME}${NC}"
  echo -e "  ${CAT_GREEN}high${NC}  ${CAT_SUBTEXT0}->${NC} ${CAT_YELLOW}${PODMAN_MACHINE_HIGH_NAME}${NC}"
  echo ""
  echo -e "${BOLD}${CAT_TEAL}Examples${NC}"
  echo -e "  ${CAT_SAPPHIRE}podman machine init --cpus 4 --memory 8192 --disk-size 120 ${PODMAN_MACHINE_LOW_NAME}${NC}"
  echo -e "  ${CAT_SAPPHIRE}podman machine init --cpus 8 --memory 32768 --disk-size 300 ${PODMAN_MACHINE_HIGH_NAME}${NC}"
  echo ""
  echo -e "${DIM}Resource sizes are per-host. The dotfiles only care about the machine names.${NC}"
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

function __pm_running_machine() {
  podman machine list --format '{{range .}}{{if .Running}}{{.Name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null | head -n 1
}

function __pm_running_machines() {
  podman machine list --format '{{range .}}{{if .Running}}{{.Name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null
}

function __pm_machine_exists() {
  podman machine inspect "$1" >/dev/null 2>&1
}

function __pm_ensure_machine_exists() {
  emulate -L zsh

  local machine="$1"

  if __pm_machine_exists "$machine"; then
    echo -e "${CHECK_MARK} ${GREEN}Podman machine already exists:${NC} ${YELLOW}${machine}${NC}"
    return 0
  fi

  echo -e "${ARROW} ${GREEN}Creating Podman machine with default settings:${NC} ${YELLOW}${machine}${NC}"
  podman machine init "$machine" || return 1
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
  local running="$(__pm_running_machine)"
  local connection=""

  if ! __pm_machine_exists "$target"; then
    echo -e "${WARNING}${RED} Podman machine not found: ${YELLOW}${target}${NC}"
    __pm_usage
    return 1
  fi

  if [[ -n "$running" && "$running" != "$target" ]]; then
    echo -e "${ARROW} ${GREEN}Stopping Podman machine:${NC} ${YELLOW}${running}${NC}"
    podman machine stop "$running" || return 1
  fi

  if [[ "$running" != "$target" ]]; then
    echo -e "${ARROW} ${GREEN}Starting Podman machine:${NC} ${YELLOW}${target}${NC}"
    podman machine start --no-info "$target" || return 1
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
  echo -e "${DIM}Missing machines are created with Podman defaults. Resource tuning remains your responsibility per host.${NC}"
  echo ""

  __pm_ensure_machine_exists "$PODMAN_MACHINE_LOW_NAME" || return 1
  __pm_ensure_machine_exists "$PODMAN_MACHINE_HIGH_NAME" || return 1

  echo ""
  echo -e "${CHECK_MARK} ${GREEN}Profile machines are ready:${NC} ${YELLOW}${PODMAN_MACHINE_LOW_NAME}${NC}, ${YELLOW}${PODMAN_MACHINE_HIGH_NAME}${NC}"
  echo -e "${DIM}If you need custom CPU/RAM/disk on libkrun-based macOS installs, recreate the machines with the same names and your desired specs.${NC}"
}

function p.help() {
  __pm_usage
}

if [[ -n "$ZSH_VERSION" ]] && [[ -n "${functions[compdef]}" ]]; then
  compdef _p.use p.use
fi
