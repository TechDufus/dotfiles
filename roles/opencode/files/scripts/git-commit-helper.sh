#!/usr/bin/env bash
# Git commit helper following user's strict rules
#
# Validates git commit messages according to:
# 1. Conventional Commits specification: https://www.conventionalcommits.org/
# 2. Angular convention: https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit
# 3. Community standards: https://github.com/commitizen/conventional-commit-types
#
# Rules enforced:
# - First line (subject): max 50 characters
# - Body lines: max 72 characters
# - Comment lines (starting with #) are ignored
# - Conventional commit format: <type>[optional scope]: <description>
# - No Claude branding or attribution
#
# Format: <type>[optional scope]: <description>
# Examples:
#   feat: add user authentication
#   fix(auth): resolve login timeout issue
#   docs: update API documentation
#   custom-type: any lowercase word is valid
#
# Common types (not restrictive):
# - feat: new feature
# - fix: bug fix
# - docs: documentation only changes
# - style: code style changes (formatting, semicolons, etc)
# - refactor: code change that neither fixes a bug nor adds a feature
# - test: adding missing tests or correcting existing tests
# - build: changes that affect the build system or external dependencies
# - ci: changes to CI configuration files and scripts
# - perf: performance improvements
# - chore: other changes that don't modify src or test files
# - revert: reverts a previous commit

if [ $# -eq 0 ]; then
    echo "Usage: $0 <commit message>"
    exit 1
fi

MESSAGE="$1"

# Process message line by line
line_num=0
first_content_line=""
errors=0

while IFS= read -r line; do
    line_num=$((line_num + 1))
    
    # Skip comment lines (starting with #)
    if [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Skip empty lines until we find the first content line
    if [[ -z "$first_content_line" ]] && [[ -z "$line" ]]; then
        continue
    fi
    
    # First non-comment, non-empty line
    if [[ -z "$first_content_line" ]]; then
        first_content_line="$line"
        FIRST_LINE="$line"
        
        # Check first line length (50 chars max)
        if [ ${#line} -gt 50 ]; then
            echo "ERROR: First line exceeds 50 characters (${#line} chars)"
            echo "Line $line_num: $line"
            errors=$((errors + 1))
        fi
    else
        # All other non-comment lines (72 chars max)
        if [ ${#line} -gt 72 ]; then
            echo "ERROR: Line $line_num exceeds 72 characters (${#line} chars)"
            echo "Line $line_num: $line"
            errors=$((errors + 1))
        fi
    fi
done <<< "$MESSAGE"

# Exit if any line length errors
if [ $errors -gt 0 ]; then
    exit 1
fi

# Check for conventional commit format
# Format: <type>[optional scope]: <description>
# Example: feat(auth): add login functionality
# Example: fix: resolve memory leak
if ! echo "$FIRST_LINE" | grep -qE '^[a-z]+(\([a-z0-9\-]+\))?!?: .+$'; then
    echo "ERROR: First line must use conventional commit format"
    echo "Format: <type>[optional scope]: <description>"
    echo "Examples:"
    echo "  feat: add new feature"
    echo "  fix(auth): resolve login bug"
    echo "  custom-type: any lowercase word works"
    echo "Common types: feat, fix, docs, style, refactor, test, chore, perf, ci, build"
    exit 1
fi

# Check for forbidden phrases
if echo "$MESSAGE" | grep -qiE "(generated with claude|co-authored-by.*claude|🤖|claude code)"; then
    echo "ERROR: Commit message contains forbidden Claude branding"
    exit 1
fi

echo "✓ Commit message passes all checks"
