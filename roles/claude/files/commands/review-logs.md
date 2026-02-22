---
description: "Analyze Claude logs for improvement patterns: /review-logs [--days N] [--apply]"
argument-hint: "[--days N] [--apply]"
allowed-tools:
  - Bash(find:*)
  - Bash(ls:*)
  - Read
  - Edit
  - Grep
---

# /review-logs - Self-Improving Flywheel

Mine Claude Code conversation logs for recurring patterns, then suggest (or apply) AGENTS.md improvements.

## Usage

```
/review-logs                  # Analyze last 7 days, suggest improvements
/review-logs --days 30        # Analyze last 30 days
/review-logs --apply          # Automatically apply suggestions to AGENTS.md
```

## Arguments: $ARGUMENTS

---

## Philosophy

**The Flywheel**:
1. Work with Claude → Logs generated
2. Analyze logs → Find recurring issues
3. Update AGENTS.md → Better guidance
4. Better behavior → Fewer issues
5. Repeat

**Goal**: Each review cycle makes Claude smarter for YOUR specific workflows.

---

## Phase 1: Gather Log Data

First, identify available logs:

```bash
# Find all project log directories
find ~/.claude/projects -type d -name "logs" 2>/dev/null

# Count logs by age (default: 7 days, or --days N)
find ~/.claude/projects -name "*.jsonl" -mtime -{days} 2>/dev/null | wc -l
```

If no logs found, report and exit:
> "No Claude Code logs found in ~/.claude/projects/. Logs are generated during Claude Code sessions."

---

## Phase 2: Parallel Pattern Analysis

Launch THREE analysis subagents simultaneously:

### Subagent 1: Error Pattern Analyzer

```
Task(
  subagent_type: "general-purpose",
  description: "Analyze error patterns in logs",
  prompt: """
  Analyze Claude Code logs for ERROR patterns.

  <commands>
  Search logs from the last {days} days:
  1. `find ~/.claude/projects -name "*.jsonl" -mtime -{days} -exec grep -l -i "error\|exception\|failed\|traceback" {} \;`
  2. For each file found (limit 10), extract error context:
     `grep -i "error\|exception\|failed" <file> | head -20`
  </commands>

  <analysis>
  Identify:
  - Repeated error messages (same error 2+ times)
  - Error categories (tool errors, permission errors, syntax errors, etc.)
  - Root causes if apparent
  - Which projects/contexts trigger these errors
  </analysis>

  <output_format>
  Return:
  <error_analysis>
    <pattern name="..." frequency="N">
      <description>What keeps happening</description>
      <example>Actual error text</example>
      <suggested_fix>AGENTS.md addition to prevent this</suggested_fix>
    </pattern>
    ...
  </error_analysis>
  </output_format>
  """
)
```

### Subagent 2: Correction Pattern Analyzer

```
Task(
  subagent_type: "general-purpose",
  description: "Analyze user corrections in logs",
  prompt: """
  Analyze Claude Code logs for USER CORRECTION patterns.

  <commands>
  Search logs from the last {days} days for correction indicators:
  1. `find ~/.claude/projects -name "*.jsonl" -mtime -{days} -exec grep -l -i "no,\|actually\|instead\|wrong\|don't\|shouldn't\|not that\|I meant" {} \;`
  2. For each file found (limit 10), extract correction context:
     `grep -B2 -A2 -i "no,\|actually\|instead\|wrong" <file> | head -30`
  </commands>

  <analysis>
  Identify:
  - What Claude did wrong that user corrected
  - Patterns in corrections (same type of mistake repeated)
  - Preferences being expressed ("use X not Y")
  - Context that triggers wrong behavior
  </analysis>

  <output_format>
  Return:
  <correction_analysis>
    <pattern name="..." frequency="N">
      <wrong_behavior>What Claude kept doing</wrong_behavior>
      <correct_behavior>What user wanted instead</correct_behavior>
      <suggested_fix>AGENTS.md addition to encode this preference</suggested_fix>
    </pattern>
    ...
  </correction_analysis>
  </output_format>
  """
)
```

### Subagent 3: Workflow Inefficiency Analyzer

```
Task(
  subagent_type: "general-purpose",
  description: "Analyze workflow inefficiencies",
  prompt: """
  Analyze Claude Code logs for WORKFLOW INEFFICIENCY patterns.

  <commands>
  Search logs from the last {days} days:
  1. Permission denials: `grep -r "denied\|rejected\|not allowed" ~/.claude/projects/*/logs/*.jsonl 2>/dev/null | head -20`
  2. Repeated tool calls: `grep -r "tool_use" ~/.claude/projects/*/logs/*.jsonl 2>/dev/null | cut -d'"' -f4 | sort | uniq -c | sort -rn | head -10`
  3. Long conversations: `find ~/.claude/projects -name "*.jsonl" -mtime -{days} -size +100k 2>/dev/null`
  </commands>

  <analysis>
  Identify:
  - Frequently denied permissions (should they be pre-approved?)
  - Tools used repeatedly in sequence (could be a slash command?)
  - Very long conversations (context management issue?)
  - Repeated file reads (should be in AGENTS.md context?)
  </analysis>

  <output_format>
  Return:
  <workflow_analysis>
    <pattern name="..." frequency="N">
      <inefficiency>What's happening</inefficiency>
      <impact>Time/tokens wasted</impact>
      <suggested_fix>How to optimize (AGENTS.md, settings.json, or new command)</suggested_fix>
    </pattern>
    ...
  </workflow_analysis>
  </output_format>
  """
)
```

---

## Phase 3: Synthesize Findings

After all subagents return, create a unified improvement report:

```markdown
# Log Analysis Report

**Period**: Last {days} days
**Logs analyzed**: {count}
**Patterns found**: {total_patterns}

## High-Priority Improvements

### Errors to Prevent
{From Subagent 1 - patterns with frequency >= 2}

| Pattern | Frequency | Suggested AGENTS.md Addition |
|---------|-----------|------------------------------|
| ...     | ...       | ...                          |

### Preferences to Encode
{From Subagent 2 - repeated corrections}

| Wrong Behavior | Correct Behavior | Suggested Addition |
|----------------|------------------|-------------------|
| ...            | ...              | ...               |

### Workflow Optimizations
{From Subagent 3 - inefficiencies}

| Inefficiency | Impact | Fix Type | Suggestion |
|--------------|--------|----------|------------|
| ...          | ...    | AGENTS.md / settings.json / new command | ... |

## Suggested AGENTS.md Additions

Based on analysis, add these to your AGENTS.md:

```markdown
## Learned from Log Analysis ({date})

### Error Prevention
- {suggestion 1}
- {suggestion 2}

### Preferences
- {preference 1}
- {preference 2}

### Workflow Notes
- {note 1}
```

## Settings.json Suggestions
{If any permission pre-approvals recommended}

## New Command Ideas
{If any repeated workflows could become commands}
```

---

## Phase 4: Apply (if --apply flag)

If `--apply` flag provided:

1. Read current `~/.claude/AGENTS.md`
2. Append new section under `## Learned Patterns`:
   ```markdown
   ### {date} - Log Analysis
   - Errors: {summary}
   - Preferences: {summary}
   - Optimizations: {summary}
   ```
3. Write updated file
4. Report what was added

If `--apply` NOT provided:
- Display suggestions only
- Prompt: "Run `/review-logs --apply` to add these to AGENTS.md"

---

## Example Output

```markdown
# Log Analysis Report

**Period**: Last 7 days
**Logs analyzed**: 23
**Patterns found**: 5

## High-Priority Improvements

### Errors to Prevent

| Pattern | Frequency | Suggested AGENTS.md Addition |
|---------|-----------|------------------------------|
| Ansible lint failures on `command` module | 3 | "Prefer ansible.builtin modules over command/shell" |
| Git commit with unstaged changes | 2 | "Always run git status before git commit" |

### Preferences to Encode

| Wrong Behavior | Correct Behavior | Suggested Addition |
|----------------|------------------|-------------------|
| Created README.md | User deleted it | "No README.md unless explicitly requested" ✓ (already in AGENTS.md) |
| Used `cat` to read files | User said "use Read tool" | "Use Read tool instead of cat for file contents" |

### Workflow Optimizations

| Inefficiency | Impact | Fix Type | Suggestion |
|--------------|--------|----------|------------|
| Repeated `gh pr view` calls | 5 calls/session | AGENTS.md | "Cache PR info in session, don't re-fetch" |
| Permission denied: sudo | 8 denials | Expected | Keep denied - security boundary |

## Suggested AGENTS.md Additions

```markdown
## Learned from Log Analysis (2024-01-15)

### Error Prevention
- Prefer ansible.builtin modules over command/shell to pass linting
- Always verify git status before committing

### Preferences
- Use Read tool instead of cat/head/tail for file contents
- Cache GitHub API responses within a session

### Workflow Notes
- sudo permission denials are expected - use non-root approaches
```
```

---

## Frequency Recommendation

| Cadence | When to Use |
|---------|-------------|
| Weekly | Heavy Claude Code usage, rapid iteration |
| Bi-weekly | Moderate usage, good baseline |
| Monthly | Light usage, still valuable for patterns |

---

## Privacy Note

Logs stay local. This command only reads `~/.claude/projects/` on your machine. Nothing is sent externally beyond normal Claude API usage for analysis.
