---
description: "Initialize a comprehensive CLAUDE.md using ultrathink methodology: /init-ultrathink [optional-context]"
---

# Initialize CLAUDE.md with Ultrathink

## Usage

`/init-ultrathink [optional context about the project]`

## Context

- Project context: $ARGUMENTS
- This command creates a comprehensive CLAUDE.md file by analyzing the repository with multiple specialized agents

## Your Role

You are the Coordinator Agent orchestrating specialized sub-agents to create a comprehensive CLAUDE.md file that will guide Claude in understanding and working with this codebase.

## Sub-Agents

1. **Repository Analyst Agent** - Analyzes project structure, tech stack, and patterns
2. **Context Gatherer Agent** - Identifies key abstractions, workflows, and conventions
3. **Documentation Agent** - Extracts insights from existing docs and comments
4. **Testing Agent** - Analyzes test patterns and quality standards

## Process

### Phase 1: Repository Analysis (Repository Analyst Agent)

1. **Project Structure Analysis**
   - Identify project type (web app, CLI tool, library, etc.)
   - Map directory structure and key entry points
   - Detect build tools and package managers
   - Identify configuration files and their purposes

2. **Tech Stack Detection**
   - Programming languages and versions
   - Frameworks and major libraries
   - Development tools and scripts
   - Database and external services

3. **Architecture Patterns**
   - Design patterns in use (MVC, microservices, etc.)
   - Code organization principles
   - Module boundaries and dependencies

### Phase 2: Context Discovery (Context Gatherer Agent)

1. **Coding Conventions**
   - Naming conventions (files, variables, functions)
   - Code style and formatting rules
   - Import/export patterns
   - Error handling approaches

2. **Development Workflows**
   - Branch strategies (from git history)
   - Common command patterns (from scripts/Makefile)
   - Testing procedures
   - Deployment processes

3. **Key Abstractions**
   - Core domain models
   - Common utilities and helpers
   - Shared components or modules
   - Authentication/authorization patterns

### Phase 3: Documentation Mining (Documentation Agent)

1. **Existing Documentation**
   - README files and their key insights
   - API documentation
   - Code comments revealing intent
   - TODO/FIXME patterns

2. **Implicit Knowledge**
   - Complex algorithms or business logic
   - Performance optimizations
   - Security considerations
   - Known issues or limitations

### Phase 4: Quality Standards (Testing Agent)

1. **Testing Patterns**
   - Test framework and structure
   - Coverage expectations
   - Mocking strategies
   - Test data management

2. **Quality Gates**
   - Linting rules
   - Type checking requirements
   - Pre-commit hooks
   - CI/CD checks

## Ultrathink Reflection Phase

Synthesize all gathered information to create a comprehensive CLAUDE.md that includes:

1. **Repository Overview** - What this project does and its purpose
2. **Essential Commands** - Most important commands for development
3. **Architecture & Key Concepts** - How the codebase is organized
4. **Important Patterns** - Coding conventions and best practices
5. **Hidden Context** - Non-obvious but crucial information

## Output Format

Generate a CLAUDE.md file with this structure:

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

[Concise description of what this project is and does]

## Essential Commands

### Development
\`\`\`bash
# Start development environment
[command]

# Run tests
[command]

# Build the project
[command]
\`\`\`

### Common Tasks
\`\`\`bash
# [Task description]
[command]
\`\`\`

## Architecture and Key Concepts

### 1. **[Concept Name]**
[Explanation of the concept and why it matters]

### 2. **[Another Concept]**
[Explanation]

## Important Patterns

### [Pattern Category]
[Description of the pattern with examples]
- Example: [specific file or usage]

### Adding New Features
[Step-by-step guidance for common development tasks]

### Testing Approach
[How tests should be written]

## Hidden Context

### [Non-obvious aspect]
[Explanation of something that might trip up newcomers]

### Performance Considerations
[Any performance-related notes]

### Security Notes
[Security-related patterns or requirements]

## Code Style

### Naming Conventions
- [Convention]: [Example]

### File Organization
- [Pattern]: [Explanation]

### Error Handling
[How errors should be handled]

## Gotchas and Tips

- **[Common mistake]**: [How to avoid it]
- **[Useful tip]**: [Explanation]
```

## Validation Questions

After generating the CLAUDE.md, ask:
1. "Are there any critical workflows or patterns I missed?"
2. "Any project-specific conventions that should be highlighted?"
3. "Are the commands accurate for your development setup?"

## Final Steps

1. Show the generated CLAUDE.md for review
2. Make any requested adjustments
3. Save the file to the repository root
4. Remind user to commit the file when satisfied

## Notes

- Focus on actionable information Claude would need
- Prioritize patterns over exhaustive documentation
- Include both obvious and non-obvious context
- Make commands copy-pasteable
- Keep sections concise but comprehensive