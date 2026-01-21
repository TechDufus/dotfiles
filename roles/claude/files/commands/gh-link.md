---
description: "Link GitHub issues: /gh-link <parent> <child> [--force]"
argument-hint: "<parent> <child> [--force]"
allowed-tools:
  - Bash(gh:*)
  - Bash(~/.claude/scripts/gh-link-sub-issue.sh:*)
---

# /gh-link

Link two existing GitHub issues in a parent/child relationship.

## Usage

```
/gh-link <parent-issue> <child-issue> [--force]
```

## Parameters

- `parent-issue`: Parent issue reference (formats: `123`, `#123`, or `org/repo#123`)
- `child-issue`: Child issue reference (formats: `123`, `#123`, or `org/repo#123`)
- `--force`: Optional - Remove existing parent relationship and reassign

## Examples

```
# Link issues in same repository
/gh-link 5 12
/gh-link 10 25 --force

# Link issues across repositories
/gh-link TechDufus/dotfiles#42 27
/gh-link 19 org/other-repo#55
/gh-link org/repo1#100 org/repo2#200 --force
```

## Features

- Creates native GitHub parent/sub-issue relationships
- Supports cross-repository linking within the same organization
- Auto-detects current repository for relative issue numbers
- Force flag to reassign existing relationships
- Validates both issues exist before linking

## Notes

- Child issues can only have one parent
- Use `--force` to change an existing parent relationship
- The script will scan recent issues to find existing parents when using force

## Environment Variables

- `GITHUB_REPOSITORY`: Override auto-detected repository (format: owner/repo)

## Implementation

Execute the following command with the provided arguments:

```bash
~/.claude/scripts/gh-link-sub-issue.sh "<parent-issue>" "<child-issue>" [--force]
```

**Important:** Always quote issue references containing `#` to prevent shell interpretation as comments:
- ✅ `~/.claude/scripts/gh-link-sub-issue.sh "org/repo#123" "27"`
- ❌ `~/.claude/scripts/gh-link-sub-issue.sh org/repo#123 27` (# will be treated as comment)

### Script Location
`~/.claude/scripts/gh-link-sub-issue.sh`

### What the script does
1. Validates both issues exist in the repository
2. Gets the database ID of the child issue
3. If --force is used, attempts to remove existing parent relationships
4. Creates the parent/child relationship via GitHub API
5. Provides feedback on success or failure

### Error Handling
- If child already has a parent: suggests using --force
- If issues don't exist: reports which issue number is invalid
- If linking fails: provides specific error message