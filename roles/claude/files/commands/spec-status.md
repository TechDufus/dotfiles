---
description: "Check comprehensive status and metrics of spec-driven features: /spec-status [feature-name|all] [--format json|timeline|burndown]"
---

# Spec Status & Progress Tracking

## Query: $ARGUMENTS

Display real-time status, progress metrics, and actionable insights for spec-driven development using SPARC methodology.

## Process

### Phase 1: Context Loading

1. **Check SPECS Infrastructure**
   ```python
   if not exists("SPECS/"):
       display_no_specs_message()
       suggest_initialization()
       exit()

   # Load global metrics
   global_metrics = load("SPECS/.sparc/metrics.json")
   active_features = scan_dir("SPECS/active/")
   completed_features = scan_dir("SPECS/completed/")
   ```

2. **Parse Arguments & Options**
   ```python
   target = parse_target()  # feature-name, "all", or wildcard
   format = parse_format()  # json, timeline, burndown, dashboard
   filters = parse_filters()  # blocked, at-risk, overdue
   detail_level = parse_detail()  # summary, standard, detailed
   ```

### Phase 2: Feature Status Report

3. **For Specific Feature**
   Load comprehensive state from `SPECS/active/{feature-name}/`:

   ```
   ═══════════════════════════════════════════════════════════
   📋 Feature: {feature-name}
   ═══════════════════════════════════════════════════════════

   📊 SPARC Phase Progress:
   ├─ S: Specification  ████████████████████ 100% ✅ (2.5 hrs)
   ├─ P: Pseudocode    ████████████████████ 100% ✅ (1.5 hrs)
   ├─ A: Architecture  ████████████████████ 100% ✅ (3.0 hrs)
   ├─ R: Refinement    ████████░░░░░░░░░░░░  40% 🔄 (1.2/3 hrs)
   └─ C: Completion    ░░░░░░░░░░░░░░░░░░░░   0% ⬜ (0/2 hrs)

   📍 Current Status:
   Phase: Refinement (iteration 2 of 3)
   Task: "Optimizing query performance"
   Started: 45 minutes ago
   Velocity: 1.2x estimated pace

   🎯 Key Metrics:
   ├─ Overall Progress: 72% complete
   ├─ Time Investment: 8.2 hours (estimated: 12 hours)
   ├─ Efficiency Score: 8.5/10
   ├─ Quality Score: 9.2/10
   └─ Risk Level: Low 🟢

   📈 Velocity Tracking:
   Week 1: ████████ 8 tasks/day
   Week 2: ██████████ 10 tasks/day (current)
   Trend: ↑ Accelerating

   🔄 Active Checkpoints:
   Latest: checkpoint-2024-01-15-16-45-00 [STABLE]
   Previous: checkpoint-2024-01-15-14-30-00
   Rollback Available: Yes

   ✅ Validation Gates (Last Run: 15 min ago):
   ├─ Syntax/Lint:     ✅ Passing
   ├─ Type Safety:     ✅ No errors
   ├─ Unit Tests:      ✅ 47/47 passing (92% coverage)
   ├─ Integration:     ✅ 12/12 passing
   ├─ Performance:     ⚠️  p99 @ 105ms (target: <100ms)
   └─ Security:        ✅ No vulnerabilities

   📝 Recent Decisions & Rationale:
   1. "Switched to connection pooling" - Reduced latency by 40%
   2. "Added Redis caching layer" - Improved throughput 3x
   3. "Refactored auth middleware" - Simplified code, better tests

   🚧 Blockers & Risks:
   ├─ None currently active
   └─ Resolved (2): Database connection limits, API rate limiting

   📋 Next Actions:
   1. [IN PROGRESS] Optimize database queries
   2. [QUEUED] Add request caching
   3. [QUEUED] Update performance benchmarks
   4. [PLANNED] Run load tests

   💡 AI Insights:
   • Performance bottleneck identified in user lookup
   • Consider index on users.email field
   • Test coverage exceeds target - good job!
   • Ready for completion phase after performance fix
   ```

4. **For All Features Dashboard**
   Show comprehensive overview:

   ```
   ═══════════════════════════════════════════════════════════
   📊 SPECS Portfolio Dashboard
   ═══════════════════════════════════════════════════════════

   🔄 Active Features (4):
   ┌──────────────────┬────────────────┬──────────┬──────────┐
   │ Feature          │ SPARC Progress │ Time     │ Health   │
   ├──────────────────┼────────────────┼──────────┼──────────┤
   │ api-auth         │ S✅P✅A✅R🔄C⬜ │ 8.2/12h  │ 🟢 Good  │
   │ ui-dashboard     │ S✅P✅A🔄R⬜C⬜ │ 4.5/15h  │ 🟢 Good  │
   │ data-migration   │ S✅P✅A✅R✅C🔄 │ 18/20h   │ 🟡 At Risk│
   │ cli-tool         │ S✅P🔄A⬜R⬜C⬜ │ 2.1/10h  │ 🟢 Good  │
   └──────────────────┴────────────────┴──────────┴──────────┘

   📈 Portfolio Metrics:
   ├─ Total Active Tasks: 67 (41 completed, 26 remaining)
   ├─ Weekly Velocity: 18.5 tasks/week (↑12% from last week)
   ├─ Average Cycle Time: 4.8 days per feature
   ├─ Success Rate: 94% (16/17 features delivered)
   └─ Team Efficiency: 87% (actual vs estimated time)

   🏆 Recently Completed (This Week):
   ✅ payment-integration - 3 days ago (12 hours, exceeded targets)
   ✅ notification-system - 5 days ago (8 hours, on schedule)

   ⚠️ Attention Required:
   • data-migration: Performance gate failing (p99 > 200ms)
   • ui-dashboard: Waiting for design review (blocked 2 hours)

   📅 Upcoming Milestones:
   • api-auth: Ready for completion tomorrow
   • cli-tool: Architecture review scheduled
   • Q1 Target: 8 features (on track)
   ```

### Phase 3: Advanced Visualizations

5. **Timeline View** (`--format timeline`)
   ```
   📅 Feature Timeline (January 2024)

   Week 1  │███████████░░░░░░░│ api-auth
   Week 2  │░░░████████████░░░│ ui-dashboard
   Week 3  │░░░░░░███████████░│ data-migration
   Week 4  │░░░░░░░░░░████████│ cli-tool
           └──────────────────┘
            S  P  A  R  C     (SPARC Phases)
   ```

6. **Burndown Chart** (`--format burndown`)
   ```
   📉 Sprint Burndown

   100 │\
    80 │ \___
    60 │     \___
    40 │         \___ideal
    20 │             ●---actual
     0 │________________\●
       M  T  W  T  F  S  S

   Remaining: 26 tasks
   Burn rate: 4.2 tasks/day
   Projected completion: Thursday
   ```

### Phase 4: Analytics & Insights

7. **Pattern Recognition**
   ```python
   insights = {
       "bottlenecks": identify_common_blockers(),
       "estimation_accuracy": calculate_estimation_variance(),
       "phase_efficiency": analyze_phase_durations(),
       "validation_failures": track_gate_failure_patterns(),
       "rollback_frequency": analyze_checkpoint_usage()
   }
   ```

8. **Predictive Analytics**
   ```
   🔮 Predictions & Recommendations:
   • api-auth likely to complete 2 hours early
   • data-migration at risk of delay (recommend adding resources)
   • Consider parallelizing ui-dashboard tasks 3 & 4
   • Historical pattern suggests Friday deployments have 30% more issues
   ```

## Status Indicators

- 🟢 **Healthy**: On track, no blockers
- 🟡 **At Risk**: Behind schedule or has warnings
- 🔴 **Critical**: Blocked or failing gates
- 🔄 **In Progress**: Active development
- ✅ **Complete**: All gates passed
- ⬜ **Not Started**: Waiting to begin
- ⏸️ **On Hold**: Paused by decision

## Command Options

```bash
# View specific feature
/spec-status api-auth

# View all features
/spec-status all

# Filter views
/spec-status all --blocked
/spec-status all --at-risk
/spec-status * --format json

# Visualizations
/spec-status all --format timeline
/spec-status api-auth --format burndown
/spec-status all --format dashboard

# Detail levels
/spec-status api-auth --detailed
/spec-status all --summary
```

## Output Formats

- **Dashboard** (default): Rich terminal UI with tables and charts
- **JSON**: Machine-readable for automation
- **Timeline**: Gantt-style phase visualization
- **Burndown**: Sprint progress tracking
- **CSV**: Export for spreadsheet analysis

## Actionable Insights

Always provide:
- **What needs immediate attention** (blockers, failures)
- **Optimization opportunities** (parallelization, resource allocation)
- **Risk mitigation suggestions** (based on patterns)
- **Next best actions** (prioritized task list)
- **Celebration moments** (milestones achieved)