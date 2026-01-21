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

# k.deleteContext - Clean up kubectl cluster and associated contexts/users
# Usage: k.deleteContext <cluster-name> [--force] [--dry-run]
function k.deleteContext() {
  local cluster_name=""
  local force=false
  local dry_run=false
  local kubeconfig_path="${KUBECONFIG:-$HOME/.kube/config}"
  local backup_dir="$HOME/.kube/backups"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force=true
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --help|-h)
        __k.deleteContext_usage
        return 0
        ;;
      *)
        if [[ -z "$cluster_name" ]]; then
          cluster_name="$1"
        else
          echo -e "${RED}Error: Multiple cluster names provided${NC}"
          __k.deleteContext_usage
          return 1
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$cluster_name" ]]; then
    echo -e "${RED}Error: Cluster name is required${NC}"
    __k.deleteContext_usage
    return 1
  fi

  # Verify kubeconfig exists
  if [[ ! -f "$kubeconfig_path" ]]; then
    echo -e "${RED}Error: kubeconfig not found at $kubeconfig_path${NC}"
    return 1
  fi

  # Dry run banner
  if [[ "$dry_run" == true ]]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}         DRY RUN MODE - NO CHANGES     ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
  fi

  # Check if cluster exists
  if ! kubectl config get-clusters | grep -q "^${cluster_name}$"; then
    echo -e "${RED}Error: Cluster '${cluster_name}' not found${NC}"
    echo ""
    echo "Available clusters:"
    kubectl config get-clusters
    return 1
  fi

  # Find contexts using this cluster
  echo -e "${YELLOW}Finding contexts for cluster: ${cluster_name}${NC}"
  local contexts=$(kubectl config get-contexts -o name | while read -r context; do
    local cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$context')].context.cluster}")
    if [[ "$cluster" == "$cluster_name" ]]; then
      echo "$context"
    fi
  done)

  local context_count=0
  if [[ -z "$contexts" ]]; then
    echo "No contexts found for this cluster"
  else
    context_count=$(echo "$contexts" | wc -l | tr -d ' ')
    echo -e "${GREEN}Found $context_count context(s):${NC}"
    echo "$contexts" | sed 's/^/  - /'
  fi

  # Find users from those contexts
  echo ""
  echo -e "${YELLOW}Finding users associated with contexts...${NC}"
  local users=""
  if [[ -n "$contexts" ]]; then
    users=$(echo "$contexts" | while read -r context; do
      kubectl config view -o jsonpath="{.contexts[?(@.name=='$context')].context.user}"
      echo ""
    done | sort -u | grep -v '^$')
  fi

  local user_count=0
  if [[ -z "$users" ]]; then
    echo "No users found"
  else
    user_count=$(echo "$users" | wc -l | tr -d ' ')
    echo -e "${GREEN}Found $user_count user(s):${NC}"
    echo "$users" | sed 's/^/  - /'
  fi

  # Check which users would actually be deleted (not used by other contexts)
  echo ""
  echo -e "${YELLOW}Checking user dependencies...${NC}"
  local users_to_delete=""
  local users_to_keep=""
  if [[ -n "$users" ]]; then
    while IFS= read -r user; do
      local other_contexts=$(kubectl config get-contexts -o name | while read -r ctx; do
        local ctx_cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$ctx')].context.cluster}")
        local ctx_user=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$ctx')].context.user}")
        if [[ "$ctx_user" == "$user" ]] && [[ "$ctx_cluster" != "$cluster_name" ]]; then
          echo "$ctx"
        fi
      done)

      if [[ -z "$other_contexts" ]]; then
        users_to_delete="${users_to_delete}${user}"$'\n'
      else
        users_to_keep="${users_to_keep}${user}"$'\n'
      fi
    done <<< "$users"

    # Clean up trailing newlines
    users_to_delete=$(echo "$users_to_delete" | grep -v '^$' || true)
    users_to_keep=$(echo "$users_to_keep" | grep -v '^$' || true)
  fi

  # Summary
  echo ""
  if [[ "$dry_run" == true ]]; then
    echo -e "${BLUE}=== Deletion Preview (DRY RUN) ===${NC}"
  else
    echo -e "${YELLOW}=== Deletion Summary ===${NC}"
  fi
  echo ""
  echo -e "Cluster to delete:  ${RED}$cluster_name${NC}"
  echo ""
  if [[ $context_count -gt 0 ]]; then
    echo -e "Contexts to delete: ${RED}$context_count${NC}"
    echo "$contexts" | sed 's/^/  - /'
  else
    echo -e "Contexts to delete: ${RED}0${NC}"
  fi
  echo ""

  local delete_count=0
  if [[ -n "$users_to_delete" ]]; then
    delete_count=$(echo "$users_to_delete" | wc -l | tr -d ' ')
    echo -e "Users to delete:    ${RED}$delete_count${NC}"
    echo "$users_to_delete" | sed 's/^/  - /'
  else
    echo -e "Users to delete:    ${RED}0${NC}"
  fi

  if [[ -n "$users_to_keep" ]]; then
    local keep_count=$(echo "$users_to_keep" | wc -l | tr -d ' ')
    echo ""
    echo -e "Users to keep (used by other clusters): ${GREEN}$keep_count${NC}"
    echo "$users_to_keep" | sed 's/^/  - /'
  fi
  echo ""

  # Exit if dry run
  if [[ "$dry_run" == true ]]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DRY RUN COMPLETE - NO CHANGES MADE  ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "To perform the actual deletion, run without --dry-run:"
    echo "  k.deleteContext $cluster_name"
    return 0
  fi

  # Confirmation
  if [[ "$force" == false ]]; then
    echo -e "${YELLOW}This will delete the cluster, all associated contexts, and unused users.${NC}"
    echo -n "Do you want to proceed? (yes/no): "
    read REPLY
    echo ""
    if [[ ! "$REPLY" =~ ^[Yy][Ee][Ss]$ ]]; then
      echo "Aborted."
      return 0
    fi
  fi

  # Create backup directory
  mkdir -p "$backup_dir"

  # Create backup
  local backup_file="$backup_dir/config.$(date +%Y%m%d_%H%M%S).backup"
  echo -e "${YELLOW}Creating backup...${NC}"
  cp "$kubeconfig_path" "$backup_file"
  echo -e "${GREEN}✓ Backup saved to: $backup_file${NC}"
  echo ""

  # Delete contexts
  if [[ -n "$contexts" ]]; then
    echo -e "${YELLOW}Deleting contexts...${NC}"
    echo "$contexts" | while read -r context; do
      if kubectl config delete-context "$context" &>/dev/null; then
        echo -e "${GREEN}✓ Deleted context: $context${NC}"
      else
        echo -e "${RED}✗ Failed to delete context: $context${NC}"
      fi
    done
    echo ""
  fi

  # Delete cluster
  echo -e "${YELLOW}Deleting cluster...${NC}"
  if kubectl config delete-cluster "$cluster_name" &>/dev/null; then
    echo -e "${GREEN}✓ Deleted cluster: $cluster_name${NC}"
  else
    echo -e "${RED}✗ Failed to delete cluster: $cluster_name${NC}"
  fi
  echo ""

  # Delete users
  if [[ -n "$users_to_delete" ]]; then
    echo -e "${YELLOW}Deleting users...${NC}"
    echo "$users_to_delete" | while read -r user; do
      if kubectl config delete-user "$user" &>/dev/null; then
        echo -e "${GREEN}✓ Deleted user: $user${NC}"
      else
        echo -e "${RED}✗ Failed to delete user: $user${NC}"
      fi
    done
  fi

  if [[ -n "$users_to_keep" ]]; then
    echo ""
    echo -e "${YELLOW}Skipped users (still used by other clusters):${NC}"
    echo "$users_to_keep" | sed 's/^/  ⊘ /'
  fi

  echo ""
  echo -e "${GREEN}=== Cleanup Complete ===${NC}"
  echo ""
  echo "To restore from backup:"
  echo "  cp $backup_file $kubeconfig_path"
}

# Usage helper function
function __k.deleteContext_usage() {
  echo -e "${BOLD}USAGE${NC}"
  echo "    k.deleteContext <cluster-name> [options]"
  echo ""
  echo -e "${BOLD}DESCRIPTION${NC}"
  echo "    Clean up a kubectl cluster and all associated contexts and users."
  echo ""
  echo -e "${BOLD}OPTIONS${NC}"
  echo "    --force       Skip confirmation prompt"
  echo "    --dry-run     Show what would be deleted without actually deleting"
  echo "    -h, --help    Display this help message"
  echo ""
  echo -e "${BOLD}EXAMPLES${NC}"
  echo "    k.deleteContext my-cluster --dry-run"
  echo "    k.deleteContext my-cluster"
  echo "    k.deleteContext production-cluster --force"
  echo ""
  echo "The function will:"
  echo "  1. Create a backup of your kubeconfig (unless --dry-run)"
  echo "  2. Find all contexts using the cluster"
  echo "  3. Find all users associated with those contexts"
  echo "  4. Delete the cluster, contexts, and users"
  echo ""
  echo "Backups are stored in: \$HOME/.kube/backups"
}

# Tab completion for k.deleteContext (ZSH native style like in .raftrc)
function _k.deleteContext() {
  local -a clusters
  clusters=(${(f)"$(kubectl config get-clusters 2>/dev/null | grep -v NAME)"})

  _arguments \
    '1:cluster:(($clusters))' \
    '(--force)--force[Skip confirmation prompt]' \
    '(--dry-run)--dry-run[Show what would be deleted without actually deleting]' \
    '(-h --help)'{-h,--help}'[Display help message]'
}

# Register the completion function with compdef (ZSH native)
compdef _k.deleteContext k.deleteContext

# complete -o nospace -F __kc_complete kc
complete -o nospace -F __kgnonly_complete k.node.debug k.node.exec
# complete -o nospace -F __kgnsonly_complete kns
complete -W "master worker etcd control-plane" kgnonly kgnonly.allCluster
