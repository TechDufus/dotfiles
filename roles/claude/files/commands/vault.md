---
description: "Cross-project vault access: /vault <capture|daily|search> [args]"
---

# /vault - SecondBrain Vault Integration

Access your Obsidian vault from any project. Query knowledge, capture thoughts, update daily notes.

## Usage

```
/vault capture <text>        # Quick capture to inbox
/vault daily                 # Read today's daily note
/vault daily + <text>        # Append to today's daily note
/vault search <query>        # Search vault (agent-based)
```

## Arguments: $ARGUMENTS

---

## Configuration

```
VAULT_PATH: $HOME/Documents/SecondBrain
VAULT_AGENT: {VAULT_PATH}/99 - Meta/claude/agents/vault.md
INBOX_PATH: 08 - In
DAILY_PATH: 06 - Daily Notes
DAILY_FORMAT: MM-DD-YYYY-Daily Note.md
```

**Note**: The vault-specific agent definition lives IN the vault itself (private), not in this command file (public). This allows the command to be shared while keeping vault structure details private.

---

## Subcommand: capture

**Pattern**: `/vault capture <text>`

**Execution** (direct, no agent):

1. Determine target file: `{VAULT_PATH}/{INBOX_PATH}/Quick Captures.md`
2. If file doesn't exist, create with frontmatter:
   ```markdown
   ---
   created: {today}
   tags:
     - inbox
     - quick-capture
   ---
   # Quick Captures

   Rapid captures from Claude Code sessions.

   ---
   ```
3. Append entry:
   ```markdown

   ## {timestamp} - from {current_project_name}
   {captured text}

   ```
4. Confirm: "Captured to vault inbox"

**Current project detection**:
- If in git repo: use repo directory name
- Otherwise: use current directory name

---

## Subcommand: daily

**Pattern**: `/vault daily` or `/vault daily + <text>`

**Read mode** (`/vault daily`):

1. Calculate today's date path:
   - Year folder: `{YYYY}`
   - Month folder: `{MM}-{MMMM}` (e.g., `01-January`)
   - File: `{MM-DD-YYYY}-Daily Note.md`
   - Full path: `{VAULT_PATH}/{DAILY_PATH}/{year}/{month}/{file}`

2. Read the file and display to user

3. If file doesn't exist, report: "No daily note for today. Create one in Obsidian first."

**Append mode** (`/vault daily + <text>`):

1. Find today's daily note (same path logic)

2. If file doesn't exist, report error (don't create - daily notes should be created via Obsidian template)

3. Find the `# Notes` section (look for `# 📝 Notes` or `# Notes`)

4. Append after the first bullet point under Notes:
   ```markdown
   - [{HH:MM}] {text} #from-claude
   ```

5. Confirm: "Added to today's daily note"

---

## Subcommand: search

**Pattern**: `/vault search <query>`

**Execution** (spawns agent for context efficiency):

The agent first reads its configuration from the vault, then executes the search. This keeps vault-specific knowledge private.

```
Task(
  subagent_type: "general-purpose",
  description: "Search vault for query",
  prompt: """
  ## Step 1: Load Your Agent Configuration

  First, read your agent instructions:
  $HOME/Documents/SecondBrain/99 - Meta/claude/agents/vault.md

  This file contains vault-specific knowledge: folder structure, conventions, tags, and search strategies.

  ## Step 2: Execute Search

  Search the vault for: {query}

  Use the search strategies and exclusions defined in your agent configuration.

  ## Step 3: Return Results

  Return a concise summary:

  ### Search Results: "{query}"

  **Files Found**: {count}

  **Most Relevant**:
  1. `{relative_path}` - {one-line summary of relevance}
  2. ...

  **Key Excerpts**:
  > {relevant quote from most relevant file}
  > — [[{note name}]]

  **Connections**: {any wiki-links or tags that connect these notes}

  If no results found, say so clearly and suggest alternative queries.
  """
)
```

**After agent returns**: Display the synthesized results to user.

---

## Examples

### Quick capture from any project
```
/vault capture TIL: kubectl drain needs --ignore-daemonsets flag
```
→ Appends to `08 - In/Quick Captures.md` with timestamp and project context

### Check today's notes
```
/vault daily
```
→ Displays today's daily note content

### Add to daily note while working
```
/vault daily + discussed postgres migration strategy with team
```
→ Appends to Notes section with timestamp and #from-claude tag

### Search for past knowledge
```
/vault search terraform state
```
→ Agent searches vault, returns relevant notes about terraform state management

---

## Future Extensions

These are not implemented yet but could be added:

```
/vault context              # Auto-infer relevant notes from current project
/vault link <note>          # Create bidirectional link between project and note
/vault learn <insight>      # Store to permanent notes with proper categorization
/vault weekly               # Weekly review synthesis
```

All agent-based operations would use the same pattern: read `{VAULT_PATH}/99 - Meta/claude/agents/vault.md` first, then execute.

---

## Customizing the Vault Agent

The vault agent definition lives at:
```
{VAULT_PATH}/99 - Meta/claude/agents/vault.md
```

Edit this file to:
- Add personal context (goals, projects, preferences)
- Define custom search strategies
- Add new tag conventions
- Include accountability/coaching instructions
- Reference other notes for context (reading lists, current projects)

This file is private to your vault and never shared via the public command.

---

## Error Handling

- **Vault not found**: Check VAULT_PATH exists, report if missing
- **Agent file missing**: If `{VAULT_PATH}/99 - Meta/claude/agents/vault.md` doesn't exist, report and suggest creating it
- **Daily note missing**: Don't create - suggest opening Obsidian
- **Search no results**: Report clearly, suggest alternative queries
- **Permission errors**: Report and suggest checking file permissions
