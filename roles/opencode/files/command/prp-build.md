---
description: "Build a PRP from feature file: /prp-build <feature-file>"
---

Build a complete PRP (Prompt Refinement Protocol) from a feature file with comprehensive research.

## Feature File: $ARGUMENTS

Read the feature file first to understand requirements, examples, and considerations.

## Research Process

### 1. Codebase Analysis
- Search for similar features/patterns
- Identify files to reference in PRP
- Note existing conventions
- Check test patterns

### 2. External Research
- Search for similar implementations online
- Library documentation (include URLs)
- Implementation examples (GitHub/StackOverflow/blogs)
- Best practices and common pitfalls

### 3. User Clarification (if needed)
- Specific patterns to mirror?
- Integration requirements?
- Missing context?

## PRP Generation

### Critical Context to Include
The AI agent only gets context you provide and training data. Include:
- **Documentation**: URLs with specific sections
- **Code Examples**: Real snippets from codebase
- **Gotchas**: Library quirks, version issues
- **Patterns**: Existing approaches to follow

### Implementation Blueprint
- Start with pseudocode showing approach
- Reference real files for patterns
- Include error handling strategy
- List tasks in completion order

### Validation Gates (Executable)
```bash
# Example for Python project
ruff check --fix && mypy .
uv run pytest tests/ -v

# Example for Node.js project
npm run lint && npm run typecheck
npm test
```

> ⚠️ **CRITICAL**: Before building the PRP:
>
> **ULTRATHINK** about the PRP and plan your approach comprehensively.

## Output
Save as: `PRPs/{feature-name}.md`

Use template: `~/.config/opencode/templates/prp_base.md` (if exists)

## Quality Checklist
- [ ] All necessary context included
- [ ] Validation gates executable by AI
- [ ] References existing patterns
- [ ] Clear implementation path
- [ ] Error handling documented

Score the PRP confidence level (1-10) for one-pass implementation success.

## Notes
- Goal: Enable one-pass implementation through comprehensive context
- Agent has websearch - provide documentation URLs
- Assume agent has same knowledge cutoff as you
- Include all research findings or references
