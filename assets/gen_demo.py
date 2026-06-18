"""
Forge animated terminal demo SVG generator.

Static-fallback works because fill-mode:both causes the animation end-state
(opacity:1, translateX(0)) to apply even before/without CSS execution — so
static renderers (e.g. plain HTML viewers, accessibility tools) show ALL lines.

Residual risk: GitHub camo image proxy may rasterize the SVG at t=0 (before
animations fire), rendering a blank or partial image. Verify on live GitHub
after pushing. Fallback plan: replace with a static hero PNG if camo breaks
the animation.
"""

import html
import os

WIDTH = 780
LINE_HEIGHT = 28
TOP = 56
BOTTOM_PAD = 24

FRAMES = [
    (0.3,  "# /f-fix → Forge routes a pipeline, not one lone agent",            "#6e7681", 13),
    (0.9,  "you ›  /f-fix  add rate-limiting to the API",                        "#c9d1d9", 15),
    (1.5,  "pm  ›  L3 — architect → dev → review ∥ security → verify", "#2f81f7", 14),
    (2.0,  "├─ architect     ›  token-bucket, Redis-backed        ✓",  "#d2a8ff", 14),
    (2.4,  "├─ developer     ›  middleware + unit tests           ✓",  "#c9d1d9", 14),
    (2.9,  "│  developer     ›  tries to PASS its own task…",              "#d29922", 14),
    (3.3,  "│  ⊘ role-write-guard hook — BLOCKED",                        "#f85149", 14),
    (3.8,  "├─ code-review   ›  2 findings → fixed                 ✓", "#f0883e", 14),
    (4.2,  "└─ reality-check ›  verified vs real code      ✓ PASSED", "#3fb950", 14),
    (4.6,  "Roles enforced by hooks. Pipelined by complexity. No infra.",             "#e3b341", 15),
]

TITLE_TEXT = "Forge: one prompt routes a gated multi-agent pipeline; role violations are blocked by hooks"
DESC_TEXT  = "Animated walkthrough of a Forge /f-fix run: PM routes L3 pipeline, role-write-guard hook blocks a developer overreach, and reality-check gates the final result."

HEADER_TITLE = "forge ⚒️ — your AI dev team, gated by hooks"
FONT = "SFMono-Regular,Consolas,Menlo,monospace"


def e(text: str) -> str:
    """HTML-escape a string."""
    return html.escape(text, quote=True)


def generate_svg() -> str:
    n = len(FRAMES)
    height = TOP + n * LINE_HEIGHT + BOTTOM_PAD

    lines = []

    # --- SVG open tag ---
    lines.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{height}" '
        f'role="img" viewBox="0 0 {WIDTH} {height}">'
    )

    # --- accessibility ---
    lines.append(f'  <title>{e(TITLE_TEXT)}</title>')
    lines.append(f'  <desc>{e(DESC_TEXT)}</desc>')

    # --- CSS ---
    css_parts = []
    css_parts.append("    <style>")
    css_parts.append(f"      @keyframes sh{{from{{opacity:0;transform:translateX(-4px)}} to{{opacity:1;transform:translateX(0)}}}}")
    # Per-line animation rules — NO base opacity:0 so static renderers show all lines
    for i, (t, _text, _color, _size) in enumerate(FRAMES):
        css_parts.append(f"      .l{i}{{animation:sh .15s ease {t}s both;}}")
    css_parts.append("    </style>")
    lines.extend(css_parts)

    # --- background ---
    lines.append(f'  <rect width="{WIDTH}" height="{height}" rx="8" fill="#0d1117"/>')

    # --- header bar ---
    lines.append(f'  <rect width="{WIDTH}" height="38" rx="8" fill="#161b22"/>')
    lines.append(f'  <rect y="30" width="{WIDTH}" height="8" fill="#161b22"/>')

    # --- traffic lights ---
    for cx, color in ((20, "#ff5f56"), (40, "#ffbd2e"), (60, "#27c93f")):
        lines.append(f'  <circle cx="{cx}" cy="19" r="6" fill="{color}"/>')

    # --- header title ---
    lines.append(
        f'  <text x="{WIDTH // 2}" y="24" text-anchor="middle" '
        f'font-family="{FONT}" font-size="13" fill="#8b949e">{e(HEADER_TITLE)}</text>'
    )

    # --- terminal lines ---
    for i, (t, text, color, size) in enumerate(FRAMES):
        y = TOP + i * LINE_HEIGHT
        weight = 700 if i == n - 1 else 400
        lines.append(
            f'  <text x="20" y="{y}" class="l{i}" '
            f'font-family="{FONT}" font-size="{size}" '
            f'font-weight="{weight}" fill="{color}">{e(text)}</text>'
        )

    lines.append("</svg>")
    return "\n".join(lines)


def main() -> None:
    svg = generate_svg()
    out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "demo.svg")
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(svg)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
