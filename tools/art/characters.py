"""Cardboard paper-puppet characters for Business as Usual.

Each character is drawn on a 512 x 1024 canvas (feet at y=1000) and split into
puppet parts so Godot can animate them cheaply:
  body_stand, body_walk, arm_l, arm_r, head      -> printed card pieces (die-cut)
  eyes_*, brows_*, mouth_*, front                -> face overlays (no border)
"""
import re

from svgkit import INK, p, shade, ell, circ, line, rect, clip

W, H = 512, 1024
MOUTH_DARK = "#5a1f24"
TONGUE = "#e9767a"
WHITE = "#ffffff"


def mirror(d, cx=256):
    """Mirror an absolute-coordinate path (M/L/C/Q/Z only) around x=cx."""
    out = []
    tokens = re.findall(r"[MLCQZ]|-?\d+(?:\.\d+)?", d)
    is_x = True
    for t in tokens:
        if t in "MLCQZ":
            out.append(t)
            is_x = True
            continue
        v = float(t)
        if is_x:
            v = 2 * cx - v
        out.append(f"{v:g}")
        is_x = not is_x
    return " ".join(out)


# ---------------------------------------------------------------- face overlays

def face_parts(c):
    """Builds the eyes / brows / mouth overlay variants from a face spec."""
    (lx, ly), (rx, ry) = c["eyes"]
    ew, eh = c.get("eye_size", (19, 24))
    pupil = c.get("pupil", "#2a1d18")
    skin = c["skin"]
    brow = c["brow"]
    bw = c.get("brow_w", 11)
    by = c["brow_y"]
    mx, my = c["mouth"]
    mw = c.get("mouth_w", 30)
    parts = {}

    def eye_open(cx, cy, look=(3, 3), scale=1.0, pr=11):
        w, h = ew * scale, eh * scale
        return (ell(cx, cy, w, h, WHITE, sw=5)
                + circ(cx + look[0], cy + look[1], pr * min(scale, 1.15), pupil, stroke=None)
                + circ(cx + look[0] + 4, cy + look[1] - 5, 4, WHITE, stroke=None))

    parts["eyes_open"] = eye_open(lx, ly) + eye_open(rx, ry, (-2, 3))
    parts["eyes_side"] = eye_open(lx, ly, (7, 2)) + eye_open(rx, ry, (7, 2))
    parts["eyes_wide"] = eye_open(lx, ly, (0, 0), 1.22, 7) + eye_open(rx, ry, (0, 0), 1.22, 7)
    parts["eyes_blink"] = (line(f"M{lx - ew},{ly + 4} Q{lx},{ly + 14} {lx + ew},{ly + 4}", sw=6)
                           + line(f"M{rx - ew},{ry + 4} Q{rx},{ry + 14} {rx + ew},{ry + 4}", sw=6))
    parts["eyes_happy"] = (line(f"M{lx - ew},{ly + 8} Q{lx},{ly - 14} {lx + ew},{ly + 8}", sw=7)
                           + line(f"M{rx - ew},{ry + 8} Q{rx},{ry - 14} {rx + ew},{ry + 8}", sw=7))

    def lid(cx, cy):
        return (p(f"M{cx - ew - 3},{cy - 1} C{cx - ew - 3},{cy - eh - 12} {cx + ew + 3},{cy - eh - 12} {cx + ew + 3},{cy - 1} Z",
                  skin, sw=0, stroke=None)
                + line(f"M{cx - ew - 2},{cy - 1} L{cx + ew + 2},{cy - 1}", sw=6))
    parts["eyes_half"] = parts["eyes_open"] + lid(lx, ly) + lid(rx, ry)

    def brow_pair(l_in, l_out, r_in, r_out, arch=8, dy=0):
        # in = end nearest the nose; positive values move that end down
        a = line(f"M{lx - 24},{by + l_out + dy} Q{lx},{by - arch + dy + (l_in + l_out) / 2} {lx + 24},{by + l_in + dy}", stroke=brow, sw=bw)
        b = line(f"M{rx - 24},{by + r_in + dy} Q{rx},{by - arch + dy + (r_in + r_out) / 2} {rx + 24},{by + r_out + dy}", stroke=brow, sw=bw)
        return a + b
    parts["brows_neutral"] = brow_pair(0, 2, 0, 2)
    parts["brows_up"] = brow_pair(0, 0, 0, 0, 12, -14)
    parts["brows_angry"] = brow_pair(12, -8, 12, -8, 2)
    parts["brows_worried"] = brow_pair(-12, 6, -12, 6, 4)
    parts["brows_smug"] = brow_pair(2, 4, -6, -16, 14)

    def mouth_shape(top_y, bottom_y, half_w, teeth=True, tongue=True):
        d = f"M{mx - half_w},{top_y} Q{mx},{top_y + 6} {mx + half_w},{top_y} Q{mx + half_w - 4},{bottom_y} {mx},{bottom_y} Q{mx - half_w + 4},{bottom_y} {mx - half_w},{top_y} Z"
        cid = f"m_{c['name']}_{int(top_y)}_{int(bottom_y)}_{int(half_w)}"
        s = f"<defs>{clip(cid, d)}</defs>" + p(d, MOUTH_DARK, sw=5)
        if teeth:
            s += shade(f"M{mx - half_w},{top_y - 4} L{mx + half_w},{top_y - 4} L{mx + half_w},{top_y + 9} L{mx - half_w},{top_y + 9} Z", WHITE, cid)
        if tongue:
            s += shade(f"M{mx - half_w * 0.6},{bottom_y + 2} Q{mx},{bottom_y - 18} {mx + half_w * 0.6},{bottom_y + 2} Z", TONGUE, cid)
        return s + p(d, "none", sw=5)

    parts["mouth_smile"] = line(f"M{mx - mw},{my - 6} Q{mx},{my + 16} {mx + mw},{my - 6}", sw=6)
    parts["mouth_grin"] = mouth_shape(my - 10, my + 30, mw + 4)
    parts["mouth_talk"] = mouth_shape(my - 4, my + 18, mw * 0.62, teeth=True)
    parts["mouth_flat"] = line(f"M{mx - mw * 0.7},{my + 4} L{mx + mw * 0.7},{my + 2}", sw=6)
    parts["mouth_frown"] = line(f"M{mx - mw * 0.85},{my + 12} Q{mx},{my - 8} {mx + mw * 0.85},{my + 12}", sw=6)
    parts["mouth_shock"] = (ell(mx, my + 10, mw * 0.45, mw * 0.62, MOUTH_DARK, sw=5)
                            + ell(mx, my + 20, mw * 0.3, mw * 0.18, TONGUE, stroke=None))
    parts["mouth_smirk"] = line(f"M{mx - mw * 0.7},{my + 6} Q{mx + 8},{my + 12} {mx + mw},{my - 10}", sw=6)
    parts["mouth_wobble"] = line(f"M{mx - mw * 0.8},{my + 6} L{mx - mw * 0.4},{my} L{mx},{my + 6} L{mx + mw * 0.4},{my} L{mx + mw * 0.8},{my + 6}", sw=5)
    return parts


# ---------------------------------------------------------------- ALEX
def alex():
    skin, skin_s, nose = "#f4c7a1", "#e2a47e", "#f2b493"
    hair, hair_s, hair_h = "#8b4a25", "#68331a", "#b9703f"
    shirt, shirt_s = "#fbfaf6", "#d6dee9"
    trou, trou_s = "#3d4e6b", "#2c3a53"
    shoe, shoe_s = "#5a3a2a", "#3f281c"
    lan = "#2b6fd1"

    def body(walk):
        if walk:
            legs = "M176,585 L336,585 C342,690 354,820 374,958 L316,968 C302,860 284,762 260,700 C244,768 220,860 196,968 L138,958 C158,840 172,700 176,585 Z"
            legs_s = "M300,600 L336,600 C342,690 354,820 374,958 L346,962 C330,840 312,720 300,600 Z"
            shoes = (p("M126,1000 C120,978 140,958 168,960 L202,964 C208,978 206,994 198,1000 Z", shoe)
                     + p("M386,1000 C392,978 372,958 344,960 L310,964 C304,978 306,994 314,1000 Z", shoe))
        else:
            legs = "M176,585 L336,585 C340,700 338,840 334,968 L276,968 C272,860 266,760 258,690 C250,760 242,860 238,968 L180,968 C176,840 172,700 176,585 Z"
            legs_s = "M300,600 L336,600 C340,700 338,840 334,968 L306,968 C310,850 308,720 300,600 Z"
            shoes = (p("M166,1000 C160,980 176,962 204,962 L238,962 C246,975 246,992 238,1000 Z", shoe)
                     + p("M346,1000 C352,980 336,962 308,962 L274,962 C266,975 266,992 274,1000 Z", shoe))
        torso = "M222,318 C200,322 168,330 152,350 C140,365 150,420 160,470 C166,520 170,560 172,592 L340,592 C342,560 346,520 352,470 C362,420 372,365 360,350 C344,330 312,322 290,318 Z"
        s = "<defs>" + clip("al_legs", legs) + clip("al_torso", torso) + "</defs>"
        s += shoes
        s += p(legs, trou) + shade(legs_s, trou_s, "al_legs") + p(legs, "none")
        s += line("M208,640 L206,930", stroke="#2c3a53", sw=3, extra='opacity="0.6"')
        s += p("M232,288 L280,288 L282,330 C268,342 244,342 230,330 Z", skin)
        s += shade("M228,286 L284,286 L284,312 C266,320 246,320 228,312 Z", skin_s)
        s += p(torso, shirt) + shade("M318,330 C345,338 362,350 362,360 C370,420 354,500 344,595 L312,595 C320,520 328,420 318,330 Z", shirt_s, "al_torso") + p(torso, "none")
        s += line("M256,352 L256,578", stroke="#c9d2de", sw=4)
        for y in (390, 440, 490, 540):
            s += circ(256, y, 4.5, "#c9d2de", stroke=None)
        s += line("M286,402 L322,400 L320,434 L290,436 Z", sw=4)
        s += line("M190,560 C210,572 230,566 240,580", sw=3, extra='opacity="0.35"')
        s += p("M226,316 L256,354 L232,366 L210,330 Z", shirt) + p("M286,316 L256,354 L280,366 L302,330 Z", shirt)
        s += p("M172,578 L340,578 L340,606 L172,606 Z", "#4a3426") + rect(242, 580, 28, 24, 4, "#e4bd5f", sw=4)
        # lanyard + VISITOR badge (the joke continues)
        s += line("M234,330 L250,452", stroke=lan, sw=9) + line("M278,330 L262,452", stroke=lan, sw=9)
        s += rect(230, 448, 52, 66, 7, WHITE, sw=5) + rect(232, 450, 48, 16, 5, lan, stroke=None)
        s += line("M240,482 L272,482", sw=3) + line("M240,496 L264,496", sw=3)
        return s

    def arm(side):
        sleeve = "M190,346 C162,342 140,356 134,390 C128,422 126,448 128,470 L182,474 C186,438 194,398 190,346 Z"
        sleeve_s = "M190,346 C172,346 156,360 150,392 C144,424 142,450 144,472 L128,470 C126,448 128,422 134,390 C140,356 162,342 190,346 Z"
        cuff = "M122,462 C140,470 168,474 188,470 L186,494 C166,498 140,494 122,486 Z"
        fore = "M132,490 L180,494 C182,530 178,564 172,594 L142,592 C136,560 132,524 132,490 Z"
        hand = "M136,586 C120,596 120,628 136,640 C150,650 172,646 178,630 C184,614 180,598 172,588 Z"
        thumb = "M174,596 C190,598 192,616 180,624"
        parts = [(sleeve, shirt), (sleeve_s, shirt_s, True), (cuff, shirt_s), (fore, skin), (hand, skin)]
        s = ""
        for item in parts:
            d = item[0] if side == "l" else mirror(item[0])
            if len(item) == 3:
                s += shade(d, item[1])
            else:
                s += p(d, item[1])
        t = thumb if side == "l" else mirror(thumb)
        s += line(t, sw=5)
        return s

    def head():
        face = "M256,302 C204,302 164,266 162,206 C160,140 198,100 256,100 C314,100 352,140 350,206 C348,266 308,302 256,302 Z"
        hair_d = "M156,214 C146,160 156,112 196,84 C214,60 250,50 282,56 C326,62 360,96 362,150 C364,180 360,200 354,214 C348,184 340,164 326,152 C318,168 300,174 284,160 C276,176 252,180 240,164 C226,178 204,178 194,160 C180,172 168,190 164,214 Z"
        s = "<defs>" + clip("al_face", face) + clip("al_hair", hair_d) + "</defs>"
        s += ell(158, 210, 17, 26, skin) + ell(354, 210, 17, 26, skin)
        s += ell(158, 212, 7, 12, skin_s, stroke=None) + ell(354, 212, 7, 12, skin_s, stroke=None)
        s += p(face, skin)
        s += shade("M330,130 C356,160 356,252 318,290 C302,300 288,304 278,304 C318,270 338,222 330,130 Z", skin_s, "al_face")
        s += p(face, "none")
        s += ell(204, 246, 20, 12, "#f39a8c", stroke=None, extra='opacity="0.55"')
        s += ell(314, 246, 20, 12, "#f39a8c", stroke=None, extra='opacity="0.55"')
        s += p("M244,234 C242,214 256,202 270,206 C286,210 292,228 284,240 C276,250 248,252 244,234 Z", nose, sw=6)
        s += circ(262, 218, 5, WHITE, stroke=None, extra='opacity="0.75"')
        # hair
        for tuft in ("M198,90 C192,58 214,36 240,42 C228,54 224,70 226,84 Z",
                     "M244,60 C250,30 280,22 302,36 C286,42 272,52 268,64 Z",
                     "M300,66 C320,46 348,48 360,68 C342,68 328,74 320,84 Z"):
            s += p(tuft, hair)
        s += p(hair_d, hair)
        s += shade("M300,96 C340,106 364,140 360,196 C352,176 340,162 326,152 C318,168 300,174 284,160 C292,140 300,120 300,96 Z", hair_s, "al_hair")
        s += line("M206,100 C222,84 244,78 262,80", stroke=hair_h, sw=7)
        s += line("M286,84 C300,82 316,88 326,98", stroke=hair_h, sw=6)
        s += p(hair_d, "none")
        return s

    face = dict(name="alex", skin=skin, eyes=((220, 198), (294, 198)), brow="#5a2c15", brow_y=162,
                mouth=(260, 268), mouth_w=28)
    return {
        "body_stand": body(False), "body_walk": body(True),
        "arm_l": arm("l"), "arm_r": arm("r"), "head": head(),
        "face": face_parts(face),
        "rig": {"shoulder_l": [160, 360], "shoulder_r": [352, 360], "neck": [256, 300], "height": 1.0},
    }


# ---------------------------------------------------------------- MAGGIE
def maggie():
    skin, skin_s, nose = "#f6d2b6", "#e7b190", "#f3bba0"
    hair, hair_s, hair_h = "#c4683a", "#9a4a22", "#e3925d"
    card, card_s = "#f2b134", "#d48f22"
    blouse = "#fff3df"
    skirt, skirt_s = "#4e6a8f", "#3b5274"
    tights = "#b78678"
    shoe = "#d2453a"

    def body(walk):
        if walk:
            legs = [("M214,812 L246,812 C240,860 222,920 200,968 L172,962 C188,912 204,860 214,812 Z", tights),
                    ("M268,812 L300,812 C312,860 330,912 344,962 L316,968 C296,920 278,860 268,812 Z", tights)]
            shoes = (p("M160,1000 C152,982 166,962 190,962 L208,966 C214,980 212,994 206,1000 Z", shoe)
                     + p("M352,1000 C360,982 346,962 322,962 L304,966 C298,980 300,994 306,1000 Z", shoe))
        else:
            legs = [("M212,812 L246,812 L242,968 L214,968 Z", tights), ("M266,812 L300,812 L298,968 L270,968 Z", tights)]
            shoes = (p("M198,1000 C190,982 202,962 226,962 L246,964 C252,978 250,994 244,1000 Z", shoe)
                     + p("M314,1000 C322,982 310,962 286,962 L266,964 C260,978 262,994 268,1000 Z", shoe))
        sk = "M168,640 L344,640 C354,710 362,770 368,830 C320,850 192,850 144,830 C150,770 158,710 168,640 Z"
        torso = "M210,432 C176,438 146,450 136,476 C128,520 138,600 150,702 L362,702 C374,600 384,520 376,476 C366,450 336,438 302,432 Z"
        s = "<defs>" + clip("mg_sk", sk) + clip("mg_t", torso) + "</defs>"
        s += shoes
        for d, f in legs:
            s += p(d, f)
        s += p(sk, skirt) + shade("M300,640 L344,640 C354,710 362,770 368,830 C350,836 330,840 316,842 C318,780 312,700 300,640 Z", skirt_s, "mg_sk") + p(sk, "none")
        s += line("M220,700 L212,836", stroke=skirt_s, sw=4) + line("M290,700 L298,836", stroke=skirt_s, sw=4)
        s += p("M236,410 L276,410 L278,440 C266,450 246,450 234,440 Z", skin)
        s += p(torso, card) + shade("M318,440 C350,446 372,458 378,480 C384,540 374,620 362,702 L330,702 C338,610 340,520 318,440 Z", card_s, "mg_t") + p(torso, "none")
        s += p("M222,434 L290,434 L278,566 L256,606 L234,566 Z", blouse)
        s += line("M234,566 L240,702", sw=5) + line("M278,566 L272,702", sw=5)
        for y in (600, 640, 680):
            s += circ(250, y, 6, "#fff3df", sw=4)
        # cardigan knit texture
        for x in range(160, 360, 22):
            s += line(f"M{x},690 L{x},700", stroke=card_s, sw=3)
        # pearls
        for i in range(9):
            t = i / 8.0
            x = 230 + 52 * t
            y = 448 + 26 * (1 - (2 * t - 1) ** 2)
            s += circ(x, y, 6.5, "#fffaf2", sw=3)
        return s

    def arm(side):
        sleeve = "M180,452 C146,446 122,470 116,512 C110,550 110,590 114,630 L166,636 C168,590 174,548 178,500 Z"
        sleeve_s = "M180,452 C160,452 140,474 134,514 C128,552 128,592 130,632 L114,630 C110,590 110,550 116,512 C122,470 146,446 180,452 Z"
        cuff = "M108,624 C126,632 150,636 170,634 L168,658 C148,662 124,658 106,650 Z"
        hand = "M116,650 C102,662 104,692 122,702 C138,710 160,704 164,688 C168,672 164,658 156,652 Z"
        s = ""
        for d, f, sh in ((sleeve, card, False), (sleeve_s, card_s, True), (cuff, card_s, False), (hand, skin, False)):
            dd = d if side == "l" else mirror(d)
            s += shade(dd, f) if sh else p(dd, f)
        return s

    def head():
        face = "M256,420 C206,420 172,388 170,334 C168,276 206,240 256,240 C306,240 344,276 342,334 C340,388 306,420 256,420 Z"
        back = "M146,352 C136,268 180,206 256,204 C332,206 376,268 366,352 C364,388 354,410 340,420 C330,404 316,396 300,394 L212,394 C196,396 182,404 172,420 C158,410 148,388 146,352 Z"
        fringe = "M166,324 C168,262 208,222 256,222 C304,222 344,262 346,324 C330,296 310,276 288,270 C268,290 232,292 210,278 C192,288 178,302 166,324 Z"
        s = "<defs>" + clip("mg_face", face) + clip("mg_back", back) + "</defs>"
        s += p(back, hair) + shade("M300,214 C346,232 372,290 364,360 C362,390 352,412 340,420 C334,380 340,300 300,214 Z", hair_s, "mg_back") + p(back, "none")
        s += p(face, skin) + shade("M322,280 C344,300 346,360 320,398 C306,412 290,420 276,420 C312,388 330,340 322,280 Z", skin_s, "mg_face") + p(face, "none")
        s += ell(206, 368, 22, 13, "#f39a8c", stroke=None, extra='opacity="0.6"')
        s += ell(306, 368, 22, 13, "#f39a8c", stroke=None, extra='opacity="0.6"')
        s += p("M244,356 C242,338 254,328 266,332 C280,336 284,350 278,360 C270,368 248,370 244,356 Z", nose, sw=6)
        s += circ(260, 342, 4.5, WHITE, stroke=None, extra='opacity="0.75"')
        s += p(fringe, hair) + line("M206,252 C222,240 244,234 262,236", stroke=hair_h, sw=7)
        s += circ(162, 404, 7, "#f2c14e", sw=3) + circ(350, 404, 7, "#f2c14e", sw=3)
        return s

    face = dict(name="maggie", skin=skin, eyes=((222, 324), (290, 324)), eye_size=(17, 21), brow="#8a3c1c",
                brow_y=290, mouth=(256, 388), mouth_w=26, pupil="#2a3a26")
    fp = face_parts(face)
    # glasses sit above the eyes (front overlay)
    glasses = ""
    for cx in (222, 290):
        glasses += rect(cx - 30, 300, 60, 48, 18, "rgba(255,255,255,0.18)", stroke="#c0392b", sw=7)
    glasses += line("M252,320 Q256,314 260,320", stroke="#c0392b", sw=6)
    fp["front"] = glasses
    return {
        "body_stand": body(False), "body_walk": body(True),
        "arm_l": arm("l"), "arm_r": arm("r"), "head": head(), "face": fp,
        "rig": {"shoulder_l": [150, 470], "shoulder_r": [362, 470], "neck": [256, 420], "height": 0.86},
    }


# ---------------------------------------------------------------- CHAD
def chad():
    skin, skin_s, nose = "#f1c7a5", "#dba480", "#efb595"
    hair, hair_s, hair_h = "#e8c466", "#c69c3a", "#fbe7a0"
    suit, suit_s, lapel = "#22314f", "#17223a", "#2e4068"
    tie, tie_s = "#f2b134", "#d0901f"
    shoe = "#7a4322"

    def body(walk):
        if walk:
            legs = "M184,600 L328,600 C336,710 348,830 368,962 L312,970 C298,860 282,766 258,710 C238,770 218,860 200,970 L144,962 C162,830 178,710 184,600 Z"
            shoes = (p("M118,1000 C112,980 140,962 178,964 L206,966 C212,980 210,994 202,1000 Z", shoe)
                     + p("M394,1000 C400,980 372,962 334,964 L306,966 C300,980 302,994 310,1000 Z", shoe))
        else:
            legs = "M184,600 L328,600 C334,720 334,850 330,970 L276,970 C272,860 266,766 258,706 C250,766 244,860 238,970 L184,970 C180,850 180,720 184,600 Z"
            shoes = (p("M146,1000 C142,982 168,966 212,966 L238,966 C244,980 244,994 238,1000 Z", shoe)
                     + p("M366,1000 C370,982 344,966 300,966 L274,966 C268,980 268,994 274,1000 Z", shoe))
        torso = "M214,300 C176,306 130,318 122,350 C114,400 140,470 168,540 L172,642 L340,642 L344,540 C372,470 398,400 390,350 C382,318 336,306 298,300 Z"
        s = "<defs>" + clip("ch_t", torso) + clip("ch_l", legs) + "</defs>"
        s += shoes
        s += ell(196, 974, 10, 4, WHITE, stroke=None, extra='opacity="0.6"') + ell(318, 974, 10, 4, WHITE, stroke=None, extra='opacity="0.6"')
        s += p(legs, suit) + shade("M300,610 L330,610 C336,720 336,850 332,970 L306,970 C310,850 308,720 300,610 Z", suit_s, "ch_l") + p(legs, "none")
        s += line("M212,650 L212,950", stroke="#3a4a6c", sw=3) + line("M300,650 L302,950", stroke="#3a4a6c", sw=3)
        s += p("M228,268 L284,268 L286,306 C272,318 240,318 226,306 Z", skin)
        s += p(torso, suit) + shade("M330,316 C370,326 392,340 392,360 C398,420 372,480 344,544 L342,642 L318,642 C322,540 336,420 330,316 Z", suit_s, "ch_t") + p(torso, "none")
        s += p("M224,302 L288,302 L256,424 Z", WHITE)
        s += p("M244,306 L268,306 L264,322 L248,322 Z", tie) + p("M248,320 L264,320 L272,334 L262,446 L256,458 L250,446 L240,334 Z", tie)
        s += line("M252,350 L262,360 M250,384 L262,394 M250,418 L260,426", stroke=tie_s, sw=4)
        s += p("M224,302 L256,424 L234,476 L196,326 Z", lapel) + p(mirror("M224,302 L256,424 L234,476 L196,326 Z"), lapel)
        s += line("M256,424 L256,640", sw=4)
        s += circ(256, 500, 6, "#3a4a6c", sw=3) + circ(256, 560, 6, "#3a4a6c", sw=3)
        s += p("M318,380 L346,374 L342,394 L322,396 Z", tie)
        s += line("M200,606 L240,604", sw=3, extra='opacity="0.4"') + line("M280,604 L318,606", sw=3, extra='opacity="0.4"')
        return s

    def arm(side):
        sleeve = "M170,326 C134,320 110,340 104,384 C98,428 98,488 104,536 L156,542 C158,486 166,430 170,380 Z"
        sleeve_s = "M170,326 C148,326 128,346 122,388 C116,430 116,490 120,538 L104,536 C98,488 98,428 104,384 C110,340 134,320 170,326 Z"
        cuff = "M102,528 C120,536 140,540 158,538 L156,560 C138,562 118,558 100,552 Z"
        hand = "M106,550 C92,562 94,594 112,604 C128,612 150,606 154,590 C158,574 154,560 146,554 Z"
        s = ""
        for d, f, sh in ((sleeve, suit, False), (sleeve_s, suit_s, True), (cuff, WHITE, False), (hand, skin, False)):
            dd = d if side == "l" else mirror(d)
            s += shade(dd, f) if sh else p(dd, f)
        if side == "l":
            s += rect(106, 524, 46, 12, 4, "#f2c14e", sw=4)   # a watch that costs more than your car
        return s

    def head():
        face = "M256,286 C214,286 186,270 178,236 C170,206 170,130 196,104 C214,86 236,80 256,80 C276,80 298,86 316,104 C342,130 342,206 334,236 C326,270 298,286 256,286 Z"
        hair_d = "M174,172 C166,112 188,62 244,50 C286,40 332,52 348,92 C354,112 352,150 342,178 C334,142 320,122 298,116 C272,110 238,118 214,110 C200,126 184,148 174,172 Z"
        s = "<defs>" + clip("ch_face", face) + clip("ch_hair", hair_d) + "</defs>"
        s += ell(176, 186, 15, 24, skin) + ell(336, 186, 15, 24, skin)
        s += p(face, skin) + shade("M318,120 C344,150 344,226 330,246 C318,272 296,286 276,288 C312,256 330,200 318,120 Z", skin_s, "ch_face") + p(face, "none")
        s += line("M250,272 Q256,278 262,272", sw=4)
        s += p("M244,214 C242,190 256,180 268,186 C282,192 286,208 280,218 C272,228 248,230 244,214 Z", nose, sw=6)
        s += circ(260, 196, 4.5, WHITE, stroke=None, extra='opacity="0.75"')
        s += p("M194,92 C198,46 252,22 306,36 C276,42 256,56 250,76 C234,70 212,76 194,92 Z", hair)
        s += p(hair_d, hair) + shade("M300,60 C334,72 352,100 346,170 C336,140 320,122 298,116 C304,100 306,80 300,60 Z", hair_s, "ch_hair")
        s += line("M214,78 C240,64 272,60 300,66", stroke=hair_h, sw=6) + line("M210,98 C236,90 262,90 286,96", stroke=hair_h, sw=5)
        s += p(hair_d, "none")
        return s

    face = dict(name="chad", skin=skin, eyes=((222, 178), (290, 178)), eye_size=(18, 21), brow="#a5762a",
                brow_y=144, mouth=(258, 246), mouth_w=30, pupil="#1d3a66")
    return {
        "body_stand": body(False), "body_walk": body(True),
        "arm_l": arm("l"), "arm_r": arm("r"), "head": head(), "face": face_parts(face),
        "rig": {"shoulder_l": [138, 342], "shoulder_r": [374, 342], "neck": [256, 286], "height": 1.06},
    }


CHARACTERS = {"alex": alex, "maggie": maggie, "chad": chad}
