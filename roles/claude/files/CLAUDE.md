# Claude User Memory

## Project Standards
- Commits: conventional format, no AI attribution (validated by git-commit-validator skill)
- Secrets: Use 1Password CLI (`op`) exclusively
- No README.md unless explicitly requested
- Clean up temp files after tasks

## Code Style
- Prefer concise implementations over verbose ones
- Code should be human-readable without sacrificing functionality
- No unnecessary abstractions or over-engineering

## Git Behavior
- **NEVER commit unless explicitly requested** - always ask first
- Skip local build/test runs when CI/CD exists - just commit and push
- Delete obsolete code rather than deprecating - trust git history

## Workflow Scripts (`~/.claude/scripts/`)
- `gh-create-issue.sh "<title>" --body "<content>" [--parent <num>]`
- `gh-work-issue.sh <issue-number> [branch-name]`
- `gh-complete-fix.sh`
- `gh-link-sub-issue.sh <parent> <child> [--force]`
- `gh-ai-review.sh <pr-reference>`
- `gh-issue-hierarchy.sh <issue> [--format json|yaml|tree]`

## When to Use Scripts
- **Full workflow**: features, bugs, team projects
- **Direct commits OK**: typos, docs, config
- **Emergency**: bypass when critical

## PR Description Rules
- Concise and to the point (2-3 short paragraphs max)
- Human-style writing, not AI/formal style
- No emojis
- No unnecessary sections (like "Result" or "Testing")
- Focus on what changed and why
- ALWAYS create PRs as drafts (`gh pr create --draft`)
