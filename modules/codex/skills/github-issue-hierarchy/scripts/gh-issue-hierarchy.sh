#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  gh-issue-hierarchy.sh issue-types [--repo owner/repo]
  gh-issue-hierarchy.sh create [--repo owner/repo] --title TITLE [--body TEXT | --body-file PATH] [--parent ISSUE] [--type NAME] [--label NAME] [--assignee LOGIN]
  gh-issue-hierarchy.sh link --parent ISSUE --child ISSUE [--replace-parent]
  gh-issue-hierarchy.sh set-type ISSUE --type NAME

Issue references:
  123
  #123
  owner/repo#123
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"
}

default_repo() {
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    printf '%s\n' "$GITHUB_REPOSITORY"
    return
  fi

  gh repo view --json owner,name --jq '.owner.login + "/" + .name' \
    || die "could not determine repository; pass --repo owner/repo"
}

parse_issue_ref() {
  local ref="$1"
  local default_repo_value="$2"

  if [[ "$ref" =~ ^([^/#]+/[^/#]+)#([0-9]+)$ ]]; then
    printf '%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return
  fi

  if [[ "$ref" =~ ^#?([0-9]+)$ ]]; then
    [[ -n "$default_repo_value" ]] || die "issue reference '$ref' needs an explicit repo"
    printf '%s\t%s\n' "$default_repo_value" "${BASH_REMATCH[1]}"
    return
  fi

  die "invalid issue reference: $ref"
}

ensure_default_repo_for_ref() {
  local ref="$1"
  local default_repo_value="${2:-}"

  if [[ -n "$default_repo_value" ]]; then
    printf '%s\n' "$default_repo_value"
    return
  fi

  if [[ "$ref" =~ ^([^/#]+/[^/#]+)#([0-9]+)$ ]]; then
    printf '\n'
    return
  fi

  default_repo
}

repo_meta_json() {
  gh api "repos/$1" \
    --jq '{repo: (.owner.login + "/" + .name), repo_id: .node_id, owner: .owner.login, owner_type: .owner.type}'
}

issue_node_id() {
  gh api "repos/$1/issues/$2" --jq .node_id
}

issue_types_payload() {
  local repo="${1:-$(default_repo)}"
  local meta
  local owner
  local owner_type
  local issue_types
  local lookup_output

  meta=$(repo_meta_json "$repo")
  owner=$(jq -r '.owner' <<<"$meta")
  owner_type=$(jq -r '.owner_type' <<<"$meta")

  if [[ "$owner_type" != "Organization" ]]; then
    jq -n \
      --arg repo "$repo" \
      --arg owner "$owner" \
      --arg owner_type "$owner_type" \
      '{repo: $repo, owner: $owner, owner_type: $owner_type, supported: false, issue_types: []}'
    return
  fi

  if ! lookup_output=$(gh api "orgs/$owner/issue-types" 2>&1); then
    jq -n \
      --arg repo "$repo" \
      --arg owner "$owner" \
      --arg owner_type "$owner_type" \
      --arg lookup_error "$lookup_output" \
      '{
        repo: $repo,
        owner: $owner,
        owner_type: $owner_type,
        supported: false,
        lookup_error: $lookup_error,
        issue_types: []
      }'
    return
  fi

  issue_types="$lookup_output"

  jq -n \
    --arg repo "$repo" \
    --arg owner "$owner" \
    --arg owner_type "$owner_type" \
    --argjson issue_types "$issue_types" \
    '{repo: $repo, owner: $owner, owner_type: $owner_type, supported: true, issue_types: $issue_types}'
}

resolve_issue_type_node_id() {
  local repo="$1"
  local requested_type="$2"
  local payload
  local node_id

  payload=$(issue_types_payload "$repo")

  if [[ "$(jq -r '.supported' <<<"$payload")" != "true" ]]; then
    local lookup_error
    lookup_error=$(jq -r '.lookup_error // ""' <<<"$payload")
    if [[ -n "$lookup_error" ]]; then
      die "issue types are unavailable for $repo: $lookup_error"
    fi
    die "issue types are not supported for $repo"
  fi

  node_id=$(
    jq -r --arg requested_type "$requested_type" '
      .issue_types[]
      | select((.is_enabled // true) == true)
      | select((.name | ascii_downcase) == ($requested_type | ascii_downcase))
      | .node_id
    ' <<<"$payload" | head -n1
  )

  [[ -n "$node_id" ]] || die "issue type not found or disabled in $repo: $requested_type"
  printf '%s\n' "$node_id"
}

graphql_optional_id() {
  if [[ -n "${1:-}" ]]; then
    printf '%s\n' "$1"
  else
    printf 'null\n'
  fi
}

create_issue() {
  local repo=""
  local title=""
  local body=""
  local body_file=""
  local parent_ref=""
  local issue_type=""
  local parent_repo=""
  local parent_number=""
  local parent_issue_id=""
  local issue_type_id=""
  local meta
  local repo_id=""
  local response
  local number
  local url
  local -a labels=()
  local -a assignees=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        repo="$2"
        shift 2
        ;;
      --title)
        title="$2"
        shift 2
        ;;
      --body)
        body="$2"
        shift 2
        ;;
      --body-file)
        body_file="$2"
        shift 2
        ;;
      --parent)
        parent_ref="$2"
        shift 2
        ;;
      --type)
        issue_type="$2"
        shift 2
        ;;
      --label)
        labels+=("$2")
        shift 2
        ;;
      --assignee)
        assignees+=("$2")
        shift 2
        ;;
      *)
        die "unknown create argument: $1"
        ;;
    esac
  done

  [[ -n "$title" ]] || die "create requires --title"

  if [[ -n "$body" && -n "$body_file" ]]; then
    die "use either --body or --body-file, not both"
  fi

  if [[ -n "$body_file" ]]; then
    [[ -f "$body_file" ]] || die "body file not found: $body_file"
    body=$(<"$body_file")
  fi

  if [[ -z "$repo" ]]; then
    repo=$(default_repo)
  fi

  meta=$(repo_meta_json "$repo")
  repo_id=$(jq -r '.repo_id' <<<"$meta")

  if [[ -n "$parent_ref" ]]; then
    read -r parent_repo parent_number < <(parse_issue_ref "$parent_ref" "$repo")
    parent_issue_id=$(issue_node_id "$parent_repo" "$parent_number")
  fi

  if [[ -n "$issue_type" ]]; then
    issue_type_id=$(resolve_issue_type_node_id "$repo" "$issue_type")
  fi

  response=$(
    gh api graphql \
      -f query='
        mutation($repositoryId: ID!, $title: String!, $body: String, $parentIssueId: ID, $issueTypeId: ID) {
          createIssue(input: {
            repositoryId: $repositoryId,
            title: $title,
            body: $body,
            parentIssueId: $parentIssueId,
            issueTypeId: $issueTypeId
          }) {
            issue {
              number
              url
              title
              issueType { name }
            }
          }
        }
      ' \
      -F repositoryId="$repo_id" \
      -f title="$title" \
      -f body="$body" \
      -F parentIssueId="$(graphql_optional_id "$parent_issue_id")" \
      -F issueTypeId="$(graphql_optional_id "$issue_type_id")"
  )

  number=$(jq -r '.data.createIssue.issue.number' <<<"$response")
  url=$(jq -r '.data.createIssue.issue.url' <<<"$response")

  [[ "$number" != "null" && -n "$number" ]] || die "failed to create issue"

  if [[ "${#labels[@]}" -gt 0 ]]; then
    local label
    for label in "${labels[@]}"; do
      gh issue edit "$number" --repo "$repo" --add-label "$label" >/dev/null
    done
  fi

  if [[ "${#assignees[@]}" -gt 0 ]]; then
    local assignee
    for assignee in "${assignees[@]}"; do
      gh issue edit "$number" --repo "$repo" --add-assignee "$assignee" >/dev/null
    done
  fi

  jq -n \
    --arg repo "$repo" \
    --argjson number "$number" \
    --arg url "$url" \
    --arg parent_ref "$parent_ref" \
    --arg issue_type "$issue_type" \
    '{
      repo: $repo,
      number: $number,
      url: $url,
      parent: (if $parent_ref == "" then null else $parent_ref end),
      issue_type: (if $issue_type == "" then null else $issue_type end)
    }'
}

link_issue() {
  local default_repo_value=""
  local parent_ref=""
  local child_ref=""
  local replace_parent=false
  local parent_repo=""
  local parent_number=""
  local child_repo=""
  local child_number=""
  local parent_issue_id=""
  local child_issue_id=""
  local response

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --parent)
        parent_ref="$2"
        shift 2
        ;;
      --child)
        child_ref="$2"
        shift 2
        ;;
      --replace-parent)
        replace_parent=true
        shift
        ;;
      *)
        die "unknown link argument: $1"
        ;;
    esac
  done

  [[ -n "$parent_ref" ]] || die "link requires --parent"
  [[ -n "$child_ref" ]] || die "link requires --child"

  default_repo_value=$(ensure_default_repo_for_ref "$parent_ref" "$default_repo_value")
  read -r parent_repo parent_number < <(parse_issue_ref "$parent_ref" "$default_repo_value")
  default_repo_value=$(ensure_default_repo_for_ref "$child_ref" "$default_repo_value")
  read -r child_repo child_number < <(parse_issue_ref "$child_ref" "$default_repo_value")

  parent_issue_id=$(issue_node_id "$parent_repo" "$parent_number")
  child_issue_id=$(issue_node_id "$child_repo" "$child_number")

  response=$(
    gh api graphql \
      -f query='
        mutation($issueId: ID!, $subIssueId: ID!, $replaceParent: Boolean) {
          addSubIssue(input: {
            issueId: $issueId,
            subIssueId: $subIssueId,
            replaceParent: $replaceParent
          }) {
            issue { number url }
            subIssue { number url }
          }
        }
      ' \
      -F issueId="$parent_issue_id" \
      -F subIssueId="$child_issue_id" \
      -F replaceParent="$replace_parent"
  )

  jq '.data.addSubIssue' <<<"$response"
}

set_issue_type() {
  local issue_ref=""
  local issue_type=""
  local issue_repo=""
  local issue_number=""
  local issue_node=""
  local issue_type_id=""
  local default_repo_value=""
  local response

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)
        issue_type="$2"
        shift 2
        ;;
      -*)
        die "unknown set-type argument: $1"
        ;;
      *)
        if [[ -z "$issue_ref" ]]; then
          issue_ref="$1"
          shift
        else
          die "unexpected argument: $1"
        fi
        ;;
    esac
  done

  [[ -n "$issue_ref" ]] || die "set-type requires an issue reference"
  [[ -n "$issue_type" ]] || die "set-type requires --type"

  default_repo_value=$(ensure_default_repo_for_ref "$issue_ref" "$default_repo_value")
  read -r issue_repo issue_number < <(parse_issue_ref "$issue_ref" "$default_repo_value")
  issue_node=$(issue_node_id "$issue_repo" "$issue_number")
  issue_type_id=$(resolve_issue_type_node_id "$issue_repo" "$issue_type")

  response=$(
    gh api graphql \
      -f query='
        mutation($issueId: ID!, $issueTypeId: ID) {
          updateIssueIssueType(input: {
            issueId: $issueId,
            issueTypeId: $issueTypeId
          }) {
            issue {
              number
              url
              issueType { name }
            }
          }
        }
      ' \
      -F issueId="$issue_node" \
      -F issueTypeId="$issue_type_id"
  )

  jq '.data.updateIssueIssueType.issue' <<<"$response"
}

main() {
  need_cmd gh
  need_cmd jq

  [[ $# -gt 0 ]] || {
    usage
    exit 1
  }

  case "$1" in
    issue-types)
      shift
      local repo=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --repo)
            repo="$2"
            shift 2
            ;;
          *)
            die "unknown issue-types argument: $1"
            ;;
        esac
      done
      issue_types_payload "$repo"
      ;;
    create)
      shift
      create_issue "$@"
      ;;
    link)
      shift
      link_issue "$@"
      ;;
    set-type)
      shift
      set_issue_type "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      die "unknown command: $1"
      ;;
  esac
}

main "$@"
