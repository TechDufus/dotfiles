#!/usr/bin/env zsh

ghelp() {
  # Display help for custom git functions
  
  echo -e "${BOLD}${BLUE}━━━ Custom Git Functions ━━━${NC}\n"
  
  echo -e "${BOLD}${GREEN}Enhanced Commands:${NC}"
  echo -e "  ${YELLOW}gss${NC}         - Enhanced git status with branch info, PR status, worktrees, and more"
  echo -e "  ${YELLOW}gco${NC}         - Interactive branch checkout with fuzzy search and preview"
  echo -e "  ${YELLOW}glog${NC}        - Interactive commit log browser with full diff preview"
  echo -e "  ${YELLOW}gstash${NC}      - Interactive stash manager (apply/pop/drop/branch)"
  echo ""
  
  echo -e "${BOLD}${GREEN}Worktree Commands:${NC}"
  echo -e "  ${YELLOW}gwl${NC}         - List all worktrees with detailed information"
  echo -e "  ${YELLOW}gwn${NC} <branch> - Create new worktree in <repo>/worktrees/<branch>"
  echo -e "  ${YELLOW}gwd${NC}         - Interactive worktree deletion"
  echo -e "  ${YELLOW}gws${NC}         - Interactive worktree switcher"
  echo ""

  echo -e "${BOLD}${GREEN}Git Bisect Commands:${NC}"
  echo -e "  ${YELLOW}gbisect${NC}     - Git bisect with visual enhancements (use 'gbisect help' for guide)"
  echo -e "  ${YELLOW}gbisect-start${NC}   - Start bisect session with interactive commit selection"
  echo -e "  ${YELLOW}gbisect-good${NC}    - Mark current commit as good"
  echo -e "  ${YELLOW}gbisect-bad${NC}     - Mark current commit as bad"
  echo -e "  ${YELLOW}gbisect-skip${NC}    - Skip current untestable commit"
  echo -e "  ${YELLOW}gbisect-reset${NC}   - Exit bisect mode"
  echo -e "  ${YELLOW}gbisect-progress${NC} - Show visual progress bar and statistics"
  echo -e "  ${YELLOW}gbisect-log${NC}     - View enhanced bisect log with colors"
  echo -e "  ${YELLOW}gbisect-status${NC}  - Show current bisect state"
  echo -e "  ${YELLOW}gbisect-save${NC}    - Save bisect state for later"
  echo -e "  ${YELLOW}gbisect-restore${NC} - Restore previously saved bisect state"
  echo ""

  echo -e "${BOLD}${GREEN}Quick Commands:${NC}"
  echo -e "  ${YELLOW}gacp${NC} <msg>  - Add all, commit (signed), and push in one command"
  echo -e "  ${YELLOW}gacpgh${NC} <msg>- Same as gacp + create PR, approve, and merge"
  echo -e "  ${YELLOW}ai-commit${NC}   - Generate commit message using Claude (stages changes first)"
  echo -e "  ${YELLOW}gtags${NC}       - Interactive tag browser with preview"
  echo ""
  
  echo -e "${BOLD}${GREEN}Git Aliases:${NC}"
  echo -e "  ${YELLOW}gs${NC}          - git status"
  echo -e "  ${YELLOW}gc${NC}          - git checkout"
  echo -e "  ${YELLOW}gcb${NC}         - git checkout -b"
  echo -e "  ${YELLOW}gcm${NC}         - git commit -m"
  echo -e "  ${YELLOW}gcane${NC}       - git commit --amend --no-edit"
  echo -e "  ${YELLOW}gd${NC}          - git diff"
  echo -e "  ${YELLOW}gp${NC}          - git push"
  echo -e "  ${YELLOW}gpf${NC}         - git push --force-with-lease"
  echo -e "  ${YELLOW}gu${NC}          - git restore --staged (unstage)"
  echo -e "  ${YELLOW}gw${NC}          - git worktree"
  echo -e "  ${YELLOW}gbr${NC}         - git branch (formatted with dates)"
  echo -e "  ${YELLOW}ggl${NC}         - git log graph (pretty format)"
  echo ""
  
  echo -e "${CYAN}Tip: Most interactive commands use fzf for fuzzy searching${NC}"
}

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

# Unalias any conflicting aliases
unalias gss 2>/dev/null || true
unalias gco 2>/dev/null || true
unalias glog 2>/dev/null || true
unalias gstash 2>/dev/null || true
unalias gwl 2>/dev/null || true
unalias gwn 2>/dev/null || true
unalias gwd 2>/dev/null || true
unalias gws 2>/dev/null || true

gss() {
  # Enhanced git status with comprehensive repository information
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not in a git repository"
    return 1
  fi


  # Get current branch
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  
  # Get upstream branch
  local upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
  
  # Header
  echo -e "${BOLD}${BLUE}━━━ Git Repository Status ━━━${NC}"
  echo ""
  
  # Branch info
  echo -e "${BOLD}Branch:${NC} ${GREEN}$branch${NC}"
  if [[ -n "$upstream" ]]; then
    echo -e "${BOLD}Tracks:${NC} ${CYAN}$upstream${NC}"
    
    # Get ahead/behind info
    local ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null)
    local behind=$(git rev-list --count HEAD..@{u} 2>/dev/null)
    
    if [[ $ahead -gt 0 || $behind -gt 0 ]]; then
      echo -n -e "${BOLD}Status:${NC} "
      [[ $ahead -gt 0 ]] && echo -n -e "${GREEN}↑$ahead${NC} "
      [[ $behind -gt 0 ]] && echo -n -e "${RED}↓$behind${NC}"
      echo ""
    fi
  else
    echo -e "${BOLD}Tracks:${NC} ${YELLOW}(no upstream)${NC}"
  fi
  
  # Last commit
  echo ""
  echo -e "${BOLD}Last Commit:${NC}"
  echo -e "  $(git log -1 --format="${YELLOW}%h${NC} - %s ${CYAN}(%cr)${NC} ${MAGENTA}<%an>${NC}")"
  
  # Stash info
  local stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
  if [[ $stash_count -gt 0 ]]; then
    echo ""
    echo -e "${BOLD}Stashes:${NC} ${YELLOW}$stash_count${NC}"
  fi
  
  # Working tree status
  echo ""
  echo -e "${BOLD}Working Tree:${NC}"
  
  # Get file counts
  local staged=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  local modified=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
  local untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  
  if [[ $staged -eq 0 && $modified -eq 0 && $untracked -eq 0 ]]; then
    echo -e "  ${GREEN}✓ Clean${NC}"
  else
    [[ $staged -gt 0 ]] && echo -e "  ${GREEN}● Staged:${NC} $staged"
    [[ $modified -gt 0 ]] && echo -e "  ${YELLOW}● Modified:${NC} $modified"
    [[ $untracked -gt 0 ]] && echo -e "  ${RED}● Untracked:${NC} $untracked"
  fi
  
  # Worktrees
  local worktrees=$(git worktree list --porcelain 2>/dev/null | grep "^worktree" | wc -l | tr -d ' ')
  if [[ $worktrees -gt 1 ]]; then
    echo ""
    echo -e "${BOLD}Worktrees:${NC} ${CYAN}$worktrees${NC}"
    git worktree list | tail -n +2 | while read -r line; do
      echo "  $line"
    done
  fi
  
  # GitHub PR info (if gh is available)
  if command -v gh >/dev/null 2>&1 && [[ -n "$upstream" ]]; then
    local pr_info=$(gh pr status --json number,url,title 2>/dev/null | jq -r 'select(.currentBranch != null) | .currentBranch | select(.number != null) | "PR #\(.number): \(.title)\n  \(.url)"' 2>/dev/null)
    if [[ -n "$pr_info" ]]; then
      echo ""
      echo -e "${BOLD}Pull Request:${NC}"
      echo -e "  ${MAGENTA}$pr_info${NC}"
    fi
  fi
  
  echo ""
}

gco() {
  # Interactive git branch checkout with fzf
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi
  
  # Get current branch
  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  
  # Get all branches and launch fzf
  git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/ | \
    grep -v "HEAD" | \
    sort -u | \
    fzf \
      --preview='branch=$(echo {} | sed "s/^origin\///"); \
                 echo -e "\033[1;34m━━━ BRANCH: {} ━━━\033[0m\n"; \
                 if [[ {} == origin/* ]]; then \
                   echo -e "\033[1;33m⚠ Remote branch - will create local tracking branch\033[0m\n"; \
                 fi; \
                 echo -e "\033[1;32m📅 Last Activity:\033[0m $(git log -1 --format="%cr" {})"; \
                 echo -e "\033[1;33m👤 Last Author:\033[0m $(git log -1 --format="%an <%ae>" {})"; \
                 echo -e "\033[1;35m🔗 Last Commit:\033[0m $(git log -1 --format="%h" {})"; \
                 echo -e "\033[1;36m💬 Last Message:\033[0m $(git log -1 --format="%s" {})"; \
                 echo -e "\n\033[1;90m─── Recent Commits ───\033[0m"; \
                 git log --oneline --graph --color=always -10 {} | head -20' \
      --preview-window=right:60% \
      --header="Current branch: $current_branch" \
      --bind='enter:execute(
        branch={}
        if [[ $branch == origin/* ]]; then
          local_branch=${branch#origin/}
          git checkout -b "$local_branch" "$branch" 2>/dev/null || git checkout "$local_branch"
        else
          git checkout "$branch"
        fi
      )+abort'
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

glog() {
  # Interactive git log browser with fzf
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi
  
  # Git log with graph, all branches, and color
  git log --graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr %C(auto)%an" --all "$@" | \
  fzf --ansi --no-sort --reverse --tiebreak=index \
      --header="Navigate: ↑/↓ • Show commit: Enter • Exit: Esc" \
      --preview='
        commit=$(echo {} | grep -o "[a-f0-9]\{7,\}" | head -1)
        if [ -n "$commit" ]; then
          echo -e "\033[1;34m━━━ COMMIT: $commit ━━━\033[0m\n"
          git show --color=always --stat --patch "$commit" | head -500
        fi
      ' \
      --preview-window=right:60% \
      --bind='enter:execute(
        commit=$(echo {} | grep -o "[a-f0-9]\{7,\}" | head -1)
        if [ -n "$commit" ]; then
          git show --color=always --stat --patch "$commit" | less -R
        fi
      )'
}

gstash() {
  # Interactive git stash manager with fzf
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi
  
  # Check if there are any stashes
  if ! git stash list >/dev/null 2>&1 || [ -z "$(git stash list)" ]; then
    echo "No stashes found"
    return 0
  fi
  
  local stash=$(git stash list | \
    fzf --preview='
      stash_id=$(echo {} | cut -d: -f1)
      echo -e "\033[1;34m━━━ STASH: $stash_id ━━━\033[0m\n"
      git stash show -p --color=always "$stash_id" | head -500
    ' \
    --preview-window=right:60% \
    --header="Actions: Enter=apply, Ctrl-P=pop, Ctrl-D=drop, Ctrl-B=branch" \
    --bind='enter:execute(
      stash_id=$(echo {} | cut -d: -f1)
      echo "Applying $stash_id..."
      git stash apply "$stash_id"
    )+abort' \
    --bind='ctrl-p:execute(
      stash_id=$(echo {} | cut -d: -f1)
      echo "Popping $stash_id..."
      git stash pop "$stash_id"
    )+abort' \
    --bind='ctrl-d:execute(
      stash_id=$(echo {} | cut -d: -f1)
      echo -n "Drop $stash_id? [y/N] "
      read -r confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        git stash drop "$stash_id"
        echo "Dropped $stash_id"
      fi
    )+abort' \
    --bind='ctrl-b:execute(
      stash_id=$(echo {} | cut -d: -f1)
      echo -n "Create branch from $stash_id. Branch name: "
      read -r branch_name
      if [ -n "$branch_name" ]; then
        git stash branch "$branch_name" "$stash_id"
      fi
    )+abort'
  )
}

gwl() {
  # List git worktrees with detailed information
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi
  
  
  echo -e "${BOLD}${BLUE}━━━ Git Worktrees ━━━${NC}\n"
  
  # Get current worktree
  local current_worktree=$(git rev-parse --show-toplevel 2>/dev/null)
  
  git worktree list --porcelain | awk -v current="$current_worktree" -v green="$GREEN" -v yellow="$YELLOW" -v cyan="$CYAN" -v magenta="$MAGENTA" -v nc="$NC" -v bold="$BOLD" '
    /^worktree / { 
      path = $2
      is_current = (path == current) ? " (current)" : ""
    }
    /^HEAD / { 
      commit = $2
    }
    /^branch / { 
      branch = $2
      gsub(/^refs\/heads\//, "", branch)
    }
    /^detached/ {
      branch = "detached HEAD"
    }
    /^$/ {
      if (path) {
        # Get last commit info
        cmd = "git -C \"" path "\" log -1 --format=\"%h - %s (%cr) <%an>\" 2>/dev/null"
        cmd | getline commit_info
        close(cmd)
        
        printf "%s%s%s%s\n", cyan, path, nc, is_current
        printf "  %sBranch:%s %s%s%s\n", bold, nc, green, branch, nc
        printf "  %sCommit:%s %s%s%s\n", bold, nc, yellow, commit_info, nc
        print ""
      }
      path = ""; branch = ""; commit = ""
    }
  '
}

gwn() {
  # Create new git worktree in unified worktrees directory
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi
  
  if [ -z "$1" ]; then
    echo "Usage: gwn <branch-name>"
    echo "Creates a new worktree in <repo-root>/worktrees/<branch-name>"
    return 1
  fi
  
  local branch="$1"
  local repo_root=$(git rev-parse --show-toplevel)
  local worktrees_dir="${repo_root}/worktrees"
  local path="${worktrees_dir}/${branch}"
  
  # Create worktrees directory if it doesn't exist
  if [ ! -d "$worktrees_dir" ]; then
    echo "Creating worktrees directory at: $worktrees_dir"
    mkdir -p "$worktrees_dir"
  fi
  
  # Check if branch exists
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "Creating worktree for existing branch '$branch' at '$path'"
    git worktree add "$path" "$branch"
  else
    echo "Creating worktree with new branch '$branch' at '$path'"
    git worktree add -b "$branch" "$path"
  fi
  
  if [ $? -eq 0 ]; then
    echo -e "\nWorktree created successfully!"
    echo "To switch to it: cd $path"
    # Add worktrees to .gitignore if not already there
    if ! grep -q "^/worktrees$" "${repo_root}/.gitignore" 2>/dev/null; then
      echo -e "\nAdding /worktrees to .gitignore"
      echo "/worktrees" >> "${repo_root}/.gitignore"
    fi
  fi
}

gwd() {
  # Interactive git worktree deletion
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi
  
  # Get current worktree to exclude it
  local current_worktree=$(git rev-parse --show-toplevel 2>/dev/null)
  
  # Get worktrees (excluding main/current)
  local worktree=$(git worktree list --porcelain | \
    awk -v current="$current_worktree" '
      /^worktree / { 
        path = $2
        if (path != current) paths[path] = 1
      }
      /^branch / { 
        if (path in paths) {
          branch = $2
          gsub(/^refs\/heads\//, "", branch)
          branches[path] = branch
        }
      }
      END {
        for (p in paths) {
          print p " [" branches[p] "]"
        }
      }
    ' | \
    fzf --preview='
      path=$(echo {} | cut -d" " -f1)
      echo -e "\033[1;34m━━━ WORKTREE: $path ━━━\033[0m\n"
      git -C "$path" log -5 --oneline --graph --color=always 2>/dev/null
    ' \
    --preview-window=right:50% \
    --header="Select worktree to delete (Enter to confirm)")
  
  if [ -n "$worktree" ]; then
    local path=$(echo "$worktree" | cut -d' ' -f1)
    echo -n "Delete worktree at '$path'? [y/N] "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      git worktree remove "$path"
      if [ $? -eq 0 ]; then
        echo "Worktree deleted successfully"
      fi
    else
      echo "Deletion cancelled"
    fi
  fi
}

gws() {
  # Switch between git worktrees interactively
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi
  
  local current_worktree=$(git rev-parse --show-toplevel 2>/dev/null)
  
  local selected=$(git worktree list --porcelain | \
    awk -v current="$current_worktree" '
      /^worktree / { 
        path = $2
        is_current = (path == current) ? " (current)" : ""
        paths[path] = is_current
      }
      /^branch / { 
        branch = $2
        gsub(/^refs\/heads\//, "", branch)
        branches[path] = branch
      }
      /^detached/ {
        branches[path] = "detached HEAD"
      }
      END {
        for (p in paths) {
          print p " [" branches[p] "]" paths[p]
        }
      }
    ' | \
    fzf --preview='
      path=$(echo {} | cut -d" " -f1)
      echo -e "\033[1;34m━━━ WORKTREE: $path ━━━\033[0m\n"
      echo -e "\033[1;33mBranch:\033[0m $(echo {} | sed "s/.*\[\(.*\)\].*/\1/")"
      echo -e "\033[1;32mLast 10 commits:\033[0m"
      git -C "$path" log -10 --oneline --graph --color=always 2>/dev/null
    ' \
    --preview-window=right:60% \
    --header="Select worktree to switch to")
  
  if [ -n "$selected" ]; then
    local path=$(echo "$selected" | cut -d' ' -f1)
    cd "$path"
    echo "Switched to worktree: $path"
  fi
}

