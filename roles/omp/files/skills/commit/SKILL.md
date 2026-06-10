---
name: commit
description: Preparing and creating git commits when explicitly requested; covers staged diff review, secrets checks, and conventional commit messages.
condition: User explicitly asks to commit, ship, wrap up with a commit, or create a commit message.
---

# Commit playbook

Only use this skill when the user explicitly requests a commit or commit message.

## Procedure
1. Inspect current git status and diff before staging or committing.
2. Do not revert, stash, or overwrite unexpected user changes.
3. Check staged and unstaged diffs for secrets, credentials, tokens, private keys, and plaintext secret material.
4. Stage only files relevant to the requested change.
5. Generate a concise conventional commit message from the staged diff.
6. Commit only after verification has run, concrete prior verification evidence is recorded honestly, or the user explicitly accepts the remaining risk.

## Message shape
- Use conventional commit format: `type(scope): summary`.
- Prefer `fix`, `feat`, `refactor`, `docs`, `test`, `chore`, or `ci`.
- Summary should describe user-visible or maintainer-visible effect, not implementation trivia.

## PR follow-ups

- For follow-up work on an open PR, prefer creating a new commit and pushing normally so review history remains chronological.
- Do not amend, rebase, squash, or force-push an existing PR branch unless the user explicitly asks to rewrite history.
- If history rewriting is explicitly requested, use `--force-with-lease`, explain why it is needed, and never use plain `--force`.

## Hard stops
- Do not commit secrets.
- Do not commit unrelated changes without explicit user approval.
- Do not claim verification that was not run.
