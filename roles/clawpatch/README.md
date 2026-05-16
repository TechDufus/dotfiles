# Clawpatch Role

Install [Clawpatch](https://clawpatch.ai/), the OpenClaw automated code review CLI.

## What This Role Does

- Installs `clawpatch` globally from npm.
- Requires Node.js `>=22`.
- Supports nvm, user-local npm prefixes, and normal npm installs by loading the same PATH locations used by this dotfiles repo.
- Keeps the install idempotent by comparing the installed CLI version to the desired npm version.

## Usage

```bash
dotfiles -t clawpatch
```

## Configuration

```yaml
clawpatch_npm_package: clawpatch
clawpatch_version: latest
clawpatch_min_node_major: 22
```

Pin a specific version when you want repeatable installs:

```yaml
clawpatch_version: "0.1.0"
```

## Notes

- The `npm` role should run before this role so Node.js, npm, and user-local npm prefix handling are already configured.
- The `codex` role is optional but recommended because Clawpatch currently uses local Codex CLI as its default AI provider.
- This role only installs the CLI. Project-specific `.clawpatch/` state should live inside each reviewed project or a separate audit artifact directory.

## Uninstall

```bash
~/.dotfiles/roles/clawpatch/uninstall.sh
```
