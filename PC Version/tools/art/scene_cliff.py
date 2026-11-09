"""Lighthouse Cliff: Rosa's bench, the keeper's cottage, the Hushwater Light."""
import math
import random

from paperlib import (Layer, arc_pts, darken_bottom, ellipse, ground_light, layer_meta, layer_text, rect, ridge,
                      rrect, shade, wobble)
from props import (BRASS, INK, IRON, LIT, LIT_HOT, TRIM, WOOD, WOOD_DARK, bench, door, grass_tufts, house,
                   lamp_post, rope, sag, window)

S = 2000
V = 720
M = 80
HZ = 840
LX = 1510         # lighthouse centre
LAMP_Y = 212


def _w(f):
    return V + (S - V) * f + 2 * M


def ground_y(x):
    return 958 - (x / S) * 28 - 4


def far(out):
    f = 0.12
    W = _w(f)
    L = Layer(W, 200, x0=-M, y0=680, scale=0.5)
    L.sheet(ridge(W * 0.55, W * 0.85, 826, 10, 41, step=8, bottom=HZ), "#7a6c9c", shadow=0.05, seed=1)
    # a far ship
    sx = W * 0.3
    L.sheet([(sx, HZ - 8), (sx + 70, HZ - 8), (sx + 62, HZ - 1), (sx + 6, HZ - 1)], "#4a4272", seed=2)
    L.sheet(rect(sx + 26, HZ - 20, 22, 12), "#4a4272", seed=3)
    L.glow(sx + 36, HZ - 14, 8, "#ffd28a", 0.9)
    L.tint("#f0a07f", 0.1)
    p = L.save(f"{out}/far.png")
    return layer_meta("far.png", L, p, f, -40)


def mid(out):
    f = 0.4
    W = _w(f)
    L = Layer(W, 520, x0=-M, y0=420, scale=0.75)
    # Hushwater down the coast, to the west (left)
    L.sheet(ridge(-M, 760, 760, 40, 51, bottom=HZ), "#3f3866", shadow=0.2, seed=1)
    rng = random.Random(5)
    x = -M
    i = 0
    while x < 600:
        w = 26 + rng.random() * 30
        h = 30 + rng.random() * 60
        base = 800 - math.sin(x * 0.01) * 10
        L.sheet(rect(x, base - h, w, h + 40), ["#4a4174", "#433a6c", "#504679"][i % 3], shadow=0.1, seed=10 + i)
        L.sheet([(x - 3, base - h + 1), (x + w / 2, base - h - 16), (x + w + 3, base - h + 1)], "#3a3260", shadow=0.05, seed=60 + i)
        for _ in range(2):
            if rng.random() < 0.7:
                lx, ly = x + 4 + rng.random() * (w - 12), base - h + 8 + rng.random() * (h - 16)
                L.sheet(rect(lx, ly, 6, 8), "#ffd18a", shadow=0, edge=0, seed=99)
                L.glow(lx + 3, ly + 4, 14, "#ffb050", 0.5)
        x += w + 2
        i += 1
    # the clock tower's spire and the crooked post office, tiny
    L.sheet(rect(260, 670, 30, 110), "#433a6c", seed=200)
    L.sheet([(254, 672), (275, 610), (296, 672)], "#3d6458", seed=201)
    L.sheet(ellipse(275, 690, 9, 9, 12), "#efe3c8", seed=202)
    L.sheet([(470, 790), (476, 700), (520, 694), (518, 790)], "#4b5a80", seed=203)
    L.glow(497, 740, 14, "#ffb050", 0.7)
    # the harbour lamps
    for k in range(6):
        L.glow(560 + k * 26, 806, 10, "#ffcf7a", 0.8)
    L.tint("#c88aa0", 0.07)
    p = L.save(f"{out}/mid.png")
    return layer_meta("mid.png", L, p, f, -30)


def cottage(L):
    x, w, base = 640, 300, int(ground_y(790))
    top = house(L, x, base, w, 250, "#d9d3c6", "#3c3a52", roof_h=120, seed=10, chimney=True, trim="#e8e2d6")
    # stone texture
    rng = random.Random(4)
    for i in range(26):
        sx, sy = x + 10 + rng.random() * (w - 30), top + 20 + rng.random() * 210
        L.sheet(ellipse(sx, sy, 10 + rng.random() * 8, 6 + rng.random() * 4, 10), "#c9c2b4", shadow=0.15, shadow_off=(1, 2), shadow_blur=1, edge=0.15, seed=20 + i)
    # smoke from the chimney
    for k in range(5):
        L.sheet(ellipse(x + 230 + k * 18, top - 170 - k * 34, 18 + k * 6, 13 + k * 5, 20), "#b8b0c8", shadow=0, edge=0, alpha=0.35 - k * 0.05, seed=40 + k)
    # the lit window with a photograph on the sill
    window(L, 668, 698, 112, 104, lit=True, panes=(2, 2), seed=50, curtain="#7a8aa6")
    L.sheet(rect(730, 778, 22, 26), "#3a2e2a", shadow=0.1, seed=55)
    L.sheet(rect(733, 781, 16, 18), "#d6c6a6", shadow=0, edge=0, seed=56)
    door(L, 818, 760, 72, base - 760 - 8, "#3f5a6a", arch=False, glass=False, seed=58)
    # porch to the right: posts, roof, table with the logbook, a rocking chair, a lantern
    px0, px1 = 940, 1104
    L.sheet([(px0 - 6, 720), (px1 + 10, 736), (px1 + 6, 752), (px0 - 6, 738)], "#3c3a52", seed=60)
    for i, ppx in enumerate((px0 + 4, px1 - 6)):
        L.sheet(rect(ppx, 738, 10, base - 738), WOOD, seed=61 + i)
    L.sheet(rect(px0, base - 8, px1 - px0, 10), WOOD_DARK, seed=63)
    # table + logbook (open)
    L.sheet(rect(958, 872, 104, 10), WOOD, seed=64)
    L.sheet(rect(966, 882, 8, base - 882), WOOD_DARK, seed=65)
    L.sheet(rect(1046, 882, 8, base - 882), WOOD_DARK, seed=66)
    L.sheet([(970, 870), (1008, 866), (1008, 856), (972, 860)], "#efe6d0", shadow=0.15, shadow_off=(1, 2), shadow_blur=1, seed=67)
    L.sheet([(1008, 866), (1046, 870), (1044, 860), (1008, 856)], "#f4ecd8", shadow=0.15, shadow_off=(1, 2), shadow_blur=1, seed=68)
    L.sheet(ellipse(1034, 856, 9, 6, 10), "#7a7890", seed=69)
    for k in range(3):
        L.ink([(976, 862 + k * 3), (1002, 860 + k * 3)], "#5a5070", 1, alpha=0.6)
    # rocking chair
    L.ink([(1068, base - 2), (1100, base - 4)], WOOD_DARK, 4)
    L.sheet(rect(1072, 880, 26, 8), WOOD, seed=70)
    L.ink([(1074, 884), (1072, 840)], WOOD, 4)
    L.ink([(1096, 884), (1096, 846)], WOOD, 4)
    L.ink([(1072, 842), (1096, 846)], WOOD, 4)
    # hanging lantern
    L.ink([(1020, 744), (1020, 770)], IRON, 2)
    L.sheet([(1010, 770), (1030, 770), (1027, 796), (1013, 796)], LIT_HOT, grad_color="#ffb45a", shadow=0.1, edge=0.03, seed=71)
    L.glow(1020, 783, 70, "#ffb04a", 0.5)


def lighthouse(L):
    base = int(ground_y(LX)) + 4
    bw, tw, ty = 300, 196, 290
    body = [(LX - bw / 2, base), (LX - tw / 2, ty), (LX + tw / 2, ty), (LX + bw / 2, base)]
    L.sheet(wobble(body, 0.8, 100), "#e9e3d8", grad=0.12, seed=100)
    # shading on the right flank
    L.sheet([(LX + bw / 2 - 40, base), (LX + tw / 2 - 26, ty), (LX + tw / 2, ty), (LX + bw / 2, base)], "#c8c0b4", shadow=0, edge=0, alpha=0.75, seed=101)
    # red bands
    for (y0, y1) in ((420, 470), (600, 650)):
        def wid(y):
            t = (y - ty) / (base - ty)
            return tw / 2 + (bw / 2 - tw / 2) * t
        L.sheet([(LX - wid(y1), y1), (LX - wid(y0), y0), (LX + wid(y0), y0), (LX + wid(y1), y1)], "#b4423c", shadow=0.05, edge=0.06, seed=102 + y0)
    # small windows up the tower
    for i, wy in enumerate((380, 540, 700)):
        L.sheet(rrect(LX - 12, wy, 24, 34, 10), LIT if i != 1 else "#2b3050", grad_color="#ffb45a" if i != 1 else None, shadow=0.1, seed=110 + i)
        if i != 1:
            L.glow(LX, wy + 17, 40, "#ffb04a", 0.35)
    # gallery + lantern room
    L.sheet(rect(LX - 130, ty - 12, 260, 18), "#2a2638", seed=120)
    for x in range(int(LX - 124), int(LX + 128), 14):
        L.ink([(x, ty - 46), (x, ty - 12)], IRON, 2.5)
    L.ink([(LX - 128, ty - 46), (LX + 128, ty - 46)], IRON, 4)
    L.sheet(rect(LX - 64, 160, 128, ty - 172), "#ffefc4", grad_color="#ffd28a", shadow=0.1, edge=0.03, alpha=0.95, seed=121)
    for x in (LX - 32, LX, LX + 32):
        L.ink([(x, 160), (x, ty - 12)], "#2a2638", 4)
    L.sheet(rect(LX - 70, ty - 18, 140, 8), "#2a2638", seed=122)
    L.sheet(arc_pts(LX, 166, 78, 60, math.pi, 2 * math.pi, 20) + [(LX + 78, 168), (LX - 78, 168)], "#2a2638", seed=123)
    L.sheet(ellipse(LX, 104, 12, 12, 14), "#2a2638", seed=124)
    L.ink([(LX, 92), (LX, 56)], IRON, 3)
    L.glow(LX, LAMP_Y, 140, "#ffd98a", 0.5)
    # door + sign
    door(L, LX - 60, 734, 120, base - 734 - 8, "#2f4f45", arch=True, glass=False, seed=130, frame="#d8d0c2")
    for k in range(3):
        L.ink([(LX - 54, 790 + k * 50), (LX + 54, 790 + k * 50)], IRON, 3)
    layer_text(L, LX, 706, "112 STEPS TO THE LAMP", "Cinzel.ttf", 13, "#3a3040")


def main_layer(out):
    L = Layer(S + 2 * M, 1500, x0=-M, y0=100, scale=1.0)
    # rock face first (below the grass), then the clifftop
    rock = [(-M, 1040)] + [(x, ground_y(x) + 90 + math.sin(x * 0.02) * 10) for x in range(-M, 1900, 40)] + [(1900, 1100), (1960, 1600), (-M, 1600)]
    L.sheet(rock, "#3a3654", grad_color="#1e1a30", seed=1)
    rng = random.Random(3)
    for i in range(18):
        y = 1080 + i * 28
        L.ink([(-M, y + rng.random() * 8), (1880 - i * 4, y + rng.random() * 10)], "#2c2844", 2, alpha=0.6)
    top = [(x, ground_y(x) + math.sin(x * 0.05) * 3) for x in range(-M, 1880, 30)]
    grass = top + [(1880, ground_y(1880)), (1900, ground_y(1880) + 40), (1890, 1100), (-M, 1100)]
    L.sheet(grass, "#4c6656", grad_color="#2d4038", grad=0.0, seed=2)
    # the cliff edge on the right: jagged drop to the sea, the Teeth below
    L.sheet(wobble([(1880, ground_y(1880)), (1932, ground_y(1900) + 30), (1990, 1060), (2060, 1300), (2080, 1600), (1880, 1600)], 6, 3, 18), "#332f4c", seed=3)
    for i, tx in enumerate((1960, 2020, 2060)):
        L.sheet(wobble([(tx - 30, 1560), (tx - 8, 1440 - i * 30), (tx + 18, 1450), (tx + 30, 1560)], 3, 10 + i, 10), "#1f1b30", seed=10 + i)
    # path down on the left + signpost
    L.sheet([(-M, ground_y(0) + 6), (140, ground_y(140) + 4), (100, 1100), (-M, 1100)], "#6a5a4a", shadow=0, edge=0.05, alpha=0.9, seed=20)
    L.sheet(rect(118, 830, 8, 120), WOOD_DARK, seed=21)
    L.sheet([(60, 842), (150, 842), (162, 856), (150, 870), (60, 870)], "#e9dcc0", seed=22)
    layer_text(L, 104, 856, "HARBOUR", "Cinzel.ttf", 11, "#3a2e3a")
    # Rosa's bench, facing the sea
    bench(L, 290, int(ground_y(385)) + 30, 190, seed=30)
    L.sheet(rect(366, int(ground_y(385)) - 50, 36, 12), BRASS, seed=31)
    cottage(L)
    lighthouse(L)
    # fence along the cliff edge
    for i, fx in enumerate(range(1730, 1900, 42)):
        L.sheet(rect(fx, ground_y(fx) - 58, 10, 62), WOOD_DARK, seed=40 + i)
    rope(L, sag(1730, ground_y(1730) - 50, 1890, ground_y(1890) - 50, 12), "#c8b48a", 3)
    # heather & wildflowers on the grass; tufts along the back edge
    flowers_pts = []
    for i in range(140):
        fx = rng.random() * 1880
        fy = ground_y(fx) + 10 + rng.random() * 110
        flowers_pts.append(ellipse(fx, fy, 3.5, 3.5, 8))
    L.sheet(flowers_pts[:70], "#a07ac0", shadow=0.15, shadow_off=(1, 1), shadow_blur=1, seed=50)
    L.sheet(flowers_pts[70:], "#e8d8a0", shadow=0.15, shadow_off=(1, 1), shadow_blur=1, seed=51)
    grass_tufts(L, -M, 1880, int(ground_y(900)) - 4, "#3a5248", h=20, density=0.08, seed=52)
    for gx, gy, rx, ry in [(1020, 930, 120, 30), (725, 935, 150, 30), (LX, 950, 160, 30)]:
        ground_light(L, gx, gy, rx, ry, "#ffb45a", 0.28)
    darken_bottom(L, 1150, 1600, amount=0.45)
    p = L.save(f"{out}/main.png")
    return layer_meta("main.png", L, p, 1.0, -10)


def fg_layer(out):
    f = 1.3
    W = _w(f)
    L = Layer(W, 600, x0=-M, y0=1100, scale=1.0)
    rng = random.Random(7)
    L.sheet(ridge(-M, W, 1460, 16, 3, step=10, bottom=1700), "#141b1c", shadow=0.4, seed=1)
    blades = []
    for i in range(int(W / 7)):
        x = -M + i * 7 + rng.random() * 4
        h = 40 + rng.random() * 120
        lean = (rng.random() - 0.5) * 40
        blades.append([(x - 4, 1480), (x + lean, 1480 - h), (x + 4, 1480)])
    L.sheet(blades, "#121a1a", shadow=0.3, seed=2)
    for i in range(14):
        x = rng.random() * W
        L.sheet(ellipse(x, 1400 - rng.random() * 40, 6, 6, 8), "#6a4a8a", shadow=0.2, seed=10 + i)
    p = L.save(f"{out}/fg.png")
    return layer_meta("fg.png", L, p, f, 10, group="fg")


def build(out):
    layers = [far(out), mid(out), main_layer(out), fg_layer(out)]
    return {"width": S, "height": 1600, "horizon": HZ, "sea": True,
            "beam": {"x": LX, "y": LAMP_Y, "factor": 1.0, "scale": 1.0},
            "layers": [l for l in layers if l], "props": []}
