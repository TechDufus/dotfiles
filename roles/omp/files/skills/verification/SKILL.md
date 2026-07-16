---
name: verification
description: Verifying effective state and idempotence for Ansible role, playbook, and repository-managed configuration changes.
condition: Use for Ansible role/playbook or repository-managed configuration changes that need applied-state or idempotence verification.
---

# Ansible and managed-configuration verification

Demonstrate effective state with the evidence that is safe and applicable:

- Apply the changed role or playbook when applicable, then confirm a subsequent run is idempotent.
- Inspect the exact managed configuration value or the resulting runtime behavior.
- For a bug fix, a reproduction showing that the original failure is gone may provide the needed proof.

If a dependency needed for this scoped verification is unavailable, report that limitation honestly.

## Not enough by itself

- A syntax check.
- An unrelated broad test suite.
- A successful file write or formatter run.
- YAML that merely looks valid.
