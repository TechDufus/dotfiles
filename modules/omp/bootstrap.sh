#!/usr/bin/env bash
# Upstream herdr/worktrunk skills, marketplace plugins and herdr's omp lifecycle integration. Fail-soft.
set -uo pipefail

export GIT_TERMINAL_PROMPT=0
share_dir="$HOME/.local/share/dotfiles"
skills_dir="$HOME/.omp/agent/skills"

warn() { echo "omp: $*, skipped"; }

# link_skill <name> <repo-url> <branch>
link_skill() {
  local name=$1 url=$2 branch=$3
  local dir="$share_dir/$name" dest="$skills_dir/$name"

  mkdir -p "$share_dir" || { warn "cannot create $share_dir"; return 0; }
  if [ -d "$dir/.git" ]; then
    git -C "$dir" pull --ff-only --quiet || echo "omp: $name skill update failed, keeping existing checkout"
  else
    git clone --quiet --depth 1 --single-branch --branch "$branch" "$url" "$dir" || warn "$name skill clone failed"
  fi

  [ -f "$dir/skills/$name/SKILL.md" ] || return 0
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    warn "$dest exists and is not a symlink"
    return 0
  fi
  mkdir -p "$skills_dir" || { warn "cannot create $skills_dir"; return 0; }
  ln -sfn "$dir/skills/$name" "$dest" || warn "cannot link $dest"
}

link_skill herdr https://github.com/herdrdev/herdr.git master
link_skill worktrunk https://github.com/max-sixty/worktrunk.git main

# install_plugin <name@marketplace> <marketplace-source>
# Installs once; upgrades stay manual (`omp plugin upgrade`). A linked checkout of the same
# package (`omp plugin link`) shares its node_modules entry, so it counts as installed.
install_plugin() {
  local id=$1 source=$2 name=${1%@*} market=${1#*@} plugins
  command -v omp >/dev/null 2>&1 || { warn "$id: omp not found"; return 0; }
  command -v jq >/dev/null 2>&1 || { warn "$id: jq not found"; return 0; }
  plugins=$(omp plugin list --json 2>/dev/null) || { warn "$id: omp plugin list failed"; return 0; }
  jq -e --arg id "$id" --arg name "$name" \
    'any(.marketplace[]; .id == $id) or any(.npm[]; .name == $name)' <<<"$plugins" >/dev/null && return 0
  # With its marketplace unconfigured, `omp plugin install name@marketplace` is an npm spec.
  if ! omp plugin marketplace list 2>/dev/null | awk -v m="$market" '$1 == m { found = 1 } END { exit !found }'; then
    omp plugin marketplace add "$source" || { warn "$market marketplace add failed"; return 0; }
  fi
  omp plugin install "$id" || warn "$id install failed"
}

install_plugin omp-cloud@omp-cloud TechDufus/omp-cloud

# Herdr resolves Pi and OMP from PI_CODING_AGENT_DIR alike and refuses to install
# OMP when they collide; select OMP via PI_CONFIG_DIR instead.
if command -v herdr >/dev/null 2>&1; then
  if status=$(PI_CODING_AGENT_DIR="" PI_CONFIG_DIR="$HOME/.omp" herdr integration status 2>&1); then
    if [[ $status != *"omp: current ("* ]]; then
      PI_CODING_AGENT_DIR="" PI_CONFIG_DIR="$HOME/.omp" herdr integration install omp || warn "herdr omp integration install failed"
    fi
  fi
else
  echo "omp: herdr not found, skipping integration"
fi

exit 0
