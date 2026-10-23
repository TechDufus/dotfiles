"""Terminal screen capture (tmux capture-pane -e) -> SVG fragment.

Stdlib only. The screen is parsed into a cell grid (SGR 16/256/truecolor, bold, italic,
dim, reverse, underline, strike); the SVG places every glyph on the exact column grid
with a per-character `x` list, so proportional fallback glyphs and Nerd Font icons can
never shift a column. Box drawing, block elements and Powerline separators are drawn as
shapes (like Ghostty's builtin renderer) so lines meet across cells without gaps.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from xml.sax.saxutils import escape

FONT_FAMILY = "BerkeleyMono Nerd Font, DejaVu Sans Mono, monospace"
ADVANCE_EM = 0.6  # BerkeleyMono advance, measured with rsvg-convert
ASCENT_EM = 0.956  # hhea ascent; ascent + |descent| = 1.2 em = the cell height

DEFAULT_BG = "#030304"
DEFAULT_FG = "#cdd6f4"

# Ghostty's catppuccin-mocha palette 0-15.
ANSI16 = [
    "#45475a", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#bac2de",
    "#585b70", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#a6adc8",
]


def _xterm256(n: int) -> str:
    if n < 16:
        return ANSI16[n]
    if n < 232:
        n -= 16
        steps = (0, 95, 135, 175, 215, 255)
        return "#%02x%02x%02x" % (steps[n // 36], steps[n // 6 % 6], steps[n % 6])
    v = 8 + (n - 232) * 10
    return "#%02x%02x%02x" % (v, v, v)


@dataclass(frozen=True)
class Style:
    fg: str | None = None  # "#rrggbb", or None for the default
    bg: str | None = None
    fg_idx: int | None = None  # ANSI index 0-7, kept for bold-is-bright
    bold: bool = False
    italic: bool = False
    dim: bool = False
    reverse: bool = False
    underline: bool = False
    strike: bool = False
    hidden: bool = False


@dataclass
class Cell:
    ch: str = " "
    style: Style = Style()
    wide_tail: bool = False  # right half of a double-width character


Grid = list[list[Cell]]

_SGR = re.compile(r"\x1b\[([0-9;:]*)m")
_ESC_OTHER = re.compile(r"\x1b\[[0-9;:?]*[A-HJKSTfhlnsu]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[()][0-9A-B]|\x1b[=>]")


def _apply_sgr(style: Style, params: str) -> Style:
    codes = [c for c in re.split(r"[;:]", params)] if params else ["0"]
    nums = [int(c) if c else 0 for c in codes]
    s = style
    i = 0
    while i < len(nums):
        n = nums[i]
        if n == 0:
            s = Style()
        elif n == 1:
            s = _r(s, bold=True)
        elif n == 2:
            s = _r(s, dim=True)
        elif n == 3:
            s = _r(s, italic=True)
        elif n in (4, 21):
            s = _r(s, underline=True)
        elif n == 7:
            s = _r(s, reverse=True)
        elif n == 8:
            s = _r(s, hidden=True)
        elif n == 9:
            s = _r(s, strike=True)
        elif n == 22:
            s = _r(s, bold=False, dim=False)
        elif n == 23:
            s = _r(s, italic=False)
        elif n == 24:
            s = _r(s, underline=False)
        elif n == 27:
            s = _r(s, reverse=False)
        elif n == 28:
            s = _r(s, hidden=False)
        elif n == 29:
            s = _r(s, strike=False)
        elif 30 <= n <= 37:
            s = _r(s, fg=ANSI16[n - 30], fg_idx=n - 30)
        elif n == 39:
            s = _r(s, fg=None, fg_idx=None)
        elif 40 <= n <= 47:
            s = _r(s, bg=ANSI16[n - 40])
        elif n == 49:
            s = _r(s, bg=None)
        elif 90 <= n <= 97:
            s = _r(s, fg=ANSI16[n - 90 + 8], fg_idx=None)
        elif 100 <= n <= 107:
            s = _r(s, bg=ANSI16[n - 100 + 8])
        elif n in (38, 48):
            target = "fg" if n == 38 else "bg"
            mode = nums[i + 1] if i + 1 < len(nums) else None
            color = None
            if mode == 5 and i + 2 < len(nums):
                color = _xterm256(nums[i + 2])
                idx = nums[i + 2] if nums[i + 2] < 8 else None
                i += 2
            elif mode == 2:
                # 38;2;r;g;b, or the colon form 38:2::r:g:b (an empty colourspace slot)
                skip = 1 if len(codes) > i + 2 and codes[i + 2] == "" and len(nums) >= i + 6 else 0
                rgb = nums[i + 2 + skip : i + 5 + skip]
                if len(rgb) == 3:
                    color = "#%02x%02x%02x" % tuple(rgb)
                idx = None
                i += 4 + skip
            if color is not None:
                if target == "fg":
                    s = _r(s, fg=color, fg_idx=idx)
                else:
                    s = _r(s, bg=color)
        i += 1
    return s


def _r(style: Style, **kw) -> Style:
    return Style(**{**style.__dict__, **kw})


def _width(ch: str) -> int:
    if unicodedata.combining(ch):
        return 0
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1


def parse_capture(text: str, cols: int, rows: int) -> Grid:
    """Parse `tmux capture-pane -p -e [-J]` output into a rows x cols grid."""
    grid: Grid = [[Cell() for _ in range(cols)] for _ in range(rows)]
    for y, line in enumerate(text.split("\n")[:rows]):
        line = _ESC_OTHER.sub("", line)
        style = Style()
        x = 0
        pos = 0
        for m in _SGR.finditer(line):
            x, style = _put(grid[y], x, line[pos : m.start()], style)
            style = _apply_sgr(style, m.group(1))
            pos = m.end()
        _put(grid[y], x, line[pos:], style)
    return grid


def _put(row: list[Cell], x: int, chunk: str, style: Style) -> tuple[int, Style]:
    for ch in chunk:
        w = _width(ch)
        if w == 0:
            continue  # combining marks are not drawn separately
        if x + w > len(row):
            break
        row[x] = Cell(ch, style)
        if w == 2:
            row[x + 1] = Cell(" ", style, wide_tail=True)
        x += w
    return x, style


def blank_rows_at_end(grid: Grid) -> int:
    n = 0
    for row in reversed(grid):
        if any(c.ch != " " or c.style.bg or c.style.reverse for c in row):
            break
        n += 1
    return n


# ---------------------------------------------------------------------------------------
# colour helpers


def _rgb(h: str) -> tuple[int, int, int]:
    return int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)


def mix(a: str, b: str, t: float) -> str:
    """a*(1-t) + b*t"""
    ra, rb = _rgb(a), _rgb(b)
    return "#%02x%02x%02x" % tuple(round(x * (1 - t) + y * t) for x, y in zip(ra, rb))


def resolve(style: Style, default_fg: str, default_bg: str, bold_is_bright: bool = True) -> tuple[str, str | None]:
    """Final (fg, bg) of a cell; bg None means 'the terminal background'."""
    fg = style.fg
    if fg is None:
        fg = default_fg
    elif bold_is_bright and style.bold and style.fg_idx is not None:
        fg = ANSI16[style.fg_idx + 8]
    bg = style.bg
    if style.reverse:
        fg, bg = (bg or default_bg), fg
    if style.dim:
        fg = mix(fg, bg or default_bg, 0.5)
    return fg, bg


# ---------------------------------------------------------------------------------------
# drawn glyphs

# (left, right, up, down) weights: 0 none, 1 light, 2 heavy
_LINES = {
    "─": (1, 1, 0, 0), "━": (2, 2, 0, 0), "│": (0, 0, 1, 1), "┃": (0, 0, 2, 2),
    "┌": (0, 1, 0, 1), "┏": (0, 2, 0, 2), "┐": (1, 0, 0, 1), "┓": (2, 0, 0, 2),
    "└": (0, 1, 1, 0), "┗": (0, 2, 2, 0), "┘": (1, 0, 1, 0), "┛": (2, 0, 2, 0),
    "├": (0, 1, 1, 1), "┣": (0, 2, 2, 2), "┤": (1, 0, 1, 1), "┫": (2, 0, 2, 2),
    "┬": (1, 1, 0, 1), "┳": (2, 2, 0, 2), "┴": (1, 1, 1, 0), "┻": (2, 2, 2, 0),
    "┼": (1, 1, 1, 1), "╋": (2, 2, 2, 2),
    "╴": (1, 0, 0, 0), "╵": (0, 0, 1, 0), "╶": (0, 1, 0, 0), "╷": (0, 0, 0, 1),
    "┄": (1, 1, 0, 0), "┈": (1, 1, 0, 0), "╌": (1, 1, 0, 0), "┆": (0, 0, 1, 1),
    "┊": (0, 0, 1, 1), "╎": (0, 0, 1, 1),
}
_ARCS = {"╭": "dr", "╮": "dl", "╯": "ul", "╰": "ur"}  # which two sides the arc joins

# block elements as fractions (x0, y0, x1, y1) of the cell, filled with the foreground
_BLOCKS: dict[str, list[tuple[float, float, float, float]]] = {
    "▀": [(0, 0, 1, .5)], "▄": [(0, .5, 1, 1)], "█": [(0, 0, 1, 1)], "▌": [(0, 0, .5, 1)], "▐": [(.5, 0, 1, 1)],
    "▔": [(0, 0, 1, 1 / 8)], "▕": [(7 / 8, 0, 1, 1)],
    "▖": [(0, .5, .5, 1)], "▗": [(.5, .5, 1, 1)], "▘": [(0, 0, .5, .5)], "▝": [(.5, 0, 1, .5)],
    "▙": [(0, 0, .5, 1), (.5, .5, 1, 1)], "▚": [(0, 0, .5, .5), (.5, .5, 1, 1)],
    "▛": [(0, 0, 1, .5), (0, .5, .5, 1)], "▜": [(0, 0, 1, .5), (.5, .5, 1, 1)],
    "▞": [(.5, 0, 1, .5), (0, .5, .5, 1)], "▟": [(.5, 0, 1, 1), (0, .5, 1, 1)],
}
for _i, _c in enumerate("▁▂▃▄▅▆▇"):
    _BLOCKS[_c] = [(0, 1 - (_i + 1) / 8, 1, 1)]
for _i, _c in enumerate("▉▊▋▌▍▎▏"):
    _BLOCKS[_c] = [(0, 0, (7 - _i) / 8, 1)]
_SHADES = {"░": 0.25, "▒": 0.5, "▓": 0.75}


def _fmt(v: float) -> str:
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return s or "0"


def _glyph_shapes(ch: str, x: float, y: float, w: float, h: float, fg: str) -> str | None:
    """SVG for a drawn glyph, or None when `ch` is rendered as text."""
    if ch in _LINES:
        l, r, u, d = _LINES[ch]
        cx, cy = x + w / 2, y + h / 2
        out = []
        for weight, side in ((l, "l"), (r, "r"), (u, "u"), (d, "d")):
            if not weight:
                continue
            t = 1.0 if weight == 1 else 2.0
            # every arm reaches half a stroke past the centre so corners and joins are filled
            if side == "l":
                rx, ry, rw, rh = x, cy - t / 2, cx + t / 2 - x, t
            elif side == "r":
                rx, ry, rw, rh = cx - t / 2, cy - t / 2, x + w - cx + t / 2, t
            elif side == "u":
                rx, ry, rw, rh = cx - t / 2, y, t, cy + t / 2 - y
            else:
                rx, ry, rw, rh = cx - t / 2, cy - t / 2, t, y + h - cy + t / 2
            out.append(f'<rect x="{_fmt(rx)}" y="{_fmt(ry)}" width="{_fmt(rw)}" height="{_fmt(rh)}"/>')
        return f'<g fill="{fg}">{"".join(out)}</g>'
    if ch in _ARCS:
        cx, cy = x + w / 2, y + h / 2
        r = w / 2
        a = _ARCS[ch]
        if a == "dr":  # ╭: from the bottom edge up, round, out to the right edge
            d = f"M{_fmt(cx)} {_fmt(y + h)}V{_fmt(cy + r)}A{_fmt(r)} {_fmt(r)} 0 0 1 {_fmt(cx + r)} {_fmt(cy)}H{_fmt(x + w)}"
        elif a == "dl":  # ╮
            d = f"M{_fmt(cx)} {_fmt(y + h)}V{_fmt(cy + r)}A{_fmt(r)} {_fmt(r)} 0 0 0 {_fmt(cx - r)} {_fmt(cy)}H{_fmt(x)}"
        elif a == "ur":  # ╰
            d = f"M{_fmt(cx)} {_fmt(y)}V{_fmt(cy - r)}A{_fmt(r)} {_fmt(r)} 0 0 0 {_fmt(cx + r)} {_fmt(cy)}H{_fmt(x + w)}"
        else:  # ╯
            d = f"M{_fmt(cx)} {_fmt(y)}V{_fmt(cy - r)}A{_fmt(r)} {_fmt(r)} 0 0 1 {_fmt(cx - r)} {_fmt(cy)}H{_fmt(x)}"
        return f'<path d="{d}" fill="none" stroke="{fg}" stroke-width="1"/>'
    if ch in _BLOCKS:
        rects = "".join(
            f'<rect x="{_fmt(x + a * w)}" y="{_fmt(y + b * h)}" width="{_fmt((c - a) * w)}" height="{_fmt((d - b) * h)}"/>'
            for a, b, c, d in _BLOCKS[ch]
        )
        return f'<g fill="{fg}">{rects}</g>'
    if ch in _SHADES:
        return f'<rect x="{_fmt(x)}" y="{_fmt(y)}" width="{_fmt(w)}" height="{_fmt(h)}" fill="{fg}" fill-opacity="{_SHADES[ch]}"/>'
    # Powerline separators (Nerd Font E0B0-E0B7)
    if ch == "\ue0b0":
        return f'<path d="M{_fmt(x)} {_fmt(y)}L{_fmt(x + w)} {_fmt(y + h / 2)}L{_fmt(x)} {_fmt(y + h)}Z" fill="{fg}"/>'
    if ch == "\ue0b2":
        return f'<path d="M{_fmt(x + w)} {_fmt(y)}L{_fmt(x)} {_fmt(y + h / 2)}L{_fmt(x + w)} {_fmt(y + h)}Z" fill="{fg}"/>'
    if ch == "\ue0b1":
        return f'<path d="M{_fmt(x)} {_fmt(y)}L{_fmt(x + w)} {_fmt(y + h / 2)}L{_fmt(x)} {_fmt(y + h)}" fill="none" stroke="{fg}" stroke-width="1"/>'
    if ch == "\ue0b3":
        return f'<path d="M{_fmt(x + w)} {_fmt(y)}L{_fmt(x)} {_fmt(y + h / 2)}L{_fmt(x + w)} {_fmt(y + h)}" fill="none" stroke="{fg}" stroke-width="1"/>'
    if ch == "\ue0b4":  # half circle bulging right
        return f'<path d="M{_fmt(x)} {_fmt(y)}A{_fmt(w)} {_fmt(h / 2)} 0 0 1 {_fmt(x)} {_fmt(y + h)}Z" fill="{fg}"/>'
    if ch == "\ue0b6":  # half circle bulging left
        return f'<path d="M{_fmt(x + w)} {_fmt(y)}A{_fmt(w)} {_fmt(h / 2)} 0 0 0 {_fmt(x + w)} {_fmt(y + h)}Z" fill="{fg}"/>'
    if ch == "\ue0b5":
        return f'<path d="M{_fmt(x)} {_fmt(y)}A{_fmt(w)} {_fmt(h / 2)} 0 0 1 {_fmt(x)} {_fmt(y + h)}" fill="none" stroke="{fg}" stroke-width="1"/>'
    if ch == "\ue0b7":
        return f'<path d="M{_fmt(x + w)} {_fmt(y)}A{_fmt(w)} {_fmt(h / 2)} 0 0 0 {_fmt(x + w)} {_fmt(y + h)}" fill="none" stroke="{fg}" stroke-width="1"/>'
    return None


# ---------------------------------------------------------------------------------------


def _is_icon(ch: str) -> bool:
    o = ord(ch)
    return 0xE000 <= o <= 0xF8FF or o >= 0xF0000


def _text(x: float, y: float, s: str, fg: str, bold: bool, italic: bool, *, size: float | None = None, anchor: str = "") -> str:
    attrs = ' font-weight="bold"' if bold else ""
    attrs += ' font-style="italic"' if italic else ""
    attrs += f' font-size="{_fmt(size)}"' if size is not None else ""
    attrs += f' text-anchor="{anchor}"' if anchor else ""
    return f'<text x="{_fmt(x)}" y="{_fmt(y)}" fill="{fg}"{attrs}>{escape(s)}</text>'


def grid_svg(
    grid: Grid,
    cell_w: float,
    cell_h: float,
    *,
    default_fg: str = DEFAULT_FG,
    default_bg: str = DEFAULT_BG,
    cursor: tuple[int, int] | None = None,
    cursor_color: str = DEFAULT_FG,
    bold_is_bright: bool = True,
    pad_rect: bool = False,
) -> str:
    """Return a <g> in the grid's own coordinates (origin at the grid's top-left)."""
    fs = cell_h / 1.2
    baseline = ASCENT_EM * fs
    rows, cols = len(grid), len(grid[0]) if grid else 0
    parts: list[str] = []
    if pad_rect:
        parts.append(f'<rect width="{_fmt(cols * cell_w)}" height="{_fmt(rows * cell_h)}" fill="{default_bg}"/>')

    # 1. backgrounds, merged per row
    bgs: list[str] = []
    for y, row in enumerate(grid):
        x = 0
        while x < cols:
            _, bg = resolve(row[x].style, default_fg, default_bg, bold_is_bright)
            if bg is None or bg == default_bg:
                x += 1
                continue
            x2 = x + 1
            while x2 < cols and resolve(row[x2].style, default_fg, default_bg, bold_is_bright)[1] == bg:
                x2 += 1
            # half a device pixel of overlap hides seams between rows
            bgs.append(
                f'<rect x="{_fmt(x * cell_w)}" y="{_fmt(y * cell_h - .1)}" width="{_fmt((x2 - x) * cell_w)}" '
                f'height="{_fmt(cell_h + .2)}" fill="{bg}"/>'
            )
            x = x2
    parts.extend(bgs)

    # 2. cursor block under the glyph
    if cursor is not None:
        cx, cy = cursor
        if 0 <= cy < rows and 0 <= cx < cols:
            parts.append(f'<rect x="{_fmt(cx * cell_w)}" y="{_fmt(cy * cell_h)}" width="{_fmt(cell_w)}" height="{_fmt(cell_h)}" fill="{cursor_color}"/>')

    # 3. glyphs: drawn shapes; ASCII words as one <text>; every other glyph on its own cell
    for y, row in enumerate(grid):
        top = y * cell_h
        run: list | None = None  # [key, x0_col, last_col, chars]

        def flush() -> None:
            nonlocal run
            if run is not None:
                key, x0, _, chars = run
                parts.append(_text(x0 * cell_w, top + baseline, "".join(chars), *key))
                run = None

        for x, c in enumerate(row):
            if c.ch == " " or c.wide_tail or c.style.hidden:
                flush()
                continue
            fg, bg = resolve(c.style, default_fg, default_bg, bold_is_bright)
            if cursor == (x, y):
                fg = default_bg
            shape = _glyph_shapes(c.ch, x * cell_w, top, cell_w, cell_h, fg)
            if shape is not None:
                flush()
                parts.append(shape)
            elif _is_icon(c.ch):
                flush()
                # Like Ghostty: an icon may spill into a following blank cell, else it is fitted to one cell.
                nxt = row[x + 1] if x + 1 < cols else None
                span = 2 if nxt is None or (nxt.ch == " " and not nxt.wide_tail) else 1
                f2 = fs * min(1.0, span * cell_w / fs)
                y2 = top + baseline - 0.33 * (fs - f2)
                parts.append(
                    _text(x * cell_w + span * cell_w / 2, y2, c.ch, fg, c.style.bold, c.style.italic, size=f2, anchor="middle")
                )
            else:
                key = (fg, c.style.bold, c.style.italic)
                if c.ch.isascii() and run is not None and run[0] == key and run[2] == x - 1:
                    run[2] = x
                    run[3].append(c.ch)
                else:
                    flush()
                    if c.ch.isascii():
                        run = [key, x, x, [c.ch]]
                    else:
                        parts.append(_text(x * cell_w, top + baseline, c.ch, *key))
            if c.style.underline:
                parts.append(f'<rect x="{_fmt(x * cell_w)}" y="{_fmt(top + cell_h - 2.5)}" width="{_fmt(cell_w)}" height="1" fill="{fg}"/>')
            if c.style.strike:
                parts.append(f'<rect x="{_fmt(x * cell_w)}" y="{_fmt(top + cell_h * .52)}" width="{_fmt(cell_w)}" height="1" fill="{fg}"/>')
        flush()

    return (
        f'<g font-family="{FONT_FAMILY}" font-size="{_fmt(fs)}" xml:space="preserve">' + "".join(parts) + "</g>"
    )
