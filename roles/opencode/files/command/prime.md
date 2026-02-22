---
description: "Prime context for fresh session: /prime [task hint] [--quick] [--verbose]"
---

# /prime - Context Priming for Fresh Sessions

Rapidly build complete understanding of current work state after `/clear` or new session start. Uses parallel subagents to maximize context gathering while minimizing main context token usage.

## Usage

```
/prime                                    # Full context priming (default)
/prime <task-hint>                        # Prime with upcoming task focus
/prime --quick                            # Essential git state only (faster)
/prime --verbose                          # Include full diffs in report
```

### Examples
```
/prime                                    # General orientation
/prime migrating postgres init scripts    # Focus exploration on postgres/init
/prime reviewing PR #42                   # Pull PR context to forefront
/prime debugging auth timeout             # Look for auth-related changes
```

## Arguments: $ARGUMENTS

---

## Philosophy

**Problem**: Fresh sessions lack context about in-progress work. Manually explaining state wastes tokens and misses details.

**Solution**: Subagents explore repository state in parallel, then synthesize into a concise briefing. The main context receives only the summary, not the raw exploration data.

**Token Efficiency**: Each subagent has its own context window. Raw git diffs, PR bodies, and file contents stay in subagent contexts. Main context receives only distilled insights.

**Task-Focused Priming**: When a task hint is provided, subagents prioritize context relevant to that task.

---

## Phase -1: Parse Arguments

Parse `$ARGUMENTS` to extract:
- **Task hint**: Any non-flag text (e.g., "migrating postgres init scripts")
- **Flags**: `--quick`, `--verbose`

If task hint is provided, it will be passed to all subagents to focus their exploration.

---

## Phase 0: Quick Snapshot (Main Agent)

First, gather low-token essentials directly (no subagent needed):

```bash
# Run these commands in parallel via Bash tool:
git branch --show-current
git rev-parse --abbrev-ref HEAD@{upstream} 2>/dev/null || echo "no upstream"
git status --short --branch
git log --oneline -5
git stash list --format="%gd: %s"
```

**Parse and display immediately:**
```
## Quick Snapshot
- **Branch**: <current-branch> (tracking: <upstream-or-none>)
- **Status**: <N files changed, M staged, K untracked>
- **Recent commits**: <last 3-5 one-liners>
- **Stashes**: <count or "none">
```

If `--quick` flag provided, STOP HERE. Display snapshot and exit.

---

## Phase 1: Parallel Subagent Exploration

Launch THREE subagents simultaneously using @mentions. OpenCode will spawn each as a separate subagent context.

### Subagent 1: Git Changes Analyst

@general Analyze the current git state for this repository. TASK HINT: {task_hint or "None - do general analysis"}.

Run these git commands and analyze:
1. `git log main..HEAD --format='%h %s' 2>/dev/null || git log -10 --format='%h %s'`
2. `git diff --cached --stat` (staged changes)
3. `git diff --stat` (unstaged changes)
4. `git diff --cached` (full staged diff - summarize key changes)
5. `git diff` (full unstaged diff - summarize key changes)
6. `git stash show -p stash@{0} 2>/dev/null` (if stashes exist)
7. `git ls-files --others --exclude-standard | head -20` (untracked files)

Return a CONCISE summary (under 400 words) covering:
- **Branch commits**: What work has been done? Group by feature/fix/refactor.
- **Staged changes**: What's ready to commit?
- **Unstaged changes**: What's in progress?
- **Untracked files**: New files being created?
- **Work narrative**: 2-3 sentences on what developer is working on.
- **Task relevance** (if hint provided): Which changes relate to the hinted task?

### Subagent 2: GitHub Context Analyst

@general Gather GitHub context for this repository. TASK HINT: {task_hint or "None - do general analysis"}.

Run these gh commands:
1. `gh pr list --state open --author @me --json number,title,headRefName,isDraft,reviewDecision --limit 5`
2. `gh pr view --json number,title,state,reviews,statusCheckRollup 2>/dev/null` (current branch PR)
3. `gh issue list --assignee @me --state open --json number,title,labels --limit 10`
4. `gh run list --limit 3 --json conclusion,name,headBranch`

Return a CONCISE summary (under 300 words) covering:
- **Current PR**: Draft/ready? Review status? CI status?
- **Related issue**: If branch name contains issue number, fetch issue details
- **Other PRs**: Any other open PRs by me?
- **Open issues**: What's assigned to me?
- **Task relevance** (if hint provided): Related PRs/issues for the hinted task?

If gh CLI fails, just report "GitHub context unavailable".

### Subagent 3: Project Context Analyst

@explore Search for project context and active work markers. TASK HINT: {task_hint or "None - do general analysis"}.

Check these files (if they exist):
1. `AGENTS.md` - Look for "## Active Work" section
2. `.opencode/AGENTS.md` or `.claude/AGENTS.md` - Project instructions
3. `TODO.md` or `TODO` - Tracked tasks
4. Recent changes: `git diff --name-only HEAD~5..HEAD 2>/dev/null | head -20`

IF TASK HINT PROVIDED:
- Use Glob to find files matching task keywords
- Use Grep to search for relevant patterns
- Read key files (limit to 3-5 most relevant)
- Note file locations for later reference

Return a CONCISE summary (under 300 words) covering:
- **Active work**: From AGENTS.md tracking
- **Focus areas**: Primary directories being worked on
- **Project type**: Language, framework, available commands
- **Task exploration** (if hint): Relevant files, implementation summary, conventions

---

## Phase 2: Synthesis

After all three subagents return, synthesize into a unified briefing.

**Token Budget**: Keep synthesis under 800 tokens.

**If task hint was provided**, lead with task-relevant findings:

```markdown
# Work State Briefing

## TL;DR
<One paragraph: Current state + relevance to the hinted task>

## Task Context: {task_hint}
- **Relevant files**: <From Project Context Analyst>
- **Related changes**: <From Git Changes Analyst>
- **Associated PRs/issues**: <From GitHub Context Analyst>
- **Implementation notes**: <Key patterns, conventions discovered>

## General State
### Git
<Branch, commits, changes NOT related to task>

### GitHub
<Other PRs, issues, CI status>

### Project
<Active work tracking, focus areas>

## Suggested Next Actions
<Tailored to the hinted task>
```

**If NO task hint**, use general format:

```markdown
# Work State Briefing

## TL;DR
<One paragraph summary: What work is in progress, what state it's in, what's next>

## Git State
<From Subagent 1: Branch, commits, changes summary>

## GitHub Context
<From Subagent 2: PR status, issue linkage, CI status>

## Project Context
<From Subagent 3: Active work tracking, focus areas>

## Suggested Next Actions
<Based on all context, suggest 2-3 logical next steps>
```

---

## Mode Variations

### `--quick` Mode
- Only run Phase 0 (Quick Snapshot)
- No subagents spawned
- Minimal token usage (~100-200 tokens)
- Best for: Quick orientation, simple repos

### `--verbose` Mode
- Include actual diff content in synthesis (not just summaries)
- Higher token usage in main context
- Best for: Complex changes needing detailed review

### Default Mode (no flags)
- Full Phase 0 + Phase 1 + Phase 2
- Balanced token usage (~500-800 tokens in main context)
- Best for: Most situations

---

## Error Handling

- **Not a git repo**: Report error, suggest running from repo root
- **No gh CLI**: Skip GitHub context, note in output
- **No AGENTS.md**: Skip project context section
- **Empty branch** (no commits vs main): Focus on staged/unstaged only
- **Network issues**: Timeout GitHub calls after 10s, report partial results

---

## Integration with /work

After `/prime` completes, you can immediately run `/work <task>` to continue.
The priming context helps `/work` make better routing decisions.

Typical workflows:
```
/clear                                    # Fresh start
/prime                                    # Build context
/work continue PR #47                     # Resume with full understanding

# Or with task focus:
/clear
/prime migrating postgres init scripts    # Prime with task context
/work start migration                     # /work has full context already
```
