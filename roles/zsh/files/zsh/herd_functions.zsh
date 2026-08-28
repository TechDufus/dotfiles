#!/usr/bin/env zsh
# Worktrunk+Herdr current-workspace helpers for Cursor CLI; does not start an agent.

typeset -g _HERD_PYTHON
_HERD_PYTHON='
import json, os, re, signal, subprocess, sys

FORBIDDEN = {"--execute", "--yes", "--no-hooks", "--clobber", "--force"}
OWNER_RE = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$")
NAME_RE = re.compile(r"^[A-Za-z0-9._-]+$")
ENDPOINT_OWNER = r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
ENDPOINT_NAME = r"[A-Za-z0-9._-]+?"
ENDPOINT_RE = re.compile(
    r"^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com(?::22)?/)("
    + ENDPOINT_OWNER
    + r")/("
    + ENDPOINT_NAME
    + r")(?:\.git)?$",
    re.I,
)
BRANCH_TYPE_ALIASES = {
    "feat": "feat", "feature": "feat", "enhancement": "feat", "story": "feat",
    "fix": "fix", "bug": "fix", "repair": "fix", "resolve": "fix", "security": "fix", "correction": "fix",
    "docs": "docs", "doc": "docs", "document": "docs", "documentation": "docs", "readme": "docs",
    "refactor": "refactor", "test": "test", "tests": "test", "testing": "test",
    "chore": "chore", "maintenance": "chore", "dependencies": "chore", "dependency": "chore", "task": "chore",
    "ci": "ci", "build": "build", "perf": "perf", "performance": "perf",
    "create": "feat", "add": "feat", "implement": "feat", "design": "feat",
}
SPECIFIC_TYPES = ["fix", "docs", "chore", "test", "refactor", "ci", "build", "perf"]


class HerdError(Exception):
    pass


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(2)


def object_(value):
    if not isinstance(value, dict):
        raise HerdError("Command returned malformed JSON")
    return value


def text(value, field):
    if not isinstance(value, str) or not value:
        raise HerdError("Command JSON is missing %s" % field)
    return value


def repository_owner(value, field):
    owner = text(value, field)
    if not OWNER_RE.match(owner):
        raise HerdError("Command JSON has malformed %s" % field)
    return owner


def repository_name(value, field):
    name = text(value, field)
    if not NAME_RE.match(name):
        raise HerdError("Command JSON has malformed %s" % field)
    return name


def repository_identity(value, field):
    repo = text(value, field)
    parts = repo.split("/")
    if len(parts) != 2:
        raise HerdError("Command JSON has malformed %s" % field)
    repository_owner(parts[0], "%s owner" % field)
    repository_name(parts[1], "%s name" % field)
    return {"repo": repo, "owner": parts[0]}


def json_object(stdout):
    try:
        value = json.loads(stdout)
    except Exception:
        raise HerdError("Command returned invalid JSON")
    try:
        return object_(value)
    except HerdError:
        raise
    except Exception:
        raise HerdError("Command returned invalid JSON")


def json_array(stdout):
    try:
        value = json.loads(stdout)
        if not isinstance(value, list):
            raise HerdError("Command returned malformed JSON")
        return value
    except HerdError:
        raise
    except Exception:
        raise HerdError("Command returned invalid JSON")


def result_envelope(stdout):
    return object_(json_object(stdout).get("result"))


def worktrunk_worktrees(stdout):
    try:
        value = json.loads(stdout)
    except Exception:
        raise HerdError("Command returned invalid JSON")
    if isinstance(value, list):
        return [object_(item) for item in value]
    envelope = object_(value)
    if envelope.get("schema") != 2 or not isinstance(envelope.get("items"), list):
        raise HerdError("Worktrunk returned an unsupported list JSON schema")
    worktrees = []
    for raw in envelope["items"]:
        item = object_(raw)
        if item.get("worktree") is None:
            continue
        worktree = object_(item["worktree"])
        if not isinstance(worktree.get("main"), bool):
            raise HerdError("Worktrunk list JSON is missing worktree.main")
        worktrees.append({
            "branch": item.get("branch"),
            "path": text(worktree.get("path"), "worktree.path"),
            "kind": "worktree",
            "is_main": worktree["main"],
        })
    return worktrees


def slug(value):
    compact = re.sub(r"[^a-z0-9]+", "-", value.lower())
    compact = re.sub(r"^-|-$", "", compact)
    compact = compact[:36]
    compact = re.sub(r"-$", "", compact)
    return compact or "task"


def category_type(category):
    key = re.sub(r"^type\s*:\s*", "", category.strip().lower())
    return BRANCH_TYPE_ALIASES.get(key)


def request_branch(request):
    unscaffolded = re.sub(
        r"^\s*(?:(?:please|i\s+(?:want|need)\s+to|we\s+need\s+to|can\s+you)\b[\s,:-]*)+",
        "",
        request,
        flags=re.I,
    )
    leading = re.search(
        r"^(?:\[([a-z]+)\]|([a-z]+))(?:\([^)\r\n]*\))?(?:\s*[:-]\s*|\s+|$)",
        unscaffolded,
        flags=re.I,
    )
    raw_type = ""
    if leading:
        raw_type = leading.group(1) or leading.group(2) or ""
    found = category_type(raw_type)
    seed = unscaffolded[len(leading.group(0)):] if found and leading else unscaffolded
    return {"type": found or "feat", "seed": seed}


def issue_number(reference):
    url = re.search(r"^https://github\.com/([^/]+/[^/]+)/issues/(\d+)/?$", reference)
    if url:
        return {"repo": url.group(1), "number": int(url.group(2))}
    qualified = re.search(r"^([^/#]+/[^/#]+)#(\d+)$", reference)
    if qualified:
        return {"repo": qualified.group(1), "number": int(qualified.group(2))}
    local = re.search(r"^#?(\d+)$", reference)
    if local:
        return {"number": int(local.group(1))}
    raise HerdError("Invalid issue reference: %s" % reference)


def issue_type(labels, title):
    label_types = [category_type(label) for label in labels]
    for category in SPECIFIC_TYPES:
        if category in label_types:
            return category
    bracketed = re.search(r"^\s*\[([^\]\r\n]+)\]", title)
    title_type = category_type(bracketed.group(1) if bracketed else "")
    if title_type:
        return title_type
    return "feat"


def github_repository_from_endpoint(endpoint):
    match = ENDPOINT_RE.search(endpoint)
    if not match:
        return None
    return "%s/%s" % (match.group(1), match.group(2))


def repository_proof(value):
    identity = repository_identity(value.get("nameWithOwner"), "nameWithOwner")
    identity_id = text(value.get("id"), "id")
    url = text(value.get("url"), "url")
    if url.lower() != ("https://github.com/%s" % identity["repo"]).lower():
        raise HerdError("Command JSON has inconsistent repository URL")
    identity["id"] = identity_id
    identity["url"] = url
    return identity


def parse_topology(stdout):
    metadata = json_object(stdout)
    current = repository_identity(metadata.get("nameWithOwner"), "nameWithOwner")
    if not isinstance(metadata.get("isFork"), bool):
        raise HerdError("Repository JSON is missing isFork")
    candidates = [{"repo": current["repo"], "isCrossRepository": False}]
    if metadata["isFork"]:
        parent_raw = metadata.get("parent")
        if not isinstance(parent_raw, dict):
            raise HerdError("Repository JSON has malformed fork parent metadata")
        parent_metadata = object_(parent_raw)
        owner_raw = parent_metadata.get("owner")
        if not isinstance(owner_raw, dict):
            raise HerdError("Repository JSON has malformed fork parent owner metadata")
        parent_owner = repository_owner(object_(owner_raw).get("login"), "parent.owner.login")
        parent_name = repository_name(parent_metadata.get("name"), "parent.name")
        parent = "%s/%s" % (parent_owner, parent_name)
        if parent.lower() == current["repo"].lower():
            raise HerdError("Repository JSON has malformed fork parent metadata")
        candidates.append({"repo": parent, "isCrossRepository": True})
        scope = "the current repository or its direct parent"
    else:
        if metadata.get("parent") is not None:
            raise HerdError("Repository JSON has malformed non-fork parent metadata")
        scope = "the current repository"
    return {"current": current, "candidates": candidates, "scope": scope}


def parse_issue(stdout):
    data = json_object(stdout)
    number = data.get("number")
    if type(number) not in (int, float) or isinstance(number, bool):
        raise HerdError("Issue JSON is missing number")
    labels = data.get("labels")
    if not isinstance(labels, list):
        raise HerdError("Issue JSON is missing labels")
    names = []
    for label in labels:
        names.append(text(object_(label).get("name"), "labels.name"))
    return {
        "number": number,
        "title": text(data.get("title"), "title"),
        "labels": names,
    }


def is_safe_integer(value):
    return type(value) is int and abs(value) <= 9007199254740991


def exact_prs(stdout, branch, head, owner, is_cross, repo):
    rows = json_array(stdout)
    if len(rows) >= 100:
        raise HerdError("GitHub pull request lookup reached its 100-result safety limit; cleanup was refused")
    exact = []
    cross = is_cross == "true"
    for row in rows:
        value = object_(row)
        number = value.get("number")
        if not is_safe_integer(number) or number <= 0:
            raise HerdError("Pull request JSON has malformed number")
        state = text(value.get("state"), "state")
        merged_at = value.get("mergedAt")
        if merged_at is not None and (not isinstance(merged_at, str) or not merged_at):
            raise HerdError("Pull request JSON has malformed mergedAt")
        url = text(value.get("url"), "url")
        head_ref_name = text(value.get("headRefName"), "headRefName")
        head_ref_oid = text(value.get("headRefOid"), "headRefOid")
        if not isinstance(value.get("isCrossRepository"), bool):
            raise HerdError("Pull request JSON is missing isCrossRepository")
        head_owner_raw = value.get("headRepositoryOwner")
        if not isinstance(head_owner_raw, dict):
            raise HerdError("Pull request JSON is missing headRepositoryOwner")
        head_owner = repository_owner(object_(head_owner_raw).get("login"), "headRepositoryOwner.login")
        if (
            head_ref_name == branch
            and head_ref_oid == head
            and head_owner.lower() == owner.lower()
            and value["isCrossRepository"] is cross
        ):
            exact.append({
                "number": number,
                "state": state,
                "mergedAt": merged_at,
                "url": url,
                "repo": repo,
            })
    return exact


def parse_removal(stdout, checkout_path, branch):
    try:
        results = json_array(stdout)
    except Exception:
        raise HerdError("Worktrunk reported success, but returned malformed JSON; the checkout may already be removed")
    if len(results) != 1:
        raise HerdError(
            "Worktrunk reported success, but returned %s cleanup results instead of one; the checkout may already be removed"
            % len(results)
        )
    try:
        removal = object_(results[0])
    except Exception:
        raise HerdError("Worktrunk reported success, but returned a malformed cleanup result; the checkout may already be removed")
    if removal.get("kind") != "worktree" or removal.get("path") != checkout_path or removal.get("branch") != branch:
        raise HerdError("Worktrunk reported success for an unexpected cleanup target; the checkout may already be removed")


def match_worktree(stdout, checkout_path, branch):
    worktrees = worktrunk_worktrees(stdout)
    matches = [worktree for worktree in worktrees if worktree.get("path") == checkout_path]
    if len(matches) != 1:
        raise HerdError("Expected one Worktrunk checkout at %s; found %s" % (checkout_path, len(matches)))
    worktree = matches[0]
    if text(worktree.get("branch"), "branch") != branch or worktree.get("kind") != "worktree" or worktree.get("is_main") is not False:
        raise HerdError("Worktrunk no longer identifies this path as the expected non-main branch checkout")


def switch_path(stdout):
    switched = json_object(stdout)
    path = text(switched.get("path"), "path")
    if not path.startswith("/"):
        raise HerdError("Worktrunk returned a non-absolute checkout path")
    return path


def tab_identity(stdout):
    result = result_envelope(stdout)
    tab = object_(result.get("tab"))
    root = object_(result.get("root_pane"))
    return {
        "tab_id": text(tab.get("tab_id"), "tab.tab_id"),
        "root_pane": text(root.get("pane_id"), "root_pane.pane_id"),
    }


def split_config_stdout(stdout):
    values = re.split(r"\r?\n", stdout)
    if values and values[-1] == "":
        values.pop()
    return values


def exec_command(timeout_ms, cwd, argv):
    for token in argv:
        if token in FORBIDDEN:
            return {
                "stdout": "",
                "stderr": "forbidden argv token: %s" % token,
                "exitCode": 2,
                "killed": False,
            }
    try:
        proc = subprocess.Popen(
            argv,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
    except FileNotFoundError:
        return {
            "stdout": "",
            "stderr": "command not found: %s" % argv[0],
            "exitCode": 127,
            "killed": False,
        }
    except Exception as error:
        return {
            "stdout": "",
            "stderr": str(error),
            "exitCode": 1,
            "killed": False,
        }
    killed = False
    try:
        stdout, stderr = proc.communicate(timeout=timeout_ms / 1000.0)
    except subprocess.TimeoutExpired:
        killed = True
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        stdout, stderr = proc.communicate()
    return {
        "stdout": stdout.decode("utf-8", errors="replace"),
        "stderr": stderr.decode("utf-8", errors="replace"),
        "exitCode": proc.returncode if proc.returncode is not None else -1,
        "killed": killed,
    }


def is_hook_approval(stdout, stderr, exit_code, killed):
    if killed == "true" or str(exit_code) == "0":
        return False
    output = "%s\n%s" % (stderr, stdout)
    return bool(
        re.search(r"\bneeds approval to execute\b", output, re.I)
        and re.search(r"\bcannot prompt for approval in non-interactive environment\b", output, re.I)
    )


def emit(value):
    sys.stdout.write(json.dumps(value, ensure_ascii=False))
    sys.stdout.write("\n")


def main():
    if len(sys.argv) < 2:
        fail("herd helper requires an operation")
    op = sys.argv[1]
    try:
        if op == "exec":
            if len(sys.argv) < 5:
                fail("exec requires timeout, cwd, and a command")
            timeout_ms = int(sys.argv[2])
            cwd = sys.argv[3]
            argv = sys.argv[4:]
            emit(exec_command(timeout_ms, cwd, argv))
            return
        if op == "slug":
            sys.stdout.write(slug(sys.argv[2] if len(sys.argv) > 2 else ""))
            return
        if op == "request_branch":
            emit(request_branch(sys.argv[2] if len(sys.argv) > 2 else ""))
            return
        if op == "issue_number":
            emit(issue_number(sys.argv[2] if len(sys.argv) > 2 else ""))
            return
        if op == "issue_type":
            labels = json.loads(sys.argv[2])
            title = sys.argv[3] if len(sys.argv) > 3 else ""
            sys.stdout.write(issue_type(labels, title))
            return
        if op == "parse_issue":
            emit(parse_issue(sys.stdin.read()))
            return
        if op == "parse_topology":
            emit(parse_topology(sys.stdin.read()))
            return
        if op == "switch_path":
            sys.stdout.write(switch_path(sys.stdin.read()))
            return
        if op == "tab_identity":
            emit(tab_identity(sys.stdin.read()))
            return
        if op == "match_worktree":
            match_worktree(sys.stdin.read(), sys.argv[2], sys.argv[3])
            return
        if op == "parse_removal":
            parse_removal(sys.stdin.read(), sys.argv[2], sys.argv[3])
            return
        if op == "exact_prs":
            emit(exact_prs(sys.stdin.read(), sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]))
            return
        if op == "github_repo":
            repo = github_repository_from_endpoint(sys.argv[2] if len(sys.argv) > 2 else "")
            emit(repo)
            return
        if op == "repository_proof":
            emit(repository_proof(json_object(sys.stdin.read())))
            return
        if op == "split_config":
            emit(split_config_stdout(sys.stdin.read()))
            return
        if op == "is_hook_approval":
            ok = is_hook_approval(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
            sys.stdout.write("true" if ok else "false")
            return
        if op == "strip_issue_title":
            title = sys.argv[2] if len(sys.argv) > 2 else ""
            sys.stdout.write(re.sub(r"^\s*\[[^\]\r\n]+\]\s*", "", title))
            return
        fail("unknown herd helper operation")
    except HerdError as error:
        fail(str(error))


if __name__ == "__main__":
    main()
'

_herd.trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  print -r -- "$s"
}

_herd.info() {
  print -r -- "${CAT_TEXT:-}$1${NC:-}"
}

_herd.warn() {
  print -r -- "${CAT_YELLOW:-}$1${NC:-}" >&2
}

_herd.err() {
  print -r -- "${CAT_RED:-}$1${NC:-}" >&2
}

_herd.reset_state() {
  typeset -g _HERD_STDOUT="" _HERD_STDERR="" _HERD_EXIT=0 _HERD_KILLED=false
  typeset -g _HERD_FAILURE="" _HERD_FAILURE_HAS_RESULT=0
  typeset -g _HERD_MODE=context _HERD_BRANCH="" _HERD_BASE="^"
  typeset -g _HERD_HAS_BRANCH=0 _HERD_HAS_BASE=0 _HERD_DRY_RUN=0 _HERD_LOAD_SECRETS=1
  typeset -g _HERD_ISSUE="" _HERD_INSTRUCTIONS="" _HERD_DONE_MODE=plain
  typeset -g _HERD_CALLER_WORKSPACE="" _HERD_CALLER_TAB="" _HERD_CALLER_PANE="" _HERD_CALLER_CWD=""
  typeset -g _HERD_ORIG_WORKSPACE="" _HERD_ORIG_PANE=""
  typeset -g _HERD_OWNED_WORKTRUNK="" _HERD_OWNED_HERDR="" _HERD_OWNED_BRANCH=""
  typeset -g _HERD_OWNED_PATH="" _HERD_OWNED_CREATED="" _HERD_OWNED_TAB=""
  typeset -g _HERD_OWNED_ROOT_PANE="" _HERD_OWNED_LAST_STATE=""
  typeset -g _HERD_BRANCH_FINAL="" _HERD_CHECKOUT_PATH=""
  typeset -g _HERD_REPO_ROOT="" _HERD_REPO_BRANCH="" _HERD_REPO_DIRTY=0
  typeset -g _HERD_ISSUE_NUMBER="" _HERD_ISSUE_TITLE="" _HERD_ISSUE_REPO="" _HERD_ISSUE_LABELS="[]"
}

_herd.py() {
  local op="$1" out st
  shift
  out="$(python3 -c "$_HERD_PYTHON" "$op" "$@" 2>&1)"
  st=$?
  if (( st != 0 )); then
    _HERD_FAILURE="$(_herd.trim "$out")"
    [[ -n "$_HERD_FAILURE" ]] || _HERD_FAILURE="herd helper failed: ${op}"
    return 1
  fi
  if [[ -n "$out" ]]; then
    print -r -- "$out"
  fi
}

_herd.py_stdin() {
  _herd.py "$@"
}

_herd.run() {
  local timeout_ms="$1" exec_cwd="$2" allow_failure="$3" cmd token envelope
  shift 3
  _HERD_STDOUT=""
  _HERD_STDERR=""
  _HERD_EXIT=0
  _HERD_KILLED=false
  _HERD_FAILURE=""
  _HERD_FAILURE_HAS_RESULT=0
  if (( $# == 0 )); then
    _HERD_FAILURE="herd exec requires a command"
    return 1
  fi
  cmd="$1"
  for token in "$@"; do
    case "$token" in
      --execute|--yes|--no-hooks|--clobber|--force)
        _HERD_FAILURE="forbidden argv token: ${token}"
        return 1
        ;;
      --force-delete)
        if [[ "${_HERD_ALLOW_FORCE_DELETE:-0}" != 1 ]]; then
          _HERD_FAILURE="forbidden argv token: ${token}"
          return 1
        fi
        ;;
    esac
  done
  envelope="$(python3 -c "$_HERD_PYTHON" exec "$timeout_ms" "$exec_cwd" "$@" 2>&1)" || {
    _HERD_FAILURE="python3 exec wrapper failed"
    return 1
  }
  if ! print -r -- "$envelope" | jq -e 'type == "object" and has("stdout") and has("stderr") and has("exitCode") and has("killed")' >/dev/null 2>&1; then
    _HERD_FAILURE="python3 exec wrapper returned invalid JSON"
    return 1
  fi
  _HERD_STDOUT="$(print -r -- "$envelope" | jq -r '.stdout')"
  _HERD_STDERR="$(print -r -- "$envelope" | jq -r '.stderr')"
  _HERD_EXIT="$(print -r -- "$envelope" | jq -r '.exitCode')"
  _HERD_KILLED="$(print -r -- "$envelope" | jq -r '.killed')"
  if (( allow_failure == 0 )) && { [[ "$_HERD_KILLED" == true ]] || (( _HERD_EXIT != 0 )); }; then
    local detail
    if [[ "$_HERD_KILLED" == true ]]; then
      detail="execution timed out"
    else
      detail="$(_herd.trim "$_HERD_STDERR")"
      [[ -n "$detail" ]] || detail="$(_herd.trim "$_HERD_STDOUT")"
      [[ -n "$detail" ]] || detail="exit ${_HERD_EXIT}"
    fi
    _HERD_FAILURE="${cmd} failed: ${detail}"
    _HERD_FAILURE_HAS_RESULT=1
    return 1
  fi
  return 0
}

_herd.require_herdr_env() {
  if [[ "${HERDR_ENV:-}" != 1 ]]; then
    _HERD_FAILURE="herd requires HERDR_ENV=1"
    return 1
  fi
}

_herd.require_runtime() {
  local -a missing=()
  command -v python3 >/dev/null 2>&1 || missing+=(python3)
  command -v herdr >/dev/null 2>&1 || missing+=(herdr)
  command -v jq >/dev/null 2>&1 || missing+=(jq)
  if (( ${#missing} )); then
    _HERD_FAILURE="herd requires ${(j:, :)missing} on PATH"
    return 1
  fi
}

_herd.require_pane_id() {
  if [[ -z "${HERDR_PANE_ID:-}" ]]; then
    _HERD_FAILURE="herd requires HERDR_PANE_ID"
    return 1
  fi
}

_herd.json_text() {
  local json="$1" field="$2" value
  value="$(print -r -- "$json" | jq -r --arg field "$field" '.[$field] | if type == "string" and . != "" then . else empty end')" || {
    _HERD_FAILURE="Command JSON is missing ${field}"
    return 1
  }
  if [[ -z "$value" ]]; then
    _HERD_FAILURE="Command JSON is missing ${field}"
    return 1
  fi
  print -r -- "$value"
}

_herd.fresh_caller() {
  local cwd="$1" result_type panes_type matches count pane
  _herd.run 15000 "$cwd" 0 herdr pane list || return
  if ! print -r -- "$_HERD_STDOUT" | jq -e '.' >/dev/null 2>&1; then
    _HERD_FAILURE="Command returned invalid JSON"
    return 1
  fi
  result_type="$(print -r -- "$_HERD_STDOUT" | jq -r '.result | type')"
  if [[ "$result_type" != object ]]; then
    _HERD_FAILURE="Command returned malformed JSON"
    return 1
  fi
  panes_type="$(print -r -- "$_HERD_STDOUT" | jq -r '.result.panes | type')"
  if [[ "$panes_type" != array ]]; then
    _HERD_FAILURE="herdr pane list returned no panes"
    return 1
  fi
  if [[ "$(print -r -- "$_HERD_STDOUT" | jq -r '[.result.panes[] | type == "object"] | all')" != true ]]; then
    _HERD_FAILURE="Command returned malformed JSON"
    return 1
  fi
  matches="$(print -r -- "$_HERD_STDOUT" | jq -c --arg pane_id "$HERDR_PANE_ID" '[.result.panes[] | select(.pane_id == $pane_id)]')" || {
    _HERD_FAILURE="Command returned invalid JSON"
    return 1
  }
  count="$(print -r -- "$matches" | jq -r 'length')"
  if [[ "$count" != 1 ]]; then
    _HERD_FAILURE="Expected exactly one Herdr pane for this HERDR_PANE_ID; found ${count}"
    return 1
  fi
  pane="$(print -r -- "$matches" | jq -c '.[0]')"
  _HERD_CALLER_WORKSPACE="$(_herd.json_text "$pane" workspace_id)" || return
  _HERD_CALLER_TAB="$(_herd.json_text "$pane" tab_id)" || return
  _HERD_CALLER_PANE="$(_herd.json_text "$pane" pane_id)" || return
  _HERD_CALLER_CWD="$(_herd.json_text "$pane" cwd)" || return
}

_herd.reresolve() {
  local when="$1" cwd="$2"
  _herd.fresh_caller "$cwd" || return
  if [[ "$_HERD_CALLER_WORKSPACE" != "$_HERD_ORIG_WORKSPACE" || "$_HERD_CALLER_PANE" != "$_HERD_ORIG_PANE" ]]; then
    _HERD_FAILURE="Invoking workspace or pane changed before ${when}"
    return 1
  fi
}

_herd.retained() {
  local -a resources=()
  [[ -n "${_HERD_OWNED_WORKTRUNK:-}" ]] && resources+=("Worktrunk owner=${_HERD_OWNED_WORKTRUNK}")
  [[ -n "${_HERD_OWNED_HERDR:-}" ]] && resources+=("Herdr owner=${_HERD_OWNED_HERDR}")
  [[ -n "${_HERD_OWNED_BRANCH:-}" ]] && resources+=("branch=${_HERD_OWNED_BRANCH}")
  [[ -n "${_HERD_OWNED_PATH:-}" ]] && resources+=("path=${_HERD_OWNED_PATH}")
  [[ -n "${_HERD_OWNED_CREATED:-}" ]] && resources+=("created=${_HERD_OWNED_CREATED}")
  [[ -n "${_HERD_OWNED_TAB:-}" ]] && resources+=("tab=${_HERD_OWNED_TAB}")
  [[ -n "${_HERD_OWNED_ROOT_PANE:-}" ]] && resources+=("root pane=${_HERD_OWNED_ROOT_PANE}")
  [[ -n "${_HERD_OWNED_LAST_STATE:-}" ]] && resources+=("last state=${_HERD_OWNED_LAST_STATE}")
  if (( ${#resources} )); then
    print -r -- " Retained: ${(j:, :)resources}."
  fi
}

_herd.safe_inspection() {
  local -a inspect_cmds=()
  [[ -n "${_HERD_OWNED_WORKTRUNK:-}" ]] && inspect_cmds+=("wt list")
  [[ -n "${_HERD_OWNED_HERDR:-}" ]] && inspect_cmds+=("herdr pane list")
  if (( ${#inspect_cmds} )); then
    print -r -- " Next: inspect fresh read-only state with ${(j: and :)inspect_cmds}."
  fi
}

_herd.hook_hint() {
  local approval
  if [[ "${_HERD_FAILURE_HAS_RESULT:-0}" != 1 || "$_HERD_KILLED" == true ]]; then
    return 0
  fi
  if [[ "${_HERD_FAILURE}" != [Ww][Tt]\ failed:* ]]; then
    return 0
  fi
  approval="$(_herd.py is_hook_approval "$_HERD_STDOUT" "$_HERD_STDERR" "$_HERD_EXIT" "$_HERD_KILLED")" || return 0
  if [[ "$approval" == true ]]; then
    print -r -- " Review and approve the reported Worktrunk hooks interactively with: wt config approvals add"
  fi
}

_herd.report_create_failure() {
  local hint retained inspect
  hint="$(_herd.hook_hint)"
  retained="$(_herd.retained)"
  inspect="$(_herd.safe_inspection)"
  _herd.err "herd failed: ${_HERD_FAILURE}.${hint}${retained}${inspect}"
}

_herd.done_cleanup_status() {
  if [[ "${_HERD_FAILURE_HAS_RESULT:-0}" == 1 && "$_HERD_EXIT" == 0 && "$_HERD_KILLED" != true && "${_HERD_FAILURE}" == [Ww]orktrunk\ reported\ success* ]]; then
    print -r -- " Worktrunk reported success but cleanup target validation failed, so its mutation state is unknown and no tab was intentionally closed."
  else
    print -r -- " Cleanup was not confirmed and no tab was intentionally closed."
  fi
}

_herd.report_done_failure() {
  local hint cleanup_status
  hint="$(_herd.hook_hint)"
  cleanup_status="$(_herd.done_cleanup_status)"
  _herd.err "herd done failed: ${_HERD_FAILURE}.${hint}${cleanup_status} Inspect fresh state with wt list and herdr pane list."
}

_herd.parse_done_mode() {
  local -a arguments
  arguments=("${@:2}")
  if (( ${#arguments} == 0 )); then
    _HERD_DONE_MODE=plain
    return 0
  fi
  if (( ${#arguments} == 1 )); then
    case "${arguments[1]}" in
      --force|-f) _HERD_DONE_MODE=force; return 0 ;;
      --delete|-d) _HERD_DONE_MODE=delete; return 0 ;;
    esac
  fi
  if (( ${#arguments} == 2 )); then
    if [[ ( "${arguments[1]}" == --force || "${arguments[1]}" == -f ) && ( "${arguments[2]}" == --delete || "${arguments[2]}" == -d ) ]] \
      || [[ ( "${arguments[1]}" == --delete || "${arguments[1]}" == -d ) && ( "${arguments[2]}" == --force || "${arguments[2]}" == -f ) ]]; then
      _HERD_DONE_MODE=delete
      return 0
    fi
  fi
  local joined="${arguments[*]}"
  _HERD_FAILURE="Unexpected herd done argument: ${joined:-done}"
  return 1
}

_herd.parse_args() {
  _HERD_MODE=context
  _HERD_BRANCH=""
  _HERD_BASE="^"
  _HERD_HAS_BRANCH=0
  _HERD_HAS_BASE=0
  _HERD_DRY_RUN=0
  _HERD_LOAD_SECRETS=1
  _HERD_ISSUE=""
  _HERD_INSTRUCTIONS=""
  if (( $# == 0 )); then
    return 0
  fi
  if [[ "$1" != context && "$1" != task && "$1" != issue && "$1" != done && "$1" != help && "$1" != -* ]]; then
    _HERD_MODE=task
    _HERD_INSTRUCTIONS="$*"
    return 0
  fi
  local -a head=() tail=()
  local found_delim=0 token
  for token in "$@"; do
    if (( found_delim )); then
      tail+=("$token")
    elif [[ "$token" == -- ]]; then
      found_delim=1
    else
      head+=("$token")
    fi
  done
  local -a tokens
  tokens=("${head[@]}")
  if (( ${#tokens} )) && [[ "${tokens[1]}" == context || "${tokens[1]}" == task || "${tokens[1]}" == issue ]]; then
    _HERD_MODE="${tokens[1]}"
    shift tokens
  elif (( ${#tokens} )) && [[ "${tokens[1]}" != --* ]]; then
    _HERD_FAILURE="Unknown herd mode: ${tokens[1]}"
    return 1
  fi
  local issue=""
  for token in "${tokens[@]}"; do
    case "$token" in
      --dry-run) _HERD_DRY_RUN=1 ;;
      --no-secret) _HERD_LOAD_SECRETS=0 ;;
      --branch=*)
        _HERD_BRANCH="${token#--branch=}"
        _HERD_HAS_BRANCH=1
        ;;
      --base=*)
        _HERD_BASE="${token#--base=}"
        _HERD_HAS_BASE=1
        ;;
      --model|--model=*)
        _HERD_FAILURE="Unexpected herd argument: ${token}"
        return 1
        ;;
      *)
        if [[ "$_HERD_MODE" == issue && -z "$issue" ]]; then
          issue="$token"
        else
          _HERD_FAILURE="Unexpected herd argument: ${token}"
          return 1
        fi
        ;;
    esac
  done
  local IFS=' '
  _HERD_INSTRUCTIONS="${tail[*]}"
  local trimmed
  trimmed="$(_herd.trim "$_HERD_INSTRUCTIONS")"
  if [[ "$_HERD_MODE" == task ]] && { (( ! found_delim )) || [[ -z "$trimmed" ]]; }; then
    _HERD_FAILURE="Task mode requires -- <exact task>"
    return 1
  fi
  if [[ "$_HERD_MODE" == issue && -z "$issue" ]]; then
    _HERD_FAILURE="Issue mode requires an issue reference"
    return 1
  fi
  if [[ "$_HERD_MODE" == issue ]]; then
    _HERD_ISSUE="$issue"
    _herd.py issue_number "$issue" >/dev/null || return
  fi
}

_herd.repo_info() {
  local cwd="$1" branch base_arg
  _herd.run 15000 "$cwd" 0 git rev-parse --show-toplevel || return
  _HERD_REPO_ROOT="$(_herd.trim "$_HERD_STDOUT")"
  _herd.run 15000 "$_HERD_REPO_ROOT" 0 git symbolic-ref --quiet --short HEAD || return
  branch="$(_herd.trim "$_HERD_STDOUT")"
  if [[ -z "$branch" ]]; then
    _HERD_FAILURE="The source checkout must be on a branch"
    return 1
  fi
  _HERD_REPO_BRANCH="$branch"
  if (( _HERD_HAS_BASE )); then
    base_arg="${_HERD_BASE}^{commit}"
    _herd.run 15000 "$_HERD_REPO_ROOT" 0 git rev-parse --verify "$base_arg" || return
  else
    _HERD_BASE="^"
  fi
  _herd.run 15000 "$_HERD_REPO_ROOT" 0 git status --porcelain || return
  if [[ -n "$(_herd.trim "$_HERD_STDOUT")" ]]; then
    _HERD_REPO_DIRTY=1
  else
    _HERD_REPO_DIRTY=0
  fi
}

_herd.unique_branch() {
  local root="$1" requested="$2" has_requested="$3" seed="$4" type="$5"
  local initial slugged suffix=1 candidate
  if (( has_requested )); then
    initial="$requested"
  else
    slugged="$(_herd.py slug "$seed")" || return
    initial="${type}/${slugged}"
  fi
  _herd.run 15000 "$root" 0 git check-ref-format --branch "$initial" || return
  while true; do
    if (( suffix == 1 )); then
      candidate="$initial"
    else
      candidate="${initial}-${suffix}"
    fi
    _herd.run 15000 "$root" 1 git show-ref --verify --quiet "refs/heads/${candidate}" || return
    if [[ "$_HERD_KILLED" == true ]]; then
      _HERD_FAILURE="git show-ref failed: execution timed out"
      _HERD_FAILURE_HAS_RESULT=1
      return 1
    fi
    if (( _HERD_EXIT == 0 )); then
      :
    elif (( _HERD_EXIT == 1 )); then
      _HERD_BRANCH_FINAL="$candidate"
      return 0
    else
      _HERD_FAILURE="git show-ref failed: exit ${_HERD_EXIT}"
      _HERD_FAILURE_HAS_RESULT=1
      return 1
    fi
    if (( has_requested )); then
      _HERD_FAILURE="Branch already exists: ${requested}"
      return 1
    fi
    (( suffix++ ))
  done
}

_herd.load_issue() {
  local root="$1" reference="$2" parsed topology selected repo data labels_json
  parsed="$(_herd.py issue_number "$reference")" || return
  _herd.run 15000 "$root" 0 gh repo view --json nameWithOwner,isFork,parent || return
  topology="$(print -r -- "$_HERD_STDOUT" | _herd.py_stdin parse_topology)" || return
  local parsed_repo
  parsed_repo="$(print -r -- "$parsed" | jq -r '.repo // empty')"
  if [[ -n "$parsed_repo" ]]; then
    selected="$(print -r -- "$topology" | jq -c --arg repo "$parsed_repo" '[.candidates[] | select(.repo | ascii_downcase == ($repo | ascii_downcase))] | if length == 1 then .[0] else empty end')" || {
      _HERD_FAILURE="Command returned invalid JSON"
      return 1
    }
    if [[ -z "$selected" ]]; then
      local scope candidate_repos
      scope="$(print -r -- "$topology" | jq -r '.scope')"
      candidate_repos="$(print -r -- "$topology" | jq -r '[.candidates[].repo] | join(", ")')"
      _HERD_FAILURE="Cross-repository issue rejected: ${parsed_repo} (allowed scope is ${scope}: ${candidate_repos})"
      return 1
    fi
    repo="$(print -r -- "$selected" | jq -r '.repo')"
  else
    repo="$(print -r -- "$topology" | jq -r '.candidates[0].repo')"
  fi
  local number
  number="$(print -r -- "$parsed" | jq -r '.number')"
  _herd.run 15000 "$root" 0 gh issue view "$number" --repo "$repo" --json number,title,labels || return
  data="$(print -r -- "$_HERD_STDOUT" | _herd.py_stdin parse_issue)" || return
  _HERD_ISSUE_NUMBER="$(print -r -- "$data" | jq -r '.number')"
  _HERD_ISSUE_TITLE="$(print -r -- "$data" | jq -r '.title')"
  _HERD_ISSUE_REPO="$repo"
  labels_json="$(print -r -- "$data" | jq -c '.labels')"
  _HERD_ISSUE_LABELS="$labels_json"
}

_herd.create_inner() {
  local generated_type=feat generated_seed=context branch_seed_json stripped issue_type
  _herd.parse_args "$@" || return
  _herd.require_herdr_env || return
  _herd.require_runtime || return
  _herd.require_pane_id || return
  _herd.fresh_caller "${PWD}" || return
  _HERD_ORIG_WORKSPACE="$_HERD_CALLER_WORKSPACE"
  _HERD_ORIG_PANE="$_HERD_CALLER_PANE"
  _herd.repo_info "$_HERD_CALLER_CWD" || return
  if (( _HERD_REPO_DIRTY )); then
    _herd.warn "Source checkout has dirty or untracked changes; they will not be copied."
  fi
  if [[ "$_HERD_MODE" == issue ]]; then
    _herd.load_issue "$_HERD_REPO_ROOT" "$_HERD_ISSUE" || return
    issue_type="$(_herd.py issue_type "$_HERD_ISSUE_LABELS" "$_HERD_ISSUE_TITLE")" || return
    stripped="$(_herd.py strip_issue_title "$_HERD_ISSUE_TITLE")" || return
    generated_type="$issue_type"
    generated_seed="issue-${_HERD_ISSUE_NUMBER}-${stripped}"
  elif [[ "$_HERD_MODE" == task ]]; then
    branch_seed_json="$(_herd.py request_branch "$_HERD_INSTRUCTIONS")" || return
    generated_type="$(print -r -- "$branch_seed_json" | jq -r '.type')"
    generated_seed="$(print -r -- "$branch_seed_json" | jq -r '.seed')"
  else
    if [[ -n "$(_herd.trim "$_HERD_INSTRUCTIONS")" ]]; then
      branch_seed_json="$(_herd.py request_branch "$_HERD_INSTRUCTIONS")" || return
    else
      branch_seed_json="$(_herd.py request_branch "context")" || return
    fi
    generated_type="$(print -r -- "$branch_seed_json" | jq -r '.type')"
    generated_seed="$(print -r -- "$branch_seed_json" | jq -r '.seed')"
  fi
  _herd.unique_branch "$_HERD_REPO_ROOT" "$_HERD_BRANCH" "$_HERD_HAS_BRANCH" "$generated_seed" "$generated_type" || return
  if (( _HERD_DRY_RUN )); then
    local base_notice secret_notice
    if (( _HERD_HAS_BASE )); then
      base_notice="$_HERD_BASE"
    else
      base_notice="Worktrunk's detected default branch (resolved during the real handoff)"
    fi
    if (( _HERD_LOAD_SECRETS )); then
      secret_notice="occur"
    else
      secret_notice="not occur"
    fi
    _herd.info "Dry run: would create ${_HERD_BRANCH_FINAL} from ${base_notice} in workspace ${_HERD_CALLER_WORKSPACE}. Secret loading would ${secret_notice}."
    return 0
  fi
  _herd.reresolve Worktrunk "$_HERD_REPO_ROOT" || return
  _HERD_OWNED_WORKTRUNK="Worktrunk"
  _HERD_OWNED_BRANCH="$_HERD_BRANCH_FINAL"
  _HERD_OWNED_CREATED="checkout creation unknown; inspect wt list"
  _HERD_OWNED_LAST_STATE="Worktrunk switch pending"
  _herd.run 300000 "$_HERD_REPO_ROOT" 1 wt -C "$_HERD_REPO_ROOT" switch --create "$_HERD_BRANCH_FINAL" --base "$_HERD_BASE" --no-cd --format=json || return
  if [[ "$_HERD_KILLED" == true ]] || (( _HERD_EXIT != 0 )); then
    local detail
    if [[ "$_HERD_KILLED" == true ]]; then
      detail="execution timed out"
    else
      detail="$(_herd.trim "$_HERD_STDERR")"
      [[ -n "$detail" ]] || detail="$(_herd.trim "$_HERD_STDOUT")"
      [[ -n "$detail" ]] || detail="exit ${_HERD_EXIT}"
    fi
    _HERD_FAILURE="wt failed: ${detail}"
    _HERD_FAILURE_HAS_RESULT=1
    return 1
  fi
  _HERD_CHECKOUT_PATH="$(print -r -- "$_HERD_STDOUT" | _herd.py_stdin switch_path)" || {
    _HERD_FAILURE_HAS_RESULT=1
    return 1
  }
  _HERD_OWNED_PATH="$_HERD_CHECKOUT_PATH"
  _HERD_OWNED_CREATED="checkout"
  _HERD_OWNED_LAST_STATE="checkout created"
  _herd.run 15000 "$_HERD_CHECKOUT_PATH" 0 git symbolic-ref --quiet --short HEAD || return
  local checkout_branch
  checkout_branch="$(_herd.trim "$_HERD_STDOUT")"
  if [[ "$checkout_branch" != "$_HERD_BRANCH_FINAL" ]]; then
    _HERD_FAILURE="Checkout branch mismatch: expected ${_HERD_BRANCH_FINAL}, got ${checkout_branch}"
    return 1
  fi
  _herd.reresolve "tab creation" "$_HERD_REPO_ROOT" || return
  local label
  label="${_HERD_BRANCH_FINAL##*/}"
  [[ -n "$label" ]] || label="$_HERD_BRANCH_FINAL"
  _HERD_OWNED_HERDR="$_HERD_CALLER_WORKSPACE"
  _HERD_OWNED_CREATED="checkout; tab creation unknown"
  _HERD_OWNED_LAST_STATE="tab create pending"
  local -a tab_argv
  tab_argv=(
    tab create
    --workspace "$_HERD_CALLER_WORKSPACE"
    --cwd "$_HERD_CHECKOUT_PATH"
    --label "$label"
    --env "OMP_HERD_MANAGED=1"
    --env "OMP_HERD_SOURCE_ROOT=${_HERD_REPO_ROOT}"
    --env "OMP_HERD_CHECKOUT=${_HERD_CHECKOUT_PATH}"
    --env "OMP_HERD_BRANCH=${_HERD_BRANCH_FINAL}"
  )
  if (( _HERD_LOAD_SECRETS )); then
    tab_argv+=(--env "OMP_HERD_LOAD_SECRETS=1")
  fi
  tab_argv+=(--no-focus)
  _herd.run 15000 "$_HERD_REPO_ROOT" 1 herdr "${tab_argv[@]}" || return
  if [[ "$_HERD_KILLED" == true ]] || (( _HERD_EXIT != 0 )); then
    if [[ "$_HERD_KILLED" != true ]]; then
      _HERD_OWNED_CREATED="checkout"
      _HERD_OWNED_LAST_STATE="tab create failed"
    fi
    local detail
    if [[ "$_HERD_KILLED" == true ]]; then
      detail="execution timed out"
    else
      detail="$(_herd.trim "$_HERD_STDERR")"
      [[ -n "$detail" ]] || detail="$(_herd.trim "$_HERD_STDOUT")"
      [[ -n "$detail" ]] || detail="exit ${_HERD_EXIT}"
    fi
    _HERD_FAILURE="herdr failed: ${detail}"
    _HERD_FAILURE_HAS_RESULT=1
    return 1
  fi
  local tab_info
  tab_info="$(print -r -- "$_HERD_STDOUT" | _herd.py_stdin tab_identity)" || {
    _HERD_FAILURE_HAS_RESULT=1
    return 1
  }
  _HERD_OWNED_TAB="$(print -r -- "$tab_info" | jq -r '.tab_id')"
  _HERD_OWNED_ROOT_PANE="$(print -r -- "$tab_info" | jq -r '.root_pane')"
  _HERD_OWNED_CREATED="checkout, tab"
  _HERD_OWNED_LAST_STATE="tab created"
  _herd.info "Created agentless tab ${_HERD_OWNED_TAB} on ${_HERD_BRANCH_FINAL} at ${_HERD_CHECKOUT_PATH} without changing focus."
}

_herd.create_cmd() {
  _herd.reset_state
  if ! _herd.create_inner "$@"; then
    _herd.report_create_failure
    return 1
  fi
  return 0
}

_herd.require_managed() {
  if [[ "${OMP_HERD_MANAGED:-}" != 1 \
     || -z "${OMP_HERD_SOURCE_ROOT:-}" \
     || -z "${OMP_HERD_CHECKOUT:-}" \
     || -z "${OMP_HERD_BRANCH:-}" \
     || -z "${HERDR_WORKSPACE_ID:-}" \
     || -z "${HERDR_TAB_ID:-}" \
     || -z "${HERDR_PANE_ID:-}" ]]; then
    _HERD_FAILURE="herd done is available only inside a managed herd checkout"
    return 1
  fi
}

_herd.done_target() {
  local source_root checkout_path branch head resolved_source source_common checkout_common
  source_root="$OMP_HERD_SOURCE_ROOT"
  _herd.fresh_caller "${PWD}" || return
  if [[ "$_HERD_CALLER_CWD" != "$OMP_HERD_CHECKOUT" ]]; then
    _HERD_FAILURE="The current pane was not started in the managed herd checkout"
    return 1
  fi
  if [[ "$_HERD_CALLER_WORKSPACE" != "$HERDR_WORKSPACE_ID" || "$_HERD_CALLER_TAB" != "$HERDR_TAB_ID" ]]; then
    _HERD_FAILURE="This pane is no longer in its original herd tab"
    return 1
  fi
  _herd.run 15000 "${PWD}" 0 git rev-parse --show-toplevel || return
  checkout_path="$(_herd.trim "$_HERD_STDOUT")"
  if [[ "$checkout_path" != "$OMP_HERD_CHECKOUT" ]]; then
    _HERD_FAILURE="The current checkout no longer matches the checkout created by herd"
    return 1
  fi
  _herd.run 15000 "$checkout_path" 0 git symbolic-ref --quiet --short HEAD || return
  branch="$(_herd.trim "$_HERD_STDOUT")"
  if [[ -z "$branch" || "$branch" != "$OMP_HERD_BRANCH" ]]; then
    _HERD_FAILURE="The current branch no longer matches the branch created by herd"
    return 1
  fi
  _herd.run 15000 "$checkout_path" 0 git rev-parse --verify HEAD || return
  head="$(_herd.trim "$_HERD_STDOUT")"
  _herd.run 15000 "$checkout_path" 0 git status --porcelain --untracked-files=all || return
  if [[ -n "$(_herd.trim "$_HERD_STDOUT")" ]]; then
    _HERD_FAILURE="The herd checkout has staged, modified, or untracked changes; commit or discard them before cleanup"
    return 1
  fi
  _herd.run 15000 "$source_root" 0 git rev-parse --show-toplevel || return
  resolved_source="$(_herd.trim "$_HERD_STDOUT")"
  if [[ "$resolved_source" != "$source_root" || "$source_root" == "$checkout_path" ]]; then
    _HERD_FAILURE="The original source checkout is unavailable or invalid"
    return 1
  fi
  _herd.run 15000 "$source_root" 0 git rev-parse --path-format=absolute --git-common-dir || return
  source_common="$(_herd.trim "$_HERD_STDOUT")"
  _herd.run 15000 "$checkout_path" 0 git rev-parse --path-format=absolute --git-common-dir || return
  checkout_common="$(_herd.trim "$_HERD_STDOUT")"
  if [[ -z "$source_common" || "$source_common" != "$checkout_common" ]]; then
    _HERD_FAILURE="The source and herd checkouts no longer belong to the same repository"
    return 1
  fi
  _herd.run 15000 "$source_root" 0 wt -C "$source_root" list --format=json || return
  print -r -- "$_HERD_STDOUT" | _herd.py_stdin match_worktree "$checkout_path" "$branch" || return
  typeset -g _HERD_DT_SOURCE="$source_root"
  typeset -g _HERD_DT_CHECKOUT="$checkout_path"
  typeset -g _HERD_DT_BRANCH="$branch"
  typeset -g _HERD_DT_HEAD="$head"
  typeset -g _HERD_DT_WS="$_HERD_CALLER_WORKSPACE"
  typeset -g _HERD_DT_TAB="$_HERD_CALLER_TAB"
  typeset -g _HERD_DT_PANE="$_HERD_CALLER_PANE"
  typeset -g _HERD_DT_CWD="$_HERD_CALLER_CWD"
}

_herd.same_done_target() {
  if [[ "$_HERD_DT_WS" != "$_HERD_INIT_WS" \
     || "$_HERD_DT_TAB" != "$_HERD_INIT_TAB" \
     || "$_HERD_DT_PANE" != "$_HERD_INIT_PANE" \
     || "$_HERD_DT_SOURCE" != "$_HERD_INIT_SOURCE" \
     || "$_HERD_DT_CHECKOUT" != "$_HERD_INIT_CHECKOUT" \
     || "$_HERD_DT_BRANCH" != "$_HERD_INIT_BRANCH" \
     || "$_HERD_DT_HEAD" != "$_HERD_INIT_HEAD" ]]; then
    _HERD_FAILURE="The herd checkout or invoking pane changed during cleanup verification"
    return 1
  fi
}

_herd.merged_pull_request() {
  local topology exact="[]" fields candidate_repo is_cross chunk count
  fields="number,state,mergedAt,url,headRefName,headRefOid,isCrossRepository,headRepositoryOwner"
  _herd.run 15000 "$_HERD_DT_CHECKOUT" 0 gh repo view --json nameWithOwner,isFork,parent || return
  topology="$(print -r -- "$_HERD_STDOUT" | _herd.py_stdin parse_topology)" || return
  local owner scope
  owner="$(print -r -- "$topology" | jq -r '.current.owner')"
  scope="$(print -r -- "$topology" | jq -r '.scope')"
  local n i
  n="$(print -r -- "$topology" | jq -r '.candidates | length')"
  for (( i = 0; i < n; i++ )); do
    candidate_repo="$(print -r -- "$topology" | jq -r --argjson i "$i" '.candidates[$i].repo')"
    is_cross="$(print -r -- "$topology" | jq -r --argjson i "$i" '.candidates[$i].isCrossRepository')"
    _herd.run 15000 "$_HERD_DT_CHECKOUT" 0 gh pr list --repo "$candidate_repo" --head "$_HERD_DT_BRANCH" --state all --limit 100 --json "$fields" || return
    chunk="$(print -r -- "$_HERD_STDOUT" | _herd.py_stdin exact_prs "$_HERD_DT_BRANCH" "$_HERD_DT_HEAD" "$owner" "$is_cross" "$candidate_repo")" || return
    exact="$(print -r -- "$exact" | jq -c --argjson more "$chunk" '. + $more')" || {
      _HERD_FAILURE="Command returned invalid JSON"
      return 1
    }
  done
  count="$(print -r -- "$exact" | jq -r 'length')"
  if [[ "$count" != 1 ]]; then
    if [[ "$count" == 0 ]]; then
      _HERD_FAILURE="No GitHub pull request in ${scope} has branch ${_HERD_DT_BRANCH} at the current local HEAD with the expected head owner and repository topology; cleanup was refused"
    else
      _HERD_FAILURE="Multiple GitHub pull requests in ${scope} match branch ${_HERD_DT_BRANCH} at the current local HEAD with the expected head owner and repository topology; cleanup was refused"
    fi
    return 1
  fi
  local state repo number url
  state="$(print -r -- "$exact" | jq -r '.[0].state')"
  repo="$(print -r -- "$exact" | jq -r '.[0].repo')"
  number="$(print -r -- "$exact" | jq -r '.[0].number')"
  url="$(print -r -- "$exact" | jq -r '.[0].url')"
  local merged_at
  merged_at="$(print -r -- "$exact" | jq -r '.[0].mergedAt // empty')"
  if [[ "$state" != MERGED || -z "$merged_at" || "$merged_at" == null ]]; then
    _HERD_FAILURE="GitHub pull request ${repo}#${number} is ${state}, not merged"
    return 1
  fi
  typeset -g _HERD_PR_REPO="$repo" _HERD_PR_NUMBER="$number" _HERD_PR_URL="$url"
}

_herd.config_values() {
  local key="$1"
  typeset -g _HERD_CONFIG_OK=0
  typeset -g _HERD_CONFIG_JSON="[]"
  _herd.run 15000 "$_HERD_DT_SOURCE" 1 git config --no-includes --local --get-all "$key" || return
  if [[ "$_HERD_KILLED" == true ]] || { (( _HERD_EXIT != 0 )) && (( _HERD_EXIT != 1 )); }; then
    return 0
  fi
  _HERD_CONFIG_OK=1
  if (( _HERD_EXIT == 1 )); then
    _HERD_CONFIG_JSON="[]"
    return 0
  fi
  _HERD_CONFIG_JSON="$(print -r -- "$_HERD_STDOUT" | _herd.py_stdin split_config)" || {
    _HERD_CONFIG_OK=0
    _HERD_CONFIG_JSON="[]"
    return 0
  }
}

_herd.remote_deletion_plan() {
  typeset -g _HERD_REMOTE_HAS_PLAN=0 _HERD_REMOTE_REASON="" _HERD_REMOTE_ENDPOINT="" _HERD_REMOTE_REF="" _HERD_REMOTE_HEAD=""
  local remote_json merge_json fetch_json push_json
  _herd.config_values "branch.${_HERD_DT_BRANCH}.remote" || { _HERD_REMOTE_REASON="branch remote configuration was missing, invalid, or ambiguous"; return 0; }
  if (( ! _HERD_CONFIG_OK )) || [[ "$(print -r -- "$_HERD_CONFIG_JSON" | jq -r 'length')" != 1 ]] \
     || [[ -z "$(print -r -- "$_HERD_CONFIG_JSON" | jq -r '.[0]')" ]] \
     || [[ "$(print -r -- "$_HERD_CONFIG_JSON" | jq -r '.[0]')" == . ]]; then
    _HERD_REMOTE_REASON="branch remote configuration was missing, invalid, or ambiguous"
    return 0
  fi
  remote_json="$_HERD_CONFIG_JSON"
  _herd.config_values "branch.${_HERD_DT_BRANCH}.merge" || { _HERD_REMOTE_REASON="branch merge configuration was missing, invalid, ambiguous, or not a heads ref"; return 0; }
  local merge_ref
  merge_ref="$(print -r -- "$_HERD_CONFIG_JSON" | jq -r '.[0] // empty')"
  if (( ! _HERD_CONFIG_OK )) || [[ "$(print -r -- "$_HERD_CONFIG_JSON" | jq -r 'length')" != 1 ]] \
     || [[ "$merge_ref" != refs/heads/* || "$merge_ref" == refs/heads/ ]]; then
    _HERD_REMOTE_REASON="branch merge configuration was missing, invalid, ambiguous, or not a heads ref"
    return 0
  fi
  merge_json="$_HERD_CONFIG_JSON"
  _herd.run 15000 "$_HERD_DT_SOURCE" 1 git check-ref-format "$merge_ref" || {
    _HERD_REMOTE_REASON="the configured upstream branch ref could not be validated"
    return 0
  }
  if [[ "$_HERD_KILLED" == true ]] || (( _HERD_EXIT != 0 )); then
    _HERD_REMOTE_REASON="the configured upstream branch ref was malformed"
    return 0
  fi
  if ! [[ "$_HERD_DT_HEAD" =~ ^[0-9a-fA-F]{40}$ || "$_HERD_DT_HEAD" =~ ^[0-9a-fA-F]{64}$ ]]; then
    _HERD_REMOTE_REASON="the managed checkout HEAD was not a full object ID"
    return 0
  fi
  local remote_name
  remote_name="$(print -r -- "$remote_json" | jq -r '.[0]')"
  _herd.config_values "remote.${remote_name}.url" || { _HERD_REMOTE_REASON="the configured remote did not have exactly one raw fetch endpoint"; return 0; }
  if (( ! _HERD_CONFIG_OK )) || [[ "$(print -r -- "$_HERD_CONFIG_JSON" | jq -r 'length')" != 1 ]] \
     || [[ -z "$(print -r -- "$_HERD_CONFIG_JSON" | jq -r '.[0]')" ]]; then
    _HERD_REMOTE_REASON="the configured remote did not have exactly one raw fetch endpoint"
    return 0
  fi
  fetch_json="$_HERD_CONFIG_JSON"
  _herd.config_values "remote.${remote_name}.pushurl" || { _HERD_REMOTE_REASON="the configured remote push endpoint was invalid or ambiguous"; return 0; }
  if (( ! _HERD_CONFIG_OK )) || [[ "$(print -r -- "$_HERD_CONFIG_JSON" | jq -r 'length')" -gt 1 ]] \
     || [[ "$(print -r -- "$_HERD_CONFIG_JSON" | jq -r 'map(select(. == "")) | length')" != 0 ]]; then
    _HERD_REMOTE_REASON="the configured remote push endpoint was invalid or ambiguous"
    return 0
  fi
  push_json="$_HERD_CONFIG_JSON"
  local fetch_endpoint push_endpoint fetch_repo push_repo
  fetch_endpoint="$(print -r -- "$fetch_json" | jq -r '.[0]')"
  if [[ "$(print -r -- "$push_json" | jq -r 'length')" == 0 ]]; then
    push_endpoint="$fetch_endpoint"
  else
    push_endpoint="$(print -r -- "$push_json" | jq -r '.[0]')"
  fi
  fetch_repo="$(_herd.py github_repo "$fetch_endpoint")" || {
    _HERD_REMOTE_REASON="the configured remote endpoints were not credential-free GitHub SSH or HTTPS endpoints"
    return 0
  }
  push_repo="$(_herd.py github_repo "$push_endpoint")" || {
    _HERD_REMOTE_REASON="the configured remote endpoints were not credential-free GitHub SSH or HTTPS endpoints"
    return 0
  }
  if [[ "$fetch_repo" == null || "$push_repo" == null || -z "$fetch_repo" || -z "$push_repo" ]]; then
    _HERD_REMOTE_REASON="the configured remote endpoints were not credential-free GitHub SSH or HTTPS endpoints"
    return 0
  fi
  fetch_repo="$(print -r -- "$fetch_repo" | jq -r '.')"
  push_repo="$(print -r -- "$push_repo" | jq -r '.')"
  if [[ -z "$fetch_repo" || -z "$push_repo" || "$fetch_repo" == null || "$push_repo" == null ]]; then
    _HERD_REMOTE_REASON="the configured remote endpoints were not credential-free GitHub SSH or HTTPS endpoints"
    return 0
  fi
  _herd.run 15000 "$_HERD_DT_SOURCE" 1 gh repo view "$fetch_repo" --json id,nameWithOwner,url || {
    _HERD_REMOTE_REASON="the configured fetch and push repository identities could not be proven"
    return 0
  }
  local fetch_result push_result
  fetch_result="$_HERD_STDOUT"
  local fetch_exit fetch_killed
  fetch_exit="$_HERD_EXIT"
  fetch_killed="$_HERD_KILLED"
  _herd.run 15000 "$_HERD_DT_SOURCE" 1 gh repo view "$push_repo" --json id,nameWithOwner,url || {
    _HERD_REMOTE_REASON="the configured fetch and push repository identities could not be proven"
    return 0
  }
  push_result="$_HERD_STDOUT"
  if [[ "$fetch_killed" == true || "$fetch_exit" != 0 || "$_HERD_KILLED" == true || "$_HERD_EXIT" != 0 ]]; then
    _HERD_REMOTE_REASON="the configured fetch and push repository identities could not be proven"
    return 0
  fi
  local source dest
  source="$(print -r -- "$fetch_result" | _herd.py_stdin repository_proof)" || {
    _HERD_REMOTE_REASON="the configured fetch and push repository identities could not be proven"
    return 0
  }
  dest="$(print -r -- "$push_result" | _herd.py_stdin repository_proof)" || {
    _HERD_REMOTE_REASON="the configured fetch and push repository identities could not be proven"
    return 0
  }
  local source_id dest_id source_repo dest_repo source_url
  source_id="$(print -r -- "$source" | jq -r '.id')"
  dest_id="$(print -r -- "$dest" | jq -r '.id')"
  source_repo="$(print -r -- "$source" | jq -r '.repo')"
  dest_repo="$(print -r -- "$dest" | jq -r '.repo')"
  source_url="$(print -r -- "$source" | jq -r '.url')"
  if [[ "$source_id" != "$dest_id" || "${source_repo:l}" != "${dest_repo:l}" ]]; then
    _HERD_REMOTE_REASON="the configured push repository did not match the branch remote's fetch repository"
    return 0
  fi
  _HERD_REMOTE_HAS_PLAN=1
  _HERD_REMOTE_ENDPOINT="${source_url}.git"
  _HERD_REMOTE_REF="$merge_ref"
  _HERD_REMOTE_HEAD="$_HERD_DT_HEAD"
}

_herd.local_branch_state() {
  typeset -g _HERD_BRANCH_STATE=unknown
  _herd.run 15000 "$_HERD_DT_SOURCE" 1 git show-ref --verify --quiet "refs/heads/${_HERD_DT_BRANCH}" || {
    _HERD_BRANCH_STATE=unknown
    return 0
  }
  if [[ "$_HERD_KILLED" == true ]] || { (( _HERD_EXIT != 0 )) && (( _HERD_EXIT != 1 )); }; then
    _HERD_BRANCH_STATE=unknown
    return 0
  fi
  if (( _HERD_EXIT == 0 )); then
    _HERD_BRANCH_STATE=present
  else
    _HERD_BRANCH_STATE=absent
  fi
}

_herd.remove_checkout() {
  local option=--no-delete-branch
  local _HERD_ALLOW_FORCE_DELETE=0
  if [[ "$_HERD_DONE_MODE" == delete ]]; then
    option=--force-delete
    _HERD_ALLOW_FORCE_DELETE=1
  fi
  _herd.run 300000 "$_HERD_DT_CHECKOUT" 1 wt remove --foreground --format=json "$option" "$_HERD_DT_CHECKOUT" || return
  if [[ "$_HERD_KILLED" == true ]] || (( _HERD_EXIT != 0 )); then
    local detail
    if [[ "$_HERD_KILLED" == true ]]; then
      detail="execution timed out"
    else
      detail="$(_herd.trim "$_HERD_STDERR")"
      [[ -n "$detail" ]] || detail="$(_herd.trim "$_HERD_STDOUT")"
      [[ -n "$detail" ]] || detail="exit ${_HERD_EXIT}"
    fi
    _HERD_FAILURE="wt failed: ${detail}"
    _HERD_FAILURE_HAS_RESULT=1
    return 1
  fi
  if ! print -r -- "$_HERD_STDOUT" | _herd.py_stdin parse_removal "$_HERD_DT_CHECKOUT" "$_HERD_DT_BRANCH"; then
    _HERD_FAILURE_HAS_RESULT=1
    return 1
  fi
}

_herd.close_tab() {
  local success="$1" closing_ws closing_tab closing_pane
  if ! _herd.fresh_caller "$_HERD_DT_SOURCE"; then
    _herd.err "Worktrunk cleanup succeeded, but the invoking pane could not be re-resolved before tab closure: ${_HERD_FAILURE}. Tab ${_HERD_DT_TAB} was left open."
    return 0
  fi
  closing_ws="$_HERD_CALLER_WORKSPACE"
  closing_tab="$_HERD_CALLER_TAB"
  closing_pane="$_HERD_CALLER_PANE"
  if [[ "$closing_ws" != "$_HERD_DT_WS" || "$closing_tab" != "$_HERD_DT_TAB" || "$closing_pane" != "$_HERD_DT_PANE" ]]; then
    _herd.err "Worktrunk cleanup succeeded, but the invoking pane identity changed before tab closure. Tab ${_HERD_DT_TAB} was left open."
    return 0
  fi
  _herd.info "$success"
  _herd.run 15000 "$_HERD_DT_SOURCE" 1 herdr tab close "$closing_tab" || {
    _herd.err "Worktrunk cleanup succeeded, but Herdr could not close tab ${_HERD_DT_TAB}: ${_HERD_FAILURE}. Close the tab manually."
    return 0
  }
  if [[ "$_HERD_KILLED" == true ]] || (( _HERD_EXIT != 0 )); then
    local detail
    if [[ "$_HERD_KILLED" == true ]]; then
      detail="execution timed out"
    else
      detail="$(_herd.trim "$_HERD_STDERR")"
      [[ -n "$detail" ]] || detail="$(_herd.trim "$_HERD_STDOUT")"
      [[ -n "$detail" ]] || detail="exit ${_HERD_EXIT}"
    fi
    _herd.err "Worktrunk cleanup succeeded, but Herdr could not close tab ${_HERD_DT_TAB}: ${detail}. Close the tab manually."
  fi
}

_herd.isolated_git_env() {
  typeset -ga _HERD_ISOLATED_ENV
  _HERD_ISOLATED_ENV=(
    -u GIT_CONFIG_PARAMETERS
    -u GIT_CONFIG
    -u GIT_DIR
    -u GIT_WORK_TREE
    -u GIT_COMMON_DIR
    -u GIT_TEMPLATE_DIR
    GIT_CONFIG_NOSYSTEM=1
    GIT_CONFIG_GLOBAL=/dev/null
    GIT_CONFIG_COUNT=1
    GIT_CONFIG_KEY_0=credential.helper
    'GIT_CONFIG_VALUE_0=!gh auth git-credential'
  )
}

_herd.delete_remote() {
  local scratch=""
  _herd.isolated_git_env
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/herd-git-XXXXXX")" || {
    _herd.warn "Local cleanup succeeded, but upstream deletion was not confirmed."
    return 0
  }
  {
    _herd.run 15000 "$_HERD_DT_SOURCE" 1 env "${_HERD_ISOLATED_ENV[@]}" git init --bare --quiet "$scratch" || {
      _herd.warn "Local cleanup succeeded, but upstream deletion was not confirmed."
      return 0
    }
    if [[ "$_HERD_KILLED" == true ]] || (( _HERD_EXIT != 0 )); then
      _herd.warn "Local cleanup succeeded, but the isolated upstream deletion environment could not be initialized."
      return 0
    fi
    _herd.run 15000 "$scratch" 1 env "${_HERD_ISOLATED_ENV[@]}" git push "$_HERD_REMOTE_ENDPOINT" "--force-with-lease=${_HERD_REMOTE_REF}:${_HERD_REMOTE_HEAD}" ":${_HERD_REMOTE_REF}" || {
      _herd.warn "Local cleanup succeeded, but upstream deletion was not confirmed."
      return 0
    }
    if [[ "$_HERD_KILLED" == true ]]; then
      _herd.warn "Local cleanup succeeded, but upstream deletion timed out; its outcome is unknown."
    elif (( _HERD_EXIT != 0 )); then
      _herd.warn "Local cleanup succeeded, but upstream deletion was not confirmed."
    else
      _herd.info "Local cleanup succeeded and the exact upstream branch deletion was confirmed."
    fi
  } always {
    if [[ -n "$scratch" && -d "$scratch" ]]; then
      rm -rf -- "$scratch"
    fi
  }
}

_herd.complete_herd() {
  local initial_pr_repo initial_pr_number initial_pr_url
  _herd.require_managed || return
  _herd.require_runtime || return
  _herd.done_target || return
  typeset -g _HERD_INIT_WS="$_HERD_DT_WS" _HERD_INIT_TAB="$_HERD_DT_TAB" _HERD_INIT_PANE="$_HERD_DT_PANE"
  typeset -g _HERD_INIT_SOURCE="$_HERD_DT_SOURCE" _HERD_INIT_CHECKOUT="$_HERD_DT_CHECKOUT"
  typeset -g _HERD_INIT_BRANCH="$_HERD_DT_BRANCH" _HERD_INIT_HEAD="$_HERD_DT_HEAD"
  if [[ "$_HERD_DONE_MODE" == plain ]]; then
    _herd.merged_pull_request || return
    initial_pr_repo="$_HERD_PR_REPO"
    initial_pr_number="$_HERD_PR_NUMBER"
    initial_pr_url="$_HERD_PR_URL"
  fi
  if [[ "$_HERD_DONE_MODE" == delete ]]; then
    _herd.remote_deletion_plan || return
  fi
  _herd.done_target || return
  _herd.same_done_target || return
  if [[ "$_HERD_DONE_MODE" == plain ]]; then
    _herd.merged_pull_request || return
    if [[ "$_HERD_PR_REPO" != "$initial_pr_repo" || "$_HERD_PR_NUMBER" != "$initial_pr_number" || "$_HERD_PR_URL" != "$initial_pr_url" ]]; then
      _HERD_FAILURE="The merged GitHub pull request changed during cleanup verification"
      return 1
    fi
    _herd.info "Merged GitHub pull request ${_HERD_PR_REPO}#${_HERD_PR_NUMBER} confirmed. Removing ${_HERD_DT_BRANCH} through Worktrunk, then closing this tab."
  elif [[ "$_HERD_DONE_MODE" == force ]]; then
    _herd.info "Clean managed checkout confirmed. Abandoning ${_HERD_DT_BRANCH} through Worktrunk while retaining local and remote branches, then closing this tab."
  else
    _herd.info "Clean managed checkout confirmed. Removing ${_HERD_DT_BRANCH} through Worktrunk; upstream deletion will be attempted only after exact local cleanup is confirmed."
  fi
  _herd.remove_checkout || return
  _herd.local_branch_state
  if [[ "$_HERD_DONE_MODE" == plain ]]; then
    if [[ "$_HERD_BRANCH_STATE" == unknown ]]; then
      _herd.warn "Worktree removal succeeded, but local branch ${_HERD_DT_BRANCH} state could not be confirmed."
    elif [[ "$_HERD_BRANCH_STATE" == present ]]; then
      _herd.warn "Worktree removal succeeded; Worktrunk retained local branch ${_HERD_DT_BRANCH} under its merge-safety policy."
    fi
    _herd.close_tab "Worktrunk accepted cleanup for merged pull request #${_HERD_PR_NUMBER}; closing herd tab ${_HERD_DT_TAB}."
    return 0
  fi
  if [[ "$_HERD_DONE_MODE" == force ]]; then
    if [[ "$_HERD_BRANCH_STATE" == present ]]; then
      _herd.info "Worktree removal succeeded; local branch ${_HERD_DT_BRANCH} was retained as requested."
    else
      local state_word
      if [[ "$_HERD_BRANCH_STATE" == absent ]]; then
        state_word="not retained"
      else
        state_word="not confirmable"
      fi
      _herd.warn "Worktree removal succeeded, but local branch ${_HERD_DT_BRANCH} was ${state_word}."
    fi
    _herd.close_tab "Worktrunk accepted forced abandonment; no remote branch was modified. Closing herd tab ${_HERD_DT_TAB}."
    return 0
  fi
  if [[ "$_HERD_BRANCH_STATE" == present ]]; then
    _herd.warn "Worktree removal succeeded, but local branch ${_HERD_DT_BRANCH} remains; upstream deletion was skipped."
  elif [[ "$_HERD_BRANCH_STATE" == unknown ]]; then
    _herd.warn "Worktree removal succeeded, but local branch ${_HERD_DT_BRANCH} absence could not be confirmed; upstream deletion was skipped."
  elif (( ! _HERD_REMOTE_HAS_PLAN )) && [[ -z "$_HERD_REMOTE_REASON" ]]; then
    _herd.warn "Worktree and local branch removal succeeded, but upstream deletion was skipped because its preflight was unavailable."
  elif (( ! _HERD_REMOTE_HAS_PLAN )); then
    _herd.warn "Worktree and local branch removal succeeded, but upstream deletion was skipped because ${_HERD_REMOTE_REASON}."
  else
    _herd.delete_remote
  fi
  local local_outcome
  if [[ "$_HERD_BRANCH_STATE" == absent ]]; then
    local_outcome="local branch deletion"
  else
    local_outcome="checkout removal"
  fi
  _herd.close_tab "Worktrunk accepted cleanup with ${local_outcome}; closing herd tab ${_HERD_DT_TAB}."
}

_herd.done_cmd() {
  _herd.reset_state
  if ! _herd.parse_done_mode "$@"; then
    _herd.report_done_failure
    return 1
  fi
  if ! _herd.require_herdr_env; then
    _herd.report_done_failure
    return 1
  fi
  if ! _herd.complete_herd; then
    _herd.report_done_failure
    return 1
  fi
  return 0
}

herd.help() {
  emulate -L zsh
  print -r -- "Usage:"
  print -r -- "  herd"
  print -r -- "  herd <exact task>"
  print -r -- "  herd context [--branch=<name>] [--base=<ref>] [--no-secret] [--dry-run] [-- <additional exact instructions>]"
  print -r -- "  herd task [--branch=<name>] [--base=<ref>] [--no-secret] [--dry-run] -- <exact task>"
  print -r -- "  herd issue <123|#123|owner/repo#123|GitHub URL> [--branch=<name>] [--base=<ref>] [--no-secret] [--dry-run] [-- <additional exact instructions>]"
  print -r -- "  Unqualified issue numbers (\`123\` or \`#123\`) target the current repository."
  print -r -- "  Qualified issues may target the current repository or its direct fork parent only; arbitrary repositories are not supported."
  print -r -- "  herd done [--force|-f] [--delete|-d]"
}

herd() {
  emulate -L zsh
  if [[ "${1:-}" == --help || "${1:-}" == -h || "${1:-}" == help ]]; then
    herd.help
    return 0
  fi
  if [[ "${1:-}" == done ]]; then
    _herd.done_cmd "$@"
    return
  fi
  _herd.create_cmd "$@"
}
