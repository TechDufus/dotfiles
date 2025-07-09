#!/bin/bash
set -e

# The github_release role is a helper role that doesn't install anything itself
# It's used by other roles to download releases from GitHub

echo -e "${YELLOW} [!]  ${WHITE}The github_release role is a utility role${NC}"
echo -e "${YELLOW}      ${WHITE}It doesn't install anything that needs to be uninstalled${NC}"
echo -e "${YELLOW}      ${WHITE}This role helps other roles download GitHub releases${NC}"

echo -e "${GREEN} [✓]  ${WHITE}Nothing to uninstall for github_release${NC}"
