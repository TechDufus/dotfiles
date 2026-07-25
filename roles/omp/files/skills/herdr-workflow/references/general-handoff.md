# General durable handoff

Use this policy for visible, durable OMP handoffs through Herdr. The official Herdr skill owns generic CLI syntax and resource semantics; this reference defines the repository's topology and orchestration choices.

## Choose checkout topology

### Default: Herdr-owned isolated worktree workspace

For a general new task, use the official Herdr skill's worktree workspace flow so Herdr owns both the isolated checkout and its workspace.

Before creation, inspect the user's intent, current branch and upstream, local repository status, existing refs and worktrees, and existing Herdr worktree/workspace state. Detect branch, path, and workspace collisions. Do not fetch. Do not assume a conventional base branch when local evidence does not establish the intended base; ask instead. Report source-checkout uncommitted and untracked changes because a new worktree does not inherit them.

Create or open the non-colliding isolated checkout/workspace using the current official Herdr contract. Use the returned checkout path and freshly returned workspace, tab, and pane identifiers for the OMP start. If a requested checkout is already safely open, reuse it and record it as reused rather than claiming creation.

### Explicit request: tab in the current workspace

Use this topology only when the user explicitly requests a tab in the current Herdr workspace:

1. Load `skill://worktrunk` before any checkout operation.
2. Give Worktrunk sole checkout ownership. Create or open the checkout through the loaded Worktrunk skill and repository configuration.
3. Keep Worktrunk automation and hooks enabled. Never bypass hooks, use an automatic approval flag, or approve hooks for the user. If Worktrunk requires approval, stop and ask the user to review the applicable approval gate.
4. Obtain the resulting checkout path from Worktrunk and freshly resolve the current Herdr workspace.
5. Use the current official Herdr contract to create a no-focus tab rooted at that checkout, then start OMP in the returned tab.

Herdr owns a tab created by this topology, but Worktrunk alone owns checkout removal. Never use Herdr worktree removal for a Worktrunk-owned checkout. The owner-specific removal rules are part of the required ownership and cleanup reference.

## Start OMP without changing layout implicitly

Create or select the target pane before starting the agent. Use a freshly resolved existing tab only for the explicit current-workspace topology. If the user explicitly requests a split for another topology, create it before agent start and start the agent in the returned pane. Agent start never creates or changes a tab, split, or other layout resource.

Start OMP in the selected pane, then submit the complete initial prompt through the official structured agent operation. Use a cryptographically random suffix in the unique agent name as the normal subsequent target. Never enable OMP auto-approval.

## Observe within bounds

For orchestration other than `/herd`, use the official skill's structured prompt, wait, and read operations. Bound every wait with explicit `--until` lifecycle states and a timeout: observe prompt acceptance or working state, then use arguments equivalent to `herdr agent wait <name> --until idle --until done --until blocked --timeout <milliseconds>` when a separate completion wait is needed, then read a bounded amount of recent unwrapped output. `/herd` is the exception: its initiating command performs only the acceptance wait described above and returns without a separate completion wait.

For every later prompt, preserve its literal argument boundary and use `herdr agent prompt <name> <prompt> --wait` with explicit accepted `--until` states and a bounded timeout. The prompt operation submits the text plus Enter atomically; do not separately send text, resolve a pane, or inject Enter.

Handle timeouts, killed operations, partial failure, and retained resources under the required ownership and cleanup reference. Never poll indefinitely.