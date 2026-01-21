#!/bin/bash

# GitHub AI-Powered PR Review
# Intelligent PR analysis with adaptive strategies for any size PR
# Supports summary-only mode, file filtering, and generated file exclusion

set -euo pipefail

# Default settings
SUMMARY_ONLY=false
FILE_PATTERNS=()
SKIP_GENERATED=true

# Generated/lock files to skip by default
GENERATED_PATTERNS=(
    "*lock.json"
    "*.lock"
    "Gemfile.lock"
    "Pipfile.lock"
    "poetry.lock"
    "*.min.js"
    "*.bundle.js"
    "dist/*"
    "build/*"
    "node_modules/*"
    "vendor/*"
    ".next/*"
    "out/*"
)

# Timeout for API calls (30 seconds)
GH_TIMEOUT="--request-timeout 30"

# Get current repository or use provided one
if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    REPO="$GITHUB_REPOSITORY"
else
    # Try to detect from git remote
    REPO=$(gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"' 2>/dev/null || echo "")
    
    # If gh repo view fails, try git remote
    if [ -z "$REPO" ]; then
        REPO=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]([^/]+/[^/.]+)(\.git)?$|\1|' || echo "")
    fi
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
    echo "  --summary-only         Only output metadata and file list (no diffs)"
    echo "  --files 'pattern'      Only include files matching pattern (can be used multiple times)"
    echo "  --no-skip-generated    Include generated/lock files (default: skip them)"
    echo ""
    echo "Examples:"
    echo "  $0 123 --summary-only                  # Get overview for strategy decision"
    echo "  $0 123 --files 'api/*'                 # Only review API files"
    echo "  $0 123 --files '*.py' --files '*.js'   # Review Python and JavaScript files"
    echo ""
    echo "Environment:"
    echo "  GITHUB_REPOSITORY: Override auto-detected repository (format: owner/repo)"
    echo ""
    exit 1
}

# Parse arguments
if [ $# -lt 1 ]; then
    usage
fi

# Check for help flag first
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    usage
fi

PR_ARG="$1"
shift

# Parse optional flags
while [ $# -gt 0 ]; do
    case "$1" in
        --summary-only)
            SUMMARY_ONLY=true
            shift
            ;;
        --files)
            if [ $# -lt 2 ]; then
                echo "ERROR: --files requires a pattern argument" >&2
                exit 1
            fi
            FILE_PATTERNS+=("$2")
            shift 2
            ;;
        --no-skip-generated)
            SKIP_GENERATED=false
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
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
    echo "ERROR: Invalid PR reference format: $PR_ARG" >&2
    exit 1
fi

# Validate we have a repo
if [ -z "$PR_REPO" ]; then
    echo "ERROR: Could not determine repository" >&2
    echo "Please run from a git repository or set GITHUB_REPOSITORY=owner/repo" >&2
    echo "Current directory: $(pwd)" >&2
    exit 1
fi

# Get PR metadata
PR_INFO=$(gh pr view $PR_NUMBER --repo $PR_REPO --json title,author,state,body,headRefName,baseRefName,files,url,additions,deletions 2>/dev/null) || {
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
TOTAL_CHANGES=$(($(echo "$PR_INFO" | jq -r .additions) + $(echo "$PR_INFO" | jq -r .deletions)))
echo "Total Changes: $TOTAL_CHANGES lines"
FILE_COUNT=$(echo "$PR_INFO" | jq -r '.files | length')
echo "Files Changed: $FILE_COUNT"
echo ""

# Output PR description
echo "=== PR DESCRIPTION ==="
PR_BODY=$(echo "$PR_INFO" | jq -r '.body // "No description provided"')
echo "$PR_BODY"
echo ""

# Filter files if needed
ALL_FILES=$(echo "$PR_INFO" | jq -r '.files[] | .path')

# Apply generated file filtering
if [ "$SKIP_GENERATED" = true ]; then
    FILTERED_FILES=""
    while IFS= read -r file; do
        SKIP=false
        for pattern in "${GENERATED_PATTERNS[@]}"; do
            # Convert glob pattern to regex
            regex_pattern=$(echo "$pattern" | sed 's/\*/.*/')
            if [[ "$file" =~ $regex_pattern ]]; then
                SKIP=true
                break
            fi
        done
        if [ "$SKIP" = false ]; then
            FILTERED_FILES="${FILTERED_FILES}${file}"$'\n'
        fi
    done <<< "$ALL_FILES"
    ALL_FILES="$FILTERED_FILES"
fi

# Apply file pattern filtering if specified
if [ ${#FILE_PATTERNS[@]} -gt 0 ]; then
    PATTERN_FILTERED=""
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        for pattern in "${FILE_PATTERNS[@]}"; do
            # Convert glob pattern to regex
            regex_pattern=$(echo "$pattern" | sed 's/\*/.*/')
            if [[ "$file" =~ $regex_pattern ]]; then
                PATTERN_FILTERED="${PATTERN_FILTERED}${file}"$'\n'
                break
            fi
        done
    done <<< "$ALL_FILES"
    ALL_FILES="$PATTERN_FILTERED"
fi

# Output changed files summary
echo "=== CHANGED FILES ==="
if [ -z "$ALL_FILES" ]; then
    echo "No files match the specified criteria"
else
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        FILE_INFO=$(echo "$PR_INFO" | jq -r --arg path "$file" '.files[] | select(.path == $path) | "\(.changeType): \(.path) (+\(.additions)/-\(.deletions))"')
        echo "$FILE_INFO"
    done <<< "$ALL_FILES"
fi
echo ""

# If summary only, stop here
if [ "$SUMMARY_ONLY" = true ]; then
    echo "=== SUMMARY MODE ==="
    echo "Use this information to decide review strategy:"
    echo "  - Small PR (<500 lines): Fetch full diff for comprehensive review"
    echo "  - Medium PR (500-2000 lines): Prioritized review with --files flag"
    echo "  - Large PR (>2000 lines): Use /parallel for chunked review"
    echo ""
    exit 0
fi

# Get the diff (filtered if patterns specified)
echo "=== DIFF ==="
if [ -z "$ALL_FILES" ]; then
    echo "No files to diff"
elif [ ${#FILE_PATTERNS[@]} -eq 0 ] && [ "$SKIP_GENERATED" = false ]; then
    # No filtering needed, get full diff
    gh pr diff $PR_NUMBER --repo $PR_REPO || {
        echo "ERROR: Could not fetch diff" >&2
        exit 1
    }
else
    # Need to filter - get full diff and extract only matching files
    FULL_DIFF=$(gh pr diff $PR_NUMBER --repo $PR_REPO 2>/dev/null)
    if [ -z "$FULL_DIFF" ]; then
        echo "ERROR: Could not fetch diff" >&2
        exit 1
    fi
    
    # Parse and filter the diff
    CURRENT_FILE=""
    IN_MATCHING_FILE=false
    while IFS= read -r line; do
        # Check if this is a diff header for a new file
        if [[ "$line" =~ ^diff\ --git\ a/(.*)\ b/(.*) ]]; then
            FILE_PATH="${BASH_REMATCH[2]}"
            # Check if this file is in our filtered list
            if echo "$ALL_FILES" | grep -q "^$FILE_PATH$"; then
                IN_MATCHING_FILE=true
                echo "$line"
            else
                IN_MATCHING_FILE=false
            fi
        elif [ "$IN_MATCHING_FILE" = true ]; then
            echo "$line"
        fi
    done <<< "$FULL_DIFF"
fi
echo ""

# Get existing comments to avoid duplicate feedback
echo "=== EXISTING REVIEW COMMENTS ==="
gh pr view $PR_NUMBER --repo $PR_REPO --comments --json comments --jq '.comments[] | "[\(.author.login)]: \(.body)"' 2>/dev/null || echo "No existing comments"
echo ""

# Get review status
echo "=== REVIEW STATUS ==="
gh pr view $PR_NUMBER --repo $PR_REPO --json reviews --jq '.reviews[] | "\(.author.login): \(.state)"' 2>/dev/null || echo "No reviews yet"
echo ""

# Get GitHub Actions check runs status
echo "=== GITHUB ACTIONS STATUS ==="
CHECK_RUNS=$(gh pr checks $PR_NUMBER --repo $PR_REPO --json name,state,link 2>/dev/null || echo "[]")
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
        # Extract run ID and job ID from URL
        if [[ "$CHECK_URL" =~ /actions/runs/([0-9]+)/job/([0-9]+) ]]; then
            RUN_ID="${BASH_REMATCH[1]}"
            JOB_ID="${BASH_REMATCH[2]}"
            echo "=== Failed Check: $CHECK_URL ==="
            gh run view $RUN_ID --repo $PR_REPO --json jobs --jq ".jobs[] | select(.databaseId == $JOB_ID) | \"Job: \(.name)\nConclusion: \(.conclusion)\nSteps:\n\(.steps[] | \"  - \(.name): \(.conclusion)\")\"" 2>/dev/null || echo "Could not fetch run details"
            echo ""
        fi
    done
fi
