#!/usr/bin/env zsh

function kgnsonly() {
  kubectl get namespaces | awk 'NR!=1 {print $1}'
}

function kgnonly() {
  local flag=""
  local filter=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -a | --all)
      flag="all"
      shift
      ;;
    *)
      filter="$1"
      shift
      ;;
    esac
  done

  if [ "$flag" == "all" ]; then
    kgnonly.allCluster $filter | sort -u
    return
  fi

  if [ -z "$filter" ]; then
    kubectl get nodes | awk 'NR!=1 {print $1}'
    return
  fi
  kubectl get nodes | grep "$filter" | awk '{print $1}'
}

function kgnonly.allCluster() {
  local originalContext=$(kubectl config current-context)
  for cluster in $(kubectl config get-contexts -o=name); do
    kubectl config use-context $cluster >/dev/null 1>&1
    kgnonly $1
  done
  kubectl config use-context $originalContext >/dev/null 1>&1
}

function __kli_usage() {
  echo "Usage: kli [-A] [-n <namespace>] tag"
}

function kli() {
  local kubectl_args=""
  local tag=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -A)
      kubectl_args="$kubectl_args -A"
      shift
      ;;
    -n | --namespace)
      kubectl_args="$kubectl_args $1 $2"
      shift 2
      ;;
    -h | --help)
      __kli_usage
      return
      ;;
    *)
      tag="$tag $1"
      shift
      ;;
    esac
  done
  if [ -n "$tag" ]; then
    kubectl get pods $kubectl_args -o=custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,IMAGE:spec.containers[*].image | {
      head -1
      grep $tag
    } | column -t
    return
  fi
  kubectl get pods $kubectl_args -o=custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,IMAGE:spec.containers[*].image
}
# function kc() {
#     kubectl config use-context $1
# }
function __refresh_kubecontexts() {
  complete -W "$(kubectl config get-contexts -o=name)" kc
}

function __kgnsonly_complete() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W "$(kgnsonly)" -- $cur))
}

function __kgnonly_complete() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W "$(kgnonly)" -- $cur))
}

function __kc_complete() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W "$(kubectl config get-contexts -o=name)" -- $cur))
}

function k.node.debug() {
  if [ -z "$1" ]; then
    echo -e "${WARNING}${RED} Node name not found: ${YELLOW}$1${NC}"
    return
  fi
  echo -e "${YELLOW}===========================================${NC}"
  echo -e "${ARROW}${CYAN} $1 ${YELLOW}: [${GREEN}${@:2}${YELLOW}] : ${SEA}$(TZ="America/Chicago" date)${NC}"
  echo -e "${YELLOW}===========================================${NC}"
  kubectl debug node/$1 -qit --image=mcr.microsoft.com/dotnet/runtime-deps:6.0 --target $1 -- chroot /host bash
}

function k.togglePromptInfo() {
  # create export if not exists
  if [ -z "$SHOW_K8S_PROMPT_INFO" ]; then
    export SHOW_K8S_PROMPT_INFO="false"
    return
  elif [ "$SHOW_K8S_PROMPT_INFO" == "true" ]; then
    export SHOW_K8S_PROMPT_INFO="false"
    return
  elif [ "$SHOW_K8S_PROMPT_INFO" == "false" ]; then
    export SHOW_K8S_PROMPT_INFO="true"
    return
  fi
}

function __k_import_context_complete() {
  local -a opts
  opts=(
    '--destination[Destination kubeconfig file]:file:_files'
    '--import[Kubeconfig file to import]:file:_files'
    '--new-name[New name for context, cluster, and user]:new_name'
    '--ssh-session[SSH session for remote kubeconfig]:ssh_session:_ssh'
    '--remote-server[Remote server for the new cluster]:remote_server'
    '--help[Display usage information]'
  )
  _arguments $opts
}

function __k.importContext_usage() {
  echo -e "${BOLD}USAGE${NC}"
  echo "    k.importContext [options]"
  echo ""
  echo -e "${BOLD}OPTIONS${NC}"
  echo "  -d <destination_kubeconfig>  Destination kubeconfig file (default: \$HOME/.kube/config)"
  echo "  -i <import_file>             Kubeconfig file to import"
  echo "  -n <new_name>                New name for context, cluster, and user"
  echo "  -s <ssh_session>             SSH session for remote kubeconfig"
  echo "  -r <remote_server>           Remote server for the new cluster"
  echo "  -h, --help                   Display this help message"
}

# A function to take an external kube config file, rename the context,
# cluster, and user names before merging it with the current kube config
function k.importContext() {
  local dest_kubeconfig="$HOME/.kube/config"
  local import_file=""
  local new_name=""
  local ssh_session=""
  local remote_server=""

  # while getopts ":d:i:n:s:r:h" opt; do
  while [[ $# -gt 0 ]]; do
    case $1 in
    -d | --destination)
      dest_kubeconfig="$2"
      shift
      shift
      ;;
    -i | --import)
      import_file="$2"
      shift
      shift
      ;;
    -n | --new-name)
      new_name="$2"
      shift
      shift
      ;;
    -s | --ssh-session)
      ssh_session="$2"
      shift
      shift
      ;;
    -r | --remote-server)
      remote_server="$2"
      shift
      shift
      ;;
    -h | --help)
      __k.importContext_usage
      return 0
      ;;
    -* | --*)
      echo "Invalid option: ${RED}$1${NC}"
      return 1
      ;;
    *)
      printf "Invalid argument: ${RED}$1${NC}\n"
      return 1
    esac
  done

  if [ -z "$import_file" ] || [ -z "$new_name" ]; then
    printf "Missing required arguments ${RED}--import${NC} and ${RED}--new-name${NC}\n"
    __k.importContext_usage
    return 1
  fi

  # Backup the destination kube config
  __task "Backing up destination kubeconfig file"
  _cmd "cp $dest_kubeconfig ${dest_kubeconfig}.bak"

  if [ -n "$ssh_session" ]; then
    local remote_ip=$(echo "$ssh_session" | awk -F'@' '{print $2}')
    __task "[$remote_ip]:: Downloading remote kubeconfig file"
    _cmd "scp $ssh_session:$import_file /tmp/remote_kubeconfig"
    import_file="/tmp/remote_kubeconfig"
  fi

  if [ -n "$new_name" ]; then
    __task "Renaming context, cluster, and user names in the import file"
    _cmd "kubectl config --kubeconfig=$import_file rename-context $(kubectl config --kubeconfig=$import_file get-contexts -o=name) $new_name"
    _cmd "kubectl config --kubeconfig=$import_file set-cluster $new_name --server=$remote_ip"
    _cmd "kubectl config --kubeconfig=$import_file set-credentials $new_name"
  fi

  # Merge the import file with the destination kube config
  __task "Importing kubeconfig file"
  _cmd "KUBECONFIG=\"$dest_kubeconfig:$import_file\" kubectl config view --merge --flatten > /tmp/merged_kubeconfig"
  _cmd "mv /tmp/merged_kubeconfig $dest_kubeconfig"

  # Clean up
  if [ -n "$ssh_session" ]; then
    __task "Cleaning up remote kubeconfig file"
    _cmd "rm /tmp/remote_kubeconfig"
  fi

  __task "Kube config imported and merged successfully." && _task_done
}

compdef __k_import_context_complete k.importContext

# complete -o nospace -F __kc_complete kc
complete -o nospace -F __kgnonly_complete k.node.debug k.node.exec
# complete -o nospace -F __kgnsonly_complete kns
complete -W "master worker etcd control-plane" kgnonly kgnonly.allCluster
