#!/usr/bin/env bash


# define the function
speedtest_loop() {
    local iterations=5
    if [ -z "$1" ]; then
        echo "Usage: speedtest_loop <number of iterations>"
        echo -e "${ARROW} ${YELLOW}Usage: ${CYAN}speedtest_loop <number of iterations>${NC}"
        echo -e "${ARROW} ${CYAN}Defaulting to '${iterations}' iterations${NC}"
    else
        local iterations=$1
    fi

    # print the header
    printf "%-10s %-10s %-10s %-10s\n" "Iteration" "Upload (Mbps)" "Download (Mbps)" "Ping (ms)"

    # loop over the iterations
    for ((i=1; i<=iterations; i++)); do
        # run the speedtest command and extract the relevant information
        local results=$(speedtest --bytes | grep -E "Upload|Download|Ping" | awk '{print $2, $3}')
        local upload=$(echo "$results" | head -n 1 | cut -d " " -f 1)
        local upload_unit=$(echo "$results" | head -n 1 | cut -d " " -f 2)
        local download=$(echo "$results" | head -n 2 | tail -n 1 | cut -d " " -f 1)
        local download_unit=$(echo "$results" | head -n 2 | tail -n 1 | cut -d " " -f 2)
        local ping=$(echo "$results" | tail -n 1 | cut -d " " -f 1)
        local ping_unit=$(echo "$results" | tail -n 1 | cut -d " " -f 2)

        # convert the values to megabits per second
        if [ "$upload_unit" == "Mbit/s" ]; then
            upload=$(awk "BEGIN {print $upload / 1}")
        elif [ "$upload_unit" == "Kbit/s" ]; then
            upload=$(awk "BEGIN {print $upload / 1000}")
        elif [ "$upload_unit" == "Gbit/s" ]; then
            upload=$(awk "BEGIN {print $upload * 1000}")
        fi
        if [ "$download_unit" == "Mbit/s" ]; then
            download=$(awk "BEGIN {print $download / 1}")
        elif [ "$download_unit" == "Kbit/s" ]; then
            download=$(awk "BEGIN {print $download / 1000}")
        elif [ "$download_unit" == "Gbit/s" ]; then
            download=$(awk "BEGIN {print $download * 1000}")
        fi
        if [ "$ping_unit" == "ms" ]; then
            ping=$(awk "BEGIN {print $ping / 1}")
        elif [ "$ping_unit" == "s" ]; then
            ping=$(awk "BEGIN {print $ping * 1000}")
        fi

        # print the results
        printf "%-10d    %-10.2f    %-10.2f    %-10.2f\n" "$i" "$upload" "$download" "$ping"
    done
}
