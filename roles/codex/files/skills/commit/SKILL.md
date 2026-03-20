---
name: commit
description: Create a conventional commit from current workspace changes. Use when the user asks to run $commit, asks to commit changes, or asks for a commit message from the current diff.
metadata:
  short-description: Minimal commit workflow
---

# Commit

Use this skill for a small, safe commit workflow. If the user only wants a commit message from the
current diff, generate the message and stop before committing.

## Workflow

1. Inspect state:
   - `git status --short`
   - If there are no changes, stop and report.
2. Determine scope:
   - If the user included `--all`, stage all changes with `git add -A`.
   - Otherwise, treat the currently staged changes as the commit candidate.
   - If both staged and unstaged changes exist, call out that only staged changes will be
     committed unless `--all` was requested.
3. Validate staged content:
   - `git diff --cached --stat`
   - If nothing is staged, stop and report.
4. Generate message:
   - Prefer conventional format: `<type>(<scope>): <summary>`
   - `scope` is optional.
   - Keep the subject concise (target 72 chars or less).
   - Valid types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `build`.
   - Do not include AI attribution text.
   - Apply any user guidance (for example: "focus on API changes").
5. Determine outcome:
   - If the user asked only for a commit message, return the generated message and stop.
   - Otherwise continue with the commit workflow.
6. Commit:
   - `git commit -m "<message>"`
7. Report result:
   - Show commit hash and subject: `git log -1 --oneline`

## Failure Handling

- If nothing is staged: `Commit aborted: no staged changes. Stage files first or rerun with --all.`
- If the commit message is missing or invalid: generate a valid message and retry once.
- If `git commit` fails: show the git error and stop.

## Notes

- This skill does not push changes.
- `--all` is opt-in because staging unrelated work by default is unsafe in a dirty tree.
