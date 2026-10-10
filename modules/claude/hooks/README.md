# Claude Code Hooks

This directory contains hooks that execute in response to Claude Code events.

## Available Hooks

Hooks are shell scripts that run at specific points during Claude Code operations:

- `pre-read` - Before reading a file
- `post-read` - After reading a file
- `pre-write` - Before writing to a file
- `post-write` - After writing to a file
- `pre-edit` - Before editing a file
- `post-edit` - After editing a file
- `pre-bash` - Before executing a bash command
- `post-bash` - After executing a bash command

## Hook Environment Variables

When a hook runs, it has access to:
- `CLAUDE_HOOK_TYPE` - The type of hook (e.g., "pre-read", "post-write")
- `CLAUDE_HOOK_PATH` - The file path being operated on (for file operations)
- `CLAUDE_HOOK_COMMAND` - The bash command being run (for bash operations)

## Example Hook

Create executable scripts in this directory with the hook name:

```bash
#!/bin/bash
# pre-write hook example

# Check if writing to a protected file
if [[ "$CLAUDE_HOOK_PATH" == *"/etc/"* ]]; then
    echo "Error: Cannot write to system files in /etc/"
    exit 1
fi

# Log all write operations
echo "$(date): Writing to $CLAUDE_HOOK_PATH" >> ~/.claude/write.log
```

## Exit Codes

- Exit code 0: Allow the operation to proceed
- Exit code 1-255: Block the operation and show the hook's output as an error

## Creating Hooks

1. Create a new file with the hook name (e.g., `pre-write`)
2. Make it executable: `chmod +x pre-write`
3. The hook will run automatically when the corresponding event occurs