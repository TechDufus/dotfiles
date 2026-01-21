#!/usr/bin/env bash

function kgp() {
    kubectl get pods $@
}
function kga() {
        kubectl get all $@
}
function kgs() {
        kubectl get service $@
}
function kgn() {
        kubectl get nodes -o wide $@
}
function kns() {
    kubectl config set-context --current --namespace $1
}
function kgns() {
    kubectl get namespaces
}
function kgnsonly() {
    kubectl get namespaces | awk 'NR!=1 {print $1}'
}
function kgnonly() {
    local flag=""
    local filter=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)
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
        kubectl config use-context $cluster > /dev/null 1>&1
        kgnonly $1
    done
    kubectl config use-context $originalContext > /dev/null 1>&1
}
function kd() {
        kubectl describe $@
}
function kl() {
        kubectl logs $@
}
function ka() {
        kubectl apply $@
}
function ktp() {
        kubectl top pods $@
}
function kli() {
  function usage() {
    echo "Usage: kli [-A] [-n <namespace>] tag"
  }
  local kubectl_args=""
  local tag=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -A)
        kubectl_args="$kubectl_args -A"
        shift
        ;;
      -n|--namespace)
        kubectl_args="$kubectl_args $1 $2"
        shift 2
        ;;
      -h|--help)
        usage
        return
        ;;
      *)
        tag="$tag $1"
        shift
        ;;
    esac
  done
  if [ -n "$tag" ]; then
    kubectl get pods $kubectl_args -o=custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,IMAGE:spec.containers[*].image | { head -1;grep $tag; } | column -t
    return
  fi
  kubectl get pods $kubectl_args -o=custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,IMAGE:spec.containers[*].image
}
function kexec() {
    kubectl exec -it -- $@
}
function kc() {
    kubectl config use-context $1
}
function __refresh_kubecontexts() {
    complete -W "$(kubectl config get-contexts -o=name)" kc
}

function __kgnsonly_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "$(kgnsonly)" -- $cur) )
}

function __kgnonly_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "$(kgnonly)" -- $cur) )
}

function __kc_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "$(kubectl config get-contexts -o=name)" -- $cur) )
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

select_pod() {
  command -v fzf >/dev/null || {
    echo "❌ fzf is not installed."
    return 1
  }
  command -v jq >/dev/null || {
    echo "❌ jq is not installed."
    return 1
  }

  search_term="$1"
  prioritize_active="$2" # Set to "true" to prioritize non-completed pods

  # Get all pods
  if [ "$prioritize_active" = "true" ]; then
    # Prioritize non-completed pods (sort active pods first)
    all_pods=$(kubectl get pods --no-headers | awk '{print $1, $3}' | sort -k2,2 -r)
  else
    all_pods=$(kubectl get pods --no-headers)
  fi

  if [ -z "$search_term" ]; then
    # No search term provided, show all pods in fzf
    selected_pod=$(echo "$all_pods" | fzf --height 40% --reverse | awk '{print $1}')
    echo "$selected_pod"
    return 0
  fi

  # Try to find pods matching the search term
  matching_pods=$(echo "$all_pods" | grep -i "$search_term")

  # Count the number of matching pods
  match_count=$(echo "$matching_pods" | grep -v "^$" | wc -l)

  if [ "$match_count" -eq 1 ]; then
    # Exactly one match found, return it directly
    pod_name=$(echo "$matching_pods" | awk '{print $1}' | tr -d '\n')
    echo "$pod_name"
    return 0
  elif [ "$match_count" -gt 1 ]; then
    # Multiple matches found, let user select with fzf
    echo "Found $match_count pods matching '$search_term'. Please select one:" >&2
    selected_pod=$(echo "$matching_pods" | fzf --height 40% --reverse --query="$search_term" | awk '{print $1}')
    echo "$selected_pod"
    return 0
  else
    # No exact matches found, try fuzzy finding with fzf
    echo "No exact matches for '$search_term'. Trying fuzzy search:" >&2

    # Use fzf's built-in fuzzy matching to find potential matches
    fuzzy_matches=$(echo "$all_pods" | fzf --filter="$search_term" | wc -l)

    if [ "$fuzzy_matches" -eq 1 ]; then
      # Only one fuzzy match found, use it directly
      fuzzy_pod=$(echo "$all_pods" | fzf --filter="$search_term" | awk '{print $1}')
      echo "Found single fuzzy match: $fuzzy_pod" >&2
      echo "$fuzzy_pod"
      return 0
    else
      # Multiple or no fuzzy matches, let user select with fzf
      echo "Select from all pods:" >&2
      selected_pod=$(echo "$all_pods" | fzf --height 40% --reverse --query="$search_term" | awk '{print $1}')
      echo "$selected_pod"
      return 0
    fi
  fi
}

# Get pod logs with fzf selection
kpl() {
  pod_name=$(select_pod "$1" "true")
  if [ -n "$pod_name" ]; then
    echo "Getting logs for pod: $pod_name"
    kubectl logs "$pod_name"
  fi
}

# Describe pod with fzf selection
kpd() {
  pod_name=$(select_pod "$1" "true")
  if [ -n "$pod_name" ]; then
    echo "Describing pod: $pod_name"
    kubectl describe pod "$pod_name"
  fi
}

# Exec into pod with fzf selection
kpx() {
  pod_name=$(select_pod "$1" "true")
  if [ -n "$pod_name" ]; then
    echo "Exec into pod: $pod_name"
    kcommand="/bin/sh"
    if [ -n "$2" ]; then
      kcommand="$2"
    fi
    kubectl exec -it "$pod_name" -- "$kcommand"
  fi
}

# Get pod name with fzf selection
kpg() {
  pod_name=$(select_pod "$1" "true")
  if [ -n "$pod_name" ]; then
    echo "$pod_name"
  fi
}

# Delete pods with fzf multi-selection
kpdel() {
  command -v fzf >/dev/null || {
    echo "❌ fzf is not installed."
    return 1
  }

  search_term="$1"

  # Get all pods, prioritize active (non-completed) pods
  all_pods=$(kubectl get pods --no-headers | awk '{print $1, $3}' | sort -k2,2 -r)

  if [ -z "$all_pods" ]; then
    echo "No pods found in current namespace."
    return 1
  fi

  # Select pods with fzf (multi-select enabled)
  if [ -n "$search_term" ]; then
    selected_pods=$(echo "$all_pods" | fzf -m --height 40% --reverse --query="$search_term" | awk '{print $1}')
  else
    selected_pods=$(echo "$all_pods" | fzf -m --height 40% --reverse | awk '{print $1}')
  fi

  if [ -z "$selected_pods" ]; then
    echo "No pods selected."
    return 0
  fi

  # Count and display selected pods
  pod_count=$(echo "$selected_pods" | wc -l)
  echo "Selected $pod_count pod(s) for deletion:"
  echo "$selected_pods" | while read -r pod; do
    echo "  - $pod"
  done
  echo

  # Confirm deletion
  printf "Delete these pods? [y/N]: "
  read -r confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Deletion cancelled."
    return 0
  fi

  # Delete each pod
  echo "$selected_pods" | while read -r pod; do
    echo "Deleting pod: $pod"
    kubectl delete pod "$pod"
  done
}


complete -o nospace -F __kc_complete kc
complete -o nospace -F __kgnonly_complete k.node.debug k.node.exec
complete -o nospace -F __kgnsonly_complete kns
complete -W "master worker etcd control-plane" kgnonly kgnonly.allCluster
