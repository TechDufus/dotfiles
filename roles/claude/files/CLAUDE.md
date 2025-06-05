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

## User Preferences
<!-- Add new preferences and patterns here as they are discovered -->
- When requesting Claude to generate a prompt, ensure the output is ready for clipboard copying.
- Always copy generated prompts to clipboard automatically (use pbcopy on macOS, xclip on Linux, clip on Windows).