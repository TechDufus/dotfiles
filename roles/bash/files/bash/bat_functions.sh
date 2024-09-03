#!/usr/bin/env bash

# btail - Tail a file and pipe it to bat
# This function will tail a file and pipe it to bat for syntax highlighting.
# This function can also be used to pipe the output of a command to bat.
# Example: btail /var/log/syslog
# Example: kubectl logs some-pod | btail
# Usage: btail [OPTION]... [FILE]...
# Usage: echo "Hello" | btail
function btail() {
  if [ ! -t 0 ]; then
    cat /dev/stdin | bat --paging=never --language=log
    return
  fi
  if [ -z "$1" ]; then
    echo -e "${ARROW} ${YELLOW}Usage: btail [OPTION]... [FILE]...${NC}"
    return 1
  fi
  # tail -f $@ | bat -P -l log # This is the short version
  tail -f $@ | bat --paging=never --language=log
}
