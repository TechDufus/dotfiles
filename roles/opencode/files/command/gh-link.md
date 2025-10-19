---
description: "Link GitHub issues: /gh-link <parent> <child>"
---

Link a child issue to a parent issue, creating a hierarchical relationship.

## Usage

```
/gh-link <parent-issue> <child-issue>
```

## Implementation

!`~/.config/opencode/scripts/gh-link-sub-issue.sh $ARGUMENTS`

## Examples

```
/gh-link 5 10      # Link issue #10 as child of #5 in current repo
/gh-link 5 "org/repo#42"  # Link cross-repo issue
```

## What It Does

1. Validates both issues exist
2. Adds reference to parent issue in child's body
3. Adds tasklist item to parent issue
4. Creates bidirectional linkage
