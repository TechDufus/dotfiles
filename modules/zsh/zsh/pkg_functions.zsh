#!/usr/bin/env zsh

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/'
}

_pkg_uname_os() {
  case "$(uname -s)" in
    Darwin) print -r -- Darwin ;;
    Linux) print -r -- Linux ;;
    *) print -r -- "$(uname -s)" ;;
  esac
}

_pkg_uname_arch() {
  case "$(uname -m)" in
    x86_64) print -r -- amd64 ;;
    arm64|aarch64) print -r -- arm64 ;;
    *) print -r -- "$(uname -m)" ;;
  esac
}

k9s-upgrade() {
    local os arch VERSION
    os="$(_pkg_uname_os)"
    arch="$(_pkg_uname_arch)"
    VERSION=$(get_latest_release derailed/k9s)
    pushd /tmp > /dev/null 2>&1
    echo -e "${ARROW} ${GREEN}Downloading k9s ${VERSION}${NC}"
    wget -q "https://github.com/derailed/k9s/releases/download/${VERSION}/k9s_${os}_${arch}.tar.gz"
    echo -e "${ARROW} ${GREEN}Extracting k9s ${VERSION}${NC}"
    tar -xzf "k9s_${os}_${arch}.tar.gz"
    sudo mv k9s /usr/local/bin
    rm -f "k9s_${os}_${arch}.tar.gz"
    echo -e "${ARROW} ${GREEN}k9s ${VERSION} installed${NC}"
    k9s version
    popd > /dev/null 2>&1
}

gone-upgrade() {
    if [[ "$(_pkg_uname_os)" != Linux ]]; then
      echo -e "${WARNING} ${YELLOW}gone-upgrade only publishes Linux binaries${NC}"
      return 1
    fi
    VERSION=$(get_latest_release guillaumebreton/gone)
    pushd /tmp > /dev/null 2>&1
    echo -e "${ARROW} ${GREEN}Downloading gone ${VERSION}${NC}"
    wget -q "https://github.com/guillaumebreton/gone/releases/download/${VERSION}/gone_Linux_x86_64.tar.gz"
    echo -e "${ARROW} ${GREEN}Extracting gone ${VERSION}${NC}"
    tar -xzf gone_Linux_x86_64.tar.gz
    sudo mv gone /usr/local/bin
    rm gone_Linux_x86_64.tar.gz
    echo -e "${ARROW} ${GREEN}gone ${VERSION} installed${NC}"
    popd > /dev/null 2>&1
}

pinger-upgrade() {
    if [[ "$(_pkg_uname_os)" != Linux ]]; then
      echo -e "${WARNING} ${YELLOW}pinger-upgrade only publishes Linux binaries${NC}"
      return 1
    fi
    VERSION=$(get_latest_release hirose31/pinger)
    pushd /tmp > /dev/null 2>&1
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
    local VERSION OS ARCH
    if [[ -z $1 ]]; then
        VERSION=$(curl -s https://go.dev/dl/?mode=json | jq -r '.[0].version')
      else
        VERSION="go$1"
    fi
    OS="$(_pkg_uname_os | tr '[:upper:]' '[:lower:]')"
    ARCH="$(_pkg_uname_arch)"
    pushd /tmp > /dev/null 2>&1
    echo -e "${ARROW} ${GREEN}Downloading upgrade $VERSION...${NC}"
    wget -q "https://storage.googleapis.com/golang/$VERSION.$OS-$ARCH.tar.gz"
    echo -e "${ARROW} ${GREEN}Extracting...${NC}"
    tar -xvf "$VERSION.$OS-$ARCH.tar.gz" > /dev/null 2>&1
    sudo rm -rf /usr/local/go
    echo -e "${ARROW} ${GREEN}Installing...${NC}"
    sudo mv go /usr/local
    popd > /dev/null 2>&1
    echo -e "${CHECK_MARK} ${GREEN}Successfully Installed GO Version: ${YELLOW}$(/usr/local/go/bin/go version)${NC}"
}
