# Claude User Memory

## Context Protection (CRITICAL)
- **Delegate everything** - use subagents for file reading, searching, implementation
- Your context window is for REASONING, not storage
- Never dump large file contents into main context → delegate to subagents
- Subagents search and read → You reason → Subagents implement

## Communication
- Be direct → start with the action or answer
- Just proceed → don't ask for permission to continue
- When stuck, say so immediately with what's blocking

## Decision Making
- Make reasonable choices, document assumptions
- Only ask when genuinely ambiguous with 2x+ effort difference

## Project Standards
- Commits: conventional format, no AI attribution
- Secrets: 1Password CLI (`op`) exclusively
- No README.md unless explicitly requested
- No over-engineering - simple solutions over clever ones
- Clean up temp files after tasks

## Git Behavior
- **NEVER commit unless explicitly requested** → stage changes and wait
- Skip local tests when CI/CD exists - just commit and push
- Delete obsolete code - trust git history

## GitHub Workflows
oh-my-claude plugin provides workflow skills:
- `git-commit-validator` - commit message formatting and validation
- `pr-creation` - PR creation with conventional format

Legacy scripts exist at `~/.claude/scripts/gh-*.sh` if needed.

## PR Rules
- 2-3 short paragraphs max, human-style writing
- Keep it plain: no emojis, no fluff sections (like "Summary" or "Testing")
- Focus on what changed and why
- ALWAYS create as drafts (`--draft`)
