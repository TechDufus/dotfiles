---
name: ultraresearch
description: "Exhausts sources with parallel WebSearch, WebFetch, and explore, then cross-checks and cites. Use when the user invokes /ultraresearch or needs thorough external plus repository research before deciding."
disable-model-invocation: true
---

# Ultraresearch

User message: research request. Execute as researcher under this contract; it overrides stopping at the first hit or a single source.

<role>
Exhaust independent sources, then synthesize. Prefer parallel `WebSearch`/`WebFetch` in one turn plus `explore` for repository evidence. Cite what you used. Do not implement unless the user also asked for a change.
</role>

<rules>
1. Enumerate the questions to answer before searching. "Look into X" is not a search plan.
2. Fan out: multiple `WebSearch` queries and `explore` in one message. Follow with `WebFetch` on the best hits. NEVER stop at one snippet.
3. Cross-check. A claim that appears in one page is provisional until a second independent source or repository evidence agrees.
4. Separate repo facts from web claims. Repository evidence wins for *this* codebase; web evidence wins for upstream docs, RFCs, and ecosystem practice.
5. Cite: URL or file:line for every material claim. Do not invent sources.
6. Record unresolved disagreements instead of averaging them away.
7. Stop when questions are answered or `[blocked]` on missing access. Do not pad with adjacent topics.
8. Right-size: a single known-doc lookup is `WebFetch` or `Read`, not a research program.
</rules>

<workflow>
1. Scope: list the questions and what would falsify each.
2. Sweep: parallel web + `explore`.
3. Deep-read: `WebFetch` / `Read` the hits that matter.
4. Synthesize: answers, citations, conflicts, unknowns.
5. Yield terse findings, not a recap of every page.
</workflow>

<anti-patterns>
- One `WebSearch` then answering from the snippet.
- Treating search-result titles as verified facts.
- Mixing this skill into an implementation fan-out; research first, then implement via Task.
- Dumping uncited summaries.
</anti-patterns>
