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

**Task-Focused Priming**: When a task hint is provided, subagents prioritize context relevant to that task. This follows the "pyramid approach" - starting with task intent allows more targeted exploration.

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

Launch THREE subagents simultaneously (all in single message):

### Subagent 1: Git Changes Analyst

```
Task(
  subagent_type: "general-purpose",
  description: "Analyze git changes",
  prompt: """
  <task_context>
  TASK HINT: {task_hint or "None provided - do general analysis"}
  </task_context>

  Analyze the current git state. Provide a CONCISE summary (under 500 words).
  If a task hint is provided, prioritize findings relevant to that task.

  <commands>
  Run these git commands:
  1. `git log main..HEAD --format='%h %s' 2>/dev/null || git log -10 --format='%h %s'`
  2. `git diff --cached --stat` (staged changes)
  3. `git diff --stat` (unstaged changes)
  4. `git diff --cached` (full staged diff - summarize, don't echo)
  5. `git diff` (full unstaged diff - summarize, don't echo)
  6. `git stash show -p stash@{0} 2>/dev/null` (if stashes exist)
  7. `git ls-files --others --exclude-standard | head -20` (untracked files)
  </commands>

  <analysis_requirements>
  Analyze and report:
  - **Branch commits**: What work has been done? Group by feature/fix/refactor.
  - **Staged changes**: What's ready to commit? Categorize by src/test/config/docs.
  - **Unstaged changes**: What's in progress? Any incomplete patterns?
  - **Untracked files**: New files being created? What kind?
  - **Stash contents**: Any paused work?
  - **Work narrative**: 2-3 sentences on what developer is working on.

  If task hint provided, add:
  - **Task relevance**: Which changes/files relate to the hinted task?
  </analysis_requirements>

  <output_format>
  Return structured XML:
  <git_analysis>
    <branch_commits>...</branch_commits>
    <staged>...</staged>
    <unstaged>...</unstaged>
    <untracked>...</untracked>
    <stashes>...</stashes>
    <narrative>...</narrative>
    <task_relevance>...</task_relevance>  <!-- only if task hint provided -->
  </git_analysis>
  </output_format>
  """
)
```

### Subagent 2: GitHub Context Analyst

```
Task(
  subagent_type: "general-purpose",
  description: "Analyze GitHub context",
  prompt: """
  <task_context>
  TASK HINT: {task_hint or "None provided - do general analysis"}
  </task_context>

  Gather GitHub context. Provide a CONCISE summary (under 400 words).
  If task hint mentions PR/issue numbers, prioritize those.

  <commands>
  Run these gh commands:
  1. `gh pr list --state open --author @me --json number,title,headRefName,baseRefName,isDraft,updatedAt,reviewDecision --limit 5`
  2. `gh pr view --json number,title,body,state,commits,reviews,statusCheckRollup 2>/dev/null` (current branch PR)
  3. `gh issue list --assignee @me --state open --json number,title,labels,updatedAt --limit 10`
  4. `gh run list --limit 3 --json conclusion,name,updatedAt,headBranch`
  </commands>

  <analysis_requirements>
  If current branch has a PR:
  - Draft or ready for review?
  - Review feedback (approved, changes requested)?
  - CI status (passing, failing, pending)?

  If branch name contains issue number (e.g., `fix-123`, `feature/456-desc`):
  - Fetch issue: `gh issue view <number> --json title,body,labels`
  - Extract key requirements

  If task hint mentions specific PR/issue, fetch that directly.
  </analysis_requirements>

  <output_format>
  Return structured XML:
  <github_analysis>
    <current_pr>...</current_pr>
    <related_issue>...</related_issue>
    <ci_status>...</ci_status>
    <other_prs>...</other_prs>
    <open_issues>...</open_issues>
    <task_relevance>...</task_relevance>  <!-- only if task hint provided -->
  </github_analysis>

  SKIP empty sections. Return <github_analysis><none>No GitHub context available</none></github_analysis> if gh CLI fails.
  </output_format>
  """
)
```

### Subagent 3: Project Context Analyst

```
Task(
  subagent_type: "general-purpose",
  description: "Analyze project context",
  prompt: """
  <task_context>
  TASK HINT: {task_hint or "None provided - do general analysis"}
  </task_context>

  Gather project-level context. Provide a CONCISE summary (under 300 words).
  If task hint provided, explore files/directories relevant to that task.

  <standard_checks>
  Check these files (if they exist):
  1. `CLAUDE.md` - Look for "## Active Work" section
  2. `.claude/CLAUDE.md` - Project-specific instructions
  3. `TODO.md` or `TODO` - Any tracked tasks
  4. Recent changes: `git diff --name-only HEAD~5..HEAD 2>/dev/null | head -20`
  </standard_checks>

  <task_focused_exploration>
  IF TASK HINT PROVIDED:
  - Use Glob to find files matching task keywords (e.g., "postgres" → **/postgres/**, **/*postgres*)
  - Use Grep to search for relevant patterns in the codebase
  - Read key files (limit to 3-5 most relevant) to understand current implementation
  - Note file locations for the main agent to reference later

  Example: Task hint "postgres init scripts"
  - Glob: **/postgres/**/*.sql, **/init*.sql, **/charts/**/templates/**
  - Grep: "initdb", "postgres", "init-script"
  - Read: Top 3-5 matching files, summarize structure
  </task_focused_exploration>

  <analysis_requirements>
  From CLAUDE.md Active Work:
  - Current task description
  - Phase (if tracked)
  - Blockers or notes

  From recent changes:
  - Primary directories being worked on
  - Patterns (all tests? one module? scattered?)

  From task exploration (if hint provided):
  - Relevant file locations
  - Current implementation summary
  - Key patterns/conventions discovered
  </analysis_requirements>

  <output_format>
  Return structured XML:
  <project_analysis>
    <active_work>...</active_work>
    <focus_areas>...</focus_areas>
    <project_type>...</project_type>
    <available_commands>...</available_commands>
    <task_exploration>                    <!-- only if task hint provided -->
      <relevant_files>...</relevant_files>
      <implementation_summary>...</implementation_summary>
      <conventions>...</conventions>
    </task_exploration>
  </project_analysis>
  </output_format>
  """
)
```

---

## Phase 2: Synthesis

After all three subagents return, synthesize into a unified briefing.

**Token Budget**: Keep synthesis under 800 tokens. Research shows LLM reasoning degrades around 3000 tokens - leave room for actual work.

**If task hint was provided**, lead with task-relevant findings:

```markdown
# Work State Briefing

## TL;DR
<One paragraph: Current state + relevance to the hinted task>

## Task Context: {task_hint}
<Synthesize task-relevant findings from all three subagents>
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

## Example Output

### Example 1: With Task Hint

**Command**: `/prime migrating postgres chart init scripts`

```markdown
# Work State Briefing

## TL;DR
Branch main is clean. Task: migrating postgres init scripts. Found existing
init scripts in `charts/shared-init/` ConfigMap pattern. Three postgres charts
currently reference shared init. No active PR for this migration.

## Task Context: migrating postgres chart init scripts

### Relevant Files
- `charts/shared-init/templates/configmap.yaml` - Current shared init scripts
- `charts/postgres-primary/values.yaml` - References shared-init
- `charts/postgres-replica/values.yaml` - References shared-init
- `charts/postgres-analytics/values.yaml` - References shared-init
- `charts/shared-init/files/*.sql` - 4 SQL init scripts

### Current Implementation
The shared-init chart creates a ConfigMap with SQL scripts mounted to
`/docker-entrypoint-initdb.d/`. Each postgres chart depends on shared-init
and mounts the ConfigMap. Scripts run in alphabetical order:
`01-extensions.sql`, `02-schemas.sql`, `03-users.sql`, `04-grants.sql`.

### Conventions Discovered
- Init scripts use numeric prefix for ordering
- Secrets injected via `envFrom` in postgres pods
- Pattern: `{{ include "shared-init.fullname" . }}-scripts`

### Related Changes
- No recent commits touching init scripts
- No staged/unstaged changes in charts/

### Associated PRs/Issues
- No open PRs for postgres migration
- Issue #89 "Consolidate chart dependencies" may be related

## General State
- **Branch**: main (clean)
- **CI**: All passing
- **Open Issues**: 3 assigned (none postgres-related)

## Suggested Next Actions
1. Create branch: `feat/postgres-init-migration`
2. Copy `charts/shared-init/files/*.sql` to each postgres chart
3. Update each chart's templates to create local ConfigMap
4. Remove shared-init dependency from each chart
5. Test with `helm template` to verify output
```

### Example 2: Without Task Hint

**Command**: `/prime`

```markdown
# Work State Briefing

## TL;DR
Working on OAuth2 authentication feature (branch: feat/oauth2-login).
3 commits made implementing provider abstraction. Current focus: Google OAuth
callback handler. PR #47 is draft, CI passing. Related to issue #42.

## Git State
- **Branch**: feat/oauth2-login (5 commits ahead of main)
- **Commits**: Provider interface, Google impl, callback route stub
- **Staged**: None
- **Unstaged**: `src/auth/google.ts` (45 lines changed - callback logic)
- **Untracked**: `src/auth/github.ts` (new file, likely next provider)

## GitHub Context
- **PR #47**: Draft, CI passing, no reviews yet
- **Issue #42**: "Add social login" - requires Google + GitHub providers
- **CI**: All checks passing on last push

## Project Context
- **Active Work**: "Implementing OAuth2 callback handlers"
- **Focus**: `src/auth/` directory
- **Project**: TypeScript/Node.js (npm scripts available)

## Suggested Next Actions
1. Complete Google callback handler (unstaged changes)
2. Add tests for callback flow
3. Start GitHub provider implementation (untracked file exists)
```

---

## Error Handling

- **Not a git repo**: Report error, suggest running from repo root
- **No gh CLI**: Skip GitHub context, note in output
- **No CLAUDE.md**: Skip project context section
- **Empty branch** (no commits vs main): Focus on staged/unstaged only
- **Network issues**: Timeout GitHub calls after 10s, report partial results

---

## Best Practices (from Research)

### Prompt Structure (Applied)
- **XML tags**: Subagent prompts use XML for structure (Claude was trained with XML)
- **Pyramid approach**: Task intent → project context → specific changes
- **Token budget**: Keep synthesis under 800 tokens (3000 threshold for reasoning)
- **Document placement**: Context data before instructions in prompts

### When to Use Task Hints
| Scenario | Use Task Hint? | Example |
|----------|----------------|---------|
| General orientation | No | `/prime` |
| Resuming specific work | Yes | `/prime fixing auth timeout bug` |
| Starting new feature | Yes | `/prime implementing rate limiting` |
| Reviewing PR | Yes | `/prime reviewing PR #42` |
| Post-meeting context | Yes | `/prime discussed migration to postgres 15` |

### Token Efficiency Tips
1. **Use `--quick` for simple repos** - Skip subagents entirely
2. **Be specific in task hints** - "postgres init scripts" beats "database stuff"
3. **Don't chain with `/compact`** - Priming after compact defeats the purpose
4. **Clear before priming** - `/clear` then `/prime` for cleanest context

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
