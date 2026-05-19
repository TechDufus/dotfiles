---
name: verification
description: Verifying implementation work before claiming completion; covers tests, affected artifacts, evidence, and unresolved risks.
condition: Use before saying work is done, complete, fixed, ready, verified, or when the user asks if something is done.
---

# Verification playbook

Use this skill before claiming non-trivial work is complete.

## Procedure
1. Identify the exact behavior or artifact changed.
2. Identify the narrowest meaningful verification command or scenario for that change.
3. Run it unless the needed dependency is genuinely unavailable.
4. Inspect the result; do not infer success from an unrelated build or lint.
5. Check directly affected artifacts: callsites, config, tests, docs, generated files, and cleanup of obsolete paths.
6. Report only observed evidence. Mark unverified claims explicitly.

## Good evidence
- A targeted unit or integration test covering changed behavior.
- A role/playbook check that applies the changed role and confirms idempotence.
- A CLI command that reads the exact managed config value or runtime behavior.
- A reproduction command showing the original failure is gone.

## Not enough by itself
- Syntax check only.
- A broad unrelated test suite that does not cover the change.
- A successful file write or formatter run.
- An assumption that config loaded because YAML looked valid.
