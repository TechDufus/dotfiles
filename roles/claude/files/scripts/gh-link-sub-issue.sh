#!/bin/bash

# Helper script to create native GitHub parent/sub-issue relationships
# Usage: gh-link-sub-issue.sh <parent-issue-number> <child-issue-number> [--force]

set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <parent-issue-number> <child-issue-number> [--force]"
    echo "Example: $0 19 27"
    echo "Example: $0 19 27 --force  # Remove existing parent and reassign"
    echo ""
    echo "This will make issue #27 a sub-issue of issue #19"
    echo "Use --force to reassign if the child already has a parent"
    echo ""
    echo "Environment:"
    echo "  GITHUB_REPOSITORY: Override auto-detected repository (format: owner/repo)"
    exit 1
fi

PARENT_ISSUE=$1
CHILD_ISSUE=$2
FORCE_FLAG=${3:-""}

# Get current repository or use provided one
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    REPO="$GITHUB_REPOSITORY"
else
    # Try to detect from git remote
    REPO=$(gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"' 2>/dev/null || echo "")
fi

# Check if repo is set
if [ -z "$REPO" ]; then
    echo "❌ Could not detect repository. Please run from a git repository or set GITHUB_REPOSITORY"
    exit 1
fi

echo "🔗 Linking issue #$CHILD_ISSUE as sub-issue of #$PARENT_ISSUE"
echo "📍 Repository: $REPO"

# Get the database ID of the child issue
echo "📊 Getting database ID for issue #$CHILD_ISSUE..."
CHILD_DB_ID=$(gh api repos/$REPO/issues/$CHILD_ISSUE --jq .id)

if [ -z "$CHILD_DB_ID" ]; then
    echo "❌ Failed to get database ID for issue #$CHILD_ISSUE"
    exit 1
fi

echo "✅ Database ID: $CHILD_DB_ID"

# If force flag is set, try to remove from any existing parent
if [ "$FORCE_FLAG" == "--force" ]; then
    echo "🔄 Force flag detected. Checking for existing parent relationships..."
    
    # Get all open issues that might be parents (limit to recent 100)
    echo "🔍 Scanning recent issues for existing parent relationship..."
    POTENTIAL_PARENTS=$(gh issue list --repo $REPO --limit 100 --json number --jq '.[].number')
    
    for POTENTIAL_PARENT in $POTENTIAL_PARENTS; do
        if gh api repos/$REPO/issues/$POTENTIAL_PARENT/sub_issue \
            -X DELETE \
            -F sub_issue_id=$CHILD_DB_ID 2>/dev/null; then
            echo "✅ Removed issue #$CHILD_ISSUE from parent #$POTENTIAL_PARENT"
            break
        fi
    done
fi

# Create the parent/sub-issue relationship
echo "🔗 Creating parent/sub-issue relationship..."
if gh api repos/$REPO/issues/$PARENT_ISSUE/sub_issues \
    -X POST \
    -F sub_issue_id=$CHILD_DB_ID 2>/dev/null; then
    echo "✅ Successfully linked issue #$CHILD_ISSUE as sub-issue of #$PARENT_ISSUE"
else
    # If it fails, try to provide helpful error message
    ERROR_MSG=$(gh api repos/$REPO/issues/$PARENT_ISSUE/sub_issues \
        -X POST \
        -F sub_issue_id=$CHILD_DB_ID 2>&1 || true)

    if echo "$ERROR_MSG" | grep -q "duplicate sub-issues"; then
        echo "⚠️  Issue #$CHILD_ISSUE is already a sub-issue of #$PARENT_ISSUE"
        echo "✅ Relationship exists - no action needed"
    elif echo "$ERROR_MSG" | grep -q "only have one parent"; then
        echo "❌ Issue #$CHILD_ISSUE already has a different parent"
        echo "💡 Use --force to reassign: $0 $PARENT_ISSUE $CHILD_ISSUE --force"
        echo "⚠️  Note: You may need to manually remove from the current parent first"
        exit 1
    else
        echo "❌ Failed to create relationship"
        echo "Error: $ERROR_MSG"
        exit 1
    fi
fi
echo ""
echo "View parent issue: https://github.com/$REPO/issues/$PARENT_ISSUE"
echo "View child issue: https://github.com/$REPO/issues/$CHILD_ISSUE"
