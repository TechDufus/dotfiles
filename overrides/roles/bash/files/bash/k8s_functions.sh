#!/usr/bin/env bash

function kgp() {
    if [ -z "$1" ]; then
        kubectl get po
    else
        kubectl get po | fzf --filter="$1"
    fi
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


complete -o nospace -F __kc_complete kc
complete -o nospace -F __kgnonly_complete k.node.debug k.node.exec
complete -o nospace -F __kgnsonly_complete kns
complete -W "master worker etcd control-plane" kgnonly kgnonly.allCluster

# ============================================================================
# Pod selection with fzf
# ============================================================================

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

# Delete pods with fzf multi-selection and confirmation
kpdel() {
  command -v fzf >/dev/null || {
    echo "❌ fzf is not installed."
    return 1
  }

  local search_term="$1"
  local all_pods
  local selected_pods

  # Get all pods (prioritize active/non-completed)
  all_pods=$(kubectl get pods --no-headers | awk '{print $1, $3}' | sort -k2,2 -r)

  if [ -z "$all_pods" ]; then
    echo "❌ No pods found in current namespace."
    return 1
  fi

  if [ -z "$search_term" ]; then
    # No search term - interactive multi-select
    selected_pods=$(echo "$all_pods" | fzf --multi --height 40% --reverse \
      --header="Select pods to delete (Tab to select, Enter to confirm)" | awk '{print $1}')
  else
    # Filter by search term first
    local matching_pods
    matching_pods=$(echo "$all_pods" | grep -i "$search_term")

    if [ -z "$matching_pods" ]; then
      # No matches - try fuzzy filter
      matching_pods=$(echo "$all_pods" | fzf --filter="$search_term")
    fi

    if [ -z "$matching_pods" ]; then
      echo "❌ No pods matching '$search_term' found."
      return 1
    fi

    local match_count
    match_count=$(echo "$matching_pods" | grep -v "^$" | wc -l)

    if [ "$match_count" -eq 1 ]; then
      # Single match - still confirm
      selected_pods=$(echo "$matching_pods" | awk '{print $1}')
    else
      # Multiple matches - let user select
      selected_pods=$(echo "$matching_pods" | fzf --multi --height 40% --reverse \
        --query="$search_term" \
        --header="Select pods to delete (Tab to select, Enter to confirm)" | awk '{print $1}')
    fi
  fi

  if [ -z "$selected_pods" ]; then
    echo "No pods selected. Aborting."
    return 0
  fi

  # Count selected pods
  local pod_count
  pod_count=$(echo "$selected_pods" | grep -v "^$" | wc -l)

  # Show pods to be deleted
  echo ""
  echo -e "\033[1;33m⚠️  The following $pod_count pod(s) will be deleted:\033[0m"
  echo ""
  echo "$selected_pods" | while read -r pod; do
    echo -e "  \033[0;31m•\033[0m $pod"
  done
  echo ""

  # Confirmation prompt
  echo -n -e "\033[1;33mAre you sure you want to delete these pods? [y/N]: \033[0m"
  read -r confirm

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    echo "$selected_pods" | while read -r pod; do
      if [ -n "$pod" ]; then
        echo -e "\033[0;36mDeleting pod:\033[0m $pod"
        kubectl delete pod "$pod"
      fi
    done
    echo ""
    echo -e "\033[0;32m✓ Done.\033[0m"
  else
    echo "Aborted."
    return 0
  fi
}

# ============================================================================
# Get all resources in namespace
# ============================================================================

function kgetall {
    # Color definitions
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local BLUE='\033[0;34m'
    local MAGENTA='\033[0;35m'
    local CYAN='\033[0;36m'
    local WHITE='\033[1;37m'
    local NC='\033[0m' # No Color
    local BOLD='\033[1m'
    local DIM='\033[2m'

    # Default values
    local namespace=""
    local grep_pattern=""
    local use_fuzzy=false
    local fuzzy_pattern=""

    # Function to show usage
    show_usage() {
        echo -e "${BOLD}${WHITE}Usage: kgetall [OPTIONS]${NC}"
        echo -e "${WHITE}  -n, --namespace <namespace>    Specify namespace${NC}"
        echo -e "${WHITE}  -g, --grep <pattern>           Grep filter on resource items${NC}"
        echo -e "${WHITE}  -f, --fuzzy [pattern]          Use fzf for fuzzy search (interactive if no pattern)${NC}"
        echo -e "${WHITE}  -h, --help                     Show this help${NC}"
        echo
        echo -e "${WHITE}Examples:${NC}"
        echo -e "${DIM}  kgetall -n kube-system${NC}"
        echo -e "${DIM}  kgetall -g \"nginx\"${NC}"
        echo -e "${DIM}  kgetall -f \"pod\"${NC}"
        echo -e "${DIM}  kgetall -n default -g \"app=web\"${NC}"
        echo -e "${DIM}  kgetall --fuzzy          # Interactive fuzzy search${NC}"
    }

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        -n | --namespace)
            namespace="$2"
            shift 2
            ;;
        -g | --grep)
            grep_pattern="$2"
            shift 2
            ;;
        -f | --fuzzy)
            use_fuzzy=true
            if [[ $# -gt 1 ]] && [[ ! "$2" =~ ^- ]]; then
                fuzzy_pattern="$2"
                shift 2
            else
                shift
            fi
            ;;
        -h | --help)
            show_usage
            return 0
            ;;
        *)
            # Handle legacy positional namespace argument
            if [[ -z "$namespace" ]] && [[ ! "$1" =~ ^- ]]; then
                namespace="$1"
                shift
            else
                echo -e "${RED}Unknown option: $1${NC}" >&2
                show_usage
                return 1
            fi
            ;;
        esac
    done

    # Check for fzf if fuzzy search is requested
    if $use_fuzzy && ! command -v fzf &>/dev/null; then
        echo -e "${RED}Error: fzf is not installed. Please install fzf for fuzzy search functionality.${NC}" >&2
        return 1
    fi

    # Function to filter output
    filter_output() {
        local output="$1"
        local resource_name="$2"

        if [[ -z "$output" ]] || [[ "$(echo "$output" | wc -l)" -le 1 ]]; then
            return 1 # No data to filter
        fi

        local filtered_output=""
        local header_line=""
        local has_matches=false

        # Extract header line
        header_line=$(echo "$output" | head -n1)

        # Apply filtering
        if [[ -n "$grep_pattern" ]]; then
            local data_lines=$(echo "$output" | tail -n +2 | grep -i "$grep_pattern")
            if [[ -n "$data_lines" ]]; then
                filtered_output=$(echo -e "$header_line\n$data_lines")
                has_matches=true
            fi
        elif $use_fuzzy; then
            if [[ -n "$fuzzy_pattern" ]]; then
                # Non-interactive fuzzy search with pattern
                local data_lines=$(echo "$output" | tail -n +2 | fzf -f "$fuzzy_pattern")
                if [[ -n "$data_lines" ]]; then
                    filtered_output=$(echo -e "$header_line\n$data_lines")
                    has_matches=true
                fi
            else
                # Interactive fuzzy search - collect all data first
                local temp_file=$(mktemp)
                echo "$output" | tail -n +2 >"$temp_file"
                if [[ -s "$temp_file" ]]; then
                    echo -e "${DIM}${YELLOW}→ Press Enter to fuzzy search ${resource_name} (Ctrl+C to skip)${NC}" >&2
                    local selected_lines=$(cat "$temp_file" | fzf --multi --header="Select ${resource_name} items (Tab to select multiple, Enter to confirm)")
                    if [[ -n "$selected_lines" ]]; then
                        filtered_output=$(echo -e "$header_line\n$selected_lines")
                        has_matches=true
                    fi
                fi
                rm -f "$temp_file"
            fi
        else
            filtered_output="$output"
            has_matches=true
        fi

        if $has_matches; then
            echo "$filtered_output"
            return 0
        else
            return 1
        fi
    }

    # Print header
    echo -e "${BOLD}${CYAN}========================================${NC}"
    local header_text="Kubectl Get All Resources"
    if [[ -n "$namespace" ]]; then
        header_text+=" (Namespace: ${YELLOW}$namespace${WHITE})"
    else
        header_text+=" (All Namespaces)"
    fi

    if [[ -n "$grep_pattern" ]]; then
        header_text+=" [Grep: ${GREEN}$grep_pattern${WHITE}]"
    elif $use_fuzzy; then
        if [[ -n "$fuzzy_pattern" ]]; then
            header_text+=" [Fuzzy: ${GREEN}$fuzzy_pattern${WHITE}]"
        else
            header_text+=" [Interactive Fuzzy Search]"
        fi
    fi

    echo -e "${BOLD}${WHITE}$header_text${NC}"
    echo -e "${BOLD}${CYAN}========================================${NC}"
    echo

    local resource_count=0
    local resources_with_items=0
    local filtered_resources=0

    for i in $(kubectl api-resources --verbs=list --namespaced -o name | grep -v "events.events.k8s.io" | grep -v "events" | sort | uniq); do
        resource_count=$((resource_count + 1))

        # Get the kubectl output
        local output=""
        if [[ -n "$namespace" ]]; then
            output=$(kubectl -n "$namespace" get --ignore-not-found "$i" 2>/dev/null)
        else
            output=$(kubectl get --ignore-not-found "$i" 2>/dev/null)
        fi

        # Check if there's any output and apply filtering
        if [[ -n "$output" ]] && [[ "$(echo "$output" | wc -l)" -gt 1 ]]; then
            resources_with_items=$((resources_with_items + 1))

            # Apply filtering
            local filtered_output=""
            if filtered_output=$(filter_output "$output" "$i"); then
                filtered_resources=$((filtered_resources + 1))

                # Print resource header with color
                echo -e "${BOLD}${MAGENTA}┌─ Resource: ${GREEN}${i}${NC}"
                echo -e "${DIM}${CYAN}│${NC}"

                # Color the filtered output
                echo "$filtered_output" | while IFS= read -r line; do
                    if [[ "$line" =~ ^NAME[[:space:]] ]] || [[ "$line" =~ ^NAMESPACE[[:space:]] ]]; then
                        # Header line - make it bold and blue
                        echo -e "${DIM}${CYAN}│${NC} ${BOLD}${BLUE}${line}${NC}"
                    else
                        # Data lines
                        echo -e "${DIM}${CYAN}│${NC} ${line}"
                    fi
                done

                echo -e "${DIM}${CYAN}└─${NC}"
                echo
            fi
        fi
    done

    # Print summary
    echo -e "${BOLD}${CYAN}========================================${NC}"
    echo -e "${BOLD}${WHITE}Summary:${NC}"
    echo -e "${WHITE}  • Total resource types checked: ${GREEN}${resource_count}${NC}"
    echo -e "${WHITE}  • Resource types with items: ${GREEN}${resources_with_items}${NC}"

    if [[ -n "$grep_pattern" ]] || $use_fuzzy; then
        echo -e "${WHITE}  • Resource types after filtering: ${GREEN}${filtered_resources}${NC}"
    fi

    if [[ -n "$namespace" ]]; then
        echo -e "${WHITE}  • Scope: ${YELLOW}Namespace '$namespace'${NC}"
    else
        echo -e "${WHITE}  • Scope: ${YELLOW}All namespaces${NC}"
    fi

    if [[ -n "$grep_pattern" ]]; then
        echo -e "${WHITE}  • Filter: ${GREEN}grep '$grep_pattern'${NC}"
    elif $use_fuzzy; then
        if [[ -n "$fuzzy_pattern" ]]; then
            echo -e "${WHITE}  • Filter: ${GREEN}fuzzy '$fuzzy_pattern'${NC}"
        else
            echo -e "${WHITE}  • Filter: ${GREEN}interactive fuzzy search${NC}"
        fi
    fi

    echo -e "${BOLD}${CYAN}========================================${NC}"
}

# ============================================================================
# Patch pending pods with tolerations
# ============================================================================

function kpatchall {
    local pods=$(kubectl get pods -o json | jq -r '.items[] | select(.status.phase == "Pending" and ((.spec.tolerations == null) or (.spec.tolerations | length == 0) or (.spec.tolerations | map(select(.key == "raft")) | length == 0))) | .metadata.name')

    for pod in $pods; do
        kubectl patch pod $pod --patch '{"spec": {"tolerations": [{"key": "core", "operator": "Exists", "effect": "NoSchedule"}]}}'
    done
}

# ============================================================================
# Loop command at interval
# ============================================================================

function loop {
    local interval=$1
    shift
    local cmd="$@"
    while true; do
        echo "[$(date)] Running: $cmd"
        eval "$cmd"
        sleep "$interval"
    done
}

function watchpo() {
    watch -n 2 "kubectl get po | fzf --filter='$1' | head -20"
}
