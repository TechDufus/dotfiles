---
description: "Check status of spec-driven features: /spec-status [feature-name|all]"
---

# Spec Status Report

## Query: $ARGUMENTS

Display status and progress of spec-driven development features.

## Process

1. **Check SPECS Directory**
   - If no SPECS directory exists, display:
     ```
     ❌ No SPECS directory found
     Run /spec-init to start your first spec-driven feature
     ```
   - Otherwise continue

2. **Parse Arguments**
   - If specific feature: show detailed status
   - If "all" or empty: show summary of all features
   - Support wildcards: "api-*"

2. **For Specific Feature**
   Load from `SPECS/active/{feature-name}/.progress.json`:
   
   ```
   📋 Feature: {feature-name}
   📅 Started: {date} ({X} days ago)
   🔄 Status: {status}
   📍 Current Phase: {phase}
   
   Progress by Phase:
   ✅ Requirements: Complete (2 days)
   ✅ Design: Complete (1 day) 
   🔵 Implementation: In Progress (60% - 12/20 tasks)
   ⬜ Testing: Not Started
   ⬜ Deployment: Not Started
   
   Current Activity:
   📝 Task: "Implement user authentication"
   ⏱️ Started: 2 hours ago
   👤 Agent: spec-builder
   
   Metrics:
   - Estimated: 24 hours | Actual: 18 hours
   - Code: +450 lines, ~120 lines
   - Tests: 15 passing, 85% coverage
   - Blockers: 2 resolved, 0 active
   
   Recent Decisions:
   1. Use JWT for auth instead of sessions
   2. PostgreSQL for user storage
   
   Next Tasks:
   1. Complete auth middleware
   2. Write auth integration tests
   3. Update API documentation
   ```

3. **For All Features**
   Show summary dashboard:
   
   ```
   📊 Spec-Driven Features Overview
   
   Active (3):
   🔵 api-auth         | Implementation  | 60% | 3 days
   🔵 ui-dashboard     | Design         | 20% | 1 day  
   🟡 data-migration   | Testing        | 85% | 5 days
   
   Completed (5):
   ✅ api-users        | Deployed       | 2 weeks ago
   ✅ cli-tool         | Deployed       | 1 month ago
   ...
   
   Summary:
   - Active Features: 3
   - Total Tasks: 45 (28 completed)
   - Avg Completion: 5.2 days
   - This Week: 12 tasks completed
   ```

4. **Status Indicators**
   - 🔵 In Progress (active work)
   - 🟡 Blocked/Waiting
   - ✅ Completed
   - ❌ Failed/Abandoned
   - ⬜ Not Started
   - ⏸️ On Hold

5. **Detailed Metrics**
   When requested with `--detailed`:
   - Time tracking analysis
   - Estimation accuracy
   - Common blockers
   - Pattern insights

## Additional Options
- `--json`: Output in JSON format
- `--detailed`: Show extensive metrics
- `--blocked`: Show only blocked items
- `--timeline`: Show Gantt-style view

## Output Format
Provide actionable insights:
- What needs attention
- Blocked items requiring input
- Features ready for next phase
- Estimation adjustments needed