#!/usr/bin/env bash
# Start the ollama brew service and wait (up to 60 s) for the local API.
set -uo pipefail

if ! brew services list | grep -q '^ollama[[:space:]]*started'; then
  brew services start ollama || { echo "ollama: could not start service, skipped"; exit 0; }
fi

for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    exit 0
  fi
  sleep 2
done

echo "ollama: API not ready after 60s, skipped"
exit 0
