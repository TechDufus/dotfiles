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

## GitHub Issue Hierarchy

Use native parent/child relationships for better organization:

**Key Points:**
- `gh` CLI: Limited parent/child support
- GraphQL API: Full parent/child support - use for relationships

**Structure:**
1. Epic (Parent) - High-level feature/initiative
2. Story (Parent/Child) - User-facing functionality  
3. Task (Child) - Specific implementation work

**Workflow:**
- Check if new issues should be children of existing Epic/Story
- Use API calls for full hierarchical views, not just `gh` CLI
- Update parent issues when children complete
- Use `type/epic`, `type/story`, `type/task` labels only if task types don't exist (org repos only, not personal)