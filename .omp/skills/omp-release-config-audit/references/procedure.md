# OMP release/configuration audit procedure

Use this procedure after loading `skill://omp-release-config-audit`. This project-local, ancestor-discovered skill is loaded from `.omp/skills/`; it does not describe global-skill deployment. It produces a bounded, reproducible compatibility assessment; it does not authorize an upgrade, deployment, configuration rewrite, or cleanup.

## 1. Establish scope and safety boundary

1. Record the question, requested target or release range, audit date/timezone, repository revision and branch, and whether the audit concerns the installed/live OMP instance, this repository's managed files, or both.
2. If the managed main config starts with exact marker `# OMP release/config audit reviewed through: <version>` and the user did not supply a boundary, validate that version against package/release evidence and use versions greater than the marker and less than or equal to the target as the release-research window. The marker is an inclusive reviewed-through baseline for the entire managed OMP surface—not an installed-version claim—and never skips a fresh schema, migration, effective-state, extension, documentation, or working-tree audit. Treat a malformed, unavailable, or target-newer marker as suspect and report the boundary uncertainty rather than trusting it.
3. If neither a valid marker nor a user range exists, define a defensible boundary from local evidence and label it an assumption; ask only when that decision would materially change the outcome.
4. Snapshot only safe metadata: current branch, commit, worktree state, relevant file paths, installed command/package version, active configuration location, and selected profile/overlay invocation. Do not fetch, upgrade, run installers, reload plugins, alter authentication, or write configuration.
5. Treat the working tree and the live OMP user base as separate evidence sources. Preserve all user-owned files and changes. Do not replace a regular file with a link, normalize a file, or remove an unknown entry during the audit.
6. Apply secret safety throughout. Exclude credential stores, OAuth/session files, private MCP data, secret-loader output, and environment values from collection. Use names, types, existence checks, hashes where safe, and narrowly redacted snippets; never put sensitive values in subagent prompts, artifacts, logs, or the final report.
7. Never advance the marker for a partial, blocked, or report-only audit. Updating it is separate repository remediation requiring explicit authorization after the target range is complete and material findings are resolved or consciously accepted.

## 2. Build branch and live-version inventory

Create an inventory table before interpreting release notes:

| Evidence source | Record | Purpose |
| --- | --- | --- |
| Repository | branch, commit, dirty/untracked status, repository paths, managed-file revisions | identifies the audit baseline and preserves unrelated user work |
| Installed command/package | executable path, installed executable version, installed package version, target-version source location/revision, and install date if available | identifies the actual behavior authority and keeps executable/package identity distinct |
| Live base | active base directory, main configuration path, discovered skills/agents/extensions, active command arguments | distinguishes live state from repository intent |
| Repository-managed surface | files, profiles, overlays, launchers, agents, rules, skills, extensions, deployment tasks/defaults/tests | defines the repository's ownership boundary |
| Upstream release evidence | installed changelog calendar date, immutable matching tag/commit, npm registry `time[version]` publish timestamp, and changelog/source/schema/migration locations | establishes chronology without conflating publication and source dates |

Do not assume the package-manager version equals the executable version, the live base equals this repository, a checked-out branch is deployed, or an advertised feature is enabled. Resolve disagreement explicitly and classify the target as installed, source-only, registry-only, or unknown.

The installed target-version source is the authority for behavior. Current-main source or documentation is corroboration only when it agrees with the installed target. In the ledger, retain installed executable/package version, installed changelog calendar date, immutable matching tag/commit, and npm registry `time[version]` publish timestamp as separate fields. Registry time establishes package-publication ordering only; never use it to infer changelog, tag, merge, or current-main dates.

## 3. Enumerate the managed surface

Enumerate the repository-owned OMP surface rather than searching only for familiar configuration keys. Include, as applicable:

- main `config.yml`, model/provider declarations, LSP and MCP configuration, repository rules/guidance, and local launchers;
- named profiles and their complete relocated bases;
- CLI overlays and the commands that select them;
- agents, skills, extensions, their discovery/deployment paths, and extension lifecycle/reload requirements;
- repository deployment defaults, tasks, templates, migration/preservation behavior, ownership boundaries, and tests that state runtime contracts;
- user-owned adjacent files that are intentionally merged, preserved, or rejected by deployment.

For each surface, record owner, source path, destination or runtime consumer, selection mechanism, whether it is managed/merged/preserved, and whether inspecting it could expose secrets. Do not treat an absent override as absent behavior: it may inherit a default, parent, base, profile, or overlay value.

## 4. Plan parallel research with explicit contracts

Split only independent questions. Use parallel research when it improves coverage, not as a substitute for reconciliation. Give every slice the same boundary, audit date, target identity, secret restrictions, and result format:

- **Release chronology:** official releases, tags, changelog entries, publication ordering, retractions, and backports.
- **Schema/migration/defaults:** target schema and validation, compatibility code, migrations, deprecated/renamed/removed keys, and default changes.
- **Effective runtime:** configuration discovery, merge/precedence semantics, command-line arguments, profiles, overlays, and observable behavior.
- **Workflow relevance:** agent, tool, provider, context, security, skill, command, and lifecycle changes that could alter this repository's intended workflows.
- **Extensions:** public APIs, hook/command registration, permissions, reload/startup behavior, packaging, and compatibility boundaries.
- **Maintenance:** deployment assumptions, symlink/copy/merge preservation, tests, documentation ownership, and stale compatibility scaffolding.

Each researcher must return: claim; exact affected version range or `unknown`; primary source path/URL and revision/date; direct supporting excerpt or symbol; affected managed surface; confidence; counterevidence/unknowns; and no secret material. Chronology findings must preserve the distinct installed/package, changelog-date, immutable-tag/commit, and registry-time fields. Researchers must not infer compatibility from release-note prose, edit files, run upgrade/migration commands, or report an unbounded release dump. The coordinator alone reconciles overlaps and contradictions.

## 5. Reconcile release chronology

Build a dated ledger from the audit boundary to the target. The installed target-version source is behavior authority; use its matching immutable tag/commit and installed changelog as primary provenance. Current-main documentation/source is corroborating evidence only when it agrees. For every ledger entry, retain distinct fields for:

- installed executable version and installed package version;
- installed changelog calendar date;
- immutable matching official tag and commit;
- npm registry `time[version]` publish timestamp;
- release identifier, affected subsystem, source links, provenance/conflict status, and in-scope/superseded/backported/ambiguous status.

Use npm registry `time[version]` only for package-publication ordering. Never substitute it for changelog, tag, merge, or current-main dates, and never collapse the fields into one “release date.” Resolve ordering from the applicable primary evidence rather than tag names. Preserve the complete ledger internally, but summarize only material changes, conflicts, and gaps in the report. Where sources disagree, do not select a convenient chronology: state the conflict and lower confidence.

## 6. Compare schema, migrations, and defaults

For each managed configuration item and discovered release change:

1. Identify the target schema/type/validation and the source symbol that consumes the value.
2. Identify migration and compatibility paths: renamed keys, value translations, deprecated aliases, removed values, one-time transforms, persisted migration state, and warning/error behavior. Compare semantics, including narrowed, widened, dropped, and fallback behavior; alias acceptance alone is not compatibility proof.
3. Establish the upstream default for the target version from source/schema/tests, not memory or an older documentation page. Record inheritance and conditional defaults.
4. Classify every explicit key as **current-schema valid**, **compatibility-migrated legacy**, **ignored/unknown**, **wrong-type**, **intentional non-default**, or **default-equal pin**. Record the source-backed effective behavior for the classification.
5. A retained default-equal pin requires documented reproducibility or behavior rationale. Without that rationale, recommend removal; do not silently remove it.
6. Compare repository intent against target semantics. An omitted key can still inherit changed behavior.

Never remove a setting merely because it now matches a default. First establish whether default behavior is conditional and whether removal would alter future-upgrade reproducibility. Do not apply migrations or write transformed configuration during the audit.

## 7. Derive effective main, profile, and overlay behavior

Compare effective executions, not isolated files. Build an invocation matrix covering the base, every named profile, every overlay, each applicable project configuration, and runtime overrides (CLI arguments, environment, launchers, and current working directory). For every row, record source/base path, selection command/arguments, precedence, inherited versus replaced layers, observed or source-traced result, and safety caveats.

- **Main/base:** inspect the normal `omp` invocation and the base directory/configuration it actually discovers. Confirm precedence using target-version source or safe inspection, not a guessed path.
- **Named profile:** identify the actual profile-selection command or environment contract in the target version. A profile may relocate to a complete alternate base rather than overlay the main base; inventory its independently deployed rules, agents, extensions, skills, auth, and state. Never assume inheritance.
- **CLI overlay:** record the literal safe command shape, such as `omp --config <overlay-path> …` only where target-version evidence confirms it. Determine whether the overlay merges with the base or replaces a configuration layer, and preserve argument order and working-directory effects.

Do not treat ordinary `omp config` loading as read-only: it may initialize storage, run migrations, or write state. Until target-version persistence behavior is established, never use live CLI configuration inspection as read-only evidence. Prefer the installed target's `Settings.loadReadOnly()` path when available, or inspect a disposable isolated copy. Commands used for evidence must otherwise be read-only, bounded, and secret-safe. Do not use interactive commands that can initialize state or commands that put credentials/configuration contents in history or output. Treat user arguments as opaque data. Note that a launcher can add environment variables or arguments whose precedence differs from file contents, and that management subcommands may not accept the same overlay flag as interactive OMP. Report a proven effective invocation with its preconditions and caveats, not a generic command recipe.

## 8. Trace semantics to source

For every material candidate, follow the chain from release claim to implementation: changelog/tag → schema/default/migration → parser/loader/merge logic → consuming subsystem → observable behavior or focused existing test. Capture exact symbols, conditionals, precedence, and error/fallback behavior.

Use semantic source navigation where available. Search narrowly for configuration keys, migration names, commands, feature flags, public extension APIs, and consumer symbols; read their definitions and callers. Do not equate a string match, documentation sentence, or accepted schema field with a behavioral contract. If tracing stops at generated, bundled, unavailable, or incompatible source, mark the conclusion unknown and name the missing evidence.

## 9. Triage workflow-relevant features

Evaluate changes only for their impact on this repository's real workflows. Triage changes affecting agent delegation, tool permissions, context/compaction, model/provider resolution, skills, rules, commands, extensions, configuration discovery, security/authentication boundaries, session behavior, and managed launchers. Deprioritize cosmetic or unrelated changes with a recorded rationale.

For each relevant feature, state the triggering version range, affected workflow and surface, old versus target semantics, whether the path is configured/defaulted/migrated/disabled/unknown, risk to users, evidence quality, and a concrete decision or follow-up. Do not overstate an optional feature as enabled merely because it exists upstream, and never bulk-enable optional features as an audit response.

## 10. Audit extension compatibility separately

Treat each managed extension as code crossing a public API boundary, not as a configuration key. For every extension, establish target API availability and signatures, registration/discovery conventions, command/hook lifecycle, permission and authentication implications, startup/reload requirements, error handling, and the presence of focused tests or source-level compatibility evidence.

Separate extension findings from core OMP configuration conclusions. An unchanged config can still be unsafe if an extension relies on changed host behavior. Extension existence, discovery, or YAML validity is not extension compatibility evidence. Do not reload, install, remove, or invoke a mutating extension as audit evidence unless separately authorized. Mark extensions with unavailable target source or no exercised contract as unknown rather than assuming compatibility.

## 11. Separate maintenance findings from compatibility

Report compatibility, maintenance, and user-preservation findings in distinct sections:

- **Compatibility:** target behavior versus the intended managed workflow.
- **Maintenance:** stale comments, obsolete pins, outdated links, deployment assumptions, dead compatibility code, missing focused coverage, or ownership/documentation drift.
- **User preservation:** behavior that merges, rejects, backs up, retains, or risks replacing user-owned state.

A maintenance cleanup is not proof of target compatibility, and an upstream compatibility change is not authority to rewrite user files. Keep proposals narrow and avoid broad reformatting or unrelated cleanup.

## 12. Obtain independent review

Before finalizing material findings, assign an independent reviewer the scope, ledger, claims, source references, and classifications—not a conclusion to endorse. Require the reviewer to challenge release ordering, target identity, schema/default inference, configuration precedence, migration assumptions, security/secret handling, extension claims, preservation effects, and missing counterevidence.

Reconcile every challenge in writing: adopt it, rebut it with source evidence, or downgrade the finding to unknown. The independent review is not a substitute for primary-source tracing and must not mutate the repository or live configuration.

## 13. Report a decision-ready result

Lead with the audit boundary and target identity, then provide:

1. **Executive outcome:** material compatible behavior, decisions required, blockers, and audit limitations.
2. **Inventory and chronology:** safe target/repository/live identities plus the summarized release ledger and conflicts.
3. **Finding table:** classification, affected surface/workflow, release range, effective-behavior conclusion, evidence links/paths, risk, confidence, and owner/next action.
4. **Extension and maintenance sections:** separately classified findings and user-preservation concerns.
5. **Unknowns:** missing source, inaccessible live evidence, ambiguous version mapping, or unproven runtime behavior; never disguise these as pass results.
6. **Appendix/internal ledger:** complete per-release evidence retained as needed, with secrets excluded.

Report material changes rather than a changelog dump. Quote only minimal non-sensitive evidence. Make no version-specific conclusion that is not supported by the audit's own boundary and sources.

## 14. Optional later remediation

If the user asks to remediate after reviewing the audit, create a separate, explicit change scope. Preserve the evidence ledger, select only accepted findings, identify exact owning files and user-preservation behavior, and obtain any required approvals before touching live/shared state. Do not silently convert audit candidates into edits, upgrades, dependency changes, migrations, extension reloads, or deployments.

For each remediation, define an observable target behavior, rollback/preservation plan, focused validation, and whether an upstream upgrade or user confirmation is required. Re-run the affected comparisons after the change; do not reuse pre-change conclusions as verification.

## 15. Verify the audit and any approved follow-up

Before delivery, verify that the procedure was followed: the boundary is explicit; target identity is reconciled; every material claim has a traceable primary source; defaults, migrations, and effective precedence were distinguished; extension and maintenance conclusions were separated; secrets were excluded; and user changes remain untouched.

For approved remediation, run only the smallest credible, safe verification for the changed contract—for example, a focused static/configuration check plus a read-only effective-state observation or existing targeted test. Confirm that preserved user-owned files remain preserved. Report commands/results, unavailable checks, and residual risk exactly; a formatter, syntax check, or successful file write alone is not verification of effective behavior.
