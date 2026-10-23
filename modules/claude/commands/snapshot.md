---
description: "Capture session state before /clear: /snapshot [filename]"
argument-hint: "[filename]"
allowed-tools:
  - Bash(git:*)
  - Bash(mkdir:*)
  - Read
  - Write
---

# /snapshot - Session State Capture

Dump current work state to markdown before running `/clear`. Enables "Document & Clear" pattern that's more explicit than `/compact`.

## Usage

```
/snapshot                    # Auto-generate filename: snapshot-YYYY-MM-DD-HHMM.md
/snapshot auth-feature       # Custom filename: auth-feature.md
```

## Arguments: $ARGUMENTS

---

## Philosophy

**Problem**: `/compact` is opaque - you don't control what context survives.

**Solution**: Explicitly document state to markdown, then `/clear` for fresh context. Resume by reading the snapshot file.

**When to use**:
- Session getting long (>50% context used)
- Before switching to unrelated task
- End of work session for next-day pickup
- Before complex multi-file refactoring

---

## Execution

### Step 1: Gather Current State

Run these in parallel:
```bash
git branch --show-current
git status --short
git log --oneline -10
git diff --cached --stat
git diff --stat
```

### Step 2: Generate Snapshot Document

Create markdown file in the **current repository** at `.claude/snapshots/{filename}.md`:

**Location logic**:
- If in a git repo: `{repo_root}/.claude/snapshots/{filename}.md`
- If not in a repo: `~/.claude/snapshots/{filename}.md` (fallback)

**Gitignore recommendation**: Add `.claude/snapshots/` to `.gitignore` - these are personal work state, not project artifacts.

```markdown
# Work Snapshot: {timestamp}

## Branch & Git State
- **Branch**: {current-branch}
- **Staged**: {staged files summary}
- **Unstaged**: {unstaged files summary}
- **Recent commits**: {last 5-10 on branch}

## Session Summary
{Ask Claude to summarize what was worked on this session}

## In-Progress Work
{List any incomplete tasks, TODO items discovered, blockers}

## Key Decisions Made
{Any architectural decisions, approach choices, tradeoffs decided}

## Files Modified This Session
{List of files touched with brief change description}

## Context for Next Session
{What the next session needs to know to continue effectively}

## Suggested Next Steps
{2-3 concrete actions for resumption}
```

### Step 3: Save and Report

1. Ensure `.claude/snapshots/` directory exists in repo root
2. Write snapshot to `{repo_root}/.claude/snapshots/{filename}.md`
3. If `.gitignore` exists and doesn't have `.claude/snapshots/`, suggest adding it
4. Display summary to user
5. Suggest: "Run `/clear` then read this snapshot to resume"

---

## Resumption Pattern

After clearing context:
```
/clear
# Then either:
Read .claude/snapshots/auth-feature.md and continue the work
# Or use /prime with task hint:
/prime continuing auth feature from snapshot
```

---

## Example Output

```markdown
# Work Snapshot: 2024-01-15 14:32

## Branch & Git State
- **Branch**: feat/oauth2-login (7 commits ahead of main)
- **Staged**: None
- **Unstaged**: src/auth/google.ts (+45 lines)
- **Recent commits**:
  - abc1234 feat(auth): add provider interface
  - def5678 feat(auth): implement Google provider
  - ghi9012 wip: callback handler skeleton

## Session Summary
Implementing OAuth2 authentication. Created provider abstraction,
completed Google provider, started callback handler implementation.

## In-Progress Work
- [ ] Google callback handler (src/auth/google.ts:45-89)
- [ ] Need to add CSRF state validation
- [ ] Token refresh logic not yet implemented

## Key Decisions Made
- Using provider pattern for OAuth flexibility
- Storing tokens in httpOnly cookies, not localStorage
- Refresh tokens will use sliding window expiration

## Files Modified This Session
- src/auth/provider.ts - New: Provider interface
- src/auth/google.ts - New: Google implementation (incomplete)
- src/auth/index.ts - Updated: Export providers
- src/routes/callback.ts - New: Callback route stub

## Context for Next Session
The callback handler needs to:
1. Validate CSRF state from cookie
2. Exchange code for tokens
3. Create/update user record
4. Set session cookies

Google provider docs: https://developers.google.com/identity/protocols/oauth2

## Suggested Next Steps
1. Complete callback validation in src/auth/google.ts
2. Add tests for callback flow
3. Implement token refresh mechanism
```

---

## Integration with Other Commands

```
# End of session:
/snapshot oauth-progress
/clear

# Next session:
/prime continuing OAuth from .claude/snapshots/oauth-progress.md

# Or quick resume:
Read .claude/snapshots/oauth-progress.md and continue implementing the callback handler
```

---

## Directory Structure

```
your-project/
├── .claude/
│   └── snapshots/           # Gitignored - personal work state
│       ├── oauth-progress.md
│       └── api-refactor.md
├── .gitignore               # Add: .claude/snapshots/
├── src/
└── ...
```
