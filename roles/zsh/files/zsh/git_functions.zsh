#!/usr/bin/env zsh

gacp() {
  git add -A
  git commit -S -m "$*"
  # if signing fails, commit without signing
  if [ $? -ne 0 ]; then
    git commit -m "$*"
  fi
  git push -u origin $(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
}

gacpgh() {
  gacp "$*"
  gh pr create --fill
  gh pr review --approve
  gh pr merge -dm
}

parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ [\1]/'
}

gtags() {
  # Show help
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "gtags - Interactive git tag browser with fzf"
    echo ""
    echo "Usage: gtags [--help]"
    echo ""
    echo "Description:"
    echo "  Browse and interact with git tags using fzf fuzzy finder"
    echo "  Tags are sorted by creation date (newest first)"
    echo ""
    echo "Features:"
    echo "  • Fuzzy search through all tags"
    echo "  • Live preview showing commit details"
    echo "  • Interactive checkout"
    echo ""
    echo "Keybindings:"
    echo "  Enter       - Checkout selected tag"
    echo "  Esc/Ctrl+C  - Exit without action"
    echo "  ↑/↓ or j/k  - Navigate"
    echo "  Type        - Search/filter tags"
    echo ""
    echo "Preview Window:"
    echo "  Right panel shows 'git show' output for the selected tag"
    echo "  Includes commit message, author, date, and diff"
    return
  fi

  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi

  # Check if repo has tags and launch fzf
  if git tag >/dev/null 2>&1 && [ -n "$(git tag)" ]; then
    git tag --sort=-creatordate | fzf \
      --preview='printf "\033[1;34m━━━ TAG: {} ━━━\033[0m\n" && \
                  printf "\033[1;32m📅 Created: %s\033[0m\n" "$(git log -1 --format="%cr (%cd)" --date=short {})" && \
                  printf "\033[1;33m👤 Author: %s\033[0m\n" "$(git log -1 --format="%an <%ae>" {})" && \
                  printf "\033[1;35m🔗 Commit: %s\033[0m\n" "$(git log -1 --format="%h" {})" && \
                  printf "\033[1;36m💬 Message: %s\033[0m\n" "$(git log -1 --format="%s" {})" && \
                  printf "\033[1;37m📊 Stats: %s\033[0m\n" "$(git show --stat {} | tail -1 | sed "s/^ *//")" && \
                  TAG_MSG="$(git tag -l --format="%(contents)" {} 2>/dev/null)" && \
                  SIGNATURE_STATUS="$(git tag -v {} 2>&1 | grep -qi "good.*signature\|valid signature\|signature verified" && echo "signed" || echo "unsigned")" && \
                  if [ -n "$TAG_MSG" ]; then \
                    printf "\n\033[1;31m🏷️  Tag Message:\033[0m\n" && \
                    CLEAN_MSG="$(echo "$TAG_MSG" | sed "/-----BEGIN PGP SIGNATURE-----/,/-----END PGP SIGNATURE-----/d" | sed "/-----BEGIN SSH SIGNATURE-----/,/-----END SSH SIGNATURE-----/d" | sed "/^$/N;/^\n$/N;/^\n\n$/d")" && \
                    echo "$CLEAN_MSG" && \
                    if [ "$SIGNATURE_STATUS" = "signed" ]; then \
                      printf "\n\033[1;32m✅ Digitally Signed\033[0m\n"; \
                    else \
                      printf "\n\033[1;91m❌ Not Signed\033[0m\n"; \
                    fi && \
                    printf "\n"; \
                  fi && \
                  printf "\033[1;90m─── Commit Details ───\033[0m\n" && \
                  git log -1 --format="%C(dim)%B%C(reset)" {} | tail -n +2 | head -6' \
      --preview-window=right:60% \
      --bind='enter:execute(git checkout {})'
  else
    echo 'No tags found in this repository'
  fi
}

