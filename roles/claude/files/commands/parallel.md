---
description: "Orchestrate parallel agent execution with intelligent task decomposition: /parallel <TASK_DESCRIPTION>"
---

# Parallel Agent Orchestration

Execute multiple specialized agents in parallel to tackle complex tasks from all angles simultaneously.

## Usage

`/parallel <TASK_DESCRIPTION>`

## Context

- Task to parallelize: $ARGUMENTS
- Execute all agents in parallel using multiple Task tool invocations in a single message

## Your Role

You are the Parallel Orchestration Engine that:
1. Analyzes tasks for parallelization opportunities
2. Identifies potential conflicts and dependencies
3. Designs independent, non-conflicting agents
4. Executes all agents simultaneously
5. Coordinates and synthesizes results

## ULTRATHINK Process

### Phase 1: Task Decomposition Analysis
**Think deeply about:**
- What aspects of this task can be done independently?
- What potential conflicts might arise from parallel execution?
- Which parts require sequential ordering vs true parallelism?
- What shared resources might cause race conditions?
- How can agents be designed to avoid stepping on each other?

### Phase 2: Conflict Avoidance Strategy
**Design agents that:**
- Work on different files/directories when possible
- Use non-overlapping search patterns
- Have clearly defined boundaries
- Can produce results that merge cleanly
- Handle their own error states independently

### Phase 3: Agent Architecture Design
**For each parallel agent, define:**
- **Scope**: Exactly what this agent will and won't do
- **Boundaries**: Files/directories/patterns it will touch
- **Output**: What it will produce and in what format
- **Independence**: Why it won't conflict with other agents
- **Fallback**: What to do if it encounters issues

### Phase 4: Parallel Execution Plan
**Structure the execution to:**
- Launch all agents in a single message with multiple Task tool calls
- Use descriptive names that indicate their parallel nature
- Provide each agent with complete, self-contained instructions
- Include conflict avoidance instructions in each prompt
- Specify expected outputs clearly

## Execution Framework

```
1. ANALYZE the task for parallelization:
   - Identify independent workstreams
   - Map potential resource conflicts
   - Design non-overlapping agent responsibilities

2. DESIGN parallel agents that:
   - Can work simultaneously without conflicts
   - Have clear boundaries and constraints
   - Produce mergeable/complementary outputs
   - Handle errors gracefully

3. EXECUTE all agents in parallel:
   - Use multiple Task tool invocations in ONE message
   - Provide complete context to each agent
   - Specify coordination instructions

4. SYNTHESIZE results:
   - Merge findings from all agents
   - Resolve any unexpected conflicts
   - Present unified solution
```

## Common Parallelization Patterns

### Pattern 1: Directory-Based Separation
```
- Agent 1: Analyze /src directory
- Agent 2: Analyze /tests directory  
- Agent 3: Analyze /docs directory
```

### Pattern 2: Language/File-Type Separation
```
- Agent 1: Python files (*.py)
- Agent 2: JavaScript files (*.js, *.ts)
- Agent 3: Configuration files (*.yml, *.json)
```

### Pattern 3: Functional Separation
```
- Agent 1: Security analysis
- Agent 2: Performance analysis
- Agent 3: Code quality analysis
```

### Pattern 4: CRUD Separation
```
- Agent 1: Find all Create operations
- Agent 2: Find all Read operations
- Agent 3: Find all Update operations
- Agent 4: Find all Delete operations
```

## Conflict Prevention Strategies

1. **File Locking**: Assign specific files to specific agents
2. **Pattern Exclusivity**: Use non-overlapping search patterns
3. **Output Isolation**: Have agents write to separate output locations
4. **Append-Only**: Agents only add, never modify existing content
5. **Namespace Separation**: Use prefixes/suffixes to avoid naming conflicts

## Example Parallel Execution

```
Task: "Refactor authentication across the codebase"

Parallel Agents:
1. AUTH_ANALYZER: Map all current auth implementations
2. PATTERN_FINDER: Identify auth patterns and anti-patterns  
3. TEST_SCANNER: Find all auth-related tests
4. DOC_REVIEWER: Analyze auth documentation
5. SECURITY_AUDITOR: Check for auth vulnerabilities

All executed simultaneously with:
- Clear boundaries (different file patterns)
- Non-conflicting outputs (separate analysis types)
- Mergeable results (different aspects of auth)
```

## Output Coordination

After parallel execution:
1. **Merge Results**: Combine findings from all agents
2. **Identify Gaps**: Check if any areas were missed
3. **Resolve Conflicts**: Handle any unexpected overlaps
4. **Present Synthesis**: Deliver integrated solution

## Key Principles

- Execute agents in parallel (multiple Task tools in one message)
- Run agents sequentially only when dependencies require it
- Consider potential conflicts during design phase
- Provide complete, self-contained instructions to each agent
- Agents cannot communicate during execution

## Error Handling

If parallel execution encounters issues:
1. Identify which agents succeeded/failed
2. Analyze if failures were due to conflicts
3. Redesign agents if necessary to avoid conflicts
4. Re-execute failed agents with adjusted parameters
5. Never let one agent's failure cascade to others

Remember: The goal is maximum parallelization with zero conflicts. Think deeply about task decomposition before executing!