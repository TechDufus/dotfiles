#!/usr/bin/env zsh

# Disable job control messages for this file
setopt NO_MONITOR

# Generate a timestamped log file name
#   Usage: LOG=$(generate_log)
#   Returns: the log file name as a string
generate_log() {
  mktemp -t "shell._task_XXXXXXXX"
}

# Task and spinner tracking
TASK=""
SPINNER_PID=""

# Spinner function that runs in background
function _spinner() {
  local task_text="$1"
  local chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local delay=0.08
  
  # Hide cursor
  tput civis
  
  # Save cursor position
  tput sc
  
  while true; do
    for char in "${chars[@]}"; do
      # Restore cursor position and clear line
      tput rc
      tput el
      printf "${CAT_OVERLAY1} [${CAT_SAPPHIRE}${char}${CAT_OVERLAY1}]  ${CAT_TEXT}${task_text}" >&2
      sleep $delay
    done
  done
}

# Stop spinner and clean up
function _stop_spinner() {
  if [[ $SPINNER_PID != "" ]]; then
    kill $SPINNER_PID 2>/dev/null
    wait $SPINNER_PID 2>/dev/null
    SPINNER_PID=""
  fi
  # Show cursor again
  tput cnorm
}

# _task colorize the given argument with spacing
#   This function will print the given argument with a color and spacing
#   It will also clear the previous task if one was set
#
# Usage: _task "installing kubectl"
# Returns: nothing
function __task {
  # if _task is called while a task was set, complete the previous
  if [[ $TASK != "" ]] && [[ $SPINNER_PID != "" ]]; then
    _task_done
  fi
  
  # set new task
  TASK="$*"
  
  # Start spinner in background
  _spinner "$TASK" &
  SPINNER_PID=$!
  
  # Disable job control messages
  disown $SPINNER_PID 2>/dev/null
}

# _clear_task clears the current task
# this is used to clear the TASK in the session when it is completed
function _clear_task {
  TASK=""
}

# _task_done completes the current task and clears the task
# this is used to mark previous TASK as complete for this session.
function _task_done {
  _stop_spinner
  
  # Clear line and show success
  printf "\r\033[K${CAT_GREEN} [✓]  ${CAT_TEXT}${TASK}\n"
  _clear_task
}

# _cmd performs commands with error checking
# This function will run the given command
# If the command fails, it will print the error and return 1
# Usage: _cmd "kubectl get pods"
# Returns: 0 on success, 1 on failure
# Note: This function will hide stdout and print stderr on failure
function _cmd {
  LOG=$(generate_log)
  # hide stdout, on error we print and exit
  if eval "$1" 1>/dev/null 2>$LOG; then
    rm $LOG
    return 0 # success
  else
    # Stop spinner on error
    _stop_spinner
    
    # Clear the line and show error
    printf "\r\033[K${CAT_RED} [✗]  ${CAT_TEXT}${TASK}${NC}\n" >&2
    
    # Show error details
    while read line; do
      printf "      ${CAT_MAROON}${line}${NC}\n" >&2
    done <$LOG
    printf "\n" >&2
    rm $LOG
    return 1
  fi
}

# Cleanup function for exit
function _task_cleanup() {
  _stop_spinner
}

# Set trap to cleanup on exit (only if we're interactive)
if [[ -o interactive ]]; then
  trap _task_cleanup EXIT INT TERM
fi