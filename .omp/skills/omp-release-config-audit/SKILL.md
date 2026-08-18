---
name: omp-release-config-audit
description: Audit recent OMP releases against project configuration, effective runtime behavior, optional features, extensions, and maintenance drift using source-backed evidence.
condition: Use when reviewing OMP upgrades or release changes for compatibility with this repository's configuration, profiles, overlays, extensions, skills, or maintenance.
---

# OMP release and configuration audit

Use this project-local, ancestor-discovered skill to decide whether a bounded set of OMP releases changes the safety, compatibility, or intent of repository-managed OMP behavior. It belongs in `.omp/skills/` and is not a role-managed or global OMP deployment. It is an evidence-gathering audit, not an upgrade or configuration-edit workflow.

## Non-negotiable evidence rules

- Establish the requested release/date boundary before research. Do not imply a current version, release window, default, or compatibility result without dated, source-backed evidence.
- When the managed main config starts with `# OMP release/config audit reviewed through: <version>`, validate it and use releases newer than that inclusive baseline through the target as the default chronology window. The marker covers release research for the whole managed OMP surface; it never replaces a fresh current-schema/effective-state audit.
- Keep installed executable/package version, installed changelog calendar date, immutable matching tag/commit, and npm registry `time[version]` publish timestamp distinct. Installed target-version source is the behavior authority; current-main source/docs only corroborate when they agree, and registry time establishes only package-publication ordering.
- Distinguish configured text, current upstream defaults, migrated legacy behavior, and demonstrated effective runtime behavior. Classify every explicit key as current-schema valid, compatibility-migrated legacy, ignored/unknown, wrong-type, intentional non-default, or default-equal pin; retain a default-equal pin only with a documented reproducibility/behavior rationale, otherwise recommend removal.
- Never expose, copy, serialize, or report credentials, tokens, OAuth material, session data, secret environment values, or unrestricted configuration dumps. Redact evidence and preserve user-owned changes.
- Do not mutate managed configuration, live state, extensions, profiles, skills, or user files during an audit unless the user explicitly asks for separately scoped remediation.

## Phase router

1. **Scope and inventory:** fix the boundary; capture branch, working-tree, installed/live, and repository-managed versions and surfaces.
2. **Research and chronology:** split independent source/schema/migration/default, release-history, runtime, feature, extension, and maintenance questions with shared evidence contracts; reconcile a dated ledger.
3. **Compare behavior:** trace relevant source semantics and compare main configuration, profiles, and overlays as effective invocations—not merely YAML keys.
4. **Triage and review:** classify workflow-relevant features, extension compatibility, and maintenance drift; obtain an independent challenge review.
5. **Report and verify:** deliver traceable findings, unknowns, and any optional later remediation plan without conflating it with the audit.

Read the complete reusable procedure before performing any phase: `skill://omp-release-config-audit/references/procedure.md`.

## Output classification

For every reviewed item, classify it as **confirmed compatible**, **compatible through migration**, **intentional non-default/pin**, **default-equivalent candidate**, **material change requiring decision**, **extension/maintenance follow-up**, or **unknown/insufficient evidence**. For every explicit key, also use the required key classification from the evidence rules. State the affected surface, release boundary, evidence, effective-behavior conclusion, risk, and next action; keep a complete internal release ledger while reporting only material changes and unresolved risks.
