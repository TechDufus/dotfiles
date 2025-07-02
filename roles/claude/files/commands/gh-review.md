---
description: "AI-powered GitHub PR review: /gh-review <pr-reference>"
---

# /gh-review

Provides intelligent, AI-powered code review for GitHub pull requests with specific, actionable feedback.

## Usage

```
/gh-review <pr-reference>
```

## PR Reference Formats

- `123` - PR in current repository
- `#123` - PR in current repository  
- `org/repo#123` - PR in specific repository
- `https://github.com/org/repo/pull/123` - Full PR URL

## Examples

```
/gh-review 42
/gh-review TechDufus/dotfiles#100
/gh-review "org/repo#123"
/gh-review https://github.com/org/repo/pull/123
```

## What This Command Does

When you run `/gh-review`, I will:

1. **Fetch PR Details** - Get the complete diff, metadata, and existing comments
2. **Analyze Code Changes** - Review the code for:
   - **Code Quality**: Style consistency, naming conventions, code organization
   - **Potential Bugs**: Logic errors, edge cases, null checks, error handling
   - **Security Issues**: Input validation, authentication, authorization concerns
   - **Performance**: Inefficient algorithms, unnecessary loops, resource usage
   - **Best Practices**: Design patterns, SOLID principles, DRY violations
   - **Testing**: Missing tests, test coverage, test quality
   - **Documentation**: Missing or outdated comments, API docs
   - **CI/CD Status**: Check GitHub Actions for failures and analyze why

3. **Generate Specific Feedback** including:
   - **Summary**: High-level overview of the changes
   - **Strengths**: What's done well
   - **Issues**: Specific problems with severity levels
   - **Suggestions**: Concrete improvements with code examples
   - **Questions**: Clarifications needed from the author

## Review Output Format

I'll provide:
- 📊 **Change Summary** - Overview of what the PR does
- ✅ **Positive Aspects** - What's implemented well
- 🔍 **Code Review Findings** organized by:
  - 🐛 Bugs/Issues (with severity)
  - 🎯 Suggestions (with examples)
  - ❓ Questions for clarification
- 🚦 **CI/CD Analysis** - GitHub Actions status and failure reasons
- 📝 **Recommended Actions** - Specific next steps

## Features

- **Intelligent Analysis**: Goes beyond syntax to understand intent and impact
- **Context-Aware**: Considers the broader codebase and patterns
- **Actionable Feedback**: Provides specific line numbers and code suggestions
- **Severity Levels**: Prioritizes issues (Critical/High/Medium/Low)
- **Learning**: Recognizes patterns from your codebase

## Environment Variables

- `GITHUB_REPOSITORY`: Override auto-detected repository (format: owner/repo)

## Implementation

I'll execute the following command to fetch PR data:

```bash
~/.claude/scripts/gh-ai-review.sh "<pr-reference>"
```

Then I'll analyze the output to provide:

1. **Code Quality Assessment**
   - Identify style inconsistencies
   - Flag naming convention violations
   - Suggest better code organization

2. **Bug Detection**
   - Find potential null pointer exceptions
   - Identify missing error handling
   - Detect logic errors and edge cases

3. **Security Analysis**
   - Check for input validation issues
   - Identify authentication/authorization problems
   - Flag potential injection vulnerabilities

4. **Performance Review**
   - Identify inefficient algorithms
   - Find unnecessary database queries
   - Suggest caching opportunities

5. **Best Practices Check**
   - SOLID principle violations
   - DRY (Don't Repeat Yourself) issues
   - Missing abstractions

### Script Location
`~/.claude/scripts/gh-ai-review.sh`

### What the script does
1. Parses PR reference (number, #number, org/repo#number, or URL)
2. Fetches PR metadata and full diff
3. Gets existing review comments to avoid duplicates
4. Outputs structured data for AI analysis

### My Analysis Process
1. Parse the diff to understand each change
2. Analyze the context and impact
3. Check against best practices and patterns
4. Generate specific, actionable feedback
5. Prioritize findings by severity
6. Provide code examples for improvements

**Important:** Always quote PR references containing `#`:
- ✅ `/gh-review "org/repo#123"`
- ❌ `/gh-review org/repo#123` (# treated as comment)