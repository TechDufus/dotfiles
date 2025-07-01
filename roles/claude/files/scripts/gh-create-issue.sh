#!/bin/bash

# GitHub Issue Creator with Optional Parent Linking
# Creates issues with custom body content and optional parent/child relationships

set -euo pipefail

# Get current repository or use provided one
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    REPO="$GITHUB_REPOSITORY"
else
    # Try to detect from git remote
    REPO=$(gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"' 2>/dev/null || echo "")
fi

# Usage function
usage() {
    echo "Usage: $0 <title> [options]"
    echo ""
    echo "Options:"
    echo "  --body <text>      Issue body content (required)"
    echo "  --parent <number>  Parent issue to link to (optional)"
    echo "  --labels <labels>  Comma-separated labels (optional)"
    echo "  --priority <level> Priority level (optional)"
    echo "  --assignee <user>  Assignee (defaults to @me)"
    echo ""
    echo "Environment:"
    echo "  GITHUB_REPOSITORY: Override auto-detected repository (format: owner/repo)"
    echo ""
    echo "Examples:"
    echo "  $0 \"Fix login bug\" --body \"Users report timeout...\" --labels \"bug,auth\""
    echo "  $0 \"Add tests\" --body \"Coverage needed...\" --parent 5"
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

# Parse arguments
TITLE="$1"
shift

BODY=""
PARENT_ISSUE=""
LABELS=""
PRIORITY=""
ASSIGNEE="${GITHUB_ASSIGNEE:-@me}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --body)
            BODY="$2"
            shift 2
            ;;
        --parent)
            PARENT_ISSUE="$2"
            shift 2
            ;;
        --labels)
            LABELS="$2"
            shift 2
            ;;
        --priority)
            PRIORITY="$2"
            shift 2
            ;;
        --assignee)
            ASSIGNEE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required body
if [ -z "$BODY" ]; then
    echo "❌ Error: --body is required"
    usage
fi

echo "📝 Creating issue in $REPO..."

# Create a temporary file for the body to preserve formatting
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT
echo "$BODY" > "$TMPFILE"

# Build the command with proper options
GH_ARGS=(
    "issue" "create"
    "--repo" "$REPO"
    "--title" "$TITLE"
    "--body-file" "$TMPFILE"
)

# Add priority label if exists
if [ -n "$PRIORITY" ] && gh label list --repo $REPO | grep -q "priority/$PRIORITY"; then
    if [ -n "$LABELS" ]; then
        LABELS="$LABELS,priority/$PRIORITY"
    else
        LABELS="priority/$PRIORITY"
    fi
fi

# Add labels if any
if [ -n "$LABELS" ]; then
    GH_ARGS+=("--label" "$LABELS")
fi

# Add assignee
if [ "$ASSIGNEE" != "none" ]; then
    GH_ARGS+=("--assignee" "$ASSIGNEE")
fi

# Create the issue
NEW_ISSUE_URL=$(gh "${GH_ARGS[@]}")
NEW_ISSUE_NUMBER=$(echo "$NEW_ISSUE_URL" | grep -o '[0-9]*$')

# Link to parent if specified
if [ -n "$PARENT_ISSUE" ]; then
    # Validate parent exists
    if ! gh issue view $PARENT_ISSUE --repo $REPO >/dev/null 2>&1; then
        echo "⚠️  Warning: Parent issue #$PARENT_ISSUE not found"
    else
        LINK_SCRIPT="$(dirname "$0")/gh-link-sub-issue.sh"
        if [ -f "$LINK_SCRIPT" ]; then
            "$LINK_SCRIPT" $PARENT_ISSUE $NEW_ISSUE_NUMBER >/dev/null 2>&1 || echo "⚠️  Linking failed"
        else
            # Fallback: Add parent reference in issue body
            gh issue comment $NEW_ISSUE_NUMBER --repo $REPO --body "Parent issue: #$PARENT_ISSUE" --silent
        fi
    fi
fi

echo ""
echo "✅ Created issue #$NEW_ISSUE_NUMBER${PARENT_ISSUE:+ (child of #$PARENT_ISSUE)}"
echo "📍 $NEW_ISSUE_URL"