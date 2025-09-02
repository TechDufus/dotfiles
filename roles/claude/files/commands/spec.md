---
description: "SPEC methodology guide and command helper: /spec [help|next|commands]"
---

# SPEC Methodology Assistant

## Query: $ARGUMENTS

Your intelligent guide to the SPEC methodology and command workflow.

## Process

### If no arguments or "help":
```
═══════════════════════════════════════════════════════════
🚀 SPEC Methodology Quick Start
═══════════════════════════════════════════════════════════

SPEC uses the SPARC framework for structured development:
S - Specification: Gather requirements
P - Pseudocode: Design algorithms  
A - Architecture: Create technical blueprint
R - Refinement: Optimize and improve
C - Completion: Finalize and archive

📋 Basic Workflow:
1. /spec-init my-feature         - Start new feature
2. /spec-architect my-feature    - Design architecture
3. /spec-implement my-feature    - Build implementation
4. /spec-validate my-feature     - Run quality checks
5. /spec-refine my-feature       - Optimize
6. /spec-complete my-feature     - Finalize

💡 Get Started:
• First time? Run: /spec-init <feature-name>
• Check progress: /spec-status
• See all commands: /spec commands
• What to do next: /spec next
```

### If "next" - Intelligent next step suggestion:
```python
# Check current state and suggest next action
def suggest_next_action():
    if not exists("SPECS/"):
        return """
        🎯 Next Step: Initialize your first SPEC feature
        
        Run: /spec-init <feature-name> "<description>"
        
        Example:
        /spec-init user-auth "Add JWT authentication to API"
        """
    
    active_features = scan("SPECS/active/")
    
    if not active_features:
        return """
        🎯 Next Step: Start a new feature
        
        No active features found.
        Run: /spec-init <feature-name> "<description>"
        """
    
    for feature in active_features:
        state = load(f"{feature}/.state/progress.json")
        
        if state.phase == "specification":
            return f"""
            🎯 Next Step for {feature}: Create architecture
            
            Specification complete. Time to design!
            Run: /spec-architect {feature}
            """
        
        elif state.phase == "architecture":
            return f"""
            🎯 Next Step for {feature}: Start implementation
            
            Architecture ready. Let's build!
            Run: /spec-implement {feature}
            """
        
        elif state.phase == "implementation":
            if not state.validation_passed:
                return f"""
                🎯 Next Step for {feature}: Run validation
                
                Implementation needs validation.
                Run: /spec-validate {feature}
                """
            else:
                return f"""
                🎯 Next Step for {feature}: Refine implementation
                
                Validation passed! Time to optimize.
                Run: /spec-refine {feature}
                """
        
        elif state.phase == "refinement":
            return f"""
            🎯 Next Step for {feature}: Complete feature
            
            Refinement done. Ready to ship!
            Run: /spec-complete {feature}
            """
```

### If "commands" - Show command reference:
```
═══════════════════════════════════════════════════════════
📚 SPEC Command Reference
═══════════════════════════════════════════════════════════

🚀 Core Workflow Commands:
├─ /spec-init <name> [desc]      Start new feature
├─ /spec-architect <name>        Design technical blueprint
├─ /spec-implement <name>        Build with TDD
├─ /spec-validate <name>         Run quality gates
├─ /spec-refine <name>           Optimize implementation
└─ /spec-complete <name>         Finalize and archive

📊 Management Commands:
├─ /spec-status [name|all]       View progress
├─ /spec-rollback <name> [id]    Revert to checkpoint
└─ /spec                         This help menu

🔍 Quick Examples:
# Start a new feature
/spec-init api-search "Add full-text search to API"

# Check what to do next
/spec next

# View all active features
/spec-status all

# Run validation on specific feature
/spec-validate api-search

# Rollback if something goes wrong
/spec-rollback api-search

💡 Pro Tips:
• Always run /spec-validate after implementation
• Use /spec-status to track progress
• Create checkpoints before risky changes
• Run /spec next when unsure what to do
```

### If specific feature name provided:
```python
def show_feature_guide(feature_name):
    if not exists(f"SPECS/active/{feature_name}"):
        return f"""
        ❌ Feature '{feature_name}' not found
        
        Available features:
        {list_active_features()}
        
        To create new: /spec-init {feature_name}
        """
    
    state = load_feature_state(feature_name)
    return generate_contextual_help(state)
```

## Interactive Mode Examples

### Scenario 1: Brand New User
```
User: /spec
Assistant: Shows quick start guide with basic workflow

User: /spec next
Assistant: "Start your first feature with /spec-init"

User: /spec-init my-api
Assistant: Begins interactive requirements gathering
```

### Scenario 2: Mid-Development
```
User: /spec next
Assistant: Checks current phase, suggests next command
"You're in implementation. Run /spec-validate my-api"

User: /spec-status
Assistant: Shows progress dashboard
```

### Scenario 3: Troubleshooting
```
User: /spec my-api
Assistant: Shows feature-specific status and options
"my-api is failing validation. Here's what to fix..."
```

## Command Aliases for Convenience

```bash
# Short aliases
/s        → /spec
/sn       → /spec next
/ss       → /spec-status
/si       → /spec-init
/sv       → /spec-validate

# Legacy PRP compatibility
/prp-init    → /spec-init
/prp-build   → /spec-architect
/prp-execute → /spec-implement
```

## Smart Suggestions

The system provides contextual help based on:
- Current phase of active features
- Validation failures that need attention
- Blocked items requiring input
- Time since last activity
- Common next steps for the situation

## Notes
- This is the main entry point for SPEC methodology
- Always provides actionable next steps
- Context-aware suggestions based on current state
- Helps prevent getting stuck or confused
- Gradually teaches the workflow through use