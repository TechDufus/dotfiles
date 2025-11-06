---
name: git-commit-validator
description: This skill should be used whenever creating git commits. It ensures commit messages follow conventional commit format, character limits, and prohibits AI attribution or branding.
---

# Git Commit Validator

## Overview

Validate and generate git commit messages that pass strict quality standards before proposing commits to users. This skill enforces conventional commit format, character limits, and content policies to maintain clean git history.

## When to Use

Activate this skill for every git commit operation:
- Before running `git commit` commands
- When drafting commit messages for user approval
- When regenerating rejected commit messages

## Commit Message Standards

### Format Requirements

**Conventional Commit Structure:**
```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

**Examples:**
```
feat: add user authentication
fix(auth): resolve login timeout issue
docs: update API documentation
```

### Validation Rules

1. **Subject line (first line):**
   - Max 50 characters
   - Format: `<type>[optional scope]: <description>`
   - Type: lowercase word (feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert, or custom)
   - Scope: optional, lowercase alphanumeric with hyphens in parentheses
   - Description: starts with lowercase, no period at end

2. **Body lines:**
   - Max 72 characters per line
   - Blank line between subject and body
   - Use body to explain "why" not "what"

3. **Forbidden content:**
   - No AI attribution (e.g., "Generated with Claude")
   - No AI co-authors (e.g., "Co-authored-by: Claude")
   - No emojis or decorative symbols
   - No branding phrases

4. **Comment lines:**
   - Lines starting with `#` are ignored
   - Use for git commit template comments

## Workflow

### Before Proposing Commits

1. **Draft the commit message** based on the changes:
   - Analyze diff to understand the change type
   - Choose appropriate conventional type
   - Write concise description focused on "why"
   - Keep subject under 50 chars

2. **Validate using the script:**
   ```bash
   ~/.claude/skills/git-commit-validator/scripts/git-commit-helper.sh "<commit-message>"
   ```

3. **Check validation output:**
   - Script exits 0 with "✓ Commit message passes all checks" on success
   - Script exits 1 with specific ERROR messages on failure

4. **Fix any errors** before proposing to user

### If Commit is Rejected

When users reject a commit message:

1. **Analyze rejection reason** (if provided)
2. **Revalidate** against standards
3. **Regenerate message** addressing:
   - User feedback
   - Validation errors
   - Clarity and conciseness
4. **Revalidate** with script before re-proposing

### Common Type Usage

- `feat`: New feature or capability
- `fix`: Bug fix or correction
- `docs`: Documentation changes only
- `refactor`: Code restructuring without behavior change
- `perf`: Performance improvement
- `test`: Test additions or corrections
- `chore`: Maintenance tasks, dependency updates
- `ci`: CI/CD configuration changes
- `build`: Build system or dependency changes
- `style`: Code formatting (no logic change)

## Best Practices

**Subject Line:**
- Use imperative mood ("add feature" not "added feature")
- No capitalization after type prefix
- Be specific but concise
- Omit obvious context (e.g., "fix: bug" → "fix: resolve login timeout")

**Body (when needed):**
- Explain motivation for change
- Describe behavior differences
- Reference issue numbers (e.g., "Closes #123")
- Skip body for trivial changes

**Scopes:**
- Use for large codebases with clear modules
- Keep scopes consistent across commits
- Skip for small projects or unclear boundaries

## Validation Script

The `~/.claude/skills/git-commit-validator/scripts/git-commit-helper.sh` script performs automated validation:

**Usage:**
```bash
~/.claude/skills/git-commit-validator/scripts/git-commit-helper.sh "feat: add new feature"
```

**What it checks:**
- Subject line length (≤50 chars)
- Body line lengths (≤72 chars)
- Conventional commit format
- Forbidden phrases (AI attribution, branding)
- Comment line handling

**Success output:**
```
✓ Commit message passes all checks
```

**Error output:**
```
ERROR: First line exceeds 50 characters (57 chars)
Line 1: feat: this commit message is way too long and exceeds limits
```

Always validate before proposing commits to ensure clean git history.
