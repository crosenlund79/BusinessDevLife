"""Illustrated props, wall decals, surface tiles and comic FX for the diorama.

Scale convention: 400 canvas px = 1 world unit (metre-ish). Each entry is
(width, height, svg, render_scale). Printed pieces get the die-cut card
filter; surface tiles and FX don't.
"""
from svgkit import INK, doc, p, shade, ell, circ, line, rect, clip, text

WHITE = "#ffffff"
WOOD, WOOD_S, WOOD_H = "#d9a066", "#b9814c", "#ecbd86"
OAK, OAK_S = "#e8c18e", "#c99a63"
TEAL, TEAL_S, TEAL_H = "#5fb8ad", "#3f968c", "#8fd3c7"
NAVY = "#2b3a55"
CORAL = "#e8735d"
AMBER = "#f2b134"
CREAM = "#fbf3e3"
STEEL, STEEL_S = "#c7cfd8", "#9ea9b6"
LEAF, LEAF_S, LEAF_H = "#5fa65a", "#3f7f43", "#8cc970"
POT, POT_S = "#e07a4f", "#b85b37"


def card(w, h, body, scale=0.6, defs="", cut=9, lip=(3, 6)):
    return (w, h, doc(w, h, body, defs=defs, cut=cut, lip=lip), scale)


def flat(w, h, body, scale=1.0, defs=""):
    return (w, h, doc(w, h, body, defs=defs, filt=False), scale)


# ======================================================================= furniture

def desk():
    w, h = 720, 600
    top = "M40,300 L680,300 L700,350 L20,350 Z"
    s = "<defs>" + clip("dk_front", "M30,350 L690,350 L690,560 L30,560 Z") + "</defs>"
    # legs & body
    s += p("M44,350 L84,350 L84,586 L44,586 Z", OAK_S)
    s += p("M636,350 L676,350 L676,586 L636,586 Z", OAK_S)
    s += p("M420,350 L676,350 L676,520 L420,520 Z", OAK)                 # drawer pedestal
    for y in (382, 440):
        s += rect(436, y, 224, 46, 6, "#f2d3a6", sw=5) + rect(522, y + 18, 52, 10, 5, STEEL, sw=4)
    s += p("M84,350 L420,350 L420,400 L84,400 Z", OAK)                    # modesty panel
    s += p(top, OAK) + shade("M20,350 L700,350 L700,366 L20,366 Z", OAK_S) + p("M20,350 L700,350 L700,366 L20,366 Z", "none")
    s += line("M120,318 L360,318", stroke="#f5dcb5", sw=5)
    # monitor
    s += p("M268,270 L332,270 L344,306 L256,306 Z", "#3a3f4b")
    s += p("M286,226 L314,226 L316,274 L284,274 Z", "#4a505e")
    s += rect(150, 40, 300, 196, 18, "#2e3340")
    s += rect(166, 56, 268, 164, 8, "#7fd1ff", sw=4)
    s += rect(166, 56, 268, 24, 6, "#3d7be0", stroke=None)
    for i in range(5):
        s += rect(180, 92 + i * 24, 120 + (i * 37) % 100, 12, 6, "#ffffff", stroke=None, extra='opacity="0.85"')
        s += rect(330, 92 + i * 24, 80, 12, 6, ["#ffd36b", "#9be59b", "#ff9b8a", "#ffffff", "#ffd36b"][i], stroke=None)
    s += line("M176,210 L424,210", stroke="#ffffff", sw=3, extra='opacity="0.4"')
    # sticky notes on the bezel
    s += rect(420, 50, 46, 44, 3, "#ffe066", sw=4, extra='transform="rotate(8 443 72)"')
    s += rect(132, 150, 40, 40, 3, "#ff9ecb", sw=4, extra='transform="rotate(-10 152 170)"')
    # keyboard & mouse
    s += p("M196,314 L404,314 L414,334 L186,334 Z", "#eef0f3", sw=5)
    for x in range(204, 400, 22):
        s += line(f"M{x},322 L{x + 10},322", stroke="#b9c0ca", sw=4)
    s += ell(448, 326, 18, 10, "#eef0f3", sw=5)
    # mug: GOOD IDEAS (USUALLY)  -> a lightbulb doodle instead of text
    s += p("M520,232 L570,232 L566,306 C562,316 528,316 524,306 Z", WHITE)
    s += p("M570,250 C594,248 596,286 568,288", "none", sw=7)
    s += circ(545, 262, 13, "#ffe066", sw=4) + line("M540,278 L550,278", sw=4) + line("M545,240 L545,232", sw=0)
    s += line("M536,222 C532,210 540,204 536,192", stroke="#c9b9a6", sw=4) + line("M552,222 C548,208 558,202 552,188", stroke="#c9b9a6", sw=4)
    # paper stack
    for i in range(4):
        s += p(f"M{70 + i * 3},{300 - i * 10} L{170 + i * 3},{300 - i * 10} L{176 + i * 3},{312 - i * 10} L{64 + i * 3},{312 - i * 10} Z", CREAM if i % 2 else WHITE, sw=4)
    # rubber duck: Senior Solution Architect
    s += ell(628, 290, 34, 24, "#ffd23f") + circ(612, 256, 20, "#ffd23f")
    s += p("M590,256 L572,262 L590,268 Z", "#f28c28", sw=4) + circ(606, 250, 4, INK, stroke=None)
    s += line("M624,292 C640,284 650,290 652,280", stroke="#e0b11f", sw=4)
    return card(w, h, s, 0.6)


def chair():
    w, h = 320, 440
    s = ""
    s += line("M160,330 L160,392", sw=14)
    for d in ("M160,392 L70,420", "M160,392 L250,420", "M160,392 L120,430", "M160,392 L210,430"):
        s += line(d, sw=11)
    for x, y in ((70, 422), (250, 422), (118, 432), (212, 432)):
        s += circ(x, y, 10, "#3a3f4b", sw=4)
    s += p("M60,300 C60,282 80,276 160,276 C240,276 262,282 262,300 L262,330 C262,344 240,348 160,348 C80,348 58,344 60,330 Z", NAVY)
    s += p("M84,48 C84,24 112,14 160,14 C208,14 236,24 236,48 L230,250 C228,270 200,282 160,282 C120,282 92,270 90,250 Z", "#3d5378")
    s += shade("M190,20 C222,24 236,32 236,48 L230,250 C228,268 210,278 190,282 C204,230 206,120 190,20 Z", NAVY)
    s += p("M84,48 C84,24 112,14 160,14 C208,14 236,24 236,48 L230,250 C228,270 200,282 160,282 C120,282 92,270 90,250 Z", "none")
    s += line("M120,70 C140,62 180,62 200,70", stroke="#5a73a0", sw=6)
    return card(w, h, s, 0.6)


def bookshelf():
    w, h = 520, 860
    s = p("M30,20 L490,20 L490,840 L30,840 Z", WOOD)
    s += p("M58,46 L462,46 L462,812 L58,812 Z", "#a86f3f")
    cols = ["#e8735d", "#5fb8ad", "#f2b134", "#3d7be0", "#8a6cff", "#4f9d4a", "#e85d8a", "#2b3a55"]
    shelves = [190, 380, 570, 790]
    for i, y in enumerate(shelves):
        s += p(f"M58,{y} L462,{y} L462,{y + 22} L58,{y + 22} Z", WOOD_H)
    # binders, boxes and things on each shelf
    x = 70
    for k in range(9):
        bw = 34 + (k * 13) % 18
        hh = 120 + (k * 29) % 30
        c = cols[k % len(cols)]
        s += rect(x, 190 - hh, bw, hh, 4, c, sw=5) + rect(x + 6, 190 - hh + 14, bw - 12, 26, 3, WHITE, sw=3) + circ(x + bw / 2, 190 - 30, 6, WHITE, sw=3)
        x += bw + 4
    # shelf 2: archive boxes + trophy
    s += rect(72, 280, 120, 100, 6, "#d8b48a", sw=5) + rect(108, 300, 48, 22, 4, WHITE, sw=3)
    s += rect(196, 290, 110, 90, 6, "#cfa77a", sw=5) + rect(226, 308, 48, 20, 4, WHITE, sw=3)
    s += p("M370,300 C370,340 420,340 420,300 Z", AMBER) + p("M386,338 L404,338 L408,364 L382,364 Z", AMBER) + rect(370, 362, 50, 18, 3, NAVY, sw=4)
    s += line("M372,306 C352,304 352,326 374,326", sw=5) + line("M418,306 C438,304 438,326 416,326", sw=5)
    # shelf 3: leaning binders + small plant
    for k in range(5):
        c = cols[(k + 3) % len(cols)]
        s += rect(80 + k * 40, 430, 34, 140, 4, c, sw=5, extra=f'transform="rotate({-6 if k == 4 else 0} {97 + k * 40} 570)"')
    s += p("M360,520 L420,520 L414,570 L366,570 Z", POT)
    for d in ("M390,520 C372,480 350,476 340,470", "M390,520 C394,470 404,452 420,444", "M390,520 C410,494 432,490 446,494"):
        s += line(d, stroke=LEAF_S, sw=14) + line(d, stroke=LEAF, sw=8)
    # bottom: magazine files + a box labelled with a big question mark
    s += rect(80, 650, 150, 140, 8, "#e9dcc6", sw=5) + text(155, 744, "?", 80, fill=CORAL)
    s += rect(250, 690, 60, 100, 4, TEAL, sw=5) + rect(316, 680, 60, 110, 4, CORAL, sw=5) + rect(382, 700, 60, 90, 4, AMBER, sw=5)
    s += shade("M440,46 L462,46 L462,812 L440,812 Z", "#7d4f2a")
    return card(w, h, s, 0.55)


def plant_tall():
    w, h = 380, 660
    s = ""
    leaves = [
        ("M190,430 C150,360 70,350 40,300 C90,270 170,300 190,430 Z", -1),
        ("M190,420 C200,330 160,250 120,190 C190,190 230,300 190,420 Z", 0),
        ("M196,430 C240,350 320,330 350,270 C300,250 220,300 196,430 Z", 1),
        ("M194,410 C250,320 260,220 240,120 C300,170 290,320 194,410 Z", 1),
        ("M186,440 C120,420 60,440 30,420 C70,380 150,390 186,440 Z", -1),
        ("M200,440 C260,420 320,440 352,410 C310,372 240,384 200,440 Z", 1),
    ]
    for d, side in leaves:
        s += p(d, LEAF if side >= 0 else LEAF_S)
    for d in ("M190,430 C150,380 90,340 60,312", "M190,420 C190,330 160,250 130,200", "M196,430 C240,370 300,320 336,280",
              "M194,410 C240,330 254,230 244,140", "M186,440 C130,420 80,424 46,418", "M200,440 C250,420 300,420 340,412"):
        s += line(d, stroke=LEAF_H, sw=4)
    # monstera holes
    for x, y in ((110, 330), (300, 316), (226, 250), (160, 260)):
        s += ell(x, y, 9, 6, "#3f7f43", stroke=None)
    s += p("M96,440 L284,440 L262,640 L118,640 Z", POT) + shade("M232,440 L284,440 L262,640 L222,640 Z", POT_S) + p("M96,440 L284,440 L262,640 L118,640 Z", "none")
    s += p("M84,424 L296,424 L296,456 L84,456 Z", "#ec8f63")
    s += line("M120,500 C150,512 180,512 210,500", stroke="#f3a47e", sw=6)
    return card(w, h, s, 0.6)


def plant_small():
    w, h = 220, 300
    s = ""
    for d, c in (("M110,170 C96,110 98,60 112,20 C130,60 128,120 110,170 Z", LEAF),
                 ("M104,176 C70,130 50,90 46,48 C84,74 104,120 104,176 Z", LEAF_S),
                 ("M116,176 C150,130 170,96 178,56 C140,78 120,120 116,176 Z", LEAF),
                 ("M100,180 C70,160 40,150 22,126 C62,124 90,146 100,180 Z", LEAF_S)):
        s += p(d, c)
    s += line("M112,150 C110,110 110,70 112,36", stroke=LEAF_H, sw=4)
    s += p("M58,170 L162,170 L150,284 L70,284 Z", "#f4efe6") + shade("M126,170 L162,170 L150,284 L118,284 Z", "#e2d8c8") + p("M58,170 L162,170 L150,284 L70,284 Z", "none")
    s += line("M70,210 L150,210", stroke=TEAL, sw=8)
    return card(w, h, s, 0.6)


def coffee_counter():
    w, h = 820, 640
    s = "<defs>" + clip("cc_cab", "M30,330 L790,330 L790,620 L30,620 Z") + "</defs>"
    # cabinets
    s += p("M30,330 L790,330 L790,620 L30,620 Z", TEAL)
    for x in (40, 230, 420, 610):
        s += rect(x, 350, 176, 256, 10, TEAL_H, sw=5) + rect(x + 70, 470, 36, 10, 5, STEEL, sw=4)
    s += shade("M30,580 L790,580 L790,620 L30,620 Z", TEAL_S, "cc_cab")
    s += p("M14,304 L806,304 L806,336 L14,336 Z", "#f7f4ee")
    s += shade("M14,326 L806,326 L806,336 L14,336 Z", "#ddd6ca")
    s += p("M14,304 L806,304 L806,336 L14,336 Z", "none")
    # coffee machine (Wi-Fi enabled)
    s += rect(80, 90, 210, 216, 22, "#2e3340")
    s += rect(100, 110, 170, 60, 10, "#7fd1ff", sw=5)
    s += line("M118,130 L200,130", stroke=WHITE, sw=5) + line("M118,148 L176,148", stroke=WHITE, sw=5)
    s += circ(250, 140, 9, "#29d17d", sw=3)
    for a, r in ((0, 10), (1, 18), (2, 26)):
        s += line(f"M{236 + 0},{126 - r * 0.2} Q{250},{110 - r} {264},{126 - r * 0.2}", stroke="#29d17d", sw=4) if a else ""
    s += rect(150, 190, 70, 30, 8, "#4a505e", sw=5)
    s += p("M156,248 L214,248 L210,296 C206,304 164,304 160,296 Z", WHITE)
    s += line("M174,238 C170,226 178,220 174,208", stroke="#c9b9a6", sw=4)
    # mugs on a rack
    s += line("M330,140 L520,140", sw=6)
    for i, c in enumerate((CORAL, AMBER, WHITE, TEAL)):
        x = 344 + i * 46
        s += line(f"M{x + 14},140 L{x + 14},152", sw=4)
        s += p(f"M{x},156 L{x + 30},156 L{x + 28},192 C{x + 26},198 {x + 4},198 {x + 2},192 Z", c, sw=5)
    # kettle + fruit bowl
    s += p("M560,300 C548,240 560,200 610,196 C660,200 672,240 660,300 Z", STEEL) + shade("M626,198 C660,206 672,240 660,300 L632,300 C640,260 638,220 626,198 Z", STEEL_S)
    s += p("M560,300 C548,240 560,200 610,196 C660,200 672,240 660,300 Z", "none")
    s += p("M600,196 L620,196 L622,184 L598,184 Z", "#3a3f4b") + p("M560,240 C536,236 530,212 548,202", "none", sw=7)
    s += p("M690,300 C690,270 780,270 780,300 Z", CREAM)
    for x, c in ((708, AMBER), (734, "#e85d5d"), (760, "#7cc35a"), (722, AMBER)):
        s += circ(x, 280 if x != 722 else 266, 16, c, sw=4)
    return card(w, h, s, 0.55)


def cake_table():
    w, h = 440, 520
    s = ""
    s += line("M220,330 L220,480", sw=16) + p("M140,480 L300,480 L320,500 L120,500 Z", "#3a3f4b")
    s += p("M30,300 C30,270 410,270 410,300 C410,330 30,330 30,300 Z", OAK) + p("M30,300 L30,316 C30,346 410,346 410,316 L410,300", OAK_S)
    s += p("M30,300 C30,270 410,270 410,300 C410,330 30,330 30,300 Z", "none")
    # plates & forks
    for x in (90, 350):
        s += ell(x, 300, 40, 12, WHITE, sw=5) + ell(x, 298, 24, 6, "#f3efe8", stroke=None)
    s += line("M120,312 L150,318", stroke=STEEL_S, sw=5)
    # cake stand + lemon drizzle
    s += p("M200,290 L240,290 L236,260 L204,260 Z", WHITE)
    s += ell(220, 258, 96, 20, WHITE)
    s += p("M140,250 L300,250 L300,160 L140,160 Z", "#f5cf6b")
    s += ell(220, 250, 80, 14, "#f5cf6b") + shade("M262,160 L300,160 L300,250 L262,252 Z", "#e2b44c")
    s += p("M140,250 L300,250 L300,160 L140,160 Z", "none")
    s += ell(220, 160, 80, 18, "#fffaf0")
    for x in (150, 176, 204, 236, 262, 288):
        s += p(f"M{x - 8},164 C{x - 8},190 {x + 8},190 {x + 8},164 Z", "#fffaf0", sw=5)
    s += ell(220, 160, 80, 18, "none")
    s += line("M146,206 L294,206", stroke="#fff4c8", sw=6)
    for x, y in ((188, 152), (222, 146), (254, 154)):
        s += ell(x, y, 13, 6, "#ffe14d", sw=4)
    # the multi-purpose flag
    s += line("M222,146 L222,86", sw=5) + p("M222,86 L272,96 L222,108 Z", CORAL, sw=5)
    return card(w, h, s, 0.6)


def water_cooler():
    w, h = 220, 580
    s = p("M50,250 L170,250 L170,560 L50,560 Z", "#eef0f3") + shade("M140,250 L170,250 L170,560 L140,560 Z", "#d4d9e0")
    s += p("M50,250 L170,250 L170,560 L50,560 Z", "none")
    s += rect(84, 290, 52, 24, 6, "#3d7be0", sw=4) + rect(84, 330, 52, 24, 6, CORAL, sw=4)
    s += p("M64,250 C56,170 66,100 110,90 C154,100 164,170 156,250 Z", "#9fd6ff", extra='opacity="0.9"')
    s += p("M64,250 C56,170 66,100 110,90 C154,100 164,170 156,250 Z", "none")
    s += line("M84,140 C84,180 86,220 92,240", stroke=WHITE, sw=8, extra='opacity="0.8"')
    s += rect(94, 70, 32, 24, 4, "#3d7be0", sw=5)
    for y in (180, 210):
        s += circ(120, y, 6, WHITE, stroke=None, extra='opacity="0.8"')
    return card(w, h, s, 0.6)


def printer():
    w, h = 360, 320
    s = p("M30,120 L330,120 L330,290 L30,290 Z", "#eef0f3") + shade("M270,120 L330,120 L330,290 L270,290 Z", "#d4d9e0") + p("M30,120 L330,120 L330,290 L30,290 Z", "none")
    s += p("M60,70 L300,70 L320,120 L40,120 Z", "#dfe3e8")
    s += p("M90,20 L270,20 L280,70 L80,70 Z", WHITE)
    s += rect(220, 150, 90, 40, 8, "#2e3340") + circ(240, 170, 7, "#ff5a4a", stroke=None) + rect(256, 164, 40, 12, 4, "#7fd1ff", stroke=None)
    s += p("M70,230 L250,230 L262,262 L58,262 Z", WHITE)
    s += text(160, 255, "!", 30, fill=CORAL)
    return card(w, h, s, 0.6)


# ======================================================================= wall decals

def window():
    w, h = 1080, 780
    s = "<defs>" + clip("win_glass", "M70,70 L1010,70 L1010,660 L70,660 Z")
    s += """<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6fb2ef"/><stop offset="0.7" stop-color="#bfe2fb"/><stop offset="1" stop-color="#fbe6c8"/></linearGradient></defs>"""
    s += p("M30,30 L1050,30 L1050,700 L30,700 Z", CREAM)
    s += '<path d="M70,70 L1010,70 L1010,660 L70,660 Z" fill="url(#sky)"/>'
    # sun + clouds
    s += shade("M820,170 m-70,0 a70,70 0 1,0 140,0 a70,70 0 1,0 -140,0", "#fff2b8", "win_glass", 0.9)
    for cx, cy, sc in ((260, 170, 1.0), (620, 120, 0.8), (930, 280, 0.6)):
        s += shade(f"M{cx - 90 * sc},{cy} C{cx - 90 * sc},{cy - 40 * sc} {cx - 30 * sc},{cy - 50 * sc} {cx - 10 * sc},{cy - 30 * sc} C{cx + 10 * sc},{cy - 70 * sc} {cx + 80 * sc},{cy - 60 * sc} {cx + 80 * sc},{cy - 20 * sc} C{cx + 120 * sc},{cy - 20 * sc} {cx + 120 * sc},{cy + 20 * sc} {cx + 80 * sc},{cy + 20 * sc} L{cx - 70 * sc},{cy + 20 * sc} C{cx - 110 * sc},{cy + 20 * sc} {cx - 110 * sc},{cy} {cx - 90 * sc},{cy} Z", WHITE, "win_glass", 0.92)
    # far skyline
    far = [(70, 420), (130, 380), (180, 440), (250, 360), (320, 410), (380, 330), (450, 400), (520, 350), (600, 420), (660, 300), (730, 390), (800, 340), (870, 410), (930, 360), (1010, 400)]
    d = "M70,660 "
    for i, (x, y) in enumerate(far):
        nx = far[i + 1][0] if i + 1 < len(far) else 1010
        d += f"L{x},{y} L{nx},{y} "
    d += "L1010,660 Z"
    s += shade(d, "#9cc3e6", "win_glass")
    # near towers with windows
    towers = [(90, 470, 120), (230, 410, 100), (350, 500, 130), (500, 380, 110), (640, 450, 140), (800, 420, 110), (920, 480, 100)]
    for x, y, tw in towers:
        s += shade(f"M{x},{y} L{x + tw},{y} L{x + tw},660 L{x},660 Z", "#4f7fb8", "win_glass")
        s += shade(f"M{x + tw * 0.65},{y} L{x + tw},{y} L{x + tw},660 L{x + tw * 0.65},660 Z", "#41699b", "win_glass")
        for wy in range(y + 20, 650, 34):
            for wx in range(x + 14, x + tw - 18, 26):
                lit = ((wx * 7 + wy * 3) % 5) < 2
                s += shade(f"M{wx},{wy} L{wx + 12},{wy} L{wx + 12},{wy + 16} L{wx},{wy + 16} Z", "#ffe8a3" if lit else "#8fb7e3", "win_glass")
        if (x // 10) % 3 == 0:
            s += line(f"M{x + tw / 2},{y} L{x + tw / 2},{y - 50}", stroke="#4f7fb8", sw=6)
    # frame, mullions, blinds
    s += p("M70,70 L1010,70 L1010,660 L70,660 Z", "none", sw=10)
    s += line("M540,70 L540,660", stroke=CREAM, sw=22) + line("M540,70 L540,660", sw=6)
    s += line("M70,360 L1010,360", stroke=CREAM, sw=18) + line("M70,360 L1010,360", sw=6)
    s += p("M70,70 L1010,70 L1010,190 L70,190 Z", "#f3e3c3")
    for y in range(86, 190, 16):
        s += line(f"M70,{y} L1010,{y}", stroke="#d9c39b", sw=4)
    s += line("M70,190 L1010,190", sw=7) + line("M300,190 L300,240", sw=4) + circ(300, 246, 8, AMBER, sw=4)
    s += p("M20,660 L1060,660 L1060,700 L20,700 Z", "#f6ead2")
    s += shade("M20,690 L1060,690 L1060,700 L20,700 Z", "#dccaa7")
    s += p("M20,660 L1060,660 L1060,700 L20,700 Z", "none")
    # a small cactus on the sill
    s += p("M840,600 L890,600 L884,660 L846,660 Z", POT) + p("M852,600 C850,560 852,530 866,520 C880,530 882,560 878,600 Z", LEAF)
    return card(w, h, s, 0.5, cut=6, lip=(2, 4))


def whiteboard():
    w, h = 620, 780
    s = ""
    for x in (100, 520):
        s += line(f"M{x},560 L{x},760", sw=12)
        s += line(f"M{x - 50},760 L{x + 50},760", sw=12)
    s += rect(30, 30, 560, 540, 16, STEEL)
    s += rect(52, 52, 516, 496, 8, "#fdfdfb", sw=5)
    s += rect(150, 552, 320, 22, 6, STEEL_S, sw=5)
    for x, c in ((180, "#e85d5d"), (230, "#3d7be0"), (280, "#2fae5c")):
        s += rect(x, 540, 40, 14, 6, c, sw=4)
    # an "organisational excellence" doodle: chart arrow going up, then down, then a smiley
    s += line("M90,470 L90,320 M90,470 L300,470", stroke="#9aa6b6", sw=4)
    s += line("M100,450 L150,410 L200,430 L250,360 L280,440", stroke="#e85d5d", sw=6)
    s += circ(470, 440, 34, "none", stroke="#3d7be0", sw=5) + line("M454,450 Q470,466 486,450", stroke="#3d7be0", sw=5)
    s += circ(458, 430, 3, "#3d7be0", stroke=None) + circ(482, 430, 3, "#3d7be0", stroke=None)
    s += line("M440,404 L500,404 L470,384 Z", stroke="#e85d5d", sw=4)  # someone gave it a tie... sort of
    return card(w, h, s, 0.55)


def poster():
    w, h = 340, 460
    s = rect(20, 20, 300, 420, 10, "#1b2433")
    s += '<defs><linearGradient id="sunset" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff9a5c"/><stop offset="1" stop-color="#ffd27a"/></linearGradient></defs>'
    s += '<rect x="40" y="40" width="260" height="250" rx="4" fill="url(#sunset)"/>'
    s += circ(170, 230, 56, "#fff3b0", stroke=None)
    s += p("M40,250 C100,220 130,250 170,240 C220,228 250,250 300,236 L300,290 L40,290 Z", "#e2723f", stroke=None)
    s += p("M40,270 C90,256 140,276 300,262 L300,290 L40,290 Z", "#b9512d", stroke=None)
    s += rect(40, 300, 260, 120, 4, "#2b3a55", stroke=None)
    return card(w, h, s, 0.6, cut=6, lip=(2, 4))


def clock():
    w, h = 240, 240
    s = circ(120, 120, 100, CREAM, sw=9) + circ(120, 120, 86, "#fffdf8", sw=4)
    for i in range(12):
        import math
        a = math.radians(i * 30)
        x0, y0 = 120 + math.sin(a) * 72, 120 - math.cos(a) * 72
        x1, y1 = 120 + math.sin(a) * 82, 120 - math.cos(a) * 82
        s += line(f"M{x0:.1f},{y0:.1f} L{x1:.1f},{y1:.1f}", sw=6 if i % 3 == 0 else 4)
    s += circ(120, 120, 8, INK, stroke=None)
    return card(w, h, s, 0.6, cut=6, lip=(2, 4))


def clock_hand_long():
    return flat(40, 160, line("M20,150 L20,20", sw=9) + circ(20, 150, 6, INK, stroke=None), 0.6)


def clock_hand_short():
    return flat(40, 120, line("M20,110 L20,26", sw=12, stroke="#e8735d") + line("M20,110 L20,26", sw=4, stroke="#b9512d"), 0.6)


def door():
    w, h = 460, 880
    s = rect(20, 20, 420, 850, 8, "#f6ead2")
    s += rect(52, 60, 356, 790, 6, WOOD)
    s += rect(84, 96, 292, 300, 8, WOOD_H, sw=5) + rect(84, 430, 292, 380, 8, WOOD_H, sw=5)
    s += rect(110, 120, 240, 120, 10, "#d9ecfb", sw=5)
    s += circ(360, 470, 16, AMBER, sw=5) + rect(340, 462, 40, 14, 6, AMBER, sw=4)
    s += shade("M372,60 L408,60 L408,850 L372,850 Z", WOOD_S)
    return card(w, h, s, 0.5, cut=6, lip=(2, 4))


def rug():
    w, h = 900, 420
    s = ell(450, 210, 430, 190, "#e9a86a", sw=8) + ell(450, 210, 380, 156, "#f4c98f", stroke=None)
    s += ell(450, 210, 300, 118, "none", stroke="#e8735d", sw=10, extra='stroke-dasharray="26 18"')
    s += ell(450, 210, 200, 70, "#f9dcae", stroke=None)
    return flat(w, h, s, 0.5)


def phone(glow=False):
    w, h = 240, 150
    s = ""
    if glow:
        s += ell(120, 80, 116, 70, "#ff5a3c", stroke=None, extra='opacity="0.35"') + ell(120, 80, 96, 56, "#ff8a3c", stroke=None, extra='opacity="0.35"')
    s += p("M40,60 L190,40 L214,92 L62,116 Z", "#1d1f24")
    s += p("M52,64 L186,46 L204,88 L68,106 Z", "#ff5a3c" if glow else "#4aa8ff", stroke=None)
    if glow:
        s += text(128, 92, "!!", 40, fill=WHITE, extra='transform="rotate(-8 128 80)"')
    else:
        s += p("M80,74 L140,66 L144,74 L84,82 Z", WHITE, stroke=None)
    return flat(w, h, s, 0.6)


# ======================================================================= surfaces

def floor_tile():
    w = h = 512
    s = rect(0, 0, 512, 512, 0, "#d9a066", stroke=None)
    tones = ["#d39a5f", "#dfa86f", "#cf9458", "#e2ad76", "#d79d63"]
    plank_h = 64
    for row in range(8):
        y = row * plank_h
        off = (row * 197) % 512
        for k in range(3):
            x = (off + k * 256) % 512 - 256
            for xx in (x, x + 512):
                s += rect(xx, y, 256, plank_h, 0, tones[(row + k) % 5], stroke=None)
                s += line(f"M{xx + 4},{y + 1} L{xx + 252},{y + 1}", stroke="#efc08c", sw=2, extra='opacity="0.7"')
                s += line(f"M{xx},{y} L{xx},{y + plank_h}", stroke="#a8743f", sw=3)
                for g in range(3):
                    gy = y + 16 + g * 14
                    s += line(f"M{xx + 20 + g * 30},{gy} C{xx + 80},{gy - 4} {xx + 140},{gy + 4} {xx + 230 - g * 20},{gy}", stroke="#c48a50", sw=2, extra='opacity="0.55"')
        s += line(f"M0,{y} L512,{y}", stroke="#9f6c3a", sw=3)
    return flat(w, h, s, 1.0)


def wall_tile():
    w = h = 512
    s = rect(0, 0, 512, 512, 0, "#f6ead6", stroke=None)
    for x in range(0, 512, 64):
        s += rect(x, 0, 32, 512, 0, "#f1e2ca", stroke=None)
    for y in range(32, 512, 64):
        for x in range(16, 512, 64):
            s += circ(x + 16, y, 3, "#e8d3b2", stroke=None)
    return flat(w, h, s, 1.0)


def wainscot_tile():
    w, h = 512, 256
    s = rect(0, 0, 512, 256, 0, TEAL, stroke=None)
    for x in (16, 272):
        s += rect(x, 40, 224, 190, 10, TEAL_H, stroke=TEAL_S, sw=6)
    s += rect(0, 0, 512, 26, 0, "#f6ead2", stroke=None) + line("M0,26 L512,26", stroke=TEAL_S, sw=6)
    s += rect(0, 236, 512, 20, 0, TEAL_S, stroke=None)
    return flat(w, h, s, 1.0)


def corrugated():
    """Cardboard cross-section for the diorama base and wall edges."""
    w, h = 256, 64
    s = rect(0, 0, 256, 64, 0, "#c99b6b", stroke=None)
    s += rect(0, 0, 256, 10, 0, "#e3bf8f", stroke=None) + rect(0, 54, 256, 10, 0, "#e3bf8f", stroke=None)
    d = "M0,32 "
    for i in range(16):
        x = i * 16
        d += f"Q{x + 8},{10 if i % 2 == 0 else 54} {x + 16},32 "
    s += line(d, stroke="#a87b4f", sw=5)
    return flat(w, h, s, 1.0)


def tabletop():
    """Out-of-focus desk surface the diorama stands on."""
    w, h = 512, 512
    s = rect(0, 0, 512, 512, 0, "#8a5a3a", stroke=None)
    s += '<defs><filter id="blur"><feGaussianBlur stdDeviation="10"/></filter></defs><g filter="url(#blur)">'
    for i in range(14):
        y = i * 38 + (i * 13) % 20
        s += line(f"M-20,{y} C140,{y + 12} 300,{y - 10} 540,{y + 6}", stroke=["#7a4c30", "#9a6844", "#845436"][i % 3], sw=18)
    s += "</g>"
    return flat(w, h, s, 1.0)


# ======================================================================= comic FX

def fx_heart():
    return flat(160, 150, p("M80,140 C20,100 6,64 20,40 C36,12 72,14 80,44 C88,14 124,12 140,40 C154,64 140,100 80,140 Z", "#ff6b8a", sw=8) + ell(52, 50, 12, 8, WHITE, stroke=None, extra='opacity="0.8"'), 0.6)


def fx_sparkle():
    return flat(140, 140, p("M70,6 C76,52 88,64 134,70 C88,76 76,88 70,134 C64,88 52,76 6,70 C52,64 64,52 70,6 Z", "#ffd23f", sw=7), 0.6)


def fx_star():
    import math
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = 64 if i % 2 == 0 else 28
        pts.append(f"{70 + math.cos(a) * r:.1f},{74 - math.sin(a) * r:.1f}")
    return flat(140, 140, p("M" + " L".join(pts) + " Z", "#ffd23f", sw=7), 0.6)


def fx_exclaim():
    s = p("M44,14 L96,14 L84,104 L56,104 Z", "#e8735d", sw=8) + circ(70, 132, 16, "#e8735d", sw=8)
    return flat(140, 160, s, 0.6)


def fx_question():
    s = p("M30,56 C30,18 110,10 116,54 C120,84 84,90 82,112 L56,112 C54,78 92,72 88,54 C84,36 58,40 58,60 Z", "#3d7be0", sw=8) + circ(70, 138, 15, "#3d7be0", sw=8)
    return flat(150, 166, s, 0.6)


def fx_dots():
    s = p("M20,30 C20,14 34,6 50,6 L170,6 C186,6 200,14 200,30 L200,80 C200,96 186,104 170,104 L80,104 L48,130 L54,104 L50,104 C34,104 20,96 20,80 Z", WHITE, sw=7)
    for x in (70, 110, 150):
        s += circ(x, 55, 10, INK, stroke=None)
    return flat(220, 140, s, 0.6)


def fx_sweat():
    return flat(90, 130, p("M45,8 C60,40 84,64 84,90 C84,114 64,124 45,124 C26,124 6,114 6,90 C6,64 30,40 45,8 Z", "#8fd3ff", sw=7) + ell(32, 92, 8, 12, WHITE, stroke=None, extra='opacity="0.8"'), 0.6)


def fx_anger():
    s = ""
    for d in ("M20,50 Q50,46 52,20", "M90,20 Q92,48 120,50", "M20,90 Q50,94 52,120", "M90,120 Q92,92 120,90"):
        s += line(d, stroke="#e8435d", sw=14)
    return flat(140, 140, s, 0.6)


def fx_ember():
    return flat(80, 110, p("M40,6 C52,30 74,46 74,72 C74,94 58,104 40,104 C22,104 6,94 6,72 C6,52 20,44 26,28 C30,44 36,48 40,6 Z", "#ff8a3c", sw=6) + p("M40,50 C48,64 56,72 56,84 C56,94 48,98 40,98 C32,98 24,94 24,84 C24,74 34,68 40,50 Z", "#ffd23f", stroke=None), 0.6)


def fx_puff():
    s = ""
    for cx, cy, r in ((90, 120, 60), (150, 90, 70), (210, 120, 56), (130, 150, 54), (180, 156, 50)):
        s += circ(cx, cy, r, "#fbf3e3", sw=8)
    for cx, cy, r in ((90, 120, 60), (150, 90, 70), (210, 120, 56), (130, 150, 54), (180, 156, 50)):
        s += circ(cx, cy, r - 4, "#fbf3e3", stroke=None)
    s += p("M110,100 C120,80 150,74 170,86", "none", stroke="#e6d8bf", sw=8)
    return flat(300, 230, s, 0.6)


def fx_grawlix():
    s = p("M20,40 C20,18 40,8 64,8 L236,8 C260,8 280,18 280,40 L280,96 C280,118 260,128 236,128 L64,128 C40,128 20,118 20,96 Z", "#fff3c4", sw=8)
    s += text(150, 92, "#@$%!", 64, fill="#e8435d")
    return flat(300, 140, s, 0.6)


def fx_arrow():
    s = p("M30,20 L110,20 L110,90 L140,90 L70,150 L0,90 L30,90 Z", "#ffb627", sw=9)
    s += line("M48,34 L48,90", stroke="#ffe08a", sw=8)
    return flat(150, 170, s, 0.6)


def fx_cake_slice():
    s = ell(110, 120, 96, 26, WHITE, sw=7)
    s += p("M40,104 L170,72 L176,108 L46,136 Z", "#f5cf6b")
    s += p("M40,104 L170,72 L150,52 L30,84 Z", "#fffaf0")
    s += p("M30,84 L40,104 L46,136 L36,118 Z", "#e2b44c")
    s += ell(96, 74, 12, 6, "#ffe14d", sw=4)
    return flat(220, 160, s, 0.6)


def fx_ring():
    return flat(300, 120, ell(150, 60, 140, 50, "none", stroke="#ffb627", sw=10) + ell(150, 60, 140, 50, "none", stroke="#fff3c4", sw=4), 0.6)


PROPS = {
    "props": {
        "desk": desk(), "chair": chair(), "bookshelf": bookshelf(), "plant_tall": plant_tall(),
        "plant_small": plant_small(), "coffee_counter": coffee_counter(), "cake_table": cake_table(),
        "water_cooler": water_cooler(), "printer": printer(), "whiteboard": whiteboard(),
        "phone": phone(False), "phone_hot": phone(True),
    },
    "decals": {
        "window": window(), "poster": poster(), "clock": clock(), "clock_hand_long": clock_hand_long(),
        "clock_hand_short": clock_hand_short(), "door": door(), "rug": rug(),
    },
    "surfaces": {
        "floor": floor_tile(), "wall": wall_tile(), "wainscot": wainscot_tile(), "corrugated": corrugated(), "tabletop": tabletop(),
    },
    "fx": {
        "heart": fx_heart(), "sparkle": fx_sparkle(), "star": fx_star(), "exclaim": fx_exclaim(), "question": fx_question(),
        "dots": fx_dots(), "sweat": fx_sweat(), "anger": fx_anger(), "ember": fx_ember(), "puff": fx_puff(), "grawlix": fx_grawlix(),
        "arrow": fx_arrow(), "ring": fx_ring(), "cake_slice": fx_cake_slice(),
    },
}
