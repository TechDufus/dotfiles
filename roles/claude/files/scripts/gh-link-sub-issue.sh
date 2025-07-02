#!/bin/bash

# Helper script to create native GitHub parent/sub-issue relationships
# Supports cross-repo linking within the same organization
# Usage: gh-link-sub-issue.sh <parent> <child> [--force]
# Where issues can be: 123, #123, or org/repo#123

set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <parent> <child> [--force]"
    echo ""
    echo "Issue formats:"
    echo "  123              - Issue in current repo"
    echo "  #123             - Issue in current repo"
    echo "  org/repo#123     - Issue in specific repo"
    echo ""
    echo "Examples:"
    echo "  $0 19 27                              # Same repo"
    echo "  $0 org/main-repo#19 27                # Cross-repo parent"
    echo "  $0 19 org/other-repo#27               # Cross-repo child"
    echo "  $0 org/repo1#19 org/repo2#27 --force  # Both cross-repo"
    echo ""
    echo "Use --force to reassign if the child already has a parent"
    exit 1
fi

PARENT_ARG=$1
CHILD_ARG=$2
FORCE_FLAG=${3:-""}

# Get current repository as default
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    DEFAULT_REPO="$GITHUB_REPOSITORY"
else
    # Try to detect from git remote
    DEFAULT_REPO=$(gh repo view --json owner,name --jq '.owner.login + "/" + .name' 2>/dev/null || echo "")
fi

# Parse parent issue format
if [[ "$PARENT_ARG" =~ ^([^/#]+/[^/#]+)#([0-9]+)$ ]]; then
    PARENT_REPO="${BASH_REMATCH[1]}"
    PARENT_ISSUE="${BASH_REMATCH[2]}"
elif [[ "$PARENT_ARG" =~ ^#?([0-9]+)$ ]]; then
    PARENT_REPO="$DEFAULT_REPO"
    PARENT_ISSUE="${BASH_REMATCH[1]}"
else
    echo "❌ Invalid parent issue format: $PARENT_ARG"
    exit 1
fi

# Parse child issue format
if [[ "$CHILD_ARG" =~ ^([^/#]+/[^/#]+)#([0-9]+)$ ]]; then
    CHILD_REPO="${BASH_REMATCH[1]}"
    CHILD_ISSUE="${BASH_REMATCH[2]}"
elif [[ "$CHILD_ARG" =~ ^#?([0-9]+)$ ]]; then
    CHILD_REPO="$DEFAULT_REPO"
    CHILD_ISSUE="${BASH_REMATCH[1]}"
else
    echo "❌ Invalid child issue format: $CHILD_ARG"
    exit 1
fi

# Validate we have repos
if [ -z "$PARENT_REPO" ] || [ -z "$CHILD_REPO" ]; then
    echo "❌ Could not determine repository. Please specify full format: org/repo#123"
    exit 1
fi

echo "🔗 Linking issues:"
echo "   Parent: $PARENT_REPO#$PARENT_ISSUE"
echo "   Child:  $CHILD_REPO#$CHILD_ISSUE"

# Validate both issues exist
echo "🔍 Validating issues exist..."
if ! gh issue view $PARENT_ISSUE --repo $PARENT_REPO >/dev/null 2>&1; then
    echo "❌ Parent issue not found: $PARENT_REPO#$PARENT_ISSUE"
    exit 1
fi
if ! gh issue view $CHILD_ISSUE --repo $CHILD_REPO >/dev/null 2>&1; then
    echo "❌ Child issue not found: $CHILD_REPO#$CHILD_ISSUE"
    exit 1
fi

# Get the database ID of the child issue
echo "📊 Getting database ID for child issue..."
CHILD_DB_ID=$(gh api repos/$CHILD_REPO/issues/$CHILD_ISSUE --jq .id)

if [ -z "$CHILD_DB_ID" ]; then
    echo "❌ Failed to get database ID for issue $CHILD_REPO#$CHILD_ISSUE"
    exit 1
fi

echo "✅ Child database ID: $CHILD_DB_ID"

# If force flag is set, try to remove from any existing parent
if [ "$FORCE_FLAG" == "--force" ]; then
    echo "🔄 Force flag detected. Checking for existing parent relationships..."
    
    # Get all open issues that might be parents (limit to recent 100)
    echo "🔍 Scanning recent issues for existing parent relationship..."
    POTENTIAL_PARENTS=$(gh issue list --repo $CHILD_REPO --limit 100 --json number --jq '.[].number')
    
    for POTENTIAL_PARENT in $POTENTIAL_PARENTS; do
        if gh api repos/$CHILD_REPO/issues/$POTENTIAL_PARENT/sub_issue \
            -X DELETE \
            -F sub_issue_id=$CHILD_DB_ID 2>/dev/null; then
            echo "✅ Removed issue #$CHILD_ISSUE from parent #$POTENTIAL_PARENT"
            break
        fi
    done
fi

# Create the parent/sub-issue relationship
echo "🔗 Creating parent/sub-issue relationship..."
if gh api repos/$PARENT_REPO/issues/$PARENT_ISSUE/sub_issues \
    -X POST \
    -F sub_issue_id=$CHILD_DB_ID \
    --silent 2>/dev/null; then
    echo "✅ Successfully linked $CHILD_REPO#$CHILD_ISSUE as sub-issue of $PARENT_REPO#$PARENT_ISSUE"
else
    # If it fails, try to provide helpful error message
    ERROR_MSG=$(gh api repos/$PARENT_REPO/issues/$PARENT_ISSUE/sub_issues \
        -X POST \
        -F sub_issue_id=$CHILD_DB_ID 2>&1 || true)

    if echo "$ERROR_MSG" | grep -q "duplicate sub-issues"; then
        echo "⚠️  $CHILD_REPO#$CHILD_ISSUE is already a sub-issue of $PARENT_REPO#$PARENT_ISSUE"
        echo "✅ Relationship exists - no action needed"
    elif echo "$ERROR_MSG" | grep -q "only have one parent"; then
        echo "❌ $CHILD_REPO#$CHILD_ISSUE already has a different parent"
        echo "💡 Use --force to reassign: $0 $PARENT_ISSUE $CHILD_ISSUE --force"
        echo "⚠️  Note: You may need to manually remove from the current parent first"
        exit 1
    else
        echo "❌ Failed to create relationship"
        echo "Error: $ERROR_MSG"
        exit 1
    fi
fi
