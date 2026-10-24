#!/usr/bin/env python3
"""Render the README header banners (header-dark.png / header-light.png).

An enlarged version of the CLI's own header box (`draw_header` in bin/dotfiles):
rounded outline, a gradient ◆ mark, the `dotfiles` wordmark and a mono meta
line, plus the tagline and a Catppuccin accent strip. Transparent PNG output
only: the wordmark uses Berkeley Mono (commercial), so no SVG or font is kept.

Needs: rsvg-convert, BerkeleyMono Nerd Font (found through fontconfig).
"""

import pathlib
import subprocess
import sys
import tempfile

W, H = 1600, 400  # CSS-pixel canvas; rasterized at 2x -> 3200x800
FONT = "BerkeleyMono Nerd Font"
ADVANCE = 0.6  # Berkeley Mono advance width in em

# Catppuccin accents in canonical order (14).
ACCENTS = (
    "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
    "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender",
)

PALETTES = {
    "dark": {  # Mocha
        "card": "#1e1e2e", "card_opacity": 0.65, "stroke": "#585b70",
        "text": "#cdd6f4", "sub": "#a6adc8", "sep": "#6c6f85",
        "grad": ("#cba6f7", "#89b4fa"),
        "rosewater": "#f5e0dc", "flamingo": "#f2cdcd", "pink": "#f5c2e7",
        "mauve": "#cba6f7", "red": "#f38ba8", "maroon": "#eba0ac",
        "peach": "#fab387", "yellow": "#f9e2af", "green": "#a6e3a1",
        "teal": "#94e2d5", "sky": "#89dceb", "sapphire": "#74c7ec",
        "blue": "#89b4fa", "lavender": "#b4befe",
    },
    "light": {  # Latte
        "card": "#eff1f5", "card_opacity": 0.85, "stroke": "#acb0be",
        "text": "#4c4f69", "sub": "#5c5f77", "sep": "#9ca0b0",
        "grad": ("#8839ef", "#1e66f5"),
        "rosewater": "#dc8a78", "flamingo": "#dd7878", "pink": "#ea76cb",
        "mauve": "#8839ef", "red": "#d20f39", "maroon": "#e64553",
        "peach": "#fe640b", "yellow": "#df8e1d", "green": "#40a02b",
        "teal": "#179299", "sky": "#04a5e5", "sapphire": "#209fb5",
        "blue": "#1e66f5", "lavender": "#7287fd",
    },
}

PROFILES = ("omarchy", "macos")
TAGLINE = "one command, every machine \u2014 applied with mise"


def mono_width(text: str, size: float) -> float:
    return len(text) * size * ADVANCE


def build_svg(p: dict) -> str:
    # Card geometry (mirrors the CLI's `╭ ◆ dotfiles  meta ╮` box).
    card_w, card_h = 1120, 172
    card_x, card_y = (W - card_w) / 2, 46
    mid_y = card_y + card_h / 2

    word_size, meta_size, tag_size = 92, 27, 28
    mark = 66  # diamond half-height * 2
    gap_mark, gap_meta = 30, 52
    meta_text = " \u00b7 ".join(PROFILES)

    word_w = mono_width("dotfiles", word_size)
    meta_w = mono_width(meta_text, meta_size)
    total = mark + gap_mark + word_w + gap_meta + meta_w
    x0 = (W - total) / 2

    cx = x0 + mark / 2
    r = mark / 2
    diamond = (
        f"M{cx:.1f},{mid_y - r:.1f} L{cx + r * 0.82:.1f},{mid_y:.1f} "
        f"L{cx:.1f},{mid_y + r:.1f} L{cx - r * 0.82:.1f},{mid_y:.1f} Z"
    )
    word_x = x0 + mark + gap_mark
    meta_x = word_x + word_w + gap_meta

    # Baselines: cap/x-height centering for mono text (cap height ~0.7em).
    word_y = mid_y + word_size * 0.35
    meta_y = mid_y + meta_size * 0.35 + 4
    tag_y = card_y + card_h + 66

    meta_spans = f'<tspan fill="{p["sep"]}"> \u00b7 </tspan>'.join(
        f'<tspan>{name}</tspan>' for name in PROFILES
    )

    # Accent strip: 14 rounded pills.
    pill_w, pill_h, pill_gap = 58, 24, 16
    strip_w = len(ACCENTS) * pill_w + (len(ACCENTS) - 1) * pill_gap
    strip_x = (W - strip_w) / 2
    strip_y = tag_y + 36
    pills = "\n".join(
        f'<rect x="{strip_x + i * (pill_w + pill_gap):.1f}" y="{strip_y:.1f}" '
        f'width="{pill_w}" height="{pill_h}" rx="{pill_h / 2}" fill="{p[name]}"/>'
        for i, name in enumerate(ACCENTS)
    )

    g0, g1 = p["grad"]
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
<linearGradient id="mark" x1="0" y1="0" x2="1" y2="1">
<stop offset="0" stop-color="{g0}"/>
<stop offset="1" stop-color="{g1}"/>
</linearGradient>
</defs>
<rect x="{card_x}" y="{card_y}" width="{card_w}" height="{card_h}" rx="44"
 fill="{p["card"]}" fill-opacity="{p["card_opacity"]}" stroke="{p["stroke"]}" stroke-width="4"/>
<path d="{diamond}" fill="url(#mark)" stroke="url(#mark)" stroke-width="10" stroke-linejoin="round"/>
<text x="{word_x:.1f}" y="{word_y:.1f}" font-family="{FONT}" font-weight="700" font-size="{word_size}" fill="{p["text"]}">dotfiles</text>
<text x="{meta_x:.1f}" y="{meta_y:.1f}" font-family="{FONT}" font-size="{meta_size}" fill="{p["sub"]}" xml:space="preserve">{meta_spans}</text>
<text x="{W / 2}" y="{tag_y}" text-anchor="middle" font-family="{FONT}" font-size="{tag_size}" fill="{p["sub"]}">{TAGLINE}</text>
{pills}
</svg>
"""


def render(out_dir: pathlib.Path) -> list[pathlib.Path]:
    out_dir = pathlib.Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    outputs = []
    with tempfile.TemporaryDirectory() as tmp:
        for variant, palette in PALETTES.items():
            svg = pathlib.Path(tmp) / f"header-{variant}.svg"
            png = out_dir / f"header-{variant}.png"
            svg.write_text(build_svg(palette), encoding="utf-8")
            subprocess.run(
                ["rsvg-convert", "--zoom", "2", "-o", str(png), str(svg)],
                check=True,
            )
            outputs.append(png)
    return outputs


if __name__ == "__main__":
    for path in render(pathlib.Path(__file__).resolve().parent.parent):
        print(path, file=sys.stderr)
