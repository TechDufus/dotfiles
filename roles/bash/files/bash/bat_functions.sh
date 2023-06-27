#!/usr/bin/env bash

 function btail() {
     if [ -z "$1" ]; then
         echo -e "${ARROW} ${YELLOW}Usage: btail [OPTION]... [FILE]...${NC}"
         return 1
     fi
     # tail -f $@ | bat -P -l log # This is the short version
     tail -f $@ | bat --paging=never --language=log
 }
