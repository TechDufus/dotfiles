---
description: "Quick commit workflow: /commit [instructions] [--staged]"
---

# /commit - Streamlined Git Commit

## Usage

```
/commit                           # Stage all, generate message
/commit --staged                  # Commit only staged files
/commit ignore the docs file      # Stage all except docs, generate message
/commit --staged focus on auth    # Commit staged, message emphasizes auth changes
```

## Arguments: $ARGUMENTS

---

## Behavior

**Default (no --staged flag):**
- Stage all changes (`git add -A`)
- Generate commit message via skill
- Commit

**With --staged flag:**
- Do NOT stage anything - commit only what's already staged
- Generate commit message from staged diff only
- Commit

**Instructions (optional):**
Pass any additional context from `$ARGUMENTS` to the skill:
- "ignore the docs file" → exclude from staging
- "this is a breaking change" → skill factors into message
- "focus on the API changes" → skill emphasizes in message

---

## Execution

Invoke the `git-commit-validator` skill with:
- Whether to use staged-only mode
- Any user instructions from `$ARGUMENTS`

The skill handles diff analysis, message generation, validation, and commit.
