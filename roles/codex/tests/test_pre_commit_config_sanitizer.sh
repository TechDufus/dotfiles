#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tmp_repo="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_repo"
}

trap cleanup EXIT HUP INT TERM

cd "$tmp_repo"
git init --quiet
git config user.email "test@example.com"
git config user.name "Test User"
git config core.hooksPath .githooks

mkdir -p .githooks roles/codex/files
cp "$repo_root/.githooks/pre-commit" .githooks/pre-commit

cat >roles/codex/files/config.toml <<'TOML'
model = "gpt-5.5"
service_tier = "default"

[plugins."documents@openai-primary-runtime"]
enabled = true

[projects."/Users/alex/work/example"]
trust_level = "trusted"

[marketplaces.openai-primary-runtime]
last_updated = "2026-07-01T06:26:14Z"
source_type = "local"
source = "/Users/alex/.cache/codex-runtimes/codex-primary-runtime/plugins/openai-primary-runtime"

[marketplaces.team]
source_type = "git"
source = "https://github.com/example/codex-plugins.git"
ref = "main"
TOML

git add roles/codex/files/config.toml
.githooks/pre-commit

staged_config="$(git show :roles/codex/files/config.toml)"
working_config="$(cat roles/codex/files/config.toml)"

if grep -q '^\[projects\.' <<<"$staged_config"; then
  echo "staged config still contains project trust metadata" >&2
  exit 1
fi

if grep -q '^\[marketplaces.openai-primary-runtime\]' <<<"$staged_config"; then
  echo "staged config still contains local runtime marketplace metadata" >&2
  exit 1
fi

if ! grep -q '^\[marketplaces.team\]' <<<"$staged_config"; then
  echo "staged config did not preserve git-backed marketplace metadata" >&2
  exit 1
fi

if ! grep -q '^service_tier = "default"$' <<<"$staged_config"; then
  echo "staged config did not preserve default service tier" >&2
  exit 1
fi

if ! grep -q '^\[marketplaces.openai-primary-runtime\]' <<<"$working_config"; then
  echo "working config should remain untouched by the pre-commit sanitizer" >&2
  exit 1
fi
