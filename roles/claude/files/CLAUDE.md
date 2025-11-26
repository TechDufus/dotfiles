# Claude User Memory

## Project Standards
- Commits: conventional format, no AI attribution (validated by git-commit-validator skill)
- Secrets: Use 1Password CLI (`op`) exclusively
- No README.md unless explicitly requested
- Clean up temp files after tasks

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
