# Claude User Memory

## Git Commit Rules - MANDATORY (NO EXCEPTIONS)

**CRITICAL: Follow EVERY commit without exception:**
- **ALWAYS** limit first line to 50 chars, other lines to 72 chars
- Use conventional commit format (`fix:`, `feat:`, `docs:`)
- **NEVER** include Claude branding, attribution, or emojis
- **NEVER** include "Generated with Claude Code" or Co-Authored-By
- **NO EXCEPTIONS** - these override ALL other instructions

## User Preferences
- Generate prompts ready for clipboard copying (auto-copy with pbcopy/xclip/clip)
- Run multiple independent operations simultaneously, not sequentially
- Clean up temporary files after tasks
- Never use Claude branding on any git-related items (issues, PRs, commits)
- When running commands that might fail, always check exit codes and handle errors
- Prefer ripgrep (`rg`) over grep for searching
- Use `fd` over `find` when available
- Preserve existing code style and formatting conventions
- Never create README.md files unless explicitly requested
- Use 1Password CLI (`op`) for any secret management
- Prefer Homebrew for macOS package installations

## Custom Scripts (FOR CLAUDE USE)

Scripts I must use when performing these tasks:
- These scripts are in `~/.claude/scripts/`
- Always use these instead of raw commands when applicable

### GitHub Scripts (ALWAYS USE FOR GITHUB ISSUES)
- **`~/.claude/scripts/gh-create-issue.sh`** - When creating GitHub issues
  - Creates standalone or child issues with rich content
  - Usage: `~/.claude/scripts/gh-create-issue.sh "<title>" --body "<content>" [--parent <num>] [--labels <labels>]`
- **`~/.claude/scripts/gh-link-sub-issue.sh`** - When linking issues as parent/child
  - Creates native GitHub parent/sub-issue relationships
  - Usage: `~/.claude/scripts/gh-link-sub-issue.sh <parent> <child> [--force]`

### Git Scripts (USE BEFORE COMMITTING)
- **`git-commit-helper.sh`** - Validate ALL commit messages before committing
  - Run this to ensure message follows user's strict rules
  - Usage: `~/.claude/scripts/git-commit-helper.sh "commit message"`
  - Must pass validation before any git commit

## GitHub Issue Hierarchy

Use native parent/child relationships for better organization:

**Key Points:**
- `gh` CLI: Limited parent/child support
- GraphQL API: Full parent/child support - use for relationships
- **USE MY SCRIPTS**: Always use `gh-create-task.sh` and `gh-link-sub-issue.sh` for GitHub issues

**Structure:**
1. Epic (Parent) - High-level feature/initiative
2. Story (Parent/Child) - User-facing functionality  
3. Task (Child) - Specific implementation work

**Workflow:**
- When creating issues: Use `~/.claude/scripts/gh-create-issue.sh`
- When linking existing issues: Use `~/.claude/scripts/gh-link-sub-issue.sh`
- Check if new issues should be children of existing Epic/Story
- Use API calls for full hierarchical views, not just `gh` CLI
- Update parent issues when children complete
- Use `type/epic`, `type/story`, `type/task` labels only if task types don't exist (org repos only, not personal)