#!/bin/bash

# GitHub Task Creator with Parent Linking
# Creates child tasks linked to parent issues

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
    echo "Usage: $0 <parent-issue-number> <task-title> [priority] [labels]"
    echo ""
    echo "Parameters:"
    echo "  parent-issue-number: The parent Story/Epic issue number"
    echo "  task-title: Title for the new task"
    echo "  priority: Optional priority (critical|high|medium|low) - defaults to medium"
    echo "  labels: Optional comma-separated labels (e.g., 'frontend,bug' or 'backend,enhancement')"
    echo ""
    echo "Environment:"
    echo "  GITHUB_REPOSITORY: Override auto-detected repository (format: owner/repo)"
    echo "  GITHUB_ASSIGNEE: Set assignee for the task (defaults to current user)"
    echo ""
    echo "Examples:"
    echo "  $0 1 'Setup Navigation' high frontend"
    echo "  $0 2 'Implement API Client' medium backend,api"
    echo "  $0 19 'Deploy Dashboard'"
    echo "  GITHUB_REPOSITORY=owner/repo $0 5 'Fix bug'"
    echo ""
    exit 1
}

# Check parameters
if [ $# -lt 2 ]; then
    usage
fi

# Check if repo is set
if [ -z "$REPO" ]; then
    echo "❌ Could not detect repository. Please run from a git repository or set GITHUB_REPOSITORY"
    exit 1
fi

PARENT_ISSUE="$1"
TASK_TITLE="$2"
PRIORITY="${3:-medium}"
CUSTOM_LABELS="${4:-}"
ASSIGNEE="${GITHUB_ASSIGNEE:-@me}"

# Validate parent issue exists
if ! gh issue view $PARENT_ISSUE --repo $REPO >/dev/null 2>&1; then
    echo "❌ Parent issue #$PARENT_ISSUE does not exist in $REPO"
    exit 1
fi

# Get parent issue details
PARENT_TITLE=$(gh issue view $PARENT_ISSUE --repo $REPO --json title --jq '.title')
echo "🔗 Creating task under parent: #$PARENT_ISSUE - $PARENT_TITLE"
echo "📍 Repository: $REPO"

# Build labels array - only add priority if the label exists
LABELS=""
if gh label list --repo $REPO | grep -q "priority/$PRIORITY"; then
    LABELS="priority/$PRIORITY"
fi

# Add custom labels if specified
if [ -n "$CUSTOM_LABELS" ]; then
    if [ -n "$LABELS" ]; then
        LABELS="$LABELS,$CUSTOM_LABELS"
    else
        LABELS="$CUSTOM_LABELS"
    fi
fi

# Create task body with parent reference
TASK_BODY="## Summary
$TASK_TITLE

## Parent Issue
$PARENT_TITLE (#$PARENT_ISSUE)

## Description
Implementation task for the parent issue.

## Acceptance Criteria
- [ ] Implementation complete
- [ ] Tests written and passing (if applicable)
- [ ] Documentation updated (if applicable)
- [ ] Parent issue updated with progress

## Technical Details
_[Add implementation details here]_

## Notes
_[Add any additional context here]_

Related to #$PARENT_ISSUE"

echo "📝 Creating new task..."

# Build gh issue create command
CREATE_CMD="gh issue create --repo $REPO --title \"$TASK_TITLE\" --body \"$TASK_BODY\""

# Add labels if any
if [ -n "$LABELS" ]; then
    CREATE_CMD="$CREATE_CMD --label \"$LABELS\""
fi

# Add assignee
if [ "$ASSIGNEE" != "none" ]; then
    CREATE_CMD="$CREATE_CMD --assignee $ASSIGNEE"
fi

# Create the issue
NEW_ISSUE_URL=$(eval $CREATE_CMD)

# Extract issue number from URL
NEW_ISSUE_NUMBER=$(echo "$NEW_ISSUE_URL" | grep -o '[0-9]*$')

echo "✅ Created task #$NEW_ISSUE_NUMBER: $TASK_TITLE"

# Try to link to parent using gh-link-sub-issue script
LINK_SCRIPT="$(dirname "$0")/gh-link-sub-issue.sh"
echo "🔗 Linking to parent issue #$PARENT_ISSUE..."
if [ -f "$LINK_SCRIPT" ]; then
    if "$LINK_SCRIPT" $PARENT_ISSUE $NEW_ISSUE_NUMBER; then
        echo "✅ Successfully linked task #$NEW_ISSUE_NUMBER to parent #$PARENT_ISSUE"
    else
        echo "⚠️  Created task but automatic linking failed"
        echo "💡 You can manually link with: $LINK_SCRIPT $PARENT_ISSUE $NEW_ISSUE_NUMBER"
    fi
else
    echo "⚠️  gh-link-sub-issue.sh not found - manual linking required"
    echo "💡 To enable auto-linking, ensure gh-link-sub-issue.sh is in the same directory"
fi

echo ""
echo "🎯 Task Creation Complete!"
echo "=========================="
echo "📋 New Task: #$NEW_ISSUE_NUMBER - $TASK_TITLE"
echo "🔗 Parent: #$PARENT_ISSUE - $PARENT_TITLE"
if [ -n "$LABELS" ]; then
    echo "🏷️  Labels: $LABELS"
fi
if [ "$ASSIGNEE" != "none" ] && [ "$ASSIGNEE" != "@me" ]; then
    echo "👤 Assignee: $ASSIGNEE"
fi
echo "🌐 URL: $NEW_ISSUE_URL"
echo ""
echo "📋 Next Steps:"
echo "- Update acceptance criteria with specific requirements"
echo "- Add technical implementation details"
echo "- Start development work!"
