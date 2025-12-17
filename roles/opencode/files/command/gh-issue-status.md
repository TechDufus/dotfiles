---
description: "Analyze GitHub issue hierarchy and provide status report: /gh-issue-status <issue> [--comment] [--update-body]"
---

# /gh-issue-status

Analyzes GitHub issue hierarchies (EPICs, Stories, Tasks) to provide comprehensive status reports with optional issue updates.

## Usage

```bash
/gh-issue-status <issue-reference> [options]
```

## Issue Reference Formats

- `123` - Issue in current repository
- `#123` - Issue in current repository
- `org/repo#123` - Issue in specific repository
- `https://github.com/org/repo/issues/123` - Full issue URL

## Options

- `--comment` - Post the status report as a comment on the issue
- `--update-body` - Update the issue body with current status
- `--depth <N>` - Maximum traversal depth (default: 10)
- `--format <type>` - Output format: summary, detailed, or tree (default: summary)

## Examples

### Basic Status Check

```bash
# Get status overview of an EPIC
/gh-issue-status 457

# Check status with full URL
/gh-issue-status https://github.com/owner/repo/issues/457

# Cross-repository issue
/gh-issue-status "org/repo#123"
```

### Post Status as Comment

```bash
# Add status report as a comment on the issue
/gh-issue-status 457 --comment

# This will post a formatted status update showing:
# - Overall completion percentage
# - Sub-issue breakdown by type and state
# - Blockers and risks
# - Recent activity summary
```

### Update Issue Body

```bash
# Update the issue description with current status
/gh-issue-status 457 --update-body

# This will:
# - Preserve existing content
# - Update/add a "Status" section
# - Include completion metrics
# - List all sub-issues with their states
```

## What This Command Does

When you run `/gh-issue-status`, I will:

1. **Fetch Issue Hierarchy** - Get the complete parent/sub-issue tree with all URLs

2. **Launch Parallel Analysis Agents** - For each top-level sub-issue:
   - Deploy a specialized agent to read the issue and all comments
   - Analyze nested sub-issues within that branch
   - Extract key information (blockers, progress, risks)
   - Identify dependencies and cross-references
   - Return a comprehensive analysis

3. **Deep Content Analysis** (via parallel agents):
   - **Issue Bodies**: Full text of each issue description
   - **Comments**: All discussion and updates
   - **Timeline**: Recent activity and state changes
   - **Blockers**: Issues mentioned as blocking
   - **Dependencies**: Cross-referenced issues
   - **Technical Details**: Implementation notes, code references

4. **Aggregate and Synthesize**:
   - Combine reports from all parallel agents
   - Identify patterns across sub-issues
   - Detect systemic blockers or risks
   - Calculate accurate completion metrics
   - Generate actionable recommendations

5. **Generate Comprehensive Report** including:
   - **Executive Summary**: Synthesized from all agent analyses
   - **Detailed Status**: Per sub-issue summaries from agents
   - **Risk Matrix**: Aggregated blockers and concerns
   - **Technical Progress**: Implementation details
   - **Next Actions**: Prioritized based on dependencies

## Status Report Format

### Summary Format (default)
```
📊 EPIC Status: [EPIC Title]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Overall Progress: ████████░░ 75% (6/8 complete)

📈 Breakdown by Type:
• Stories: 2/3 complete (67%)
• Tasks: 4/5 complete (80%)
• Bugs: 0/0

🔍 Key Insights (from parallel agent analysis):
• Blocker: API authentication not configured (#29)
• Risk: Authentication integration delayed, impacts timeline (#33)
• Progress: Infrastructure deployment fully operational
• Dependency: #340 blocked by #29 completion

⚠️ Critical Path: 2 issues blocking production
✅ Recent Activity: 3 issues resolved this week
🎯 Next Actions: Complete auth configuration

View full analysis below...
```

### Detailed Format (with Agent Analysis)
Each top-level sub-issue includes:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📌 #13: End-to-End Validation [OPEN]
Agent Analysis Summary:
• Status: 0/3 sub-tasks complete
• Blocker: Waiting on API keys from external team
• Recent: Discussion on auth approach (2 days ago)
• Risk: No assigned developer for #340
• Dependencies: Blocks production go-live
• Technical Notes:
  - SAML configuration needed
  - API gateway routes not configured
  - Missing integration tests

Sub-tasks:
  └─ #29: Configure API auth [OPEN] - blocked
  └─ #33: CAC authentication [OPEN] - in design
  └─ #340: LLM connectivity [OPEN] - not started
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Tree Format (Enhanced)
Visual hierarchy with agent insights:
```
🟢 #457 [Epic]: Main Deployment (87% - 1 blocker)
   ├── 🔴 #8 [Story]: Platform Setup ✅ COMPLETE
   │   └── All 8 tasks done, system operational
   ├── 🔴 #496 [Story]: Security Remediation ⚠️ PARTIAL
   │   └── High severity fixed, medium pending
   └── 🟢 #13 [Task]: E2E Validation 🚨 BLOCKED
       ├── #29: API keys needed from customer
       ├── #33: Auth design in review
       └── #340: Depends on #29 completion
```

## Comment Posting

When using `--comment`, the status report will be posted with:
- Timestamp of analysis
- Clear formatting with markdown
- Collapsible sections for detailed data
- @mentions for assignees of blocked items
- Action items clearly highlighted

## Body Updates

When using `--update-body`, the issue body will be updated to:
- Include a `## Current Status` section
- Show last updated timestamp
- Display key metrics prominently
- List all sub-issues with checkboxes
- Preserve all other content

## Advanced Features

### Custom Analysis Instructions

You can provide specific analysis instructions:

```bash
# Focus on security-related tasks
/gh-issue-status 457 "Focus on security CVE remediation progress"

# Analyze timeline risks
/gh-issue-status 457 "Check if we're on track for the August 22 deadline"

# Generate executive summary
/gh-issue-status 457 "Create a brief summary for leadership review" --comment
```

### Filtering and Grouping

```bash
# Only show incomplete items
/gh-issue-status 457 "Show only open issues grouped by assignee"

# Focus on specific labels
/gh-issue-status 457 "Status of issues labeled 'critical' or 'blocker'"
```

## Implementation

I'll orchestrate a comprehensive analysis using parallel agents:

```bash
# Step 1: Parse issue reference and convert to full URL
# - 123 -> https://github.com/<current-repo>/issues/123
# - #123 -> https://github.com/<current-repo>/issues/123
# - owner/repo#123 -> https://github.com/owner/repo/issues/123
# - Full URL -> use as-is

# Step 2: Fetch complete issue hierarchy
~/.claude/scripts/gh-issue-hierarchy.sh "https://github.com/owner/repo/issues/123" --format json

# Step 3: Launch parallel agents for each top-level sub-issue
# Each agent receives:
# - The sub-issue URL and its nested hierarchy
# - Instructions to read issue body, all comments, and nested issues
# - Analysis requirements (blockers, progress, risks, dependencies)

# Step 4: Aggregate results from all agents
# Synthesize comprehensive status report

# Step 5: Optional actions
# If --comment is specified
gh issue comment <number> --repo <repo> --body "<comprehensive-report>"

# If --update-body is specified
gh issue edit <number> --repo <repo> --body "<updated-body>"
```

### Parallel Agent Analysis Process

1. **Issue Hierarchy Mapping**
   - Parse hierarchy JSON to extract all issue URLs
   - Group by top-level sub-issues
   - Prepare agent task specifications

2. **Parallel Agent Deployment**
   - Launch one agent per top-level sub-issue
   - Each agent performs:
     - Read issue body via `gh issue view`
     - Read all comments via `gh issue view --comments`
     - Analyze nested sub-issues recursively
     - Extract technical details, blockers, dependencies
     - Assess completion status and risks
     - Generate detailed analysis report

3. **Analysis Aggregation**
   - Collect reports from all parallel agents
   - Identify cross-cutting themes
   - Detect inter-issue dependencies
   - Calculate overall metrics
   - Prioritize blockers and risks

4. **Report Synthesis**
   - Combine agent analyses into cohesive report
   - Generate executive summary
   - Create actionable recommendations
   - Format according to specified output style

5. **Optional Actions**
   - Post synthesized report as comment
   - Update issue body with current status
   - Include agent-discovered insights

## Script Location

`~/.claude/scripts/gh-issue-hierarchy.sh`

## Environment Variables

- `GITHUB_REPOSITORY`: Override auto-detected repository (format: owner/repo)

## Notes

- Large hierarchies (50+ issues) may take 10-15 seconds to analyze
- Cross-repository issues require appropriate access permissions
- Comment posting requires write access to the repository
- Body updates preserve existing content outside the status section

**Important:** Always quote references containing `#`:
- ✅ `/gh-issue-status "org/repo#123"`
- ❌ `/gh-issue-status org/repo#123` (# treated as comment)