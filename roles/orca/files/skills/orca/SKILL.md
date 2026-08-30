---
name: orca
description: "Optional magic words to put in an Orca worker spec for Cursor or OMP. Use only when the user invokes /orca or /skill:orca, while following the orchestration skill. Not the Orca CLI and not how to structure the spec."
disable-model-invocation: true
---

# Orca magic words

Optional tokens to drop into the worker spec when useful. Orchestration owns how to build and inject the spec. Do not wrap tokens in backticks. Only add tokens the user has used; ask before adding a row.

## Cursor

Slash. Cursor will not self-select these.

| If you want | Add |
| --- | --- |
| Right-shape / first principles | `/ultrathink` |
| In-harness fan-out | `/orchestrate` |
| Research first | `/ultraresearch` |

## OMP

Standalone lowercase prose. A leading `/` does not fire.

| If you want | Add |
| --- | --- |
| Right-shape / first principles | `ultrathink` |
| In-harness fan-out | `orchestrate` |
| Broad audit / eval | `workflowz` |
