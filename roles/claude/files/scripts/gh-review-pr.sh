#!/bin/bash

# GitHub PR Review Helper
# Reviews pull requests with detailed diff viewing and review actions
# Supports same-repo and cross-repo PR references

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
    echo "Usage: $0 <pr-reference> [options]"
    echo ""
    echo "PR Reference formats:"
    echo "  123                    - PR in current repository"
    echo "  #123                   - PR in current repository"
    echo "  org/repo#123           - PR in specific repository"
    echo "  https://github.com/... - Full PR URL"
    echo ""
    echo "Options:"
    echo "  --diff-only           Show diff only, skip review prompt"
    echo "  --approve             Auto-approve without prompting"
    echo "  --comment <text>      Add comment without prompting"
    echo ""
    echo "Environment:"
    echo "  GITHUB_REPOSITORY: Override auto-detected repository (format: owner/repo)"
    echo ""
    echo "Examples:"
    echo "  $0 42                                          # Review PR #42 in current repo"
    echo "  $0 TechDufus/dotfiles#100                      # Review PR in another repo"
    echo "  $0 https://github.com/org/repo/pull/123        # Review PR by URL"
    echo "  $0 42 --diff-only                              # Just show the diff"
    echo "  $0 42 --approve                                # Quick approve"
    echo ""
    exit 1
}

# Check parameters
if [ $# -lt 1 ]; then
    usage
fi

# Parse PR reference
PR_ARG="$1"
shift

# Parse options
DIFF_ONLY=false
AUTO_APPROVE=false
AUTO_COMMENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --diff-only)
            DIFF_ONLY=true
            shift
            ;;
        --approve)
            AUTO_APPROVE=true
            shift
            ;;
        --comment)
            AUTO_COMMENT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Parse PR reference format
if [[ "$PR_ARG" =~ ^https://github.com/([^/]+/[^/]+)/pull/([0-9]+) ]]; then
    # Full URL format
    PR_REPO="${BASH_REMATCH[1]}"
    PR_NUMBER="${BASH_REMATCH[2]}"
elif [[ "$PR_ARG" =~ ^([^/#]+/[^/#]+)#([0-9]+)$ ]]; then
    # Cross-repo format: org/repo#123
    PR_REPO="${BASH_REMATCH[1]}"
    PR_NUMBER="${BASH_REMATCH[2]}"
elif [[ "$PR_ARG" =~ ^#?([0-9]+)$ ]]; then
    # Same repo format: 123 or #123
    PR_REPO="$REPO"
    PR_NUMBER="${BASH_REMATCH[1]}"
else
    echo "❌ Invalid PR reference format: $PR_ARG"
    echo "   Use: 123, #123, org/repo#123, or full URL"
    exit 1
fi

# Validate we have a repo
if [ -z "$PR_REPO" ]; then
    echo "❌ Could not determine repository. Please run from a git repository or set GITHUB_REPOSITORY"
    exit 1
fi

echo "📋 Reviewing PR $PR_REPO#$PR_NUMBER..."
echo ""

# Get PR details
echo "🔍 Fetching PR information..."
PR_INFO=$(gh pr view $PR_NUMBER --repo $PR_REPO --json title,author,state,body,headRefName,baseRefName,files,isDraft,mergeable,mergeStateStatus 2>/dev/null) || {
    echo "❌ Failed to fetch PR #$PR_NUMBER from $PR_REPO"
    exit 1
}

# Extract PR details
PR_TITLE=$(echo "$PR_INFO" | jq -r .title)
PR_AUTHOR=$(echo "$PR_INFO" | jq -r .author.login)
PR_STATE=$(echo "$PR_INFO" | jq -r .state)
PR_BODY=$(echo "$PR_INFO" | jq -r '.body // ""')
PR_HEAD=$(echo "$PR_INFO" | jq -r .headRefName)
PR_BASE=$(echo "$PR_INFO" | jq -r .baseRefName)
PR_DRAFT=$(echo "$PR_INFO" | jq -r .isDraft)
PR_MERGEABLE=$(echo "$PR_INFO" | jq -r .mergeable)
PR_MERGE_STATUS=$(echo "$PR_INFO" | jq -r .mergeStateStatus)
PR_FILES=$(echo "$PR_INFO" | jq -r '.files | length')

# Display PR summary
echo "╭─────────────────────────────────────────────────────────╮"
echo "│ PR #$PR_NUMBER: $PR_TITLE"
echo "├─────────────────────────────────────────────────────────┤"
echo "│ Author:    @$PR_AUTHOR"
echo "│ State:     $PR_STATE $([ "$PR_DRAFT" = "true" ] && echo "[DRAFT]" || echo "")"
echo "│ Branch:    $PR_HEAD → $PR_BASE"
echo "│ Mergeable: $PR_MERGEABLE ($PR_MERGE_STATUS)"
echo "│ Files:     $PR_FILES changed"
echo "╰─────────────────────────────────────────────────────────╯"

if [ -n "$PR_BODY" ]; then
    echo ""
    echo "📝 Description:"
    echo "───────────────"
    echo "$PR_BODY" | sed 's/^/  /'
fi

# Show changed files
echo ""
echo "📁 Changed files:"
echo "─────────────────"
echo "$PR_INFO" | jq -r '.files[] | "  \(.changeType): \(.path) (+\(.additions)/-\(.deletions))"'

# Show the diff
echo ""
echo "🔍 Fetching diff..."
echo "═══════════════════════════════════════════════════════════"
gh pr diff $PR_NUMBER --repo $PR_REPO --color always || {
    echo "⚠️  Could not fetch diff. The PR might be too large or have conflicts."
}
echo "═══════════════════════════════════════════════════════════"

# If diff-only mode, exit here
if [ "$DIFF_ONLY" = "true" ]; then
    exit 0
fi

# Handle auto-approve
if [ "$AUTO_APPROVE" = "true" ]; then
    echo ""
    echo "✅ Auto-approving PR..."
    gh pr review $PR_NUMBER --repo $PR_REPO --approve --body "LGTM! 👍"
    echo "✅ PR approved successfully!"
    exit 0
fi

# Handle auto-comment
if [ -n "$AUTO_COMMENT" ]; then
    echo ""
    echo "💬 Adding comment..."
    gh pr review $PR_NUMBER --repo $PR_REPO --comment --body "$AUTO_COMMENT"
    echo "✅ Comment added successfully!"
    exit 0
fi

# Interactive review prompt
echo ""
echo "🤔 What would you like to do?"
echo ""
echo "  [a] Approve PR"
echo "  [c] Add comment"
echo "  [r] Request changes"
echo "  [s] Skip (no action)"
echo ""
read -p "Choose action [a/c/r/s]: " -n 1 ACTION
echo ""

case "$ACTION" in
    a|A)
        read -p "Add approval comment (optional): " APPROVE_COMMENT
        if [ -n "$APPROVE_COMMENT" ]; then
            gh pr review $PR_NUMBER --repo $PR_REPO --approve --body "$APPROVE_COMMENT"
        else
            gh pr review $PR_NUMBER --repo $PR_REPO --approve --body "LGTM! 👍"
        fi
        echo "✅ PR approved successfully!"
        ;;
    c|C)
        echo "Enter your comment (press Enter twice to finish):"
        COMMENT=""
        while IFS= read -r line; do
            [ -z "$line" ] && break
            COMMENT="${COMMENT}${line}\n"
        done
        if [ -n "$COMMENT" ]; then
            gh pr review $PR_NUMBER --repo $PR_REPO --comment --body "$(echo -e "$COMMENT")"
            echo "✅ Comment added successfully!"
        else
            echo "⚠️  No comment provided, skipping."
        fi
        ;;
    r|R)
        echo "Enter your change request (press Enter twice to finish):"
        CHANGES=""
        while IFS= read -r line; do
            [ -z "$line" ] && break
            CHANGES="${CHANGES}${line}\n"
        done
        if [ -n "$CHANGES" ]; then
            gh pr review $PR_NUMBER --repo $PR_REPO --request-changes --body "$(echo -e "$CHANGES")"
            echo "✅ Changes requested successfully!"
        else
            echo "⚠️  No changes specified, skipping."
        fi
        ;;
    s|S)
        echo "👍 Skipping review action."
        ;;
    *)
        echo "❌ Invalid action. Exiting."
        exit 1
        ;;
esac

echo ""
echo "🔗 View PR online: https://github.com/$PR_REPO/pull/$PR_NUMBER"