#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
zsh_bin="${ZSH_BIN:-zsh}"
herd_functions="$repo_root/roles/zsh/files/zsh/herd_functions.zsh"

if ! command -v "$zsh_bin" >/dev/null; then
  echo "SKIP: zsh not installed"
  exit 0
fi
zsh_bin="$(command -v "$zsh_bin")"

if ! command -v python3 >/dev/null; then
  echo "python3 is required for herd tests" >&2
  exit 1
fi
if ! command -v jq >/dev/null; then
  echo "jq is required for herd tests" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir"

source_dir="$tmp_dir/source"
repo_dir="$tmp_dir/repo"
checkout_dir="$tmp_dir/checkout"
mkdir -p "$source_dir" "$repo_dir/.git" "$checkout_dir"

HEAD_OID='0123456789abcdef0123456789abcdef01234567'

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  if [[ -n "${HERD_STDOUT:-}" && -f "${HERD_STDOUT:-}" ]]; then
    printf 'stdout:\n%s\n' "$(cat "$HERD_STDOUT")" >&2
  fi
  if [[ -n "${HERD_STDERR:-}" && -f "${HERD_STDERR:-}" ]]; then
    printf 'stderr:\n%s\n' "$(cat "$HERD_STDERR")" >&2
  fi
  if [[ -n "${HERD_CALLS:-}" && -f "${HERD_CALLS:-}" ]]; then
    printf 'calls:\n%s\n' "$(cat "$HERD_CALLS")" >&2
  fi
  exit 1
}

cat > "$bin_dir/_herd_mock.py" <<'PY'
#!/usr/bin/env python3
import json
import os
import sys
import time

HEAD = "0123456789abcdef0123456789abcdef01234567"


def log_call(cmd, argv):
    path = os.environ["HERD_CALLS"]
    record = {
        "cmd": cmd,
        "cwd": os.getcwd(),
        "argv": list(argv),
        "git_config_nosystem": os.environ.get("GIT_CONFIG_NOSYSTEM"),
        "git_config_global": os.environ.get("GIT_CONFIG_GLOBAL"),
        "git_dir": os.environ.get("GIT_DIR"),
        "git_config": os.environ.get("GIT_CONFIG"),
    }
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, separators=(",", ":")) + "\n")


def bump(path):
    try:
        count = int(open(path, encoding="utf-8").read().strip() or "0")
    except FileNotFoundError:
        count = 0
    count += 1
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(str(count))
    return count


def env_path(name, default=""):
    return os.environ.get(name, default)


def repo():
    return env_path("HERD_REPO")


def checkout():
    return env_path("HERD_CHECKOUT")


def is_checkout(cwd):
    target = checkout()
    if not target:
        return False
    return os.path.realpath(cwd) == os.path.realpath(target)


def created_branch():
    path = env_path("HERD_CREATED_BRANCH_FILE")
    if path and os.path.isfile(path):
        value = open(path, encoding="utf-8").read().strip()
        if value:
            return value
    return env_path("OMP_HERD_BRANCH") or env_path("HERD_CHECKOUT_BRANCH") or "fix/widget"


def collisions():
    raw = env_path("HERD_COLLISIONS")
    names = []
    for item in raw.replace(",", " ").split():
        names.append(item[11:] if item.startswith("refs/heads/") else item)
    return names


def git_main(argv):
    cwd = os.getcwd()
    if argv[:1] == ["rev-parse"]:
        rest = argv[1:]
        if rest == ["--show-toplevel"]:
            print(checkout() if is_checkout(cwd) else repo())
            return 0
        if rest == ["--verify", "HEAD"]:
            print(HEAD)
            return 0
        if rest == ["--path-format=absolute", "--git-common-dir"]:
            print(os.path.join(repo(), ".git"))
            return 0
        if rest[:1] == ["--verify"] and len(rest) == 2:
            spec = rest[1]
            if spec.endswith("^{commit}"):
                ref = spec[: -len("^{commit}")]
                if env_path("HERD_INVALID_BASE") == "1" or ref == "missing":
                    print("fatal: needed a single revision", file=sys.stderr)
                    return 1
                print(HEAD)
                return 0
            if spec == "HEAD":
                print(HEAD)
                return 0
        print(f"unexpected git rev-parse {argv!r}", file=sys.stderr)
        return 1
    if argv[:1] == ["symbolic-ref"]:
        if is_checkout(cwd):
            print(created_branch())
        else:
            print(env_path("HERD_SOURCE_BRANCH") or "main")
        return 0
    if argv[:1] == ["status"]:
        if env_path("HERD_DIRTY") == "1":
            print(" M unfinished.txt" if "--untracked-files=all" in argv else "?? new.txt")
        return 0
    if argv[:1] == ["check-ref-format"]:
        name = argv[-1]
        if "--branch" in argv:
            if env_path("HERD_INVALID_BRANCH") == "1" or ".." in name or not name:
                print("fatal: invalid branch name", file=sys.stderr)
                return 1
        return 0
    if argv[:1] == ["show-ref"]:
        count_file = env_path("HERD_SHOW_REF_COUNT_FILE")
        count = bump(count_file) if count_file else 0
        cap = int(env_path("HERD_SHOW_REF_CAP") or "0")
        if cap and count > cap:
            print("unbounded collision probe", file=sys.stderr)
            return 99
        if env_path("HERD_SHOW_REF_KILLED") == "1" and count == 1:
            time.sleep(20)
        ref = argv[-1]
        name = ref[11:] if ref.startswith("refs/heads/") else ref
        exists = name in collisions() or env_path("HERD_SHOW_REF_ALWAYS_EXISTS") == "1"
        if env_path("HERD_LOCAL_BRANCH_EXISTS") == "1" and name == (env_path("OMP_HERD_BRANCH") or "fix/widget"):
            exists = True
        return 0 if exists else 1
    if argv[:1] == ["config"] and "--get-all" in argv:
        key = argv[-1]
        branch = env_path("OMP_HERD_BRANCH") or "fix/widget"
        remote = env_path("HERD_BRANCH_REMOTE", "origin")
        merge = env_path("HERD_BRANCH_MERGE") or f"refs/heads/{branch}"
        fetch = env_path("HERD_FETCH_URL") or "https://github.com/owner/repo.git"
        values = None
        if key == f"branch.{branch}.remote":
            values = [] if env_path("HERD_NO_BRANCH_REMOTE") == "1" else [remote]
        elif key == f"branch.{branch}.merge":
            values = [merge]
        elif key == f"remote.{remote}.url":
            values = [fetch]
        elif key == f"remote.{remote}.pushurl":
            if env_path("HERD_NO_PUSHURL") == "1":
                values = []
            else:
                values = [env_path("HERD_PUSH_URL") or fetch]
        else:
            values = []
        if not values:
            return 1
        print("\n".join(values))
        return 0
    if argv[:1] == ["init"]:
        return 0
    if argv[:1] == ["push"]:
        return 0
    print(f"unexpected git {argv!r}", file=sys.stderr)
    return 1


def envelope(result):
    return json.dumps({"id": "r", "result": result}, separators=(",", ":"))


def herdr_main(argv):
    if argv[:2] == ["pane", "list"]:
        count_file = env_path("HERD_PANE_LIST_COUNT_FILE")
        count = bump(count_file) if count_file else 1
        matches = int(env_path("HERD_PANE_MATCHES") or "1")
        workspace = env_path("HERD_WORKSPACE_ID") or "workspace-fresh"
        if env_path("HERD_CALLER_CHANGE_AT") and int(env_path("HERD_CALLER_CHANGE_AT")) == count:
            workspace = "workspace-changed"
        cwd = env_path("HERD_PANE_CWD") or env_path("HERD_SOURCE")
        pane = {
            "pane_id": "caller-pane",
            "tab_id": "caller-tab",
            "workspace_id": workspace,
            "cwd": cwd,
        }
        if matches <= 0:
            panes = []
        elif matches == 1:
            panes = [pane]
        else:
            panes = [pane, dict(pane)]
        print(envelope({"type": "pane_list", "panes": panes}))
        return 0
    if argv[:2] == ["tab", "create"]:
        print(envelope({"tab": {"tab_id": "tab-1"}, "root_pane": {"pane_id": "pane-root"}}))
        return 0
    if argv[:2] == ["tab", "close"]:
        print(envelope({"type": "tab_closed", "tab_id": "caller-tab", "workspace_id": "workspace-fresh"}))
        return 0
    print(f"unexpected herdr {argv!r}", file=sys.stderr)
    return 1


def wt_main(argv):
    branch = env_path("OMP_HERD_BRANCH") or "fix/widget"
    if "switch" in argv:
        if env_path("HERD_WT_FAIL") == "approval":
            sys.stderr.write(
                "▲ cargo-difftest needs approval to execute 1 command:\n"
                "○ post-start install\n"
                "✗ Cannot prompt for approval in non-interactive environment\n"
                "↳ run wt config approvals add\n"
            )
            return 1
        create_at = argv.index("--create") + 1 if "--create" in argv else -1
        if create_at > 0:
            path = env_path("HERD_CREATED_BRANCH_FILE")
            if path:
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(argv[create_at])
        print(json.dumps({"path": checkout()}, separators=(",", ":")))
        return 0
    if "list" in argv:
        print(json.dumps([
            {"branch": branch, "path": checkout(), "kind": "worktree", "is_main": False},
        ], separators=(",", ":")))
        return 0
    if "remove" in argv:
        print(json.dumps([
            {"kind": "worktree", "branch": branch, "path": checkout(), "branch_deleted": "--no-delete-branch" not in argv},
        ], separators=(",", ":")))
        return 0
    print(f"unexpected wt {argv!r}", file=sys.stderr)
    return 1


def gh_main(argv):
    if argv[:1] == ["repo"]:
        if "--json" in argv:
            fields = argv[argv.index("--json") + 1]
            if "id" in fields:
                print(json.dumps({
                    "id": "R_owner_repo",
                    "nameWithOwner": "owner/repo",
                    "url": "https://github.com/owner/repo",
                }, separators=(",", ":")))
            else:
                print(json.dumps({
                    "nameWithOwner": "owner/repo",
                    "isFork": False,
                    "parent": None,
                }, separators=(",", ":")))
            return 0
    if argv[:1] == ["issue"]:
        print(json.dumps({
            "number": 123,
            "title": "Fix widget",
            "labels": [{"name": "bug"}],
        }, separators=(",", ":")))
        return 0
    if argv[:1] == ["pr"]:
        branch = env_path("OMP_HERD_BRANCH") or "fix/widget"
        print(json.dumps([{
            "number": 42,
            "state": "MERGED",
            "mergedAt": "2026-07-13T00:00:00Z",
            "url": "https://github.com/owner/repo/pull/42",
            "headRefName": branch,
            "headRefOid": HEAD,
            "isCrossRepository": False,
            "headRepositoryOwner": {"login": "owner"},
        }], separators=(",", ":")))
        return 0
    print(f"unexpected gh {argv!r}", file=sys.stderr)
    return 1


def main():
    cmd = os.path.basename(sys.argv[0])
    argv = sys.argv[1:]
    log_call(cmd, argv)
    if cmd == "git":
        code = git_main(argv)
    elif cmd == "herdr":
        code = herdr_main(argv)
    elif cmd == "wt":
        code = wt_main(argv)
    elif cmd == "gh":
        code = gh_main(argv)
    else:
        print(f"unexpected mock {cmd}", file=sys.stderr)
        code = 1
    sys.exit(code)


if __name__ == "__main__":
    main()
PY
chmod +x "$bin_dir/_herd_mock.py"
for mock_name in herdr git wt gh; do
  ln -s "$bin_dir/_herd_mock.py" "$bin_dir/$mock_name"
done

export HERD_FUNCTIONS="$herd_functions"
export HERD_BIN_DIR="$bin_dir"
export HERD_REPO="$repo_dir"
export HERD_CHECKOUT="$checkout_dir"
export HERD_SOURCE="$source_dir"
export HERD_HEAD="$HEAD_OID"

cat > "$tmp_dir/calls_lib.py" <<'PY'
import json
import os
import sys

FORBIDDEN = {"--execute", "--yes", "--no-hooks", "--clobber"}


def load():
    path = os.environ["HERD_CALLS"]
    if not os.path.isfile(path):
        return []
    return [json.loads(line) for line in open(path, encoding="utf-8") if line.strip()]


def die(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def same_path(left, right):
    try:
        return os.path.samefile(left, right)
    except OSError:
        return os.path.normpath(left) == os.path.normpath(right)


def invariants(calls=None):
    calls = load() if calls is None else calls
    for call in calls:
        argv = call["argv"]
        if call["cmd"] == "wt" and "--force" in argv:
            die(f"forbidden wt --force: {argv}")
        if call["cmd"] == "herdr" and argv[:2] == ["pane", "current"]:
            die(f"herdr pane current is forbidden: {argv}")
        if call["cmd"] == "herdr" and argv[:1] == ["agent"]:
            die(f"herdr agent is forbidden: {argv}")
        for arg in argv:
            if arg in FORBIDDEN:
                die(f"forbidden argv token {arg} in {call['cmd']} {argv}")
    return calls
PY

clear_fixtures() {
  unset HERD_DIRTY HERD_COLLISIONS HERD_CALLER_CHANGE_AT HERD_PANE_MATCHES \
    HERD_SOURCE_BRANCH HERD_INVALID_BASE HERD_INVALID_BRANCH \
    HERD_LOCAL_BRANCH_EXISTS HERD_WT_FAIL HERD_SHOW_REF_ALWAYS_EXISTS \
    HERD_SHOW_REF_CAP HERD_SHOW_REF_KILLED HERD_FETCH_URL HERD_PUSH_URL HERD_NO_PUSHURL \
    HERD_BRANCH_REMOTE HERD_BRANCH_MERGE HERD_NO_BRANCH_REMOTE \
    HERD_UNSET_ENV HERD_UNSET_PANE HERD_UNSET_MANAGED HERD_WORKSPACE_ID \
    HERD_CHECKOUT_BRANCH HERD_PANE_CWD OMP_HERD_MANAGED OMP_HERD_SOURCE_ROOT \
    OMP_HERD_CHECKOUT OMP_HERD_BRANCH OMP_HERD_LOAD_SECRETS \
    HERDR_WORKSPACE_ID HERDR_TAB_ID HERDR_PANE_ID HERDR_ENV \
    HERD_BOUND_SECONDS || true
}

prepare_logs() {
  CASE_DIR="$(mktemp -d "$tmp_dir/case.XXXXXX")"
  export HERD_CALLS="$CASE_DIR/calls"
  export HERD_STDOUT="$CASE_DIR/stdout"
  export HERD_STDERR="$CASE_DIR/stderr"
  export HERD_PANE_LIST_COUNT_FILE="$CASE_DIR/pane_lists"
  export HERD_CREATED_BRANCH_FILE="$CASE_DIR/created_branch"
  export HERD_SHOW_REF_COUNT_FILE="$CASE_DIR/show_ref_count"
  : > "$HERD_CALLS"
  : > "$HERD_STDOUT"
  : > "$HERD_STDERR"
  printf '0' > "$HERD_PANE_LIST_COUNT_FILE"
  : > "$HERD_CREATED_BRANCH_FILE"
  printf '0' > "$HERD_SHOW_REF_COUNT_FILE"
}

run_herd() {
  local kind="$1"
  shift
  prepare_logs
  local workdir="$source_dir"
  local pane_cwd="$source_dir"

  case "$kind" in
    help)
      workdir="$source_dir"
      pane_cwd="$source_dir"
      ;;
    create)
      workdir="$source_dir"
      pane_cwd="$source_dir"
      ;;
    done)
      workdir="$checkout_dir"
      pane_cwd="$checkout_dir"
      ;;
    *)
      fail "unknown run_herd kind: $kind"
      ;;
  esac
  export HERD_PANE_CWD="${HERD_PANE_CWD:-$pane_cwd}"

  local herd_args=("$@")
  local bound="${HERD_BOUND_SECONDS:-0}"

  set +e
  (
    for fixture in HERD_DIRTY HERD_COLLISIONS HERD_CALLER_CHANGE_AT HERD_PANE_MATCHES \
      HERD_SOURCE_BRANCH HERD_INVALID_BASE HERD_INVALID_BRANCH HERD_LOCAL_BRANCH_EXISTS \
      HERD_WT_FAIL HERD_SHOW_REF_ALWAYS_EXISTS HERD_SHOW_REF_CAP HERD_SHOW_REF_KILLED \
      HERD_FETCH_URL HERD_PUSH_URL HERD_NO_PUSHURL HERD_BRANCH_REMOTE HERD_BRANCH_MERGE \
      HERD_NO_BRANCH_REMOTE HERD_WORKSPACE_ID HERD_CHECKOUT_BRANCH HERD_PANE_CWD \
      HERD_UNSET_ENV HERD_UNSET_PANE HERD_UNSET_MANAGED; do
      if [[ -n "${!fixture+x}" ]]; then
        export "$fixture"
      fi
    done
    export PATH="$bin_dir:$PATH"
    export HERD_CALLS HERD_BIN_DIR HERD_FUNCTIONS HERD_REPO HERD_CHECKOUT HERD_SOURCE
    export HERD_PANE_CWD HERD_PANE_LIST_COUNT_FILE HERD_CREATED_BRANCH_FILE
    export HERD_SHOW_REF_COUNT_FILE HERD_HEAD
    unset HERDR_SOCKET HERDR_SOCK HERDR_URL 2>/dev/null || true

    if [[ "$kind" == "help" || "${HERD_UNSET_ENV:-}" == "1" ]]; then
      unset HERDR_ENV
    else
      export HERDR_ENV=1
    fi
    if [[ "$kind" == "help" || "${HERD_UNSET_PANE:-}" == "1" ]]; then
      unset HERDR_PANE_ID
    else
      export HERDR_PANE_ID="${HERDR_PANE_ID:-caller-pane}"
    fi

    if [[ "$kind" == "done" && "${HERD_UNSET_MANAGED:-}" != "1" ]]; then
      export OMP_HERD_MANAGED="${OMP_HERD_MANAGED:-1}"
      export OMP_HERD_SOURCE_ROOT="${OMP_HERD_SOURCE_ROOT:-$repo_dir}"
      export OMP_HERD_CHECKOUT="${OMP_HERD_CHECKOUT:-$checkout_dir}"
      export OMP_HERD_BRANCH="${OMP_HERD_BRANCH:-fix/widget}"
      export HERDR_WORKSPACE_ID="${HERDR_WORKSPACE_ID:-workspace-fresh}"
      export HERDR_TAB_ID="${HERDR_TAB_ID:-caller-tab}"
    elif [[ "$kind" != "done" ]]; then
      unset OMP_HERD_MANAGED OMP_HERD_SOURCE_ROOT OMP_HERD_CHECKOUT OMP_HERD_BRANCH
      unset HERDR_WORKSPACE_ID HERDR_TAB_ID
    fi

    if [[ "$(command -v herdr)" != "$bin_dir/herdr" ]]; then
      echo "herdr mock did not shadow PATH: $(command -v herdr)" >&2
      exit 90
    fi
    if [[ "$(command -v git)" != "$bin_dir/git" ]]; then
      echo "git mock did not shadow PATH: $(command -v git)" >&2
      exit 90
    fi
    if [[ "$(command -v wt)" != "$bin_dir/wt" ]]; then
      echo "wt mock did not shadow PATH: $(command -v wt)" >&2
      exit 90
    fi
    if [[ "$(command -v gh)" != "$bin_dir/gh" ]]; then
      echo "gh mock did not shadow PATH: $(command -v gh)" >&2
      exit 90
    fi
    command -v jq >/dev/null || { echo "jq missing from PATH" >&2; exit 91; }
    command -v python3 >/dev/null || { echo "python3 missing from PATH" >&2; exit 91; }

    cd "$workdir"
    if [[ "$bound" != "0" ]]; then
      exec python3 - "$zsh_bin" "$bound" "${herd_args[@]}" <<'PY'
import subprocess, sys
zsh = sys.argv[1]
timeout = float(sys.argv[2])
argv = sys.argv[3:]
try:
    result = subprocess.run(
        [zsh, "-f", "-c", 'source -- "$HERD_FUNCTIONS" || { print -ru2 -- "source failed"; exit 99; }\n[[ "$(command -v herdr)" == "$HERD_BIN_DIR/herdr" ]] || { print -ru2 -- "herdr mock not selected: $(command -v herdr)"; exit 90; }\nherd "$@"', "zsh", *argv],
        timeout=timeout,
    )
    raise SystemExit(result.returncode)
except subprocess.TimeoutExpired:
    raise SystemExit(124)
PY
    else
      exec "$zsh_bin" -f -c 'source -- "$HERD_FUNCTIONS" || { print -ru2 -- "source failed"; exit 99; }
[[ "$(command -v herdr)" == "$HERD_BIN_DIR/herdr" ]] || { print -ru2 -- "herdr mock not selected: $(command -v herdr)"; exit 90; }
herd "$@"' zsh "${herd_args[@]}"
    fi
  ) >"$HERD_STDOUT" 2>"$HERD_STDERR"
  HERD_STATUS=$?
  set -e

  PYTHONPATH="$tmp_dir${PYTHONPATH:+:$PYTHONPATH}" python3 -c 'from calls_lib import invariants; invariants()' \
    || fail "call-log invariants"
}

expect_status() {
  local want="$1"
  local label="$2"
  [[ "$HERD_STATUS" -eq "$want" ]] || fail "$label: exit $HERD_STATUS, want $want"
}

expect_nonzero() {
  local label="$1"
  case "$HERD_STATUS" in
    90|91|99) fail "$label: infrastructure exit $HERD_STATUS" ;;
  esac
  [[ "$HERD_STATUS" -ne 0 ]] || fail "$label: expected nonzero exit"
}

expect_stderr_has() {
  local needle="$1"
  local label="$2"
  grep -F -q -- "$needle" "$HERD_STDERR" || fail "$label: stderr missing '$needle'"
}

expect_stderr_not() {
  local needle="$1"
  local label="$2"
  if grep -F -q -- "$needle" "$HERD_STDERR"; then
    fail "$label: stderr unexpectedly contains '$needle'"
  fi
}

expect_output_not() {
  local needle="$1"
  local label="$2"
  if grep -F -q -- "$needle" "$HERD_STDOUT" "$HERD_STDERR"; then
    fail "$label: output unexpectedly contains '$needle'"
  fi
}

py() {
  PYTHONPATH="$tmp_dir${PYTHONPATH:+:$PYTHONPATH}" python3 -c "$1"
}

expect_zero_tool_calls() {
  local label="$1"
  py 'from calls_lib import load; import sys; calls=load(); sys.exit(0 if not calls else 1)' \
    || fail "$label: expected zero herdr/git/wt/gh calls"
}

expect_no_mutation() {
  local label="$1"
  py 'from calls_lib import load
import sys
calls=load()
for call in calls:
    if call["cmd"]=="wt":
        sys.exit(1)
    if call["cmd"]=="herdr" and call["argv"][:1]==["tab"]:
        sys.exit(1)
    if call["cmd"]=="herdr" and call["argv"][:1]==["agent"]:
        sys.exit(1)
sys.exit(0)' || fail "$label: unexpected wt/tab/agent mutation"
}

expect_no_wt() {
  local label="$1"
  py 'from calls_lib import load
import sys
sys.exit(0 if not any(c["cmd"]=="wt" for c in load()) else 1)' \
    || fail "$label: unexpected wt call"
}

expect_no_tab() {
  local label="$1"
  py 'from calls_lib import load
import sys
sys.exit(0 if not any(c["cmd"]=="herdr" and c["argv"][:1]==["tab"] for c in load()) else 1)' \
    || fail "$label: unexpected herdr tab call"
}

expect_no_pane_current_or_agent() {
  local label="$1"
  py 'from calls_lib import load
import sys
for call in load():
    if call["cmd"]!="herdr":
        continue
    argv=call["argv"]
    if argv[:2]==["pane","current"] or argv[:1]==["agent"]:
        sys.exit(1)
sys.exit(0)' || fail "$label: invoked herdr pane current or herdr agent"
}

expect_no_gh() {
  local label="$1"
  py 'from calls_lib import load
import sys
sys.exit(0 if not any(c["cmd"]=="gh" for c in load()) else 1)' \
    || fail "$label: unexpected gh call"
}

expect_no_gh_pr() {
  local label="$1"
  py 'from calls_lib import load
import sys
sys.exit(0 if not any(c["cmd"]=="gh" and c["argv"][:1]==["pr"] for c in load()) else 1)' \
    || fail "$label: unexpected gh pr call"
}

expect_no_git_push() {
  local label="$1"
  py 'from calls_lib import load
import sys
sys.exit(0 if not any(c["cmd"]=="git" and c["argv"][:1]==["push"] for c in load()) else 1)' \
    || fail "$label: unexpected git push"
}

expect_no_wt_remove() {
  local label="$1"
  py 'from calls_lib import load
import sys
sys.exit(0 if not any(c["cmd"]=="wt" and "remove" in c["argv"] for c in load()) else 1)' \
    || fail "$label: unexpected wt remove"
}

expect_no_tab_close() {
  local label="$1"
  py 'from calls_lib import load
import sys
sys.exit(0 if not any(c["cmd"]=="herdr" and c["argv"][:2]==["tab","close"] for c in load()) else 1)' \
    || fail "$label: unexpected herdr tab close"
}

# --- Help ---
for alias in --help -h help; do
  clear_fixtures
  run_herd help "$alias"
  expect_status 0 "help $alias"
  expect_zero_tool_calls "help $alias"
  for word in context task issue done; do
    if ! grep -Eiq -- "$word" "$HERD_STDOUT" "$HERD_STDERR"; then
      fail "help $alias: usage missing $word"
    fi
  done
  ok_msg="help $alias without HERDR_ENV"
  echo "ok $ok_msg"
done

# --- Create guards ---
clear_fixtures
HERD_UNSET_ENV=1 run_herd create context
expect_nonzero "missing HERDR_ENV"
expect_stderr_has "HERDR_ENV=1" "missing HERDR_ENV"
expect_zero_tool_calls "missing HERDR_ENV"
echo "ok missing HERDR_ENV create"

clear_fixtures
HERD_UNSET_PANE=1 run_herd create context
expect_nonzero "missing HERDR_PANE_ID"
expect_no_mutation "missing HERDR_PANE_ID"
echo "ok missing HERDR_PANE_ID"

clear_fixtures
HERD_PANE_MATCHES=0 run_herd create context
expect_nonzero "pane list 0 matches"
expect_no_mutation "pane list 0 matches"
echo "ok pane list 0 matches"

clear_fixtures
HERD_PANE_MATCHES=2 run_herd create context
expect_nonzero "pane list 2 matches"
expect_no_mutation "pane list 2 matches"
echo "ok pane list 2 matches"

# --- Create success: issue ---
clear_fixtures
HERD_DIRTY=1 run_herd create issue '#123' --base=main
expect_status 0 "issue #123"
expect_stderr_has "dirty" "issue #123 dirty warning"
py "
from calls_lib import load, same_path
import os, sys
calls=load()
repo=os.environ['HERD_REPO']
checkout=os.environ['HERD_CHECKOUT']
wt=[c for c in calls if c['cmd']=='wt' and 'switch' in c['argv']]
if len(wt)!=1: sys.exit('wt switch count %s' % len(wt))
if wt[0]['argv'] != ['-C', repo, 'switch', '--create', 'fix/issue-123-fix-widget', '--base', 'main', '--no-cd', '--format=json']:
    sys.exit('wt argv %s' % wt[0]['argv'])
tabs=[c for c in calls if c['cmd']=='herdr' and c['argv'][:2]==['tab','create']]
if len(tabs)!=1: sys.exit('tab create count %s' % len(tabs))
want=['tab','create','--workspace','workspace-fresh','--cwd',checkout,'--label','issue-123-fix-widget','--env','OMP_HERD_MANAGED=1','--env','OMP_HERD_SOURCE_ROOT='+repo,'--env','OMP_HERD_CHECKOUT='+checkout,'--env','OMP_HERD_BRANCH=fix/issue-123-fix-widget','--env','OMP_HERD_LOAD_SECRETS=1','--no-focus']
if tabs[0]['argv']!=want: sys.exit('tab argv %s' % tabs[0]['argv'])
if '--focus' in tabs[0]['argv']: sys.exit('had --focus')
if any(c['cmd']=='herdr' and c['argv'][:1]==['agent'] for c in calls): sys.exit('agent start')
pane_lists=[i for i,c in enumerate(calls) if c['cmd']=='herdr' and c['argv'][:2]==['pane','list']]
if len(pane_lists)<3: sys.exit('pane list %s' % len(pane_lists))
tab_i=next(i for i,c in enumerate(calls) if c['cmd']=='herdr' and c['argv'][:2]==['tab','create'])
syms=[i for i,c in enumerate(calls) if c['cmd']=='git' and c['argv'][:1]==['symbolic-ref'] and same_path(c['cwd'], checkout)]
if not syms or not any(i < tab_i for i in syms): sys.exit('checkout symbolic-ref not before tab')
" || fail "issue #123 argv/order"
echo "ok issue #123 dirty create"
echo "ok herd does not invoke pane current or agent"

# --- Branch naming ---
clear_fixtures
run_herd create Fix broken widget
expect_status 0 "Fix broken widget"
py "
from calls_lib import load
import sys
calls=load()
if not any(c['cmd']=='wt' and 'fix/broken-widget' in c['argv'] for c in calls):
    sys.exit('missing fix/broken-widget')
" || fail "Fix broken widget branch"
echo "ok Fix broken widget -> fix/broken-widget"

clear_fixtures
run_herd create Create widget
expect_status 0 "Create widget"
py "
from calls_lib import load
import sys
calls=load()
if not any(c['cmd']=='wt' and 'feat/widget' in c['argv'] for c in calls):
    sys.exit('missing feat/widget')
" || fail "Create widget branch"
echo "ok Create widget -> feat/widget"

# --- Implicit / explicit base ---
clear_fixtures
HERD_SOURCE_BRANCH=feat/source-worktree run_herd create context
expect_status 0 "context implicit base"
py "
from calls_lib import load
import os, sys
calls=load()
repo=os.environ['HERD_REPO']
wts=[c for c in calls if c['cmd']=='wt' and 'switch' in c['argv']]
if len(wts)!=1: sys.exit('wt count')
if wts[0]['argv'] != ['-C', repo, 'switch', '--create', 'feat/context', '--base', '^', '--no-cd', '--format=json']:
    sys.exit('wt argv %s' % wts[0]['argv'])
joined=' '.join(wts[0]['argv'])
if 'feat/source-worktree' in joined: sys.exit('source branch leaked into wt')
if any(c['cmd']=='git' and c['argv'][:2]==['rev-parse','--verify'] for c in calls):
    sys.exit('implicit base was git-verified')
" || fail "context implicit base"
echo "ok context default base caret"

clear_fixtures
run_herd create context --base=release/2026-q3
expect_status 0 "explicit base"
py "
from calls_lib import load
import sys
calls=load()
verifies=[c for c in calls if c['cmd']=='git' and c['argv'][:2]==['rev-parse','--verify']]
if [c['argv'] for c in verifies] != [['rev-parse','--verify','release/2026-q3^{commit}']]:
    sys.exit('verify argv %s' % [c['argv'] for c in verifies])
wts=[c for c in calls if c['cmd']=='wt' and 'switch' in c['argv']]
if wts[0]['argv'][wts[0]['argv'].index('--base')+1] != 'release/2026-q3':
    sys.exit('wt base')
" || fail "explicit base"
echo "ok context --base=release/2026-q3"

clear_fixtures
run_herd create context --base=missing
expect_nonzero "invalid base"
expect_no_wt "invalid base"
expect_no_tab "invalid base"
echo "ok invalid --base=missing"

clear_fixtures
HERD_COLLISIONS='herd/explicit' run_herd create context --branch=herd/explicit
expect_nonzero "explicit collision"
expect_no_wt "explicit collision"
expect_stderr_has "already exists" "explicit collision"
echo "ok explicit branch collision"

clear_fixtures
HERD_COLLISIONS='feat/context' run_herd create context
expect_status 0 "implicit collision suffix"
py "
from calls_lib import load
import sys
calls=load()
if not any(c['cmd']=='wt' and 'feat/context-2' in c['argv'] for c in calls):
    sys.exit('missing feat/context-2')
" || fail "implicit collision suffix"
echo "ok collision feat/context creates feat/context-2"

# --- Dry-run / secrets / model ---
clear_fixtures
HERD_SOURCE_BRANCH=feat/source-worktree run_herd create task --dry-run -- exact task
expect_status 0 "dry-run"
expect_no_mutation "dry-run"
if ! grep -F -q "Worktrunk's detected default branch (resolved during the real handoff)" "$HERD_STDOUT" "$HERD_STDERR"; then
  fail "dry-run: missing deferred default branch wording"
fi
if ! grep -F -q "Secret loading would occur" "$HERD_STDOUT" "$HERD_STDERR"; then
  fail "dry-run: missing secret loading would occur"
fi
if grep -F -q "feat/source-worktree" "$HERD_STDOUT" "$HERD_STDERR"; then
  fail "dry-run: mentioned source branch as base"
fi
echo "ok task --dry-run deferred default branch"

clear_fixtures
run_herd create task --no-secret --dry-run -- exact task
expect_status 0 "no-secret dry-run"
expect_no_mutation "no-secret dry-run"
if ! grep -F -q "Secret loading would not occur" "$HERD_STDOUT" "$HERD_STDERR"; then
  fail "no-secret dry-run wording"
fi
echo "ok task --no-secret --dry-run"

clear_fixtures
run_herd create context --no-secret
expect_status 0 "context --no-secret"
py "
from calls_lib import load
import sys
calls=load()
tabs=[c for c in calls if c['cmd']=='herdr' and c['argv'][:2]==['tab','create']]
if len(tabs)!=1: sys.exit('tab missing')
if 'OMP_HERD_LOAD_SECRETS=1' in tabs[0]['argv']: sys.exit('secrets env present')
if 'OMP_HERD_MANAGED=1' not in tabs[0]['argv']: sys.exit('managed env missing')
" || fail "context --no-secret tab argv"
echo "ok context --no-secret omits load-secrets"

clear_fixtures
run_herd create context --model=foo:high
expect_nonzero "model rejected"
expect_no_mutation "model rejected"
echo "ok --model rejected"

# --- Hook approval / collisions / invalid ref / caller change ---
clear_fixtures
HERD_WT_FAIL=approval run_herd create context
expect_nonzero "hook approval"
expect_stderr_has "wt config approvals add" "hook approval"
expect_stderr_has "checkout creation unknown; inspect wt list" "hook approval ledger"
expect_stderr_has "wt list" "hook approval inspect"
expect_stderr_not "herdr pane list" "hook approval inspect"
echo "ok hook approval wt failure"

clear_fixtures
HERD_SHOW_REF_KILLED=1 HERD_SHOW_REF_ALWAYS_EXISTS=1 HERD_SHOW_REF_CAP=30 HERD_BOUND_SECONDS=22 run_herd create context
expect_nonzero "killed/unbounded show-ref"
expect_no_wt "killed/unbounded show-ref"
py "
from calls_lib import load
import sys
calls=load()
n=sum(1 for c in calls if c['cmd']=='git' and c['argv'][:1]==['show-ref'])
if n < 1: sys.exit('no show-ref')
if n > 30: sys.exit('unbounded show-ref %s' % n)
" || fail "show-ref collision probe cap"
echo "ok killed/timeout or capped implicit show-ref"

clear_fixtures
run_herd create context --branch=bad..ref
expect_nonzero "invalid branch"
expect_no_wt "invalid branch"
echo "ok invalid check-ref-format --branch=bad..ref"

clear_fixtures
HERD_CALLER_CHANGE_AT=2 run_herd create context
expect_nonzero "caller change before wt"
expect_no_wt "caller change before wt"
expect_no_tab "caller change before wt"
echo "ok caller workspace change before wt"

clear_fixtures
HERD_CALLER_CHANGE_AT=3 run_herd create context
expect_nonzero "caller change before tab"
expect_no_tab "caller change before tab"
py "
from calls_lib import load
import os, sys
calls=load()
if not any(c['cmd']=='wt' and 'switch' in c['argv'] for c in calls):
    sys.exit('wt was not attempted')
err=open(os.environ['HERD_STDERR'], encoding='utf-8').read()
checkout=os.environ['HERD_CHECKOUT']
if checkout not in err and 'checkout' not in err.lower():
    sys.exit('ledger did not retain checkout')
" || fail "caller change before tab ledger"
echo "ok caller workspace change before tab retains checkout"

# --- Done guards ---
clear_fixtures
HERD_UNSET_ENV=1 run_herd done done
expect_nonzero "done missing HERDR_ENV"
expect_stderr_has "HERDR_ENV=1" "done missing HERDR_ENV"
expect_zero_tool_calls "done missing HERDR_ENV"
echo "ok done missing HERDR_ENV"

clear_fixtures
HERD_UNSET_MANAGED=1 run_herd done done
expect_nonzero "done missing managed"
expect_no_wt_remove "done missing managed"
expect_no_tab_close "done missing managed"
echo "ok done missing OMP_HERD_MANAGED"

clear_fixtures
HERD_DIRTY=1 run_herd done done
expect_nonzero "done dirty"
expect_no_wt_remove "done dirty"
echo "ok done dirty checkout refuses remove"

# --- Done success ---
clear_fixtures
run_herd done done
expect_status 0 "done plain"
py "
from calls_lib import load
import os, sys
calls=load()
checkout=os.environ['HERD_CHECKOUT']
prs=[c for c in calls if c['cmd']=='gh' and c['argv'][:1]==['pr']]
if not prs: sys.exit('missing gh pr list')
removes=[c for c in calls if c['cmd']=='wt' and 'remove' in c['argv']]
if len(removes)!=1: sys.exit('remove count')
if removes[0]['argv'] != ['remove','--foreground','--format=json','--no-delete-branch', checkout]:
    sys.exit('remove argv %s' % removes[0]['argv'])
if any(a in removes[0]['argv'] for a in ('--force','--force-delete','--yes','--no-hooks')):
    sys.exit('unsafe remove flags')
closes=[c for c in calls if c['cmd']=='herdr' and c['argv'][:2]==['tab','close']]
if [c['argv'] for c in closes] != [['tab','close','caller-tab']]:
    sys.exit('tab close argv')
status=sum(1 for c in calls if c['cmd']=='git' and c['argv'][:1]==['status'])
if status < 2: sys.exit('status checks %s' % status)
lists=sum(1 for c in calls if c['cmd']=='wt' and 'list' in c['argv'])
if lists < 2: sys.exit('wt list %s' % lists)
panes=sum(1 for c in calls if c['cmd']=='herdr' and c['argv'][:2]==['pane','list'])
if panes < 3: sys.exit('pane list %s' % panes)
if calls.index(removes[0]) > calls.index(closes[0]): sys.exit('tab closed before remove')
" || fail "done plain"
echo "ok herd done plain"

for form in '--force' '-f'; do
  clear_fixtures
  run_herd done done $form
  expect_status 0 "done $form"
  expect_no_gh "done $form"
  py "
from calls_lib import load
import os, sys
calls=load()
checkout=os.environ['HERD_CHECKOUT']
removes=[c for c in calls if c['cmd']=='wt' and 'remove' in c['argv']]
if [c['argv'] for c in removes] != [['remove','--foreground','--format=json','--no-delete-branch', checkout]]:
    sys.exit('remove argv %s' % [c['argv'] for c in removes])
closes=[c for c in calls if c['cmd']=='herdr' and c['argv'][:2]==['tab','close']]
if not closes: sys.exit('missing tab close')
" || fail "done $form"
  echo "ok herd done $form"
done

for form in '--delete' '-d' '-f -d' '-d -f'; do
  clear_fixtures
  # shellcheck disable=SC2086
  run_herd done done $form
  expect_status 0 "done $form"
  expect_no_gh_pr "done $form"
  py "
from calls_lib import load
import os, sys
calls=load()
checkout=os.environ['HERD_CHECKOUT']
head=os.environ['HERD_HEAD']
removes=[c for c in calls if c['cmd']=='wt' and 'remove' in c['argv']]
if [c['argv'] for c in removes] != [['remove','--foreground','--format=json','--force-delete', checkout]]:
    sys.exit('remove argv %s' % [c['argv'] for c in removes])
argv=removes[0]['argv']
if any(a in argv for a in ('--force','--yes','--no-hooks')): sys.exit('unsafe flags')
pushes=[c for c in calls if c['cmd']=='git' and c['argv'][:1]==['push']]
if len(pushes)!=1: sys.exit('push count %s' % len(pushes))
want=['push','https://github.com/owner/repo.git','--force-with-lease=refs/heads/fix/widget:'+head,':refs/heads/fix/widget']
if pushes[0]['argv']!=want: sys.exit('push argv %s' % pushes[0]['argv'])
if 'herd-git-' not in pushes[0]['cwd']: sys.exit('push cwd %s' % pushes[0]['cwd'])
if pushes[0]['cwd']==os.environ['HERD_REPO']: sys.exit('push reused source repo')
absences=[c for c in calls if c['cmd']=='git' and c['argv'][:1]==['show-ref']]
if not absences: sys.exit('missing local branch absence check')
if calls.index(removes[0]) > calls.index(absences[0]) or calls.index(absences[0]) > calls.index(pushes[0]):
    sys.exit('push not after remove and absence')
closes=[c for c in calls if c['cmd']=='herdr' and c['argv'][:2]==['tab','close']]
if not closes: sys.exit('tab did not close')
" || fail "done $form"
  echo "ok herd done $form"
done

clear_fixtures
HERD_LOCAL_BRANCH_EXISTS=1 run_herd done done --delete
expect_status 0 "delete retained local branch"
expect_no_git_push "delete retained local branch"
py "
from calls_lib import load
import sys
calls=load()
if not any(c['cmd']=='herdr' and c['argv'][:2]==['tab','close'] for c in calls):
    sys.exit('tab should still close')
" || fail "delete retained local branch still closes tab"
echo "ok delete with retained local branch skips remote push"

clear_fixtures
HERD_FETCH_URL='https://example.invalid/owner/repo.git' \
HERD_PUSH_URL='https://example.invalid/owner/repo.git' \
  run_herd done done --delete
expect_status 0 "non-github endpoint"
expect_no_git_push "non-github endpoint"
expect_output_not "example.invalid" "non-github endpoint"
echo "ok non-GitHub endpoint skips remote push"

clear_fixtures
HERD_FETCH_URL='https://token@github.com/owner/repo.git' \
HERD_PUSH_URL='https://token@github.com/owner/repo.git' \
  run_herd done done --delete
expect_status 0 "credential-bearing endpoint"
expect_no_git_push "credential-bearing endpoint"
expect_output_not "token@github.com" "credential-bearing endpoint"
echo "ok credential-bearing endpoint skips remote push"

clear_fixtures
HERD_DIRTY=1 run_herd done done --force
expect_nonzero "force dirty"
expect_no_wt_remove "force dirty"
echo "ok herd done --force on dirty refuses remove"

echo "all herd function cases passed"
