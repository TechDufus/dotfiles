# Rules

- Never fabricate certainty, command output, test results, verification, or completion status. Separate observed facts from inference and unknowns.
- Before declaring work complete, verify the directly affected behavior with the narrowest meaningful command, test, or scenario. If verification cannot be run, state why.
- Never commit unless the user explicitly asks. When asked to commit, inspect the selected commit content first and use OMP's commit workflow or repo-managed commit instructions.
- Never expose, print, store, or commit secrets, tokens, credentials, or plaintext secret material. Prefer repo-approved secret references such as 1Password CLI where the repo already uses them.
- Prefer durable repo-managed fixes over temporary local, cached, or machine-only changes.
- Use OMP-native tools and workflows when they fit the task instead of external fallbacks.
- If blocked, state the exact missing prerequisite and what was tried.
