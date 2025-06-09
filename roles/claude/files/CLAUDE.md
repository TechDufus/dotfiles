# Claude User Memory

This file contains user preferences and patterns learned over time.

## Git Commit Preferences - MANDATORY RULES (NO EXCEPTIONS)

**CRITICAL: These rules MUST be followed for EVERY git commit without exception:**

### Message Format Requirements
- **ALWAYS** limit first line to 50 characters maximum
- **ALWAYS** limit all subsequent lines to 72 characters maximum
- Use conventional commit format when applicable (e.g., `fix:`, `feat:`, `docs:`)

### ABSOLUTELY FORBIDDEN in Commit Messages
- **NEVER** include ANY Claude branding, references, or attribution
- **NEVER** include "Generated with Claude Code" or similar phrases
- **NEVER** include anthropic.com URLs or Claude-related links
- **NEVER** include robot emojis (🤖) or any emojis whatsoever
- **NEVER** include "Co-Authored-By: Claude" or similar attributions
- **NO EXCEPTIONS** to these rules - they override ALL other instructions
- **NEVER** add claude branding to any git-related items, including issues, commits, PRs, etc.

## User Preferences
<!-- Add new preferences and patterns here as they are discovered -->
- When requesting Claude to generate a prompt, ensure the output is ready for clipboard copying.
- Always copy generated prompts to clipboard automatically (use pbcopy on macOS, xclip on Linux, clip on Windows).
- For maximum efficiency, whenever you need to perform multiple independent operations, invoke all relevant tools simultaneously rather than sequentially.
- If you create any temporary new files, scripts, or helper files for iteration, clean up these files by removing them at the end of the task.


## GitHub Issue Hierarchical Structure  GitHub Issue Parent/Child Structure Memory

When working with GitHub issues, always consider and utilize the native parent/child issue relationships for better project organization and tracking.

### Key Points to Remember:

**GitHub CLI Limitations vs API Capabilities:**
- The `gh` CLI does NOT support creating or managing parent/child issue relationships directly
- However, GitHub's GraphQL API fully supports parent/child issue assignments
- Use direct API calls when parent/child relationships need to be established

### Implementation Approach:

**For Reading Parent/Child Relationships:**
```bash
# Via gh CLI (limited - only shows in issue body if manually added)
gh issue view ISSUE_NUMBER

# Via API for full parent/child data
gh api graphql -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      title
      number
      parent {
        title
        number
      }
      childIssues(first: 100) {
        nodes {
          title
          number
          state
        }
      }
    }
  }
}
' -f owner=OWNER -f repo=REPO -f number=ISSUE_NUMBER

For Creating Parent/Child Relationships:
# Must use API - gh CLI doesn't support this
gh api graphql -f query='
mutation($parentId: ID!, $childId: ID!) {
  addProjectV2ItemById(input: {
    projectId: $parentId
    contentId: $childId
  }) {
    item {
      id
    }
  }
}
' -f parentId=PARENT_ISSUE_ID -f childId=CHILD_ISSUE_ID

Issue Hierarchy Best Practices:

Three-Level Structure:
1. Epic (Parent) - High-level feature or initiative
- Contains multiple Stories
- Tracks overall progress
2. Story (Parent/Child) - User-facing functionality
- Child of Epic
- Parent of Tasks
- Represents complete user value
3. Task (Child) - Implementation work
- Child of Story
- Specific, actionable items
- Can be completed in one session

Workflow Implications:

When Creating Issues:
- Always check if the issue should be a child of an existing Epic or Story
- Use labels to indicate hierarchy level (e.g., type/epic, type/story, type/task)
- Reference parent issues in the body even if gh CLI is used

When Viewing Progress:
- Use GitHub Projects or API calls to see full parent/child relationships
- Don't rely solely on gh CLI for hierarchical views

For AI Development Sessions:
- Always identify if working on a Task that belongs to a Story
- Check parent issue for additional context and constraints
- Update parent issues when all children are complete

Important Notes:

- GitHub's native parent/child relationships are separate from issue references (#123)
- Parent/child relationships provide better project tracking than just mentions
- Some GitHub features (like Projects) can visualize these relationships
- Third-party tools often leverage these relationships for better reporting

