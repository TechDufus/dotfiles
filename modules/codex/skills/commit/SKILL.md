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
   - Follow the 50/72 rule: subject line is a hard 50-character maximum.
   - Body lines are a hard 72-character maximum.
   - Include a blank line between the subject and body.
   - Include a body whenever useful context is available; omit it only for
     trivial or purely mechanical commits.
   - Body should explain why the change was made, what changed, and relevant
     validation, risk, or scope notes.
   - Valid types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `build`.
   - Do not include AI attribution text.
   - Apply any user guidance (for example: "focus on API changes").
   - Before committing, check that every generated message line satisfies the
     subject/body length limits.
5. Determine outcome:
   - If the user asked only for a commit message, return the generated message and stop.
   - Otherwise continue with the commit workflow.
6. Commit:
   - Use a quoted heredoc to pass the full message on stdin; do not create a
     temporary commit-message file and do not use one-line `-m` strings.
   - Pattern:
     ```bash
     git commit -F - <<'EOF'
     <type>(<scope>): <summary>

     <wrapped body>
     EOF
     ```
7. Report result:
   - Show commit hash and subject: `git log -1 --oneline`

## Failure Handling

- If nothing is staged: `Commit aborted: no staged changes. Stage files first or rerun with --all.`
- If the commit message is missing or invalid: generate a valid message and retry once.
- If `git commit` fails: show the git error and stop.

## Notes

- This skill does not push changes.
- `--all` is opt-in because staging unrelated work by default is unsafe in a dirty tree.
