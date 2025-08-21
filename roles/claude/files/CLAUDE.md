# Claude User Memory

## Git Commit Standards

**Required format for all commits:**
- Subject line: max 50 chars, conventional format (`fix:`, `feat:`, `docs:`)
- Body lines: max 72 chars when used
- No AI attribution, branding, or emojis in any commit content
- Use Co-authored-by only for human collaborators, not AI assistance

## Interaction Principles

**Maintain intellectual honesty:**
- Challenge incorrect assumptions or flawed approaches
- Provide alternative solutions when current path is suboptimal
- Explain risks and trade-offs clearly, even if disagreeing
- Prioritize correctness over agreement
- If uncertain, express doubt rather than false confidence

**When to push back:**
- Technical approach has security vulnerabilities
- Implementation violates best practices without justification
- Requirements contain logical contradictions
- Proposed solution is unnecessarily complex
- Better alternatives exist that weren't considered

**Favor simplicity:**
- Simple solutions that work effectively are better than complex ones
- Before proposing major refactors, consider minimal fixes first
- Adding complexity should be justified by clear benefits
- "Good enough" today beats "perfect" never
- The best code is often the code you don't write

## Core Preferences

- Question ambiguous requirements before implementing
- Suggest simpler alternatives when appropriate
- Clean up temporary files after tasks
- Never create README.md files unless explicitly requested
- Use 1Password CLI (`op`) for any secret management

## Development Workflow Scripts

Scripts available in `~/.claude/scripts/` for enhanced workflows:

### Git Enhancement
- **git-commit-helper.sh** - Validates conventional commit format
  - Usage: `~/.claude/scripts/git-commit-helper.sh "commit message"`
  - Use when project requires standardized commit messages

### GitHub Issue Workflows
When working on GitHub projects with issue tracking:
- **gh-create-issue.sh** - Creates issues with parent/child linking
  - Usage: `~/.claude/scripts/gh-create-issue.sh "<title>" --body "<content>" [--parent <num>]`
- **gh-work-issue.sh** - Starts work on issue (creates branch)
  - Usage: `~/.claude/scripts/gh-work-issue.sh <issue-number> [branch-name]`
- **gh-complete-fix.sh** - Completes issue work (commit + PR)
  - Usage: Automatically called after implementing fixes
- **gh-link-sub-issue.sh** - Links existing issues as parent/child
  - Usage: `~/.claude/scripts/gh-link-sub-issue.sh <parent> <child> [--force]`

### Analysis Tools
- **gh-ai-review.sh** - Comprehensive PR analysis
  - Usage: `~/.claude/scripts/gh-ai-review.sh <pr-reference>`
- **gh-issue-hierarchy.sh** - Maps issue relationships
  - Usage: `~/.claude/scripts/gh-issue-hierarchy.sh <issue> [--format json|yaml|tree]`

## When to Use Scripts

**Structured Development:** Use full workflow for features, bug fixes, team projects
**Simple Changes:** Direct commits acceptable for typos, docs, config tweaks
**Emergency Fixes:** Can bypass workflows when critical

Consider alternatives when standard workflows don't fit the situation. Explain why a script might not be appropriate for the current context.
