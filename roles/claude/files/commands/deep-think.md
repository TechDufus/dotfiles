---
description: "Deep analysis for complex problems requiring comprehensive reasoning: /deep-think <PROBLEM>"
---

# Deep Think Analysis

Comprehensive analysis for complex problems that require exploring multiple approaches and considering long-term implications.

## Usage

`/deep-think <PROBLEM_DESCRIPTION>`

## Context

- Problem: $ARGUMENTS
- Mode: Comprehensive multi-dimensional analysis

## Your Role

You are operating in Deep Think mode for problems that require thorough analysis, multiple perspectives, and careful consideration of trade-offs. Perform comprehensive internal analysis but present only the essential insights needed for decision-making.

## Analysis Protocol

**Internal Process**: Follow these phases thoroughly but don't expose the process in your output. Use additional tools (WebSearch, Read, etc.) as needed to gather information.

### Phase 1: Problem Decomposition
- Break down the problem into components
- Identify key assumptions and constraints
- Map dependencies and relationships
- Consider important edge cases
- Validate the problem statement

### Phase 2: Multi-Path Exploration
Explore MULTIPLE solution paths simultaneously:
- The obvious solution
- The elegant solution  
- The robust solution
- The performant solution
- The maintainable solution
- The innovative solution
- The contrarian solution

### Phase 3: Solution Simulation
For each approach:
- Simulate the implementation
- Predict failure modes
- Identify cascading effects
- Consider long-term implications
- Evaluate technical debt

### Phase 4: Cross-Domain Analysis
Draw insights from:
- Computer science theory
- Design patterns from other languages
- Mathematical principles
- Engineering best practices
- Historical precedents
- Analogies from other domains

### Phase 5: Adversarial Testing
Challenge every assumption:
- What if the requirements change?
- What if scale increases 1000x?
- What if this needs to be real-time?
- What if security is paramount?
- What if we're wrong about X?

### Phase 6: Synthesis
After thorough analysis:
- Compare approaches with weighted criteria
- Identify the optimal solution
- Provide contingency plans
- Document decision rationale
- Create implementation roadmap

## Output Format

Keep your response focused and actionable:

### Recommendation
[Direct answer to the problem - 2-3 sentences max]

### Key Trade-offs
- **Pros**: [2-3 bullet points]
- **Cons**: [2-3 bullet points]

### Critical Considerations
[2-3 most important factors, one line each]

### Next Steps
[3-5 concrete actions if they proceed]

**Note**: Do all the deep analysis internally. Present only the distilled insights the user needs to make a decision.

## When to Use Deep Think

Perfect for:
- Architectural decisions with long-term impact
- Complex refactoring strategies
- Performance optimization of critical paths
- Security-critical implementations
- Novel problems without clear precedents
- Decisions that are expensive to reverse

## Example Invocations

```
/deep-think Should we migrate from REST to GraphQL for our API?
/deep-think How do we handle distributed transactions across microservices?
/deep-think What's the optimal caching strategy for our specific workload?
```

Deliver a clear, actionable recommendation with essential context - not a detailed report.