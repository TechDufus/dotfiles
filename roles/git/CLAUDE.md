# Git Role

Configures Git with SSH-based commit signing, 1Password credential integration, delta diff viewer, and cross-platform settings.

## Key Files
- `~/.config/git/allowed_signers` - SSH keys for signature verification (from 1Password)
- `~/.config/git/commit_template` - 50/72 char commit message guide
- `files/commit_template` - Source template in repo

## Patterns

### 1Password for Secrets
All credentials fetched via 1Password CLI with graceful fallback:
```yaml
op:
  git:
    user:
      email: "op://Personal/GitHub/email"
    allowed_signers: "op://Personal/TechDufus SSH/allowed_signers"
```

### SSH Signing Over GPG
Uses SSH keys instead of GPG for simpler cross-platform signing:
- `user.signingkey = ~/.ssh/id_ed25519.pub`
- `gpg.format = ssh`
- Requires SSH role to run first for keys

### Delta Diff Viewer
Enhanced diffs with `git-delta` - macOS only via Homebrew:
- Side-by-side diffs
- Syntax highlighting
- `merge.conflictStyle = zdiff3`

## Integration
- **Requires**: SSH role (keys must exist before signing config)
- **Requires**: 1Password role (for credential retrieval)
- **Used by**: ZSH/Bash roles (provide `gacp`, `gss`, `glog` functions)
- **Used by**: GitHub CLI role (enhances PR workflows)

## Gotchas
- Delta only installs on macOS; Linux uses standard diff
- `allowed_signers` file requires 1Password authentication
- Without 1Password auth, role succeeds but prints manual setup instructions
- Git aliases like `gbr` defined in role; shell functions in zsh/bash roles
- Never uninstalls git package (critical system dependency)
