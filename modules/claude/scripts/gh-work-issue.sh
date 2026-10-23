#!/bin/bash

# GitHub Issue Worker
# Views an issue, creates a branch, and prepares for implementation

set -euo pipefail

# Get current repository or use provided one
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    REPO="$GITHUB_REPOSITORY"
else
    # Try to detect from git remote
    REPO=$(gh repo view --json owner,name --jq '.owner.login + "/" + .name' 2>/dev/null || echo "")
fi

# Usage function
usage() {
    echo "Usage: $0 <issue-number> [branch-name]"
    echo ""
    echo "Start working on a GitHub issue by creating a branch and viewing details"
    echo ""
    echo "Arguments:"
    echo "  issue-number  The GitHub issue number to work on"
    echo "  branch-name   Optional custom branch name (auto-generated if not provided)"
    echo ""
    echo "Examples:"
    echo "  $0 42                        # Auto-generates branch name"
    echo "  $0 15 feature/auth-system    # Uses custom branch name"
    echo ""
    exit 1
}

# Check parameters
if [ $# -lt 1 ]; then
    usage
fi

# Check if repo is set
if [ -z "$REPO" ]; then
    echo "❌ Could not detect repository. Please run from a git repository or set GITHUB_REPOSITORY"
    exit 1
fi

ISSUE_NUMBER="$1"
CUSTOM_BRANCH="${2:-}"

# Validate issue exists and get details
echo "📋 Fetching issue #$ISSUE_NUMBER from $REPO..."

# Get issue details in JSON format
ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json title,body,labels,state,assignees 2>/dev/null || echo "")

if [ -z "$ISSUE_JSON" ]; then
    echo "❌ Issue #$ISSUE_NUMBER not found in $REPO"
    exit 1
fi

# Extract issue details
ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
ISSUE_STATE=$(echo "$ISSUE_JSON" | jq -r '.state')

# Check if issue is already closed
if [ "$ISSUE_STATE" = "CLOSED" ]; then
    echo "⚠️  Warning: Issue #$ISSUE_NUMBER is already closed"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Display issue summary
echo ""
echo "📌 Issue #$ISSUE_NUMBER: $ISSUE_TITLE"
echo ""

# Generate branch name if not provided
if [ -z "$CUSTOM_BRANCH" ]; then
    # Clean up title for branch name
    CLEAN_TITLE=$(echo "$ISSUE_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-40)
    
    # Determine prefix based on labels or title
    LABELS=$(echo "$ISSUE_JSON" | jq -r '.labels[].name' | tr '\n' ' ')
    
    if echo "$LABELS $ISSUE_TITLE" | grep -qiE "bug|fix|error|broken"; then
        PREFIX="fix"
    elif echo "$LABELS $ISSUE_TITLE" | grep -qiE "feature|enhancement|add|implement"; then
        PREFIX="feat"
    elif echo "$LABELS $ISSUE_TITLE" | grep -qiE "doc|documentation|readme"; then
        PREFIX="docs"
    elif echo "$LABELS $ISSUE_TITLE" | grep -qiE "test|testing|spec"; then
        PREFIX="test"
    elif echo "$LABELS $ISSUE_TITLE" | grep -qiE "refactor|cleanup|improve"; then
        PREFIX="refactor"
    else
        PREFIX="fix"  # Default
    fi
    
    BRANCH_NAME="$PREFIX/issue-$ISSUE_NUMBER-$CLEAN_TITLE"
else
    BRANCH_NAME="$CUSTOM_BRANCH"
fi

# Get base branch
BASE_BRANCH="${GH_WORK_BASE_BRANCH:-}"
if [ -z "$BASE_BRANCH" ]; then
    # Try to detect default branch
    BASE_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "main")
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a git repository"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "⚠️  You have uncommitted changes:"
    echo ""
    git status --short
    echo ""
    read -p "Would you like to stash these changes? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git stash push -m "Auto-stash before working on issue #$ISSUE_NUMBER"
        echo "✅ Changes stashed. Run 'git stash pop' after finishing to restore them."
    else
        echo "❌ Cannot proceed with uncommitted changes. Please commit or stash them first."
        exit 1
    fi
fi

# Create and checkout branch
echo "🌿 Creating branch: $BRANCH_NAME"

# Ensure we have the latest base branch
git fetch origin "$BASE_BRANCH" --quiet

# Create branch from origin/base
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo "⚠️  Branch $BRANCH_NAME already exists"
    read -p "Switch to existing branch? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git checkout "$BRANCH_NAME"
    else
        exit 1
    fi
else
    git checkout -b "$BRANCH_NAME" "origin/$BASE_BRANCH"
fi

echo ""
echo "✅ Ready to work on issue #$ISSUE_NUMBER"
echo "🌿 Branch: $BRANCH_NAME"
echo "📍 Issue: https://github.com/$REPO/issues/$ISSUE_NUMBER"
echo ""

# Store issue info for later use
echo "$ISSUE_NUMBER" > .git/WORKING_ISSUE
echo "$ISSUE_TITLE" > .git/WORKING_ISSUE_TITLE

echo "Next steps:"
echo "  1. Issue will be analyzed and fixed"
echo "  2. Tests will be run to validate"
echo "  3. Changes will be committed"
echo "  4. PR will be created to close the issue"