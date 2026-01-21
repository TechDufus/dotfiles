#!/usr/bin/env bash

# GitHub Issue Hierarchy Helper Script
# Purpose: Traverse GitHub issue parent/sub-issue relationships and return structured JSON
# Usage: gh-issue-hierarchy.sh <issue-url-or-number> [--format json|yaml|tree] [--depth N]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FORMAT="json"
MAX_DEPTH=10
REPO=""
OWNER=""

# Function to print error and exit
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to print info
info() {
    echo -e "${BLUE}ℹ $1${NC}" >&2
}

# Function to print success
success() {
    echo -e "${GREEN}✓ $1${NC}" >&2
}

# Parse command line arguments
parse_args() {
    if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        cat <<EOF
Usage: $(basename "$0") <issue-url> [options]

Options:
    --format <json|yaml|tree|agents>  Output format (default: json)
    --depth <N>                        Maximum traversal depth (default: 10)
    --help                             Show this help message

Example:
    $(basename "$0") https://github.com/owner/repo/issues/123
    $(basename "$0") https://github.com/owner/repo/issues/123 --format tree
    $(basename "$0") https://github.com/owner/repo/issues/123 --format yaml --depth 5
EOF
        exit 0
    fi

    local issue_input="$1"
    shift

    # Parse optional arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --depth)
                MAX_DEPTH="$2"
                shift 2
                ;;
            --help)
                "$0"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done

    # Parse issue input - expecting full GitHub URL
    if [[ "$issue_input" =~ ^https://github.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        ISSUE_NUMBER="${BASH_REMATCH[3]}"
    else
        error "Invalid issue URL format. Expected: https://github.com/owner/repo/issues/123"
    fi
}

# Check prerequisites
check_prerequisites() {
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) is required. Install it with: brew install gh"
    fi

    if ! command -v jq &> /dev/null; then
        error "jq is required. Install it with: brew install jq"
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        error "Not authenticated with GitHub. Run: gh auth login"
    fi
}

# Fetch issue data using REST API
fetch_issue_data() {
    local owner="$1"
    local repo="$2"
    local number="$3"
    
    gh api "repos/${owner}/${repo}/issues/${number}" 2>/dev/null || echo "{}"
}

# Fetch sub-issues using REST API
fetch_sub_issues() {
    local owner="$1"
    local repo="$2"
    local number="$3"
    
    gh api "repos/${owner}/${repo}/issues/${number}/sub_issues" 2>/dev/null || echo "[]"
}

# Recursively build issue hierarchy
build_hierarchy() {
    local owner="$1"
    local repo="$2"
    local number="$3"
    local depth="$4"
    local visited="$5"
    
    # Check if we've already visited this issue (prevent cycles)
    local issue_key="${owner}/${repo}#${number}"
    if [[ " $visited " == *" $issue_key "* ]]; then
        echo '{"cycle": true, "issue": "'$issue_key'"}'
        return
    fi
    visited="$visited $issue_key"
    
    # Check depth limit
    if [[ $depth -ge $MAX_DEPTH ]]; then
        echo '{"depth_limit_reached": true}'
        return
    fi
    
    info "Fetching $issue_key (depth: $depth)"
    
    # Fetch the main issue data
    local issue_data
    issue_data=$(fetch_issue_data "$owner" "$repo" "$number")
    
    if [[ -z "$issue_data" ]] || [[ "$issue_data" == "{}" ]]; then
        echo '{"error": "Failed to fetch issue"}'
        return
    fi
    
    # Build minimal hierarchy object - just structure and URLs for agents
    local hierarchy
    hierarchy=$(echo "$issue_data" | jq '{
        number: .number,
        title: .title,
        url: .html_url,
        repo: "'$repo'",
        owner: "'$owner'",
        sub_issues: []
    }')
    
    # Fetch sub-issues
    local sub_issues_data
    sub_issues_data=$(fetch_sub_issues "$owner" "$repo" "$number")
    
    if [[ "$sub_issues_data" != "[]" ]] && [[ -n "$sub_issues_data" ]]; then
        local sub_hierarchies="[]"
        
        # Process each sub-issue
        local sub_issues_array
        sub_issues_array=$(echo "$sub_issues_data" | jq -c '.[]' 2>/dev/null || echo "")
        
        if [[ -n "$sub_issues_array" ]]; then
            while IFS= read -r sub_issue_json; do
                if [[ -z "$sub_issue_json" ]]; then
                    continue
                fi
                
                # Extract repository info from the sub-issue URL
                local sub_url
                sub_url=$(echo "$sub_issue_json" | jq -r '.html_url // ""')
                
                if [[ "$sub_url" =~ ^https://github.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
                    local sub_owner="${BASH_REMATCH[1]}"
                    local sub_repo="${BASH_REMATCH[2]}"
                    local sub_number="${BASH_REMATCH[3]}"
                    
                    # Recursively fetch sub-issue hierarchy
                    local sub_hierarchy
                    sub_hierarchy=$(build_hierarchy "$sub_owner" "$sub_repo" "$sub_number" $((depth + 1)) "$visited")
                    
                    sub_hierarchies=$(echo "$sub_hierarchies" | jq ". + [$sub_hierarchy]")
                fi
            done <<< "$sub_issues_array"
        fi
        
        hierarchy=$(echo "$hierarchy" | jq ".sub_issues = $sub_hierarchies")
    fi
    
    echo "$hierarchy"
}

# Convert JSON to YAML (basic implementation)
json_to_yaml() {
    # For proper YAML conversion, we'd need yq
    if command -v yq &> /dev/null; then
        yq -P '.'
    else
        info "yq not found, outputting JSON with YAML header"
        echo "---"
        cat
    fi
}

# Convert JSON to tree format (simplified)
json_to_tree() {
    local json="$1"
    local indent="${2:-}"
    
    local number title url
    number=$(echo "$json" | jq -r '.number // "N/A"')
    title=$(echo "$json" | jq -r '.title // "No title"')
    url=$(echo "$json" | jq -r '.url // "No URL"')
    
    echo "${indent}#${number}: ${title}"
    echo "${indent}   ${url}"
    
    # Process sub-issues
    local sub_issues
    sub_issues=$(echo "$json" | jq -c '.sub_issues[]?' 2>/dev/null)
    
    if [[ -n "$sub_issues" ]]; then
        local count=0
        local total_subs
        total_subs=$(echo "$json" | jq '.sub_issues | length')
        
        while IFS= read -r sub_issue; do
            if [[ -n "$sub_issue" ]]; then
                count=$((count + 1))
                if [[ $count -eq $total_subs ]]; then
                    json_to_tree "$sub_issue" "${indent}   └── "
                else
                    json_to_tree "$sub_issue" "${indent}   ├── "
                fi
            fi
        done <<< "$sub_issues"
    fi
}

# Main execution
main() {
    parse_args "$@"
    check_prerequisites
    
    info "Fetching hierarchy for ${OWNER}/${REPO}#${ISSUE_NUMBER}"
    
    # Build the hierarchy
    local hierarchy
    hierarchy=$(build_hierarchy "$OWNER" "$REPO" "$ISSUE_NUMBER" 0 "")
    
    # Output in requested format
    case "$OUTPUT_FORMAT" in
        json)
            echo "$hierarchy" | jq '.'
            ;;
        yaml)
            echo "$hierarchy" | json_to_yaml
            ;;
        tree)
            success "Issue Hierarchy:"
            echo
            json_to_tree "$hierarchy"
            ;;
        agents)
            # Output format optimized for agent deployment
            echo "$hierarchy" | jq '{
                main_issue: {
                    number: .number,
                    title: .title,
                    url: .url,
                    repo: .repo,
                    owner: .owner
                },
                top_level_count: (.sub_issues | length),
                top_level_issues: .sub_issues | map({
                    number: .number,
                    title: .title,
                    url: .url,
                    repo: .repo,
                    owner: .owner,
                    nested_count: (.sub_issues | length),
                    nested_urls: [.sub_issues[].url]
                })
            }'
            ;;
        *)
            error "Unknown output format: $OUTPUT_FORMAT"
            ;;
    esac
    
    success "Hierarchy traversal complete"
}

# Run main function
main "$@"