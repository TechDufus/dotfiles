#!/usr/bin/env zsh
# Claude-related functions for managing settings and dotfiles integration

# Show current status of Claude settings file in dotfiles
c.settings-status() {
  pushd ~/.dotfiles > /dev/null 2>&1
  echo "📊 Claude settings.json status:"
  git diff --stat roles/claude/files/settings.json
  if git diff --quiet roles/claude/files/settings.json; then
    echo "✅ No changes detected"
  else
    echo "📝 Changes detected:"
    git diff roles/claude/files/settings.json | head -20
    echo "\nUse 'c.settings-diff' to see full diff"
  fi
  popd > /dev/null 2>&1
}

# Show full diff of Claude settings
c.settings-diff() {
  pushd ~/.dotfiles > /dev/null 2>&1
  git diff roles/claude/files/settings.json
  popd > /dev/null 2>&1
}

# Save current Claude settings to dotfiles
c.settings-save() {
  pushd ~/.dotfiles > /dev/null 2>&1
  if git diff --quiet roles/claude/files/settings.json; then
    echo "✅ No changes to save"
    popd > /dev/null 2>&1
    return 0
  fi

  echo "💾 Saving Claude settings to dotfiles..."
  git add roles/claude/files/settings.json
  git commit -m "feat: update claude settings

Updated settings.json with latest preferences"
  echo "✅ Settings saved! Use 'git push' when ready to sync."
  popd > /dev/null 2>&1
}

# Ignore local Claude settings changes in git
c.settings-ignore() {
  pushd ~/.dotfiles > /dev/null 2>&1
  git update-index --skip-worktree roles/claude/files/settings.json
  echo "🙈 Git will now ignore changes to Claude settings.json"
  echo "Use 'c.settings-unignore' to track changes again"
  popd > /dev/null 2>&1
}

# Stop ignoring Claude settings changes
c.settings-unignore() {
  pushd ~/.dotfiles > /dev/null 2>&1
  git update-index --no-skip-worktree roles/claude/files/settings.json
  echo "👀 Git will now track changes to Claude settings.json"
  popd > /dev/null 2>&1
}

# Reset Claude settings to dotfiles version (careful!)
c.settings-reset() {
  echo "⚠️  This will reset your Claude settings to the dotfiles version!"
  echo -n "Are you sure? (y/N): "
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    pushd ~/.dotfiles > /dev/null 2>&1
    git checkout roles/claude/files/settings.json
    echo "✅ Settings reset to dotfiles version"
    popd > /dev/null 2>&1
  else
    echo "❌ Reset cancelled"
  fi
}

# Show all Claude functions
c.help() {
  echo "🤖 Claude Helper Functions:"
  echo ""
  echo "  c.settings-status   - Show status of Claude settings in dotfiles"
  echo "  c.settings-diff     - Show full diff of Claude settings"
  echo "  c.settings-save     - Commit current Claude settings to dotfiles"
  echo "  c.settings-ignore   - Tell git to ignore Claude settings changes"
  echo "  c.settings-unignore - Tell git to track Claude settings changes"
  echo "  c.settings-reset    - Reset Claude settings to dotfiles version"
  echo "  c.continue          - Continue Claude session with working directory"
  echo "  c.help              - Show this help message"
  echo ""
  echo "💡 Tip: Use tab completion to discover all c.* functions"
}

# Continue Claude session with current working directory context
c.continue() {
  local workspace_flag=""
  local input_text="$*"

  # Only add workspace flag if we're in a git repo or specific project directory
  if git rev-parse --git-dir > /dev/null 2>&1; then
    workspace_flag="--workspace $(pwd)"
  elif [[ -f "package.json" ]] || [[ -f "Cargo.toml" ]] || [[ -f "go.mod" ]] || [[ -f "requirements.txt" ]]; then
    workspace_flag="--workspace $(pwd)"
  fi

  if [[ -n "$input_text" ]]; then
    echo "$input_text" | claude $workspace_flag --continue
  else
    claude $workspace_flag --continue
  fi
}

# Alias for common continue patterns
alias c.c='c.continue'
