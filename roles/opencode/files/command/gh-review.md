---
description: "Intelligent AI-powered GitHub PR review: /gh-review <pr-reference>"
---

# Intelligent PR Review

Provides adaptive, AI-powered code review for GitHub pull requests of any size.

## Usage

```bash
/gh-review <pr-reference>
```

## PR Reference Formats

- `123` - PR in current repository
- `#123` - PR in current repository
- `org/repo#123` - PR in specific repository
- `https://github.com/org/repo/pull/123` - Full URL

---

## Implementation Strategy

This command uses an intelligent, adaptive approach that automatically selects the best review strategy based on PR size and complexity.

### Phase 1: Strategic Analysis (Always First)

**Gather PR intelligence to decide strategy:**

```bash
!`~/.config/opencode/scripts/gh-ai-review.sh "$ARGUMENTS" --summary-only`
```

**Analyze the summary output:**
- Total lines changed (additions + deletions)
- Number of files changed
- File types and structure
- PR description (hints about scope)

**Make strategic decision based on size:**

```
IF total_changes < 500 AND files < 10:
    → Use STRATEGY A: Full Review
    
ELSE IF total_changes < 2000 AND files < 30:
    → Use STRATEGY B: Prioritized Review
    
ELSE IF total_changes >= 2000 OR files >= 30:
    → Use STRATEGY C: Parallel Chunked Review
```

---

### Phase 2: Execute Selected Strategy

#### **STRATEGY A: Full Review** (Small PRs <500 lines)

For small, focused PRs - do comprehensive single-pass review:

```bash
!`~/.config/opencode/scripts/gh-ai-review.sh "$ARGUMENTS"`
```

Then provide complete review covering all aspects.

---

#### **STRATEGY B: Prioritized Review** (Medium PRs 500-2000 lines)

For medium PRs - review in priority order:

**Step 1: Identify Priority Files**
Based on the file list, categorize:
- **High Priority**: Security files (auth, permissions), core business logic
- **Medium Priority**: Feature implementation, API changes
- **Low Priority**: Tests, configs, documentation

**Step 2: Review High Priority First**
```bash
!`~/.config/opencode/scripts/gh-ai-review.sh "$ARGUMENTS" --files 'api/auth/*'`
!`~/.config/opencode/scripts/gh-ai-review.sh "$ARGUMENTS" --files 'core/*'`
```

**Step 3: Review Remaining Files**
```bash
!`~/.config/opencode/scripts/gh-ai-review.sh "$ARGUMENTS" --files '*.py'`
```

**Step 4: Synthesize Findings**
Combine all findings into unified review.

---

#### **STRATEGY C: Parallel Chunked Review** (Large PRs >2000 lines)

For large PRs - use parallel @general subagent calls to review chunks simultaneously:

**Step 1: Analyze File Structure**
Group files by logical concern based on paths:
- Backend: `api/`, `models/`, `services/`
- Frontend: `src/`, `components/`, `pages/`
- Tests: `tests/`, `__tests__/`, `*.test.*`
- Infrastructure: `config/`, `.github/`, `docker/`

**Step 2: Design Parallel Agents**
Create independent agents with non-overlapping file patterns.

**Step 3: Execute Parallel Review**

Launch multiple @general subagent calls:

@general **Review Backend Files** for PR $ARGUMENTS. Focus on files in api/*, models/*, services/*. Analyze: business logic correctness, error handling patterns, security vulnerabilities, database query efficiency. Return: list of issues (critical/high/medium/low), specific line references, code improvement suggestions.

@general **Review Frontend Files** for PR $ARGUMENTS. Focus on files in src/components/*, src/pages/*, *.tsx, *.jsx. Analyze: React patterns, state management, performance issues, accessibility. Return: list of issues (critical/high/medium/low), specific line references, code improvement suggestions.

@general **Review Test Files** for PR $ARGUMENTS. Focus on files in tests/*, __tests__/*, *.test.*, *.spec.*. Analyze: test coverage gaps, edge cases not tested, test quality, mock appropriateness. Return: list of issues (critical/high/medium/low), coverage recommendations.

@general **Review Infrastructure Files** for PR $ARGUMENTS. Focus on files in .github/*, docker/*, *.yml, *.yaml, config/*. Analyze: CI/CD configuration, security best practices, deployment concerns. Return: list of issues (critical/high/medium/low), security findings.

**Step 4: Synthesize Agent Findings**

After all agents complete, combine their findings:

```markdown
## 📊 Comprehensive PR Review

### Backend Analysis
[Backend-specific findings from agent 1]

### Frontend Analysis
[Frontend-specific findings from agent 2]

### Test Coverage Analysis
[Test-specific findings from agent 3]

### Infrastructure Analysis
[Infrastructure findings from agent 4]

### 🔥 Critical Cross-Cutting Issues
[Issues that span multiple areas]

### 💡 Prioritized Recommendations
[Synthesized action items from all agents]
```

---

## Review Output Format

Regardless of strategy used, provide review in this format:

### 📊 Change Summary
High-level overview of what the PR accomplishes

### ✅ Positive Aspects
What's well-implemented:
- Good patterns used
- Strong test coverage
- Clean architecture

### 🔍 Code Review Findings

#### 🐛 Bugs/Issues (with severity)
**Critical:**
- [Issue with line number and explanation]

**High:**
- [Issue with line number and explanation]

**Medium:**
- [Issue with line number and explanation]

**Low:**
- [Issue with line number and explanation]

#### 🎯 Suggestions (with code examples)
- [Improvement with specific code suggestion]
- [Refactoring opportunity]
- [Performance optimization]

#### ❓ Questions for Author
- [Clarification needed on design decision]
- [Missing context about requirement]

### 🚦 CI/CD Analysis
- GitHub Actions status
- Failure analysis if applicable
- Breaking change assessment

### 📝 Recommended Actions
Prioritized, specific next steps:
1. [Most critical action]
2. [Important improvement]
3. [Nice-to-have enhancement]

---

## Review Focus Areas

**Always consider:**
1. **Code Quality** - Naming, organization, readability
2. **Bugs** - Logic errors, edge cases, null/undefined checks
3. **Security** - Input validation, auth/authz, injection vulnerabilities
4. **Performance** - Algorithm efficiency, database queries, caching
5. **Best Practices** - SOLID principles, DRY, design patterns
6. **Testing** - Coverage adequacy, test quality, missing scenarios
7. **Documentation** - Code comments, API docs, README updates

---

## Strategy Selection Examples

### Example 1: Small PR (300 lines, 5 files)
```
Analysis: 300 lines across 5 Python files
Strategy: STRATEGY A - Full Review
Reasoning: Small enough for comprehensive single-pass review
```

### Example 2: Medium PR (1,500 lines, 20 files)
```
Analysis: 1,500 lines across 20 files (backend + tests)
Strategy: STRATEGY B - Prioritized Review
Reasoning: Review API changes first, then tests
Groups: api/*.py → tests/*.py
```

### Example 3: Large PR (4,000 lines, 60 files)
```
Analysis: 4,000 lines across 60 files (full-stack feature)
Strategy: STRATEGY C - Parallel Chunked Review
Reasoning: Too large for single context window
Agents:
  1. Backend: api/, models/ (25 files)
  2. Frontend: src/components/ (20 files)
  3. Tests: tests/ (10 files)
  4. Config: .github/, docker/ (5 files)
```

---

## Notes

- **Generated files are auto-skipped**: lockfiles, minified JS, build outputs
- **Token efficiency**: Only fetch diffs when needed
- **Scalable**: Handles PRs from 10 lines to 10,000+ lines
- **Intelligent**: Automatically chooses the right approach
- **Parallel-ready**: Uses @general subagents for parallel review of large PRs
