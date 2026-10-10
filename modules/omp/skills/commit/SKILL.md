---
name: commit
description: Preparing and creating local commits at meaningful verified checkpoints or on explicit request; covers staged diff review, secrets checks, and conventional commit messages.
condition: User requests a commit or commit message, or larger work reaches a coherent verified atomic checkpoint.
---

# Commit playbook

When a coherent verified unit is complete, use this skill before moving into distinct work; also use it when the user requests a commit or commit message.

## Procedure
1. Inspect current git status and diff before staging or committing.
2. Do not revert, stash, or overwrite unexpected user changes.
3. Check staged and unstaged diffs for secrets, credentials, tokens, private keys, and plaintext secret material.
4. Stage only files relevant to the change.
5. Generate a concise conventional commit message from the staged diff.
6. Commit only after verification has run, concrete prior verification evidence is recorded honestly, or the user explicitly accepts the remaining risk.
7. Make each checkpoint a coherent atomic unit useful for rollback or review; avoid arbitrary or frequent commit noise.

## Message shape
- Use conventional commit format on the first line: `type(scope): summary`.
- Prefer `fix`, `feat`, `refactor`, `docs`, `test`, `chore`, or `ci`.
- Keep the subject line 50 characters or fewer.
- Summary should describe user-visible or maintainer-visible effect, not implementation trivia.
- A commit body is allowed when it improves future archaeology.
- Separate subject and body with one blank line.
- Wrap non-blank body lines at 72 characters or fewer.
- Use body paragraphs for why, risk, migration notes, or verification context that belongs in git history.
- When useful, reference issue or commit identifiers only when established by context; use a closing keyword only when the checkpoint truly completes that issue.

## PR follow-ups

- For follow-up work on an open PR, prefer a new local commit so review history remains chronological.
- Push only when explicitly requested.
- Do not amend, rebase, squash, or force-push an existing PR branch unless the user explicitly asks to rewrite history.
- If history rewriting is explicitly requested, use `--force-with-lease`, explain why it is needed, and never use plain `--force`.

## Hard stops
- Do not commit secrets.
- Do not commit unrelated changes without explicit user approval.
- Do not claim verification that was not run.
