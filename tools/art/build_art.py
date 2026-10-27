#!/usr/bin/env python3
"""Builds every illustrated sprite for the diorama.

  python3 tools/art/build_art.py            # all
  python3 tools/art/build_art.py chars      # characters only
  python3 tools/art/build_art.py props      # props/effects only

SVG sources are generated into tools/art/out/ (not committed), rendered with
Chromium (tools/art/render.js) and cropped into art/sprites/ with a parts.json
manifest that the Godot puppet rig reads.
"""
import json
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_SRC = os.path.join(HERE, "out")
SPRITES = os.path.join(ROOT, "art", "sprites")
sys.path.insert(0, HERE)

import svgkit  # noqa: E402
from characters import CHARACTERS, W, H  # noqa: E402

CHAR_SCALE = 0.75   # 1024px canvas -> 768px textures (about 3x on-screen size, mipmapped)


def font_css():
    fonts = os.path.join(ROOT, "fonts")
    css = ""
    for fam, f, w in (("Fredoka", "Fredoka-700.woff2", 700), ("Fredoka", "Fredoka-600.woff2", 600),
                      ("Nunito Sans", "NunitoSans-800.woff2", 800), ("Nunito Sans", "NunitoSans-900.woff2", 900)):
        css += f"@font-face{{font-family:'{fam}';src:url('file://{os.path.join(fonts, f)}');font-weight:{w};}}"
    return css


def render(jobs):
    jf = os.path.join(OUT_SRC, "jobs.json")
    with open(jf, "w") as fh:
        json.dump(jobs, fh)
    subprocess.run(["node", os.path.join(HERE, "render.js"), jf], check=True, cwd=HERE)


def crop(png, pad=2):
    im = Image.open(png).convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        return None
    x0, y0, x1, y1 = bbox
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(im.width, x1 + pad), min(im.height, y1 + pad)
    im.crop((x0, y0, x1, y1)).save(png, optimize=True)
    return x0, y0, x1 - x0, y1 - y0


def build_characters():
    jobs, meta = [], {}
    for name, fn in CHARACTERS.items():
        spec = fn()
        src_dir = os.path.join(OUT_SRC, name)
        dst_dir = os.path.join(SPRITES, "characters", name)
        os.makedirs(src_dir, exist_ok=True)
        os.makedirs(dst_dir, exist_ok=True)
        parts = {}
        for part in ("body_stand", "body_walk", "head"):
            parts[part] = svgkit.doc(W, H, spec[part], cut=10, lip=(4, 7))
        for part in ("arm_l", "arm_r"):
            parts[part] = svgkit.doc(W, H, spec[part], cut=6, lip=(2, 5))
        for part, body in spec["face"].items():
            parts[part] = svgkit.doc(W, H, body, filt=False)
        meta[name] = {"rig": spec["rig"], "parts": list(parts.keys())}
        for part, svg in parts.items():
            sp = os.path.join(src_dir, part + ".svg")
            with open(sp, "w") as fh:
                fh.write(svg)
            jobs.append({"svg": sp, "png": os.path.join(dst_dir, part + ".png"), "w": W, "h": H, "scale": CHAR_SCALE})
    render(jobs)
    for name in CHARACTERS:
        dst_dir = os.path.join(SPRITES, "characters", name)
        manifest = {"canvas": [W, H], "scale": CHAR_SCALE, "rig": meta[name]["rig"], "parts": {}}
        for part in meta[name]["parts"]:
            png = os.path.join(dst_dir, part + ".png")
            box = crop(png)
            if box is None:
                os.remove(png)
                continue
            x, y, w, h = box
            # store in canvas units (unscaled) so the rig is resolution independent
            manifest["parts"][part] = [round(x / CHAR_SCALE, 2), round(y / CHAR_SCALE, 2), round(w / CHAR_SCALE, 2), round(h / CHAR_SCALE, 2)]
        with open(os.path.join(dst_dir, "parts.json"), "w") as fh:
            json.dump(manifest, fh, indent=1)
        print("character", name, len(manifest["parts"]), "parts")


def build_props():
    from props import PROPS  # noqa: E402
    jobs, names = [], []
    src_dir = os.path.join(OUT_SRC, "props")
    os.makedirs(src_dir, exist_ok=True)
    for group, items in PROPS.items():
        dst_dir = os.path.join(SPRITES, group)
        os.makedirs(dst_dir, exist_ok=True)
        for name, (w, h, svg, scale) in items.items():
            sp = os.path.join(src_dir, f"{group}_{name}.svg")
            with open(sp, "w") as fh:
                fh.write(svg)
            png = os.path.join(dst_dir, name + ".png")
            jobs.append({"svg": sp, "png": png, "w": w, "h": h, "scale": scale, "fonts": font_css()})
            if group != "surfaces":   # tiles must keep their exact size to repeat seamlessly
                names.append(png)
    render(jobs)
    for png in names:
        crop(png, pad=2)
    print("props", len(names))


def preview(expr=("eyes_open", "brows_neutral", "mouth_smile")):
    """Composite each puppet like the Godot rig does, for visual review."""
    out = Image.new("RGBA", (int(W * CHAR_SCALE) * len(CHARACTERS), int(H * CHAR_SCALE)), (243, 230, 210, 255))
    for i, name in enumerate(CHARACTERS):
        d = os.path.join(SPRITES, "characters", name)
        man = json.load(open(os.path.join(d, "parts.json")))
        order = ["arm_r", "body_stand", "head", *expr, "front", "arm_l"]
        for part in order:
            if part not in man["parts"]:
                continue
            x, y, _, _ = man["parts"][part]
            im = Image.open(os.path.join(d, part + ".png"))
            out.alpha_composite(im, (int(i * W * CHAR_SCALE + x * CHAR_SCALE), int(y * CHAR_SCALE)))
    path = os.path.join(OUT_SRC, "preview_" + "_".join(expr) + ".png")
    out.save(path)
    return path


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    os.makedirs(OUT_SRC, exist_ok=True)
    if what in ("all", "chars"):
        build_characters()
        print(preview())
    if what in ("all", "props"):
        build_props()
