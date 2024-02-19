#! bash oh-my-bash.module

# Axin Bash Prompt, inspired by theme "Sexy" and "Bobby"
# thanks to them

if [[ $COLORTERM = gnome-* && $TERM = xterm ]]  && infocmp gnome-256color >/dev/null 2>&1; then export TERM=gnome-256color
elif [[ $TERM != dumb ]] && infocmp xterm-256color >/dev/null 2>&1; then export TERM=xterm-256color
fi

if tput setaf 1 &> /dev/null; then
  if [[ $(tput colors) -ge 256 ]] 2>/dev/null; then
    MAGENTA=$(tput setaf 9)
    ORANGE=$(tput setaf 172)
    GREEN=$(tput setaf 190)
    PURPLE=$(tput setaf 141)
    WHITE=$(tput setaf 0)
  else
    MAGENTA=$(tput setaf 5)
    ORANGE=$(tput setaf 4)
    GREEN=$(tput setaf 2)
    PURPLE=$(tput setaf 1)
    WHITE=$(tput setaf 7)
  fi
  BOLD=$(tput bold)
  RESET=$(tput sgr0)
else
  MAGENTA="\033[1;31m"
  ORANGE="\033[1;33m"
  GREEN="\033[1;32m"
  PURPLE="\033[1;35m"
  WHITE="\033[1;37m"
  BOLD=""
  RESET="\033[m"
fi

function k.togglePromptInfo() {
if [ "$SHOW_K8S_PROMPT_INFO" == "true" ]; then
  echo -e "${ARROW} ${YELLOW}SHOW_K8S_PROMPT_INFO is set to true, setting to false${NC}"
  export SHOW_K8S_PROMPT_INFO="false"
  return
elif [ "$SHOW_K8S_PROMPT_INFO" == "false" ]; then
  echo -e "${ARROW} ${YELLOW}SHOW_K8S_PROMPT_INFO is set to false, setting to true${NC}"
  export SHOW_K8S_PROMPT_INFO="true"
  return
fi
}

function k8s_info() {
  # Only show k8s info in prompt if it is enabled
  if [[ "$SHOW_K8S_PROMPT_INFO" == "false" ]]; then
    return
  fi
  local k8s_data="$(kubectl config view --minify --output 'jsonpath={..namespace}@{.current-context}' 2> /dev/null)"
  if [[ "$k8s_data" != "" ]]; then
    echo "[$k8s_data]"
  fi
}

# function rancher_info() {
#     # if the rancher command exists, use it to get the current context
#     # which will run 'rancher context current' and parse the data from this example output:
#     # Cluster:sandbox Project:dufus-test to look like [sandbox@dufus-test]
#     if [[ -x "$(command -v rancher)" ]]; then
#         local rancher_data="$(rancher context current 2> /dev/null | sed -E 's/Cluster:(\w+) Project:(\w+)/\1@\2/')"
#         if [[ "$rancher_data" != "" ]]; then
#             echo "[$rancher_data]"
#         fi
#         return
#     fi
# }

function _omb_theme_PROMPT_COMMAND() {
  PS1="$(_clear_task)\[${BOLD}${MAGENTA}\]\u \[$WHITE\]@ \[$ORANGE\]\h \[$WHITE\]in \[$GREEN\]\w\[$WHITE\]\[$SCM_THEME_PROMPT_PREFIX\]$(clock_prompt)\[$PURPLE\]\$(scm_prompt_info)$YELLOW\$(k8s_info)$PURPLE\n\$ \[$RESET\]"
}
THEME_CLOCK_COLOR=${THEME_CLOCK_COLOR:-"${_omb_prompt_white}"}

_omb_util_add_prompt_command _omb_theme_PROMPT_COMMAND
