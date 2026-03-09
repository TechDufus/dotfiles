# AGENTS.md

This file is intentionally minimal. Add lines only for repo-specific landmines that are not obvious from the codebase.

- Secrets are referenced via 1Password `op://...`; never add plaintext secrets to the repo.
- Optional host/integration work should fail soft instead of breaking the whole play, especially around sudo and 1Password.
- Secret-bearing tasks should use `no_log: true`.
- Uninstall flows must not remove critical system dependencies such as `git` or system `python`.
- Prefer fixing confusing structure, docs, or automation over growing this file. If guidance is still needed, keep it short and scoped to the affected directory.
