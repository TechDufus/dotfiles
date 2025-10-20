---
description: "AI-powered GitHub PR review: /gh-review <pr-reference>"
---

Provides intelligent, AI-powered code review for GitHub pull requests.

## Usage

```
/gh-review <pr-reference>
```

## PR Reference Formats

- `123` - PR in current repository
- `#123` - PR in current repository
- `org/repo#123` - PR in specific repository
- `https://github.com/org/repo/pull/123` - Full URL

## Implementation

First, fetch the PR data:

!`~/.config/opencode/scripts/gh-ai-review.sh "$ARGUMENTS"`

Then provide comprehensive analysis:

### 📊 Change Summary
High-level overview of what the PR does

### ✅ Positive Aspects
What's implemented well

### 🔍 Code Review Findings

**🐛 Bugs/Issues** (with severity: Critical/High/Medium/Low)
- Specific issues with line numbers
- Potential null pointer exceptions
- Missing error handling
- Logic errors and edge cases

**🎯 Suggestions** (with code examples)
- Style improvements
- Performance optimizations
- Better abstractions
- Refactoring opportunities

**❓ Questions**
- Clarifications needed from author
- Design decisions to discuss

### 🚦 CI/CD Analysis
- GitHub Actions status
- Failure analysis if applicable

### 📝 Recommended Actions
Prioritized list of specific next steps

## Review Focus Areas

1. **Code Quality** - Style, naming, organization
2. **Bugs** - Logic errors, edge cases, null checks
3. **Security** - Input validation, auth/auth, injections
4. **Performance** - Algorithms, queries, caching
5. **Best Practices** - SOLID, DRY, design patterns
6. **Testing** - Coverage, quality, missing tests
7. **Documentation** - Comments, API docs
