---
name: github-issue-hierarchy
description: Create GitHub issues with optional parent/sub-issue relationships and organization issue types. Use when the user asks to create, link, or retag GitHub issues, especially when they mention a parent issue, sub-issues, tasks, bugs, epics, or cross-repo issue hierarchy.
metadata:
  short-description: Hierarchical GitHub issues
---

# GitHub Issue Hierarchy

Use this skill when issue creation needs hierarchy or issue types, not just a plain `gh issue create`.

## Defaults

- If the user wants a plain issue with no parent and no issue type, `gh issue create` is enough.
- If the user gives a parent issue, asks for a sub-issue, or wants an issue type like `Task` or `Epic`,
  use the bundled helper: [scripts/gh-issue-hierarchy.sh](scripts/gh-issue-hierarchy.sh).
- Do not invent a parent issue. Link only when the user or current task context identifies one.

## Workflow

1. Decide the repository.
   - Prefer an explicit repo from the user.
   - Otherwise use the current checkout or `GITHUB_REPOSITORY`.
2. Write the issue title and body from the current task context.
3. Check issue-type support when a type matters:
   - Run `scripts/gh-issue-hierarchy.sh issue-types --repo owner/repo`
   - If `supported` is `false`, the repo does not expose organization issue types. Do not force one.
   - If `lookup_error` is present, treat that as an org-level permission or feature-availability failure and tell the user plainly.
   - If `supported` is `true`, match the requested type name case-insensitively against the returned list.
4. Create the issue:
   - If a parent or issue type is involved, use the helper's `create` subcommand so the issue is created
     with `parentIssueId` and `issueTypeId` in one call.
5. Update existing issues when needed:
   - Use `link` to attach an existing child to a parent.
   - Use `set-type` to change an existing issue's type.

## Commands

Check issue-type support for a repo:

```bash
roles/codex/files/skills/github-issue-hierarchy/scripts/gh-issue-hierarchy.sh issue-types \
  --repo owner/repo
```

Create a child issue with an org issue type:

```bash
roles/codex/files/skills/github-issue-hierarchy/scripts/gh-issue-hierarchy.sh create \
  --repo owner/repo \
  --title "Implement session refresh" \
  --body-file /tmp/issue-body.md \
  --parent "owner/repo#123" \
  --type Task
```

Link an existing issue as a sub-issue:

```bash
roles/codex/files/skills/github-issue-hierarchy/scripts/gh-issue-hierarchy.sh link \
  --parent "owner/repo#123" \
  --child "owner/repo#456"
```

Reassign a child that already has a parent:

```bash
roles/codex/files/skills/github-issue-hierarchy/scripts/gh-issue-hierarchy.sh link \
  --parent "owner/repo#123" \
  --child "owner/repo#456" \
  --replace-parent
```

Change an existing issue type:

```bash
roles/codex/files/skills/github-issue-hierarchy/scripts/gh-issue-hierarchy.sh set-type \
  "owner/repo#456" \
  --type Bug
```

## Notes

- The current `gh issue create` and `gh issue edit` CLI surface still has no issue-type flag, so use the
  helper whenever issue types are relevant.
- GitHub documents REST sub-issue endpoints under `/repos/{owner}/{repo}/issues/{issue_number}/sub_issues`,
  but the helper uses GraphQL for create and link flows because `createIssue`, `addSubIssue`, and
  `updateIssueIssueType` compose cleanly with global node IDs.
- Organization issue types are discovered from the org-scoped REST endpoint. Personal repositories should
  be treated as having no issue-type support.
- Querying org issue types is permission-sensitive. A `supported: false` result with `lookup_error` usually
  means the token cannot read org issue-type settings, not necessarily that the repo can never use them.
- If `lookup_error` mentions `admin:org`, the current `gh` auth is too weak to discover type IDs by name.
  Tell the user and either skip the type or have them run `gh auth refresh -h github.com -s admin:org`.
