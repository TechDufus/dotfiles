# Cursor role

`roles/cursor` installs the Cursor Agent CLI when it is missing and manages this machine's user-level Cursor Agent home at `~/.cursor`. Keep it Cursor-specific: do not import Claude slash-command packs, and do not relocate OMP's `omp-cursor` overlay here. That overlay is an OMP session mode owned by `roles/omp`.

## Managed files

- The Agent CLI installer is official and user-local: `curl https://cursor.com/install | bash` writes `~/.local/bin/agent`. If that binary already exists, the role leaves it alone. Cursor CLI auto-updates itself; this role does not force upgrades.
- `cli-config.json` stays a regular file, not a symlink. The role rejects symlinks and special files, merges repo-managed keys into the live file, then overlays `model` and replaces `selectedModel`, `modelParameters`, and `statusLine` so a stale CLI display cache cannot keep an old pin. Extra CLI-owned `model` keys such as `aliases` are preserved. Unowned entries such as auth and caches are preserved. The file is written with restrictive permissions because credentials may land there. Managed policy is unrestricted (Run Everything), unsandboxed, and pinned to Cursor Grok 4.6 Extra High. A later `/model` change is overwritten the next time this role runs.
- Custom subagents pin `composer-2.5`, matching the OMP Cursor overlay's task role. Built-in Explore stays on Cursor's default fast model. Specialist descriptions ask the parent to delegate proactively.
- `AGENTS.md` and `statusline.sh` are repo-managed symlinks. If a destination regular file differs, the role fails: copy intended live changes back into `roles/cursor/files/` or remove the unmanaged file before rerunning. The status line is a three-line dashboard (path/git, context window, model/run mode). It needs `jq`.
- `rules/*.mdc` is deployed as per-file symlinks into `~/.cursor/rules/`; never symlink the whole directory. Unrelated user rules are preserved. Cleanup removes only stale repo-owned rule symlinks whose managed source no longer exists.
- `agents/*.md` defines additional global Cursor subagents with Cursor frontmatter and focused prompts. Specialist routing belongs in those files rather than this overview.
- `skills/*` is deployed as per-skill directory symlinks into `~/.cursor/skills/`. Never manage `~/.cursor/skills-cursor/`; that tree is Cursor's built-in skill cache.

### Context ownership

Keep always-visible context small and assign each concern one owner:

- Cursor's bundled system prompt owns generic agent behavior.
- `AGENTS.md` contains only true user interaction, review, and workstyle preferences, including always-on delegation-first. It does not name slash skills.
- `rules/user.mdc` contains only hard user invariants such as repository-memory verification, secret handling, autonomous local checkpoints, and approval before remote or shared-state mutations.
- Skill bodies stay out of always-on context until Cursor selects them.

## Agents

Global custom subagents must extend Cursor's built-ins, not replace them. Do not create global agents named `explore`, `bash`, or `browser`; those names belong to Cursor.

Preferred repo-managed additions are the same specialists as OMP: `gap-advisor`, `plan-critic`, `risk-assessor`, `validator`, and `security-auditor`. Their prompts add focused review, risk, and validation behavior while leaving ordinary exploration, planning, implementation, and review to Cursor itself. Descriptions include "use proactively" so the parent actually delegates instead of doing that work in the main window.

## Model and run-mode policy

Auto is Cursor Router, not a model: each turn is classified and sent to whatever pool member Cursor currently thinks is cheapest for that request. Pin a specific model when you want a stable daily driver.

This role pins:

| Surface | Choice | Why |
|---------|--------|-----|
| Main agent | `grok-4.6` at `effort=xhigh`, `fast=false` | Same default as `omp-cursor`; current Cursor-native frontier for long agentic coding |
| Custom specialists | `composer-2.5` | Cheaper isolated review/validation, matching OMP's Cursor task role |
| Built-in Explore | Cursor default | Fast search should not inherit Extra High |
| Approval | `unrestricted` | Same YOLO posture as Codex `danger-full-access` / OMP full tool access |
| Sandbox | disabled | Matches that autonomy; deny lists stay empty on purpose |
| Status line | `~/.cursor/statusline.sh` | Path, git, context window, model/params, YOLO vs ASK, worktree |

Switch with `/model grok-4.6` or `--model 'grok-4.6[effort=xhigh,fast=false]'` only as a session escape hatch. Edit `files/cli-config.json` when the pin itself should change.

## Skills

Current repo-managed skills:

| Skill | Purpose |
|------|---------|
| `commit` | Local conventional commits at verified checkpoints |
| `verification` | Effective-state checks for Ansible and repo-managed config |
| `orchestrate` | Slash-only maximum-effort fan-out: full surface, no early yield |
| `ultrathink` | Slash-only first-principles reasoning lens for this turn |
| `ultraresearch` | Slash-only parallel web plus `explore` research |

## Usage

```bash
dotfiles -t cursor
agent --version
```

Edit tracked sources under `roles/cursor/files/`, then rerun the role. Do not copy generated `~/.cursor/cli-config.json` auth or cache fields back into the repo.

## Out of scope

This role does not manage the Cursor desktop app, `~/.cursor/projects`, chat history, or OMP's `omp-cursor` launcher.
