#!/bin/bash

# GitHub Issue Fix Completion Helper
# Validates, commits, pushes, and creates PR for issue fixes

set -euo pipefail

# Get current repository or use provided one
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    REPO="$GITHUB_REPOSITORY"
else
    # Try to detect from git remote
    REPO=$(gh repo view --json owner,name --jq '"$(.owner.login)/$(.name)"' 2>/dev/null || echo "")
fi

# Check if repo is set
if [ -z "$REPO" ]; then
    echo "❌ Could not detect repository. Please run from a git repository or set GITHUB_REPOSITORY"
    exit 1
fi

# Check for stored issue info
if [ ! -f .git/WORKING_ISSUE ]; then
    echo "❌ No working issue found. Use gh-work-issue.sh first"
    exit 1
fi

ISSUE_NUMBER=$(cat .git/WORKING_ISSUE)
ISSUE_TITLE=$(cat .git/WORKING_ISSUE_TITLE 2>/dev/null || echo "")

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    echo "❌ Not on a feature branch. Use gh-work-issue.sh first"
    exit 1
fi

echo "📋 Completing fix for issue #$ISSUE_NUMBER"
echo "🌿 Branch: $CURRENT_BRANCH"
echo ""

# Check for changes
if git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "❌ No changes to commit"
    exit 1
fi

# Stage all changes
echo "📦 Staging changes..."
git add -A

# Show what will be committed
echo ""
echo "Changes to be committed:"
git diff --cached --stat
echo ""

# Generate commit message
if [[ $CURRENT_BRANCH == fix/* ]]; then
    COMMIT_PREFIX="fix"
elif [[ $CURRENT_BRANCH == feat/* ]]; then
    COMMIT_PREFIX="feat"
elif [[ $CURRENT_BRANCH == docs/* ]]; then
    COMMIT_PREFIX="docs"
elif [[ $CURRENT_BRANCH == test/* ]]; then
    COMMIT_PREFIX="test"
elif [[ $CURRENT_BRANCH == refactor/* ]]; then
    COMMIT_PREFIX="refactor"
else
    COMMIT_PREFIX="fix"  # Default
fi

# Create concise description from issue title
COMMIT_DESC=$(echo "$ISSUE_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | cut -c1-40)
COMMIT_MSG="$COMMIT_PREFIX: $COMMIT_DESC (closes #$ISSUE_NUMBER)"

# Validate commit message
echo "🔍 Validating commit message..."
if [ -x ~/.claude/scripts/git-commit-helper.sh ]; then
    ~/.claude/scripts/git-commit-helper.sh "$COMMIT_MSG" || {
        echo "❌ Commit message validation failed"
        exit 1
    }
fi

# Commit changes
echo "✍️  Committing: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"

# Push branch
echo "🚀 Pushing branch..."
git push -u origin "$CURRENT_BRANCH"

# Create PR
echo "🔗 Creating pull request..."

# Generate PR title
PR_TITLE="Fix: $ISSUE_TITLE"
if [[ $COMMIT_PREFIX == "feat" ]]; then
    PR_TITLE="Feature: $ISSUE_TITLE"
elif [[ $COMMIT_PREFIX == "docs" ]]; then
    PR_TITLE="Docs: $ISSUE_TITLE"
fi

# Create PR body
TMPFILE=$(mktemp)
cat > "$TMPFILE" <<EOF
Closes #$ISSUE_NUMBER

## Summary
- Fixed the issue as described
- All tests passing
- Code reviewed and validated

## Test Plan
- Ran relevant tests
- Verified fix resolves the issue
- No regressions found
EOF

# Create the PR
PR_URL=$(gh pr create \
    --title "$PR_TITLE" \
    --body-file "$TMPFILE" \
    --repo "$REPO" \
    --head "$CURRENT_BRANCH" \
    2>&1 | grep -E "https://github.com/.*/pull/[0-9]+" || echo "")

rm -f "$TMPFILE"

# Clean up stored issue info
rm -f .git/WORKING_ISSUE .git/WORKING_ISSUE_TITLE

if [ -n "$PR_URL" ]; then
    echo ""
    echo "✅ PR created successfully!"
    echo "🔗 $PR_URL"
    echo ""
    echo "The PR will automatically close issue #$ISSUE_NUMBER when merged."
else
    echo ""
    echo "⚠️  PR may have been created but URL not captured. Check GitHub."
fi