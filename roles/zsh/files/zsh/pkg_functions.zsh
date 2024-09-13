#!/usr/bin/env zsh

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

k9s-upgrade() {
    VERSION=$(get_latest_release derailed/k9s)
    pushd /tmp > /dev/null 2>&1
    # Download the binary
    echo -e "${ARROW} ${GREEN}Downloading k9s ${VERSION}${NC}"
    wget -q https://github.com/derailed/k9s/releases/download/$VERSION/k9s_Linux_x86_64.tar.gz
    # Extract the binary
    echo -e "${ARROW} ${GREEN}Extracting k9s ${VERSION}${NC}"
    tar -xzf k9s_Linux_x86_64.tar.gz
    # Move the binary to /usr/local/bin
    sudo mv k9s /usr/local/bin
    # Remove the tar file
    rm k9s_Linux_x86_64.tar.gz
    echo -e "${ARROW} ${GREEN}k9s ${VERSION} installed${NC}"
    k9s version
    popd > /dev/null 2>&1
}

gone-upgrade() {
    VERSION=$(get_latest_release guillaumebreton/gone)
    pushd /tmp > /dev/null 2>&1
    # Download the binary
    echo -e "${ARROW} ${GREEN}Downloading gone ${VERSION}${NC}"
    wget -q https://github.com/guillaumebreton/gone/releases/download/$VERSION/gone_Linux_x86_64.tar.gz
    echo -e "${ARROW} ${GREEN}Extracting gone ${VERSION}${NC}"
    tar -xzf gone_Linux_x86_64.tar.gz
    sudo mv gone /usr/local/bin
    rm gone_Linux_x86_64.tar.gz
    echo -e "${ARROW} ${GREEN}gone ${VERSION} installed${NC}"
    popd > /dev/null 2>&1
}

pinger-upgrade() {
    VERSION=$(get_latest_release hirose31/pinger)
    pushd /tmp > /dev/null 2>&1
    # Download the binary
    echo -e "${ARROW} ${GREEN}Downloading pinger ${VERSION}${NC}"
    wget -q https://github.com/hirose31/pinger/releases/download/${VERSION}/pinger_${VERSION}_linux_amd64.tar.gz
    echo -e "${ARROW} ${GREEN}Extracting pinger ${VERSION}${NC}"
    tar -xzf pinger_${VERSION}_linux_amd64.tar.gz
    cd pinger_${VERSION}_linux_amd64
    sudo mv pinger /usr/local/bin
    cd ..
    rm pinger_${VERSION}_linux_amd64.tar.gz -rf
    echo -e "${ARROW} ${GREEN}pinger ${VERSION} installed${NC}"
    popd > /dev/null 2>&1
}

go-upgrade() {
    # if no arg is passed, get latest version
    if [[ -z $1 ]]; then
        VERSION=$(curl -s https://go.dev/dl/?mode=json | jq -r '.[0].version')
      else
        VERSION="go$1"
    fi
    OS=linux
    ARCH=amd64
    pushd /tmp > /dev/null 2>&1
    echo -e "${ARROW} ${GREEN}Downloading upgrade $VERSION...${NC}"
    wget -q https://storage.googleapis.com/golang/$VERSION.$OS-$ARCH.tar.gz
    echo -e "${ARROW} ${GREEN}Extracting...${NC}"
    tar -xvf $VERSION.$OS-$ARCH.tar.gz > /dev/null 2>&1
    sudo rm -rf /usr/local/go
    echo -e "${ARROW} ${GREEN}Installing...${NC}"
    sudo mv go /usr/local
    popd > /dev/null 2>&1
    echo -e "${CHECK_MARK} ${GREEN}Successfully Installed GO Version: ${YELLOW}$(/usr/local/go/bin/go version)${NC}"
}
