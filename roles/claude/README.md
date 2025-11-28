# 🤖 Claude Code Configuration

> A batteries-included [Claude Code](https://claude.ai/code) setup with intelligent workflow routing, GitHub automation, and self-improving patterns.

[![Platform: macOS](https://img.shields.io/badge/platform-macOS-blue.svg)](https://www.apple.com/macos/)
[![Ansible Role](https://img.shields.io/badge/ansible-role-red.svg)](https://www.ansible.com/)
[![Commands: 18](https://img.shields.io/badge/commands-18-green.svg)](#commands)
[![Skills: 3](https://img.shields.io/badge/skills-3-purple.svg)](#skills)
[![Scripts: 11](https://img.shields.io/badge/scripts-11-orange.svg)](#helper-scripts)

---

## Philosophy

This configuration treats Claude Code as a **collaborative development partner**, not just a code generator. Key principles:

- **Intelligent Routing** - Let the agent decide the best approach based on task complexity
- **Context Efficiency** - Minimize token waste through smart session management
- **Self-Improvement** - Learn from logs and encode patterns into CLAUDE.md
- **Git as Safety Net** - No custom checkpoints; trust version control

---

## Platform Support

| Platform | Status | Installation Method |
|----------|--------|-------------------|
| macOS    | ✅ Full Support | Homebrew Cask (`claude-code`) |
| Ubuntu   | 🔄 Planned | TBD |
| Fedora   | 🔄 Planned | TBD |
| Arch     | 🔄 Planned | TBD |

---

## Quick Start

```bash
# Deploy with dotfiles
dotfiles -t claude

# Start working
claude
/work implement user authentication
```

---

## What Gets Installed

### Application
- **claude-code**: Anthropic's official CLI tool (installed via Homebrew Cask on macOS)

### Configuration Structure
All configuration files are symlinked from this role to enable version control:

```
~/.claude/
├── settings.json         # Core settings (permissions, hooks, 900+ allowed operations)
├── CLAUDE.md            # Global user memory and project standards
├── commands/            # 18 slash command definitions
├── skills/              # 3 built-in skills (git-commit-validator, workflow-router, skill-creator)
├── scripts/             # 11 GitHub workflow scripts (1,634 lines of shell)
├── hooks/               # Lifecycle hooks (PreToolUse, Stop, SubagentStop, Notification)
├── agents/              # Custom agent configurations
├── memory/              # Project constitution templates
└── output-styles/       # Custom output formatting (hyper-concise, etc.)
```

### Key Features

```mermaid
graph TD
    A[Task Input] --> B{Workflow Router}
    B -->|"#123"| C[GitHub Mode]
    B -->|"fix typo"| D[Quick Mode]
    B -->|"where is X"| E[Research Mode]
    B -->|"A and B and C"| F[Parallel Mode]
    B -->|"implement feature"| G[Structured Mode]
    C --> H[/gh-work]
    D --> I[Direct Execution]
    E --> J[Explore Subagent]
    F --> K[Concurrent Tasks]
    G --> L[Plan + TodoWrite]
```

**Security:**
- 900+ allowed bash operations (git, npm, docker, kubectl, etc.)
- 150+ pre-approved documentation domains for WebFetch
- Denied operations: sudo, filesystem destruction, credential access
- Permission mode: acceptEdits (with granular controls)

**Automation:**
- Lifecycle hooks for status updates and session events
- Always Thinking Mode enabled
- Custom status line with dynamic updates
- Co-authored-by attribution disabled (clean git history)

---

## Commands

### Workflow Orchestration

| Command | Purpose | Key Capabilities |
|---------|---------|-----------------|
| `/work <task>` | **Primary entry point.** Analyzes task complexity and routes to optimal workflow | Auto-detection: GitHub refs, quick fixes, research, parallel, structured |
| `/commit [instructions]` | Streamlined commit workflow | Conventional format validation, `--staged` mode, git-commit-validator skill |
| `/prime [task hint]` | Build context for fresh sessions | Parallel subagent analysis, optional task focus |
| `/snapshot [name]` | Capture session state before `/clear` | Markdown export, context preservation |
| `/review-logs [--days N]` | Mine conversation logs for improvement patterns | Self-improving flywheel, `--apply` for auto-updates to CLAUDE.md |

### GitHub Integration

| Command | Purpose | Workflow |
|---------|---------|----------|
| `/gh-work <issue>` | End-to-end issue fixing | View issue → branch → implement → test → commit → push → PR |
| `/gh-issue <title>` | Create GitHub issues | Parent/child linking, hierarchy support |
| `/gh-issue-status <issue>` | Analyze issue hierarchies | EPIC → Story → Task visualization, `--comment`, `--update-body` |
| `/gh-link <parent> <child>` | Link issues in relationships | `--force` to override existing links |
| `/gh-review <pr>` | AI-powered PR review | Adaptive strategy based on size, security checks |

### Specialized

| Command | Purpose |
|---------|---------|
| `/init-ultrathink` | Generate comprehensive CLAUDE.md via 5 parallel analysis agents |
| `/stig [options]` | Evaluate STIG compliance in Kubernetes pods |
| `/stig-summary [--copy]` | Extract STIG evaluation summary for reporting |
| `/raft-gravity-comply` | DoD Gravity pipeline compliance orchestration |
| `/raft-gravity-assess` | Assessment phase of Gravity compliance |

---

## Skills

Reusable capabilities that extend Claude's behavior:

| Skill | When It Activates | Functionality |
|-------|-------------------|---------------|
| **git-commit-validator** | Every `git commit` operation | Enforces conventional commits (type/scope/description), 50/72 char limits, blocks AI attribution/branding, validates via script |
| **workflow-router** | Complex tasks requiring analysis | Task classification (< 30s): GitHub/Quick/Research/Parallel/Structured routing, validation integration, learning pattern tracking |
| **skill-creator** | Creating new skills | Guided workflow with best practice templates, skill.md generation, testing helpers |

**Usage:**
```bash
# Skills are invoked automatically or explicitly
claude
> Use the git-commit-validator skill to check this message: "feat: add auth"
```

---

## Architecture

```
~/.claude/
├── settings.json      → Permissions, allowed domains, hooks config
├── CLAUDE.md          → Global user memory (standards, preferences)
├── commands/          → Slash command definitions
├── skills/            → Reusable skill packages
├── scripts/           → Helper shell scripts
├── hooks/             → Lifecycle hooks (PreToolUse, Stop, etc.)
└── agents/            → Custom agent definitions
```

All paths are symlinked from this role, enabling version control and cross-machine sync.

---

## Workflow Patterns

### The `/work` Router

```
/work fix typo in README          → Quick mode (direct execution)
/work where is auth handled?      → Research mode (Explore subagent)
/work update tests AND fix docs   → Parallel mode (concurrent tasks)
/work implement OAuth2            → Structured mode (plan + TodoWrite)
/work #42                         → GitHub mode (delegates to /gh-work)
```

### Session Management

```bash
# Long session getting bloated?
/snapshot auth-progress           # Save state to .claude/snapshots/
/clear                            # Fresh context

# Resume next session
/prime continuing auth from snapshot
```

### Self-Improving Flywheel

```bash
/review-logs --days 30            # Analyze last 30 days
# Identifies: repeated errors, user corrections, inefficiencies
# Suggests: CLAUDE.md additions to prevent recurrence

/review-logs --apply              # Auto-append findings to CLAUDE.md
```

---

## Configuration Highlights

### Permissions (`settings.json`)

- **140+ WebFetch domains** - Documentation sites, package registries, cloud providers
- **Comprehensive Bash allowlist** - Git, npm, docker, kubectl, terraform, etc.
- **Security boundaries** - No sudo, restricted paths, no secrets access

### Standards (`CLAUDE.md`)

```markdown
## Git Behavior
- NEVER commit unless explicitly requested
- Skip local tests when CI/CD exists
- Delete obsolete code, don't deprecate

## Project Standards
- Conventional commits (validated by skill)
- Secrets via 1Password CLI only
- Clean up temp files after tasks
```

---

## Helper Scripts

**11 production shell scripts totaling 1,634 lines** available in `~/.claude/scripts/`:

| Script | Purpose | Key Features |
|--------|---------|-------------|
| `gh-create-issue.sh` | Create GitHub issues | `--parent` linking, `--body` content support |
| `gh-work-issue.sh <issue> [branch]` | Complete issue workflow | Auto-branch creation, fix implementation, PR creation |
| `gh-complete-fix.sh` | Finalize fix and cleanup | Branch cleanup, issue closing |
| `gh-link-sub-issue.sh <parent> <child>` | Link parent/child issues | `--force` to override, hierarchy management |
| `gh-ai-review.sh <pr-ref>` | AI-powered code review | Comprehensive analysis, security checks |
| `gh-issue-hierarchy.sh <issue>` | Display issue tree | `--format json/yaml/tree` options |
| `git-commit-helper.sh <message>` | Validate commit messages | Conventional format check, character limits, forbidden phrases |
| `statusline.sh` | Dynamic terminal status | Real-time session updates |
| `claude-dashboard` | Session monitoring | Active sessions, resource usage |
| `bash/common.sh` | Shared utilities | Logging, error handling, color output |

**Usage:**
```bash
# Direct invocation
~/.claude/scripts/gh-create-issue.sh "Bug: Login fails" --parent 42

# Or from Claude
claude
> Run the gh-work-issue.sh script for issue 123
```

---

## Installation

This role is part of the [dotfiles](https://github.com/TechDufus/.dotfiles) system:

```bash
# Install via dotfiles wrapper (recommended)
dotfiles -t claude

# Or install all dotfiles including Claude
dotfiles

# Manual Ansible invocation
ansible-playbook -t claude ~/.dotfiles/main.yml
```

### What Installation Does

1. **Installs claude-code** via Homebrew Cask (macOS only)
2. **Creates ~/.claude directory** if it doesn't exist
3. **Symlinks configuration** from role files to `~/.claude/`:
   - `settings.json` (permissions, hooks, environment)
   - `commands/` (18 slash commands)
   - `scripts/` (11 workflow scripts)
   - `skills/` (3 built-in skills)
   - `hooks/` (lifecycle hooks)
   - `agents/` (agent configs)
4. **Removes non-symlink files** to ensure version control

### Prerequisites

| Requirement | Purpose | Optional? |
|------------|---------|-----------|
| [Claude Code CLI](https://claude.ai/code) | Core application | No - installed by role on macOS |
| GitHub CLI (`gh`) | GitHub integration commands | Yes - for `/gh-*` commands |
| 1Password CLI (`op`) | Secrets management | Yes - for 1Password integration |
| Ansible | Role execution | No - required for dotfiles |
| Homebrew | macOS package manager | No - macOS installation method |

### Verification

```bash
# Check Claude Code installed
which claude
# → /Applications/Claude Code.app/Contents/MacOS/claude

# Verify configuration symlinks
ls -la ~/.claude/
# All directories should show → pointing to ~/.dotfiles/roles/claude/files/

# Test a command
claude /work --status
```

---

## Customization

### Adding Slash Commands

Create `files/commands/my-command.md` following this pattern:

```markdown
---
description: "Brief description: /my-command [args]"
---

# /my-command

## Usage
```
/my-command <required-arg> [optional-arg]
```

## Arguments: $ARGUMENTS

---

## Your Command Logic

Claude will execute the instructions below when this command is invoked...
```

After creating, re-run `dotfiles -t claude` to symlink the new command.

### Adding Skills

**Option 1: Use skill-creator (recommended)**
```bash
claude
> /work create a new skill for validating API responses
```

**Option 2: Manual creation**
```bash
mkdir -p files/skills/my-skill/scripts
touch files/skills/my-skill/skill.md
```

Structure:
```
files/skills/my-skill/
├── skill.md              # Main skill documentation
├── scripts/              # Supporting scripts
│   └── helper.sh
└── resources/            # Optional resources
```

### Modifying Permissions

Edit `files/settings.json` permissions section:

```json
{
  "permissions": {
    "allow": [
      "Bash(my-new-command:*)",
      "WebFetch(domain:my-site.com)"
    ],
    "deny": [
      "Bash(dangerous-operation:*)"
    ]
  }
}
```

Re-run `dotfiles -t claude` to apply changes.

### Extending Scripts

Add scripts to `files/scripts/`:
```bash
touch files/scripts/my-workflow.sh
chmod +x files/scripts/my-workflow.sh
```

Scripts become available at `~/.claude/scripts/my-workflow.sh` after running `dotfiles -t claude`.

---

## Troubleshooting

### Commands Not Appearing

```bash
# Verify symlink
ls -la ~/.claude/commands
# Should point to: ~/.dotfiles/roles/claude/files/commands

# If not, re-run installation
dotfiles -t claude
```

### Permission Denied on Scripts

```bash
# Make scripts executable
chmod +x ~/.dotfiles/roles/claude/files/scripts/*.sh

# Or fix via role
dotfiles -t claude
```

### Settings Changes Not Applied

Settings are symlinked, so edits to `~/.dotfiles/roles/claude/files/settings.json` apply immediately. Restart Claude Code:

```bash
# Quit Claude Code
# Restart from Applications or terminal
claude
```

### GitHub Commands Failing

```bash
# Check gh CLI installed and authenticated
gh auth status

# If not authenticated
gh auth login
```

---

## Architecture Decisions

### Why Symlinks vs Copy?

**Symlinks enable:**
- Version control of all configuration
- Instant updates when role files change
- Cross-machine sync via git
- Single source of truth

### Why Bash Scripts vs Pure Claude?

**Shell scripts provide:**
- Faster execution for repetitive operations
- Reusable logic across CLI and Claude sessions
- Better error handling with bash-specific features
- Easier testing and debugging outside Claude

### Why Allow List + Deny List?

**Hybrid approach because:**
- Allow list (900+ operations) provides security by default
- Deny list explicitly blocks dangerous operations
- Clear audit trail of permitted operations
- Flexibility for development workflows without blanket sudo

---

## Related Roles

- **git**: Git configuration with signing, credential helpers, 1Password integration
- **github_release**: GitHub CLI installation via release binary
- **neovim**: Editor with LSP, completion, debugging
- **tmux**: Terminal multiplexer with session management
- **starship**: Cross-shell prompt with git integration
- **zsh**: Shell configuration with zinit plugin management

---

## Documentation

- [Claude Code Official Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Anthropic Claude](https://www.anthropic.com/claude)
- [GitHub CLI Documentation](https://cli.github.com/)
- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

---

## Contributing

When modifying this role:

1. **Test changes** on macOS before committing
2. **Update this README** for new features/commands/skills
3. **Validate JSON** in settings.json (use `jq . settings.json`)
4. **Follow conventional commits** (enforced by git-commit-validator skill)
5. **Document new scripts** with inline comments and usage examples
6. **Add tests** for new bash scripts when possible

---

## License

Part of personal dotfiles repository. MIT License.

---

**Author**: [TechDufus](https://github.com/TechDufus)
**Repository**: [TechDufus/.dotfiles](https://github.com/TechDufus/.dotfiles)
**Role Path**: `roles/claude`
**Last Updated**: 2025-11-28
