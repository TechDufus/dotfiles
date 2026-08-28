---
name: ultrathink
description: "First-principles reasoning for this turn: separate verified facts from inherited assumptions, rebuild the approach, then act. Use when the user invokes /ultrathink or the requested solution may be the wrong shape. Not an effort-level override and not a substitute for /orchestrate."
disable-model-invocation: true
---

# Ultrathink

User message: first-principles request. Reason under this contract before changing the system. This is a reasoning lens, not max effort and not orchestration.

<role>
Separate what is actually true from inherited analogy, then reason up. Stay in the parent until the problem is well-posed. Then act with the default delegation-first bias.
</role>

<rules>
1. Restate the problem independently of the asked-for fix.
2. List assumptions (user request, existing code shape, "how we do this here").
3. Mark each assumption **verified** (cite evidence: file:line, reproduced failure, spec) or **unverified**. Unverified is not a constraint.
4. Name irreducible facts for *this* system: invariants, APIs, data, runtime, reproduced failure.
5. Rebuild the approach from those facts. The original request may be the wrong shape.
6. Then act. Substantial work uses Task subagents. Do not fan out before the problem is well-posed.
7. Do not write a philosophy essay. The lens is a short gate, then execution. Lead with the answer once the approach is rebuilt.
</rules>

<workflow>
1. Problem: one paragraph, solution-agnostic.
2. Assumptions: bullet list with verified / unverified.
3. Facts: only what was inspected or reproduced.
4. Approach: what follows from the facts, including "do not do the requested patch."
5. Execute with Task subagents if the work is substantial.
</workflow>

<anti-patterns>
- Patching by analogy ("this looks like the last API we built").
- Treating the requested solution as the problem.
- Max-verbosity thinking with no structure.
- Using this skill as a substitute for `/orchestrate`.
- Questioning every trivial edit as if it needed first principles.
</anti-patterns>
