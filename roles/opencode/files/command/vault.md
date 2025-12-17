---
description: "Cross-project vault access: /vault <subcommand> [args]"
---

# /vault - SecondBrain Vault Integration

Access your Obsidian vault from any project. All operations delegate to your vault's agent for structure-specific handling.

## Arguments: $ARGUMENTS

## Configuration

```
VAULT_PATH: $HOME/Documents/SecondBrain
VAULT_AGENT: {VAULT_PATH}/99 - Meta/claude/agents/vault.md
```

---

## Execution

All subcommands spawn a @general subagent that first loads the vault-specific configuration, then executes the requested operation.

@general **Vault Operation**: Execute the following vault command.

**Step 1: Load Vault Agent Configuration**
Read your agent instructions first:
`$HOME/Documents/SecondBrain/99 - Meta/claude/agents/vault.md`

This file contains all vault-specific knowledge: structure, conventions, paths, and operation handlers.

**Step 2: Execute Operation**
- **Subcommand**: Parse from $ARGUMENTS
- **Context**: Called from current project at current working directory

Execute this operation according to your agent configuration.

**Step 3: Return Results**
Return concise, actionable output appropriate for the operation type.

---

## Subcommands

| Command | Purpose |
|---------|---------|
| `capture <text>` | Quick capture to inbox |
| `daily` | Read today's daily note |
| `daily + <text>` | Append to today's daily note |
| `search <query>` | Search vault for relevant notes |
| `triage` | Review inbox items and suggest destinations |
| `triage --process` | Interactively sort inbox items |

---

## Examples

```bash
# Quick capture from any project
/vault capture TIL: kubectl drain needs --ignore-daemonsets flag

# Check today's notes
/vault daily

# Add to daily note while working
/vault daily + discussed postgres migration strategy with team

# Search for past knowledge
/vault search terraform state

# Review what's accumulated in inbox
/vault triage

# Process inbox items interactively
/vault triage --process
```

---

## Extending

To add new subcommands or modify behavior, edit the vault agent file:
```
$HOME/Documents/SecondBrain/99 - Meta/claude/agents/vault.md
```

The command file (this file) stays generic. All vault-specific logic lives in your private agent configuration.
