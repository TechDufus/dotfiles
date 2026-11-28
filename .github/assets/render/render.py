#!/usr/bin/env python3
"""Regenerate every README image in .github/assets/ (synthetic but reproducible).

    python3 .github/assets/render/render.py [header] [hero] [demo] [social] [dry-run] [failure]

With no arguments it writes all of them: header-dark.png, header-light.png (header.py),
hero.png, demo.gif, social.png, dry-run.png and failure.png, and prints each path.
Nothing is captured from a live desktop:

* The screens are the REAL bin/dotfiles UI. It runs in an interactive zsh inside a
  private tmux server (`tmux -L dotfiles-banner`) with the real Powerlevel10k prompt,
  against a sandbox HOME, a throw-away git remote a few commits ahead (so the repo row
  pulls), a stub `mise` (stub-mise + fixtures/, recorded by capture-fixtures.sh) and a
  stub `sudo`. Real mise, sudo and the real HOME are never touched.
* One converging run feeds three outputs: `dotfiles` is typed key by key and the pane is
  sampled until the next prompt settles. Every distinct screen is a frame of demo.gif
  (played DEMO_SPEED times faster, the last one held); the last screen is also the hero's
  dotfiles tile and the window in social.png.
* The other hero tiles are real programs in tmux panes: Neovim with this repo's config
  (plugins cached under ~/.cache/dotfiles-banner/nvim; first run clones them), fastfetch
  and lsd.
* tmux's `capture-pane -e` output is parsed by termsvg.py into SVG text on an exact grid
  (BerkeleyMono Nerd Font, Catppuccin Mocha) and composed over the Omarchy catppuccin
  wallpaper with rsvg-convert. ffmpeg encodes demo.gif's frames; social.png (GitHub's
  1280x640 preview) adds header.py's wordmark card and accent strip.

Requirements: python3 (stdlib only), tmux >= 3.2, rsvg-convert (with WebP images), ffmpeg,
git, jq, zsh, nvim, fastfetch, lsd, the BerkeleyMono Nerd Font (commercial; never embedded,
only rasterised), and an Omarchy machine with these dotfiles applied (zinit's powerlevel10k,
the catppuccin wallpaper in /usr/share/omarchy). The sandbox and the tmux server are removed
on exit. Output is deterministic apart from the commit hashes of the checkout it runs in and
the spinner frames demo.gif happens to sample.
"""

from __future__ import annotations

import copy
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.dont_write_bytecode = True  # no __pycache__ next to the committed scripts
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import header  # noqa: E402
import termsvg  # noqa: E402

REPO = HERE.parents[2]
ASSETS_DIR = HERE.parent
REAL_HOME = Path(os.environ.get("HOME", "/"))
WALLPAPER = Path("/usr/share/omarchy/themes/catppuccin/backgrounds/2-waves.webp")
NVIM_CACHE = Path(os.environ.get("XDG_CACHE_HOME", REAL_HOME / ".cache")) / "dotfiles-banner" / "nvim"
SOCKET = "dotfiles-banner"
PATH = "/usr/local/bin:/usr/bin:/bin"

# One cell size for every terminal in every image (Ghostty's 11 pt BerkeleyMono, 2x-integer device pixels).
CELL_W, CELL_H = 9.0, 18.0
CLI_COLS = 82  # bin/dotfiles draws at most 80 columns; two spare keep the prompt's clock off the edge
FIXED_CLOCK = "10:24:07"  # the prompt clock, matching the desktop bar's "Thursday 10:24"


class RenderError(RuntimeError):
    pass


# ----------------------------------------------------------------------------- sandbox


def log(msg: str) -> None:
    print(f"  {msg}", flush=True)


def run(cmd, **kw) -> subprocess.CompletedProcess:
    kw.setdefault("check", True)
    kw.setdefault("text", True)
    kw.setdefault("stdout", subprocess.PIPE)
    kw.setdefault("stderr", subprocess.STDOUT)
    return subprocess.run([str(c) for c in cmd], **kw)


GIT_ENV = {**os.environ, "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0"}


def git(*args, cwd=None) -> str:
    return run(["git", *args], cwd=cwd, env=GIT_ENV).stdout.strip()


class Sandbox:
    """Throw-away HOME, XDG dirs, stubs, fixtures and a clone of this repo."""

    def __init__(self) -> None:
        self.root = Path(tempfile.mkdtemp(prefix="dotfiles-banner."))
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.fixtures = self.root / "fixtures"
        self.zdotdir = self.root / "zdotdir"
        self.tmp = self.root / "tmp"
        self.origin = self.root / "origin.git"
        self.repo = self.home / ".dotfiles"
        for d in (self.home, self.bin, self.zdotdir, self.tmp):
            d.mkdir(parents=True)
        shutil.copy2(HERE / "stub-mise", self.bin / "mise")
        shutil.copy2(HERE / "stub-sudo", self.bin / "sudo")
        shutil.copy2(WALLPAPER, self.root / WALLPAPER.name)  # every scene's <image href>
        shutil.copytree(HERE / "fixtures", self.fixtures)
        self._craft_plan()
        self._write_zshrc()

    def _craft_plan(self) -> None:
        """Real `mise bootstrap plan` data, with one package marked missing so the
        packages row shows an install (the only crafted number besides the tool list)."""
        plan = json.loads((self.fixtures / "plan.json").read_text())
        for res in plan["resources"]:
            if res["id"]["name"] == "pacman:lazygit":
                res["action"] = "create"
        (self.fixtures / "plan.json").write_text(json.dumps(plan))

    def make_clone(self, behind: int) -> None:
        """origin.git holds HEAD as main; the clone sits `behind` commits back with origin/main as upstream."""
        if self.repo.exists():
            shutil.rmtree(self.repo)
        if self.origin.exists():
            shutil.rmtree(self.origin)
        git("init", "--bare", "-q", "-b", "main", str(self.origin))
        git("fetch", "-q", str(REPO), "HEAD:refs/heads/main", cwd=self.origin)
        git("clone", "-q", "-b", "main", str(self.origin), str(self.repo))
        if behind:
            git("reset", "-q", "--hard", f"HEAD~{behind}", cwd=self.repo)

    def _write_zshrc(self) -> None:
        """Interactive zsh with only what the prompt needs. The real ~/.zshrc is not used:
        it loads zinit snippets (network on a cold cache) and 1Password-backed secret
        functions. Prompt, plugins and aliases are the same files the real one loads."""
        p10k_plugin = REAL_HOME / ".local/share/zinit/plugins/romkatv---powerlevel10k/powerlevel10k.zsh-theme"
        highlight = REAL_HOME / ".local/share/zinit/plugins/zsh-users---zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
        if not p10k_plugin.exists():
            raise RenderError(f"powerlevel10k not found at {p10k_plugin} (apply the dotfiles zsh module first)")
        gitstatus_cache = REAL_HOME / ".cache" / "gitstatus"
        rc = f"""\
export HISTFILE=/dev/null HISTSIZE=0 SAVEHIST=0
setopt EXTENDED_GLOB INTERACTIVE_COMMENTS
export GITSTATUS_CACHE_DIR={gitstatus_cache}
source {p10k_plugin}
source {REPO}/modules/zsh/p10k.zsh
# The staged prompt: fixed clock, earlier prompts kept above the command (no transient collapse).
typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
typeset -g POWERLEVEL9K_TIME_FORMAT={FIXED_CLOCK}
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off
[[ -r {highlight} ]] && source {highlight}
source {REPO}/modules/zsh/zsh/lsd_aliases.zsh
# Hidden setup: `dotfiles` is this checkout's bin/dotfiles against the sandbox.
dotfiles() {{
  command env DOTFILES_PROFILE=omarchy DOTFILES_DIR="$HOME/.dotfiles" bash {REPO}/bin/dotfiles "$@"
}}
"""
        (self.zdotdir / ".zshrc").write_text(rc)

    def pane_env(self, **extra: str) -> list[str]:
        env = {
            "HOME": str(self.home),
            "USER": "techdufus",
            "LOGNAME": "techdufus",
            "SHELL": "/usr/bin/zsh",
            "PATH": f"{self.bin}:{PATH}",
            "TERM": "tmux-256color",
            "COLORTERM": "truecolor",
            "LANG": "en_US.UTF-8",
            "TMPDIR": str(self.tmp),
            "ZDOTDIR": str(self.zdotdir),
            "STUB_FIXTURES": str(self.fixtures),
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
            **extra,
        }
        return [f"{k}={v}" for k, v in env.items()]

    def cleanup(self) -> None:
        # tools run by nvim's first-run install (go, npm) can leave read-only trees behind
        run(["chmod", "-R", "u+rwX", self.root], check=False)
        shutil.rmtree(self.root, ignore_errors=True)


# ----------------------------------------------------------------------------- tmux


def tmux(*args: str, check: bool = True) -> str:
    return run(["tmux", "-L", SOCKET, "-f", "/dev/null", "-2", *args], check=check).stdout


def tmux_start() -> None:
    tmux("kill-server", check=False)
    time.sleep(0.2)
    tmux("new-session", "-d", "-s", "boot", "-x", "80", "-y", "24", "sleep", "3600")
    for opt in (
        ("-g", "default-terminal", "tmux-256color"),
        ("-g", "status", "off"),
        ("-g", "escape-time", "0"),
        ("-g", "history-limit", "2000"),
        ("-g", "remain-on-exit", "off"),
        ("-g", "window-size", "manual"),
        ("-g", "allow-passthrough", "off"),
        ("-g", "mouse", "off"),
    ):
        tmux("set", *opt)
    tmux("set", "-as", "terminal-features", ",*:RGB")


def tmux_stop() -> None:
    tmux("kill-server", check=False)


def new_pane(name: str, cols: int, rows: int, cwd: Path, argv: list[str]) -> None:
    tmux("new-session", "-d", "-s", name, "-x", str(cols), "-y", str(rows), "-c", str(cwd), *argv)


def screen_text(name: str) -> str:
    return tmux("capture-pane", "-p", "-t", name)


def screen_ansi(name: str) -> str:
    # No -J: it would join the wrapped rows of the dry run's long notice and shift the grid.
    return tmux("capture-pane", "-p", "-e", "-t", name)


def snapshot(name: str) -> tuple[str, tuple[int, int, bool]]:
    """screen_ansi plus the cursor, read by one tmux command so the two always agree."""
    out = tmux(
        "capture-pane", "-p", "-e", "-t", name, ";",
        "display-message", "-p", "-t", name, "#{cursor_x} #{cursor_y} #{cursor_flag}",
    )
    screen, _, cursor = out.rstrip("\n").rpartition("\n")
    x, y, visible = cursor.split()
    return screen, (int(x), int(y), visible == "1")


def wait_for(name: str, pattern: str, timeout: float = 60.0, what: str = "") -> str:
    deadline = time.time() + timeout
    rx = re.compile(pattern, re.M)
    while time.time() < deadline:
        text = screen_text(name)
        if rx.search(text):
            return text
        time.sleep(0.25)
    raise RenderError(f"timed out waiting for {what or pattern!r} in pane {name}:\n{screen_text(name)}")


def wait_stable(name: str, quiet: float = 2.0, timeout: float = 60.0) -> None:
    """Return once the pane has not changed for `quiet` seconds."""
    deadline = time.time() + timeout
    last, since = None, time.time()
    while time.time() < deadline:
        cur = screen_ansi(name)
        if cur != last:
            last, since = cur, time.time()
        elif time.time() - since >= quiet:
            return
        time.sleep(0.25)
    raise RenderError(f"pane {name} never settled")


class Capture:
    def __init__(self, name: str, cols: int, rows: int, shot: tuple[str, tuple[int, int, bool]] | None = None) -> None:
        screen, self.cursor = shot or snapshot(name)
        self.cols, self.rows = cols, rows
        self.grid = termsvg.parse_capture(screen, cols, rows)

    def lines(self) -> list[str]:
        return ["".join(c.ch for c in row) for row in self.grid]

    def trim(self, rows: int | None = None) -> "Capture":
        """A copy without the blank rows below the last prompt line (the window is sized to its
        content), or cut to `rows` so every frame of an animation keeps one window size."""
        if rows is None:
            rows = max(self.rows - termsvg.blank_rows_at_end(self.grid), self.cursor[1] + 1)
        out = copy.copy(self)
        out.grid, out.rows = self.grid[:rows], rows
        return out

    def drop_wrapped_notice(self, prefix: str) -> "Capture":
        """Remove a one-off plain-text notice that is wider than the 80-column UI (and so wraps in
        this pane) together with its wrapped continuation. Only the dry run prints one, before
        the UI starts: "dotfiles: previewing local modules; no setup, pull, or conflict moves
        (mise may evaluate config templates and update metadata, state and caches)"."""
        texts = self.lines()
        start = next((i for i, t in enumerate(texts) if t.startswith(prefix)), None)
        if start is None:
            raise RenderError(f"notice {prefix!r} not found on screen")
        end = start
        while end < len(texts) and texts[end].strip():
            end += 1
        del self.grid[start:end]
        self.rows -= end - start
        x, y, vis = self.cursor
        self.cursor = (x, y - (end - start), vis)
        return self


def zsh_pane(sb: Sandbox, name: str, cols: int, rows: int, cwd: Path | None = None, **env: str) -> None:
    new_pane(name, cols, rows, cwd or sb.repo, ["env", "-i", *sb.pane_env(**env), "zsh", "-i"])
    # Prompt drawn and gitstatus chip loaded (the branch name appears once it has).
    wait_for(name, r"❯", 30, "the first prompt")
    wait_for(name, r"main", 30, "the git chip")
    time.sleep(0.6)


def type_command(name: str, cmd: str) -> None:
    tmux("send-keys", "-t", name, "-l", cmd)
    time.sleep(0.4)
    tmux("send-keys", "-t", name, "Enter")


FOOTER = r"(converged|dry run|failed) in [0-9.ms ]+\n(?:.*\n){2,6}.*❯"  # the footer and the next prompt


def finished(name: str, timeout: float = 90.0) -> None:
    """The footer is printed and a fresh prompt follows it."""
    wait_for(name, FOOTER, timeout, "the footer and the next prompt")
    time.sleep(1.2)  # command_execution_time chip, git chip refresh


def cli_capture(sb: Sandbox, name: str, args: str, rows: int, *, behind: int, fail_stage: str = "", trim: bool = True) -> Capture:
    sb.make_clone(behind)
    env = {"STUB_FAIL_STAGE": fail_stage} if fail_stage else {}
    zsh_pane(sb, name, CLI_COLS, rows, **env)
    type_command(name, args)
    finished(name)
    cap = Capture(name, CLI_COLS, rows)
    tmux("kill-session", "-t", name, check=False)
    return cap.trim() if trim else cap


# demo.gif: the run is typed at a human pace and played back faster.
DEMO_SPEED = 2.5
DEMO_HOLD_CS = 400  # the converged screen stays up 4 s before the loop restarts
TYPE_IDLE, TYPE_GAP, TYPE_ENTER = 2.5, 0.2, 0.6  # seconds before the first key, between keys, before Enter


def record_run(sb: Sandbox, name: str, command: str, rows: int, *, behind: int) -> list[tuple[float, Capture]]:
    """Type `command` key by key at the real prompt and sample the pane until the footer and the
    next prompt have settled. Returns every distinct screen with the second it appeared."""
    sb.make_clone(behind)
    zsh_pane(sb, name, CLI_COLS, rows)
    keys = [(TYPE_IDLE + i * TYPE_GAP, ("-l", ch)) for i, ch in enumerate(command)]
    keys.append((keys[-1][0] + TYPE_ENTER, ("Enter",)))
    footer = re.compile(FOOTER)
    shots: list[tuple[float, tuple[str, tuple[int, int, bool]]]] = []
    start = time.time()
    while True:
        now = time.time() - start
        while keys and keys[0][0] <= now:
            tmux("send-keys", "-t", name, *keys.pop(0)[1])
        shot = snapshot(name)
        if not shots or shot != shots[-1][1]:
            shots.append((now, shot))
        elif not keys and now - shots[-1][0] >= 2.0:
            if footer.search("\n".join(Capture(name, CLI_COLS, rows, shot).lines())):
                break
        if now > 120:
            raise RenderError(f"no footer and settled prompt in pane {name}:\n{screen_text(name)}")
        time.sleep(0.01)
    tmux("kill-session", "-t", name, check=False)
    return [(t, Capture(name, CLI_COLS, rows, shot)) for t, shot in shots]


def prompt_command(sb: Sandbox, name: str, cols: int, rows: int, command: str, *, cwd: Path | None = None, **env: str) -> Capture:
    """Type `command` at the real prompt, wait for the next prompt, capture the screen."""
    zsh_pane(sb, name, cols, rows, cwd, **env)
    type_command(name, command)
    wait_for(name, r"(?s)❯ " + re.escape(command) + r".*\n.*❯", 30, "the next prompt")
    time.sleep(1.0)
    cap = Capture(name, cols, rows)
    tmux("kill-session", "-t", name, check=False)
    return cap


NVIM_FILE = "modules/omarchy/hypr/cells.lua"
NVIM_LINE = 179  # `inset`: floating cells shrunk by gaps and border


def prepare_nvim_cache(sb: Sandbox) -> dict[str, str]:
    """Neovim runs with the repo's config copied next to a persistent plugin cache, never
    the real ~/.config, ~/.local/share or any tokens (HOME is the sandbox)."""
    config = NVIM_CACHE / "config"
    for sub in ("data", "state", "cache"):
        (NVIM_CACHE / sub).mkdir(parents=True, exist_ok=True)
    shutil.rmtree(config / "nvim", ignore_errors=True)
    marker = NVIM_CACHE / ".synced"
    shutil.copytree(REPO / "modules/neovim/nvim", config / "nvim")
    # lualine's clock is os.date("%R"); pin it to the staged time like the prompt and the bar
    statusline = config / "nvim/lua/plugins/statusline.lua"
    statusline.write_text(statusline.read_text().replace('os.date("%R")', f'"{FIXED_CLOCK[:5]}"'))
    env = {
        "XDG_CONFIG_HOME": str(config),
        "XDG_DATA_HOME": str(NVIM_CACHE / "data"),
        "XDG_STATE_HOME": str(sb.root / "nvim-state"),
        "XDG_CACHE_HOME": str(NVIM_CACHE / "cache"),
    }
    if not (NVIM_CACHE / "data/nvim/lazy/lazy.nvim").exists() or not marker.exists():
        # First run: clone the plugins (network), build the treesitter parsers, and give mason
        # time to fetch its language servers so no install popups appear in the screenshot.
        print("  nvim: installing plugins into", NVIM_CACHE, "(first run only, a few minutes)", flush=True)
        quiet_env = {"PATH": PATH, "TERM": "tmux-256color", "LANG": "en_US.UTF-8", **env, "HOME": str(sb.home)}
        run(["nvim", "--headless", "+Lazy! sync", "+qa"], env=quiet_env, timeout=900)
        run(["nvim", "--headless", "+lua vim.defer_fn(function() vim.cmd('qa!') end, 240000)"], env=quiet_env, timeout=900)
        marker.write_text("primed\n")
    return env


def nvim_capture(sb: Sandbox, cols: int, rows: int) -> Capture:
    env = prepare_nvim_cache(sb)
    pane_env = sb.pane_env(**env)
    new_pane("nvim", cols, rows, sb.repo, ["env", "-i", *pane_env, "nvim", "-R", "-n", "-i", "NONE", f"+{NVIM_LINE}", NVIM_FILE])
    wait_for("nvim", r"cells\.lua", 60, "the nvim statusline")
    # lua_ls indexes the checkout and mason may report; wait until no progress spinner or
    # install message is on screen and the pane has been still for a while.
    busy = re.compile(r"Diagnosing|Loading|Indexing|[Ii]nstalling|[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]")
    deadline, last, since = time.time() + 300, None, time.time()
    while time.time() < deadline:
        cur = screen_ansi("nvim")
        if cur != last or busy.search(screen_text("nvim")):
            last, since = cur, time.time()
        elif time.time() - since >= 6:
            break
        time.sleep(0.5)
    else:
        raise RenderError("nvim never settled:\n" + screen_text("nvim"))
    # Inline git blame appears after a race; switch it off so every run looks alike. Then clear
    # popups and put the function head at the top of the window.
    tmux("send-keys", "-t", "nvim", ":lua pcall(function() require('gitsigns').toggle_current_line_blame(false) end)", "Enter")
    tmux("send-keys", "-t", "nvim", ":Noice dismiss", "Enter", "z", "t")
    wait_stable("nvim", quiet=2.0)
    cap = Capture("nvim", cols, rows)
    tmux("kill-session", "-t", "nvim", check=False)
    return cap


# ----------------------------------------------------------------------------- SVG composition


FONT = termsvg.FONT_FAMILY
ACCENT = "#89b4fa"
INACTIVE_BORDER = ("#595959", 0.67)  # Omarchy's rgba(595959aa)
CURSOR = "#f5e0dc"  # catppuccin cursor colour


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;")


def stage_file(sb: Sandbox, name: str, svg: str) -> Path:
    path = sb.root / f"{name}.svg"
    path.write_text(svg)
    return path


def backdrop(w: float, h: float, wall: Path, dim: float) -> str:
    return (
        f'<image href="{wall.name}" x="0" y="0" width="{w}" height="{h}" preserveAspectRatio="xMidYMid slice"/>'
        f'<rect width="{w}" height="{h}" fill="#000" fill-opacity="{dim}"/>'
    )


def terminal(x: float, y: float, w: float, h: float, cap: Capture, *, border: tuple[str, float], radius: float = 0, show_cursor: bool = False, balance: bool = True) -> str:
    """A Ghostty window: 2 px border, #030304 body, grid centred in the padding."""
    bw = 2
    inner_w, inner_h = w - 2 * bw, h - 2 * bw
    ox = bw + (round((inner_w - cap.cols * CELL_W) / 2 * 2) / 2 if balance else 10)
    oy = bw + (round((inner_h - cap.rows * CELL_H) / 2 * 2) / 2 if balance else 10)
    cx, cy, vis = cap.cursor
    body = termsvg.grid_svg(
        cap.grid, CELL_W, CELL_H, cursor=(cx, cy) if show_cursor and vis else None, cursor_color=CURSOR
    )
    color, opacity = border
    return (
        f'<g transform="translate({x} {y})">'
        f'<rect x="{bw / 2}" y="{bw / 2}" width="{w - bw}" height="{h - bw}" rx="{radius}" fill="{termsvg.DEFAULT_BG}" '
        f'stroke="{color}" stroke-opacity="{opacity}" stroke-width="{bw}"/>'
        f'<g transform="translate({ox} {oy})">{body}</g></g>'
    )


def shadow(x: float, y: float, w: float, h: float, radius: float, blur: float, dy: float, opacity: float, fid: str) -> str:
    return (
        f'<defs><filter id="{fid}" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="{blur}"/></filter></defs>'
        f'<rect x="{x}" y="{y + dy}" width="{w}" height="{h}" rx="{radius}" fill="#000" fill-opacity="{opacity}" filter="url(#{fid})"/>'
    )


def window_size(cap: Capture) -> tuple[float, float]:
    """A lone window's logical size: the grid plus 10 px padding and the 2 px border on each side."""
    return cap.cols * CELL_W + 2 * 10 + 4, cap.rows * CELL_H + 2 * 10 + 4


def window_svg(cap: Capture, x: float, y: float, scale: float) -> str:
    """The focused Ghostty window and its shadow, top-left at (x, y), drawn at `scale`."""
    w, h = window_size(cap)
    return (
        shadow(x, y, w * scale, h * scale, 8, 16, 10, 0.6, "sh")
        + f'<g transform="translate({x:.2f} {y:.2f}) scale({scale:.5f})">'
        + terminal(0, 0, w, h, cap, border=(ACCENT, 1.0), radius=8 / scale, show_cursor=True, balance=False)
        + "</g>"
    )


def scene(w_img: int, h_img: int, dim: float, body: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{w_img}" height="{h_img}" viewBox="0 0 {w_img} {h_img}">'
        + backdrop(w_img, h_img, WALLPAPER, dim)
        + body
        + "</svg>"
    )


def standalone_svg(caps: list[Capture]) -> list[str]:
    """One Ghostty window per capture on the wallpaper, all at the same scale (the tallest fits the 6% margin).
    Canvas 1200x960 logical (2400x1920 @2x): both gallery images share a size so their table rows align."""
    w_img, h_img = 1200, 960
    sizes = [window_size(c) for c in caps]
    scale = min(min(0.88 * w_img / w, 0.88 * h_img / h) for w, h in sizes)
    return [
        scene(w_img, h_img, 0.28, window_svg(cap, (w_img - w * scale) / 2, (h_img - h * scale) / 2, scale))
        for cap, (w, h) in zip(caps, sizes)
    ]


DEMO_MARGIN = 48  # wallpaper around the demo window: room for its shadow


def demo_svg(cap: Capture) -> str:
    w, h = window_size(cap)
    return scene(round(w) + 2 * DEMO_MARGIN, round(h) + 2 * DEMO_MARGIN, 0.28, window_svg(cap, DEMO_MARGIN, DEMO_MARGIN, 1))


SOCIAL_TAGLINE = ("One command to converge", "a whole machine:", "Omarchy or macOS.")  # one sentence, broken for the column


def social_svg(cap: Capture) -> str:
    """GitHub's 1280x640 social preview: header.py's wordmark card, the tagline and the accent
    strip beside the converged window, everything inside a 48 px margin."""
    p = header.PALETTES["dark"]
    w_img, h_img, margin, gap = 1280, 640, 48, 40
    w, h = window_size(cap)
    scale = min(0.9, (h_img - 2 * margin) / h)
    wx, wy = w_img - margin - w * scale, (h_img - h * scale) / 2
    col_w = wx - gap - margin
    word, mark, mark_gap, card_h = 68, 50, 22, 112
    tag_size, tag_lead = 30, 44
    pill_h, pill_gap = 14, 8
    block_h = card_h + 40 + len(SOCIAL_TAGLINE) * tag_lead + 24 + pill_h
    top = (h_img - block_h) / 2
    mid = top + card_h / 2
    x0 = margin + (col_w - mark - mark_gap - header.mono_width("dotfiles", word)) / 2
    tag_y = top + card_h + 40 + tag_size * 0.75
    tagline = "".join(
        f'<tspan x="{margin}" y="{tag_y + i * tag_lead:.1f}">{line}</tspan>' for i, line in enumerate(SOCIAL_TAGLINE)
    )
    pill_w = (col_w - (len(header.ACCENTS) - 1) * pill_gap) / len(header.ACCENTS)
    return scene(
        w_img,
        h_img,
        0.4,
        f"<defs>{header.mark_gradient(p)}</defs>"
        + header.card(p, margin, top, col_w, card_h, 30, 3)
        + header.diamond(x0 + mark / 2, mid, mark)
        + f'<text x="{x0 + mark + mark_gap:.1f}" y="{mid + word * 0.35:.1f}" font-family="{header.FONT}" font-weight="700" '
        f'font-size="{word}" fill="{p["text"]}">dotfiles</text>'
        + f'<text font-family="{header.FONT}" font-size="{tag_size}" fill="{p["text"]}">{tagline}</text>'
        + header.accent_strip(p, margin, top + block_h - pill_h, pill_w, pill_h, pill_gap)
        + window_svg(cap, wx, wy, scale),
    )


def hero_svg(dotfiles: Capture, lsd: Capture, nvim: Capture, fetch: Capture, layout: "HeroLayout") -> str:
    L = layout
    bar = (
        f'<text x="14" y="15.5" font-size="12" fill="{termsvg.DEFAULT_FG}" font-weight="bold">'
        + "".join(
            f'<tspan x="{14 + 18 * i}" fill="{ACCENT if i == 0 else "#7f849c"}">{i + 1}</tspan>' for i in range(5)
        )
        + "</text>"
        f'<text x="{L.sw / 2}" y="15.5" font-size="12" fill="{termsvg.DEFAULT_FG}" text-anchor="middle">Thursday  10:24</text>'
        f'<text x="{L.sw - 14}" y="15.5" font-size="12" fill="{termsvg.DEFAULT_FG}" text-anchor="end" xml:space="preserve">'
        "\uf293   \uf1eb   \uf028   \uf240</text>"
    )
    tiles = (
        terminal(L.xl, L.y0, L.wl, L.h1, dotfiles, border=(ACCENT, 1.0), show_cursor=True)
        + terminal(L.xl, L.y0 + L.h1 + L.gap, L.wl, L.h2, lsd, border=INACTIVE_BORDER)
        + terminal(L.xr, L.y0, L.wr, L.h1, nvim, border=INACTIVE_BORDER)
        + terminal(L.xr, L.y0 + L.h1 + L.gap, L.wr, L.h2, fetch, border=INACTIVE_BORDER)
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1600" height="900" viewBox="0 0 1600 900">'
        + backdrop(1600, 900, WALLPAPER, 0.4)
        + shadow(L.sx, L.sy, L.sw, L.sh, 16, 22, 14, 0.7, "screen-shadow")
        + f'<defs><clipPath id="screen"><rect width="{L.sw}" height="{L.sh}" rx="16"/></clipPath></defs>'
        + f'<g transform="translate({L.sx} {L.sy})"><g clip-path="url(#screen)">'
        + f'<image href="{WALLPAPER.name}" width="{L.sw}" height="{L.sh}" preserveAspectRatio="xMidYMid slice"/>'
        + f'<g font-family="{FONT}">{bar}</g>'
        + tiles
        + f'</g><rect width="{L.sw}" height="{L.sh}" rx="16" fill="none" stroke="#fff" stroke-opacity="0.10"/></g>'
        "</svg>"
    )


class HeroLayout:
    """Omarchy tiling inside a 16:9 'screen' (gaps_out 4, gaps_in 2 => 4 between windows, 2 px borders)."""

    bar_h, gap, outer = 22, 4, 4
    pad, border = 10, 2
    rows_top = 27  # the dotfiles and nvim tiles

    def __init__(self) -> None:
        self.sw = 1472  # 92% of the 1600 canvas
        self.sh = self.sw * 9 / 16
        self.sx, self.sy = (1600 - self.sw) / 2, (900 - self.sh) / 2
        self.y0 = self.bar_h + self.outer
        avail_h = self.sh - self.y0 - self.outer
        self.xl = self.outer
        self.cols_l = CLI_COLS
        self.wl = self.cols_l * CELL_W + 2 * (self.pad + self.border)
        self.xr = self.xl + self.wl + self.gap
        self.wr = self.sw - self.outer - self.xr
        self.cols_r = int((self.wr - 2 * (self.pad + self.border)) // CELL_W)
        self.h1 = self.rows_top * CELL_H + 2 * (self.pad + self.border)
        self.h2 = avail_h - self.gap - self.h1
        self.rows_bottom = int((self.h2 - 2 * (self.pad + self.border)) // CELL_H)


def rasterize(svg: str, name: str, sb: Sandbox, out: Path, zoom: int = 2) -> Path:
    src = stage_file(sb, name, svg)
    run(["rsvg-convert", "-z", str(zoom), "-o", out, src])
    return out


# ----------------------------------------------------------------------------- main


def scene_fetch_config(sb: Sandbox) -> None:
    """fastfetch: the stock defaults minus lines that depend on the terminal or reveal the network,
    and only the root disk (one line on any machine, so the tile keeps its prompt on screen)."""
    cfg = sb.home / ".config/fastfetch"
    cfg.mkdir(parents=True)
    (cfg / "config.jsonc").write_text(
        json.dumps(
            {
                "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
                "logo": {"type": "small", "color": {"1": "blue"}},
                "display": {"color": {"keys": "blue", "title": "blue", "separator": "bright_black"}},
                "modules": [
                    "title", "separator", "os", "kernel", "shell", "packages", "cpu", "gpu", "memory",
                    {"type": "disk", "folders": "/"},
                ],
            },
            indent=2,
        )
    )


def build_hero(sb: Sandbox, dotfiles: Capture, out: Path) -> Path:
    L = HeroLayout()
    scene_fetch_config(sb)
    log("hero: lsd tile")
    lsd = prompt_command(sb, "hero-lsd", L.cols_l, L.rows_bottom, "lsd modules", XDG_CONFIG_HOME=str(REAL_HOME / ".config"))
    log("hero: fastfetch tile")
    fetch = prompt_command(sb, "hero-fetch", L.cols_r, L.rows_bottom, "fastfetch", XDG_CONFIG_HOME=str(sb.home / ".config"))
    log("hero: nvim tile (waits for the language server to go idle)")
    nvim = nvim_capture(sb, L.cols_r, L.rows_top)
    log("hero: composing")
    return rasterize(hero_svg(dotfiles, lsd, nvim, fetch, L), "hero", sb, out)


def build_demo(sb: Sandbox, frames: list[tuple[float, Capture]], out: Path) -> Path:
    """Every distinct screen of the recorded run as a looping GIF, played DEMO_SPEED times faster."""
    rows = frames[-1][1].trim().rows
    # Playback starts in centiseconds, GIF's unit. A screen due for under 2 cs is skipped: browsers
    # stretch such frames to 10 cs, and a screen that only one sample saw may be half drawn.
    starts = [round(t * 100 / DEMO_SPEED) for t, _ in frames]
    shown: list[tuple[int, Capture]] = []
    for i, (start, (_, cap)) in enumerate(zip(starts, frames)):
        if i + 1 < len(frames) and starts[i + 1] - start < 2:
            continue
        cap = cap.trim(rows)
        if shown and (cap.grid, cap.cursor) == (shown[-1][1].grid, shown[-1][1].cursor):
            continue
        shown.append((start, cap))
    gaps = [b - a for (a, _), (b, _) in zip(shown, shown[1:])]

    def frame(i: int) -> Path:
        return rasterize(demo_svg(shown[i][1]), f"demo-{i:04d}", sb, sb.root / f"demo-{i:04d}.png")

    with ThreadPoolExecutor(os.cpu_count()) as pool:
        pngs = list(pool.map(frame, range(len(shown))))
    concat = sb.root / "demo.ffconcat"
    entries = "".join(f"file {png.name}\nduration {cs / 100:.2f}\n" for png, cs in zip(pngs, gaps))
    concat.write_text(f"ffconcat version 1.0\n{entries}file {pngs[-1].name}\n")
    palette = sb.root / "demo-palette.png"
    source = ["ffmpeg", "-v", "error", "-y", "-f", "concat", "-i", concat]
    run([*source, "-vf", "palettegen=stats_mode=full", palette])
    run([
        *source, "-i", palette, "-lavfi", "paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
        "-fps_mode", "vfr", "-loop", "0", "-final_delay", DEMO_HOLD_CS, out,
    ])
    log(f"demo: {len(shown)} frames, a {(sum(gaps) + DEMO_HOLD_CS) / 100:.1f} s loop")
    return out


def build_standalone(sb: Sandbox, outs: dict[str, Path]) -> list[Path]:
    dry = cli_capture(sb, "dry", "dotfiles --dry-run", 46, behind=0).drop_wrapped_notice("dotfiles: previewing local modules")
    fail = cli_capture(sb, "fail", "dotfiles", 46, behind=3, fail_stage="tools")
    return [rasterize(svg, key, sb, outs[key]) for svg, key in zip(standalone_svg([dry, fail]), ("dry-run", "failure"))]


OUTPUTS = ("header", "hero", "demo", "social", "dry-run", "failure")


def main(argv: list[str]) -> int:
    wanted = set(argv) or set(OUTPUTS)
    unknown = wanted - set(OUTPUTS)
    if unknown:
        print(f"usage: render.py {' '.join(f'[{o}]' for o in OUTPUTS)}  (unknown: {' '.join(sorted(unknown))})", file=sys.stderr)
        return 2
    started = time.time()
    written: list[Path] = []
    if "header" in wanted:
        written += header.render(ASSETS_DIR)
    if wanted - {"header"}:
        sb = Sandbox()
        try:
            tmux_start()
            if wanted & {"hero", "demo", "social"}:
                log("dotfiles: a real run against the stub mise, typed and sampled (~35 s)")
                frames = record_run(sb, "cli", "dotfiles", HeroLayout.rows_top, behind=3)
                final = frames[-1][1]
                if "hero" in wanted:
                    written.append(build_hero(sb, final, ASSETS_DIR / "hero.png"))
                if "demo" in wanted:
                    written.append(build_demo(sb, frames, ASSETS_DIR / "demo.gif"))
                if "social" in wanted:
                    written.append(rasterize(social_svg(final.trim()), "social", sb, ASSETS_DIR / "social.png", zoom=1))
            if wanted & {"dry-run", "failure"}:
                outs = {"dry-run": ASSETS_DIR / "dry-run.png", "failure": ASSETS_DIR / "failure.png"}
                written += build_standalone(sb, outs)
        finally:
            tmux_stop()
            sb.cleanup()
    for p in written:
        print(f"wrote {p.relative_to(REPO)}  ({p.stat().st_size / 1024:.0f} KiB)")
    print(f"done in {time.time() - started:.0f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
