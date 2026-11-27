# Make it yours

This repo configures one person's machines. Nothing in it asks who you are: the values that make it mine are written in the files below, and a fork changes them by editing those files. Do that before the first run.

A fork does not change the supported targets: Omarchy, or macOS on Apple Silicon. Anything else stops with `unsupported machine`.

## 1. Point the bootstrap at your fork

The one-liner downloads `bin/dotfiles` from the URL you give curl. That script then clones `REPO_URL` into `~/.dotfiles` and runs from there, so a fork that keeps my `REPO_URL` installs my repo, not yours.

- `bin/dotfiles`: `REPO_URL`, and the URL in the comment above it.
- `README.md`: the one-liner under Bootstrap, and the badge and star-history links.

## 2. Identity

| Value | Where |
| --- | --- |
| Git author name | `[user] name` in `modules/git/dotfiles.gitconfig` |
| jj author name | `[user] name` in `modules/jj/config.toml` |
| npm `init-author-name` | `modules/devtools/mise.toml` |
| Git and jj email | Read from 1Password (`op://Personal/GitHub/email`) by `modules/secrets/bootstrap.sh`, which writes it to the generated `~/.config/git/identity.gitconfig` |
| jj fallback email | `FALLBACK_EMAIL` in `modules/secrets/bootstrap.sh`, used when neither 1Password nor an existing jj config has an email |

Miss the last row and your jj commits carry my GitHub noreply address.

Without 1Password, the secrets step keeps whatever email `identity.gitconfig` already holds and gives jj the same one, so setting it once per machine is enough:

```bash
git config -f ~/.config/git/identity.gitconfig user.email you@example.com
```

## 3. Secrets

`modules/secrets/bootstrap.sh` syncs from my 1Password: an SSH key pair and `allowed_signers` (`op://Personal/TechDufus SSH/...`), the email above, and the BerkeleyMono font files. It never fails the run: it warns and skips when the `op` CLI is missing, when it cannot list vaults in the `ACCOUNT` it names, and for each item it cannot read. Point `ACCOUNT` and the `op://` references at your own items, or delete `modules/secrets/`.

Either way:

- If `~/.ssh/id_ed25519.pub` exists, whether it came from 1Password or not, the step turns on SSH commit and tag signing with it.
- If you delete the module, nothing generates `identity.gitconfig`. Put `email` next to `name` in `modules/git/dotfiles.gitconfig` and `modules/jj/config.toml` instead.

The other 1Password references:

- `modules/zsh/zsh/vars.secret` and `modules/bash/bash/vars.secret` list the vault items the shell exports as environment variables. They are read when you run `secret`, not at shell startup. Replace the entries or empty the files.
- `modules/1password/agent.toml` and `agent.macos.toml` name the vaults the 1Password SSH agent offers keys from.

## 4. Settings that change how the machine behaves

| Setting | Where | What it does |
| --- | --- | --- |
| Keyboard and locale (Linux) | `modules/system/bootstrap.sh` | Sets the console keymap to `dvorak`, the X11 layout to `us` / `dvorak` with `caps:none`, and the locale to `en_US.UTF-8` |
| Passwordless sudo (Linux) | `modules/system/bootstrap.sh` | Installs `/etc/sudoers.d/techdufus`, granting the account that runs bootstrap `NOPASSWD: ALL` |
| Login shell | `[bootstrap.user]` in `modules/zsh/mise.linux.toml` and `mise.macos.toml` | Changes it to zsh |
| CapsLock | `modules/omarchy/hypr/keyboard.lua` and `summon.lua`; `modules/hammerspoon/karabiner/karabiner.json` | CapsLock stops being CapsLock and becomes the app leader |
| Font | `modules/ghostty/config`, `modules/kitty/`, `modules/tern/settings.json`, `modules/neovim/nvim/lua/techdufus/core/options.lua` | All name BerkeleyMono Nerd Font, a commercial font that only the secrets step installs. Install a Nerd Font of your own and change the name |

Change the keymap row first unless you type Dvorak. The sudoers file name is only a name: the grant always goes to the account that runs bootstrap. If you remove the policy, remove its `check:system-sudoers` test with it.

## 5. Apps, keys and hardware

- **Packages.** `modules/packages/` and `modules/devtools/` hold the plain installs and dev runtimes; modules with config declare their own.
- **App keys and window cells.** `modules/hammerspoon/config/apps.lua` and `layouts.lua` on macOS; `modules/omarchy/hypr/summon_apps.lua` and `layouts.lua` on Omarchy.
- **Hardware.** These need no change: `liquidctl` acts only when its USB fan hub is present, `battlenet` waits until Battle.net is installed, and `modules/omarchy/hypr/monitors.lua` matches my two panels by description.
- **Dropping a module.** Delete its folder under `modules/`. mise stops managing it, but what it already installed, linked or wrote stays until you remove it by hand, so prune before the first run. Preview after each removal: a module can depend on a tool another one installs.

## 6. Preview before applying

```bash
git clone https://github.com/<you>/dotfiles ~/.dotfiles
~/.dotfiles/bin/dotfiles --dry-run
```

A dry run needs a compatible mise already installed. It does not pull, install prerequisites, replace live mise config or move conflicts, but mise still evaluates config templates and may update its own state and caches.

A real run moves any file that blocks a link into `<target>.pre-dotfiles.<epoch>.<random>/original`. That is not a rollback: copies, merges, packages and system changes are not undone, as the README's [Bootstrap](../README.md#bootstrap) section spells out. Do the first real run on a fresh install or a VM.

The [validation gate](../README.md#validation) and the CI workflow work in a fork as they do here; keep them.

## Staying in sync

There are no releases and no compatibility promise: `main` is whatever my machines run today. To follow it anyway:

```bash
git remote add upstream https://github.com/TechDufus/dotfiles.git
git fetch upstream && git merge upstream/main
```

Expect conflicts in the files listed above, and keep your changes to those lines so merges stay small.
