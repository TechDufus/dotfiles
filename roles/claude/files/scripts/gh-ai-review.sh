#!/bin/bash

# GitHub AI-Powered PR Review
# Fetches PR diff and outputs it for AI analysis
# This script is designed to be called by Claude for intelligent code review
# Supports both analysis mode and comment generation mode

set -euo pipefail

# Timeout for API calls (30 seconds)
GH_TIMEOUT="--request-timeout 30"

# Get current repository or use provided one
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    REPO="$GITHUB_REPOSITORY"
else
    # Try to detect from git remote
    REPO=$(gh repo view $GH_TIMEOUT --json owner,name --jq '"\(.owner.login)/\(.name)"' 2>/dev/null || echo "")
fi

# Usage function
usage() {
    echo "Usage: $0 <pr-reference>"
    echo ""
    echo "PR Reference formats:"
    echo "  123                    - PR in current repository"
    echo "  #123                   - PR in current repository"
    echo "  org/repo#123           - PR in specific repository"
    echo "  https://github.com/... - Full PR URL"
    echo ""
    echo "Environment:"
    echo "  GITHUB_REPOSITORY: Override auto-detected repository (format: owner/repo)"
    echo ""
    exit 1
}

# Check parameters
if [ $# -lt 1 ]; then
    usage
fi

# Parse PR reference
PR_ARG="$1"

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
    echo "ERROR: Invalid PR reference format: $PR_ARG" >&2
    exit 1
fi

# Validate we have a repo
if [ -z "$PR_REPO" ]; then
    echo "ERROR: Could not determine repository" >&2
    exit 1
fi

# Get PR metadata
PR_INFO=$(gh pr view $PR_NUMBER --repo $PR_REPO $GH_TIMEOUT --json title,author,state,body,headRefName,baseRefName,files,url,additions,deletions 2>/dev/null) || {
    echo "ERROR: Failed to fetch PR #$PR_NUMBER from $PR_REPO" >&2
    exit 1
}

# Output structured data for AI analysis
echo "=== PR METADATA ==="
echo "Repository: $PR_REPO"
echo "PR Number: $PR_NUMBER"
echo "URL: $(echo "$PR_INFO" | jq -r .url)"
echo "Title: $(echo "$PR_INFO" | jq -r .title)"
echo "Author: $(echo "$PR_INFO" | jq -r .author.login)"
echo "State: $(echo "$PR_INFO" | jq -r .state)"
echo "Base Branch: $(echo "$PR_INFO" | jq -r .baseRefName)"
echo "Head Branch: $(echo "$PR_INFO" | jq -r .headRefName)"
echo "Additions: $(echo "$PR_INFO" | jq -r .additions)"
echo "Deletions: $(echo "$PR_INFO" | jq -r .deletions)"
echo ""

# Output PR description
echo "=== PR DESCRIPTION ==="
PR_BODY=$(echo "$PR_INFO" | jq -r '.body // "No description provided"')
echo "$PR_BODY"
echo ""

# Output changed files summary
echo "=== CHANGED FILES ==="
echo "$PR_INFO" | jq -r '.files[] | "\(.changeType): \(.path) (+\(.additions)/-\(.deletions))"'
echo ""

# Get the full diff with context
echo "=== FULL DIFF ==="
gh pr diff $PR_NUMBER --repo $PR_REPO $GH_TIMEOUT || {
    echo "ERROR: Could not fetch diff" >&2
    exit 1
}
echo ""

# Get existing comments to avoid duplicate feedback
echo "=== EXISTING REVIEW COMMENTS ==="
gh pr view $PR_NUMBER --repo $PR_REPO --comments $GH_TIMEOUT --json comments --jq '.comments[] | "[\(.author.login)]: \(.body)"' 2>/dev/null || echo "No existing comments"
echo ""

# Get review status
echo "=== REVIEW STATUS ==="
gh pr view $PR_NUMBER --repo $PR_REPO $GH_TIMEOUT --json reviews --jq '.reviews[] | "\(.author.login): \(.state)"' 2>/dev/null || echo "No reviews yet"
echo ""

# Get GitHub Actions check runs status
echo "=== GITHUB ACTIONS STATUS ==="
CHECK_RUNS=$(gh pr checks $PR_NUMBER --repo $PR_REPO $GH_TIMEOUT --json name,state,link 2>/dev/null || echo "[]")
if [ "$CHECK_RUNS" = "[]" ]; then
    echo "No checks found"
else
    echo "$CHECK_RUNS" | jq -r '.[] | "\(.name): \(.state)"'
fi
echo ""

# Get details of any failed checks
echo "=== FAILED CHECK DETAILS ==="
FAILED_CHECKS=$(echo "$CHECK_RUNS" | jq -r '.[] | select(.state == "FAILURE") | .link' 2>/dev/null)
if [ -z "$FAILED_CHECKS" ]; then
    echo "No failed checks"
else
    for CHECK_URL in $FAILED_CHECKS; do
        # Extract run ID and job ID from URL (format: .../actions/runs/{run_id}/job/{job_id})
        if [[ "$CHECK_URL" =~ /actions/runs/([0-9]+)/job/([0-9]+) ]]; then
            RUN_ID="${BASH_REMATCH[1]}"
            JOB_ID="${BASH_REMATCH[2]}"
            echo "=== Failed Check: $CHECK_URL ==="
            # Get the workflow run logs summary
            gh run view $RUN_ID --repo $PR_REPO $GH_TIMEOUT --json jobs --jq ".jobs[] | select(.databaseId == $JOB_ID) | \"Job: \(.name)\nConclusion: \(.conclusion)\nSteps:\n\(.steps[] | \"  - \(.name): \(.conclusion)\")\"" 2>/dev/null || echo "Could not fetch run details"
            echo ""
        fi
    done
fi