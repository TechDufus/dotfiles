#!/usr/bin/env zsh

function ai-commit() {
  # Generate commit message using Claude CLI
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi
  
  # Check if claude is installed
  if ! command -v claude >/dev/null 2>&1; then
    echo "Error: claude CLI not found. Please install it first."
    return 1
  fi
  
  # Check for unstaged changes
  if [[ -z $(git diff --cached) ]]; then
    echo "No staged changes found. Stage your changes with 'git add' first."
    return 1
  fi
  
  echo "Generating commit message with Claude..."
  
  # Generate the commit message
  local commit_msg=$(git diff --cached | claude "Generate a commit message for these changes. Follow these rules:
1. First line: 50 chars max, use conventional commit format (feat:, fix:, docs:, style:, refactor:, test:, chore:)
2. Leave blank line after first line
3. Body: wrap at 72 chars, explain what and why (not how)
4. Be specific and concise
5. No marketing language or fluff

Output ONLY the commit message, nothing else.")
  
  if [[ -z "$commit_msg" ]]; then
    echo "Error: Failed to generate commit message"
    return 1
  fi
  
  # Display the generated message
  echo -e "\n--- Generated Commit Message ---"
  echo "$commit_msg"
  echo -e "--------------------------------\n"
  
  # Ask for confirmation
  echo -n "Use this commit message? [Y/n/e(dit)] "
  read -r response
  
  case "$response" in
    [nN])
      echo "Commit cancelled."
      return 0
      ;;
    [eE])
      # Write message to temp file for editing
      local tmpfile=$(mktemp)
      echo "$commit_msg" > "$tmpfile"
      ${EDITOR:-vim} "$tmpfile"
      git commit -F "$tmpfile"
      rm -f "$tmpfile"
      ;;
    *)
      # Default to yes
      git commit -m "$commit_msg"
      ;;
  esac
}
