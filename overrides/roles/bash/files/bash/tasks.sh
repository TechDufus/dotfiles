#!/usr/bin/env bash

# Generate a timestamped log file name
#   Usage: LOG=$(generate_log)
#   Returns: the log file name as a string
generate_log() {
    mktemp -t "shell._task_"
}


# _task colorize the given argument with spacing
#   This function will print the given argument with a color and spacing
#   It will also clear the previous task if one was set
#
# Usage: _task "installing kubectl"
# Returns: nothing
function __task {
    # if _task is called while a task was set, complete the previous
    if [[ $TASK != "" ]]; then
        printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"
    fi
    # set new task title and print
    TASK="$*"
    printf "${LBLACK} [ ]  ${TASK} \n${LRED}"
}

# _clear_task clears the current task
# this is used to clear the TASK in the session when it is completed
function _clear_task {
    TASK=""
}

# _task_done completes the current task and clears the task
# this is used to mark previous TASK as complete for this session.
function _task_done {
    printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"
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
    if eval "$1" 1> /dev/null 2> $LOG; then
        rm $LOG
        return 0 # success
    fi
    # read error from log and add spacing
    printf "${OVERWRITE}${LRED} [X]  ${TASK}${LRED}\n"
    while read line; do
        printf "      ${line}\n"
    done < $LOG
    printf "\n"
    cat $LOG >> /tmp/halp.log
    rm $LOG
    return 1
}

