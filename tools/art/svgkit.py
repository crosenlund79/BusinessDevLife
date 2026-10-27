"""Tiny SVG authoring kit for the illustrated-diorama art.

Every printed piece shares one look:
  * warm dark ink outline (INK) with round joins
  * flat base colour + one cel-shade tone + small highlights
  * a die-cut white paper border and a cardboard-edge "thickness" lip
  * a faint paper grain
The die-cut / thickness / grain are SVG filters, so the source art stays clean.
"""

INK = "#2b2230"
PAPER = "#fffaf0"
CARD_EDGE = "#c99b6b"
CARD_EDGE_DARK = "#a77b52"
STROKE = 7


def filters(cut=9, lip=(3, 6), grain=True, fid="card"):
    """A die-cut card filter. `cut` = white border width, `lip` = cardboard thickness offset."""
    gx, gy = lip
    grain_nodes = ""
    grain_merge = ""
    if grain:
        grain_nodes = f"""
      <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="7" result="noise"/>
      <feColorMatrix in="noise" type="matrix" values="0 0 0 0 0.32  0 0 0 0 0.24  0 0 0 0 0.16  0.16 0 0 0 0" result="grainc"/>
      <feComposite in="grainc" in2="paperAlpha" operator="in" result="grain"/>"""
        grain_merge = '<feMergeNode in="grain"/>'
    return f"""
  <filter id="{fid}" x="-20%" y="-20%" width="140%" height="140%" color-interpolation-filters="sRGB">
      <feMorphology in="SourceAlpha" operator="dilate" radius="{cut * 0.7:.1f}" result="d0"/>
      <feGaussianBlur in="d0" stdDeviation="{cut * 0.35:.1f}" result="d1"/>
      <feComponentTransfer in="d1" result="paperAlpha"><feFuncA type="linear" slope="6" intercept="-1.6"/></feComponentTransfer>
      <feFlood flood-color="{PAPER}"/><feComposite in2="paperAlpha" operator="in" result="paper"/>
      <feOffset in="paperAlpha" dx="{gx}" dy="{gy}" result="lipA"/>
      <feFlood flood-color="{CARD_EDGE}"/><feComposite in2="lipA" operator="in" result="lip"/>
      <feOffset in="paperAlpha" dx="{gx * 0.45:.1f}" dy="{gy * 0.45:.1f}" result="lipB"/>
      <feFlood flood-color="{CARD_EDGE_DARK}"/><feComposite in2="lipB" operator="in" result="lipLine"/>
      <feMerge result="card"><feMergeNode in="lip"/><feMergeNode in="lipLine"/><feMergeNode in="paper"/><feMergeNode in="SourceGraphic"/></feMerge>{grain_nodes}
      <feMerge><feMergeNode in="card"/>{grain_merge}</feMerge>
  </filter>"""


def doc(w, h, body, defs="", filt=True, cut=9, lip=(3, 6), grain=True):
    f = filters(cut, lip, grain) if filt else ""
    group_open = '<g filter="url(#card)">' if filt else "<g>"
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs>{f}{defs}</defs>
{group_open}
{body}
</g>
</svg>"""


def p(d, fill, stroke=INK, sw=STROKE, extra=""):
    s = f'stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"' if stroke else ""
    return f'<path d="{d}" fill="{fill}" {s} {extra}/>'


def shade(d, fill, clip=None, opacity=1.0):
    c = f'clip-path="url(#{clip})"' if clip else ""
    return f'<path d="{d}" fill="{fill}" opacity="{opacity}" {c}/>'


def ell(cx, cy, rx, ry, fill, stroke=INK, sw=STROKE, extra=""):
    s = f'stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}" {s} {extra}/>'


def circ(cx, cy, r, fill, stroke=INK, sw=STROKE, extra=""):
    return ell(cx, cy, r, r, fill, stroke, sw, extra)


def line(d, stroke=INK, sw=STROKE, extra=""):
    return f'<path d="{d}" fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'


def rect(x, y, w, h, rx, fill, stroke=INK, sw=STROKE, extra=""):
    s = f'stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" {s} {extra}/>'


def clip(cid, d):
    return f'<clipPath id="{cid}"><path d="{d}"/></clipPath>'


def text(x, y, s, size, fill=INK, weight=900, anchor="middle", family="Fredoka, Nunito Sans, sans-serif", extra=""):
    return f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" {extra}>{s}</text>'
