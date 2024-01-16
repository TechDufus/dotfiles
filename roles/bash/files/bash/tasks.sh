#!/usr/bin/env bash

# generate a timestamped log file name
generate_log() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    RANDOM_STRING=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
    echo "$TMP/bash._task.$TIMESTAMP-$RANDOM_STRING.log"
}


# _header colorize the given argument with spacing
function _task {
    # if _task is called while a task was set, complete the previous
    if [[ $TASK != "" ]]; then
        printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"
    fi
    # set new task title and print
    TASK="$*"
    printf "${LBLACK} [ ]  ${TASK} \n${LRED}"
}

function _clear_task {
    TASK=""
}

function _task_done {
    printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"
    _clear_task
}

# _cmd performs commands with error checking
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
    rm $LOG
    return 1
}


