---
name: commit
description: Create a conventional commit from current workspace changes. Use when the user asks to run $commit, asks to commit changes, or asks for a commit message from the current diff.
metadata:
  short-description: Minimal commit workflow
---

# Commit

Use this skill for a small, safe commit workflow.

## Triggering

Primary explicit invocation is `$commit`.
If the user types `/commit`, treat it as the same intent.
Also use this skill when the user explicitly asks to commit changes.

## Workflow

1. Inspect state:
   - `git status --short`
   - If there are no changes, stop and report.
2. Determine mode:
   - If the user included `--staged`, do not stage files.
   - Otherwise, stage all changes with `git add -A`.
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
5. Commit:
   - `git commit -m "<message>"`
6. Report result:
   - Show commit hash and subject: `git log -1 --oneline`

## Failure Handling

- If nothing is staged: `Commit aborted: no staged changes.`
- If the commit message is missing or invalid: generate a valid message and retry once.
- If `git commit` fails: show the git error and stop.

## Notes

- This skill does not push changes.
- Do not use this skill unless the user explicitly requested a commit.
