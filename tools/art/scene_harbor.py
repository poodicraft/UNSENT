"""Hushwater Harbour: post office back, Lost & Found, the Morning Lark, memorial, pier."""
import math
import random

from paperlib import (Layer, arc_pts, darken_bottom, ellipse, ground_light, layer_meta, layer_text, rect, ridge,
                      rrect, shade, wobble)
from props import (BRASS, INK, IRON, LIT, LIT_HOT, TRIM, WOOD, WOOD_DARK, barrel, crate, door, house, lamp_post,
                   planks, rope, sag, stone_wall, window)

S = 2400
V = 720
M = 80
HZ = 840          # horizon
QUAY = 930        # quay back edge


def _w(f):
    return V + (S - V) * f + 2 * M


def far(out):
    f = 0.12
    W = _w(f)
    L = Layer(W, 260, x0=-M, y0=600, scale=0.5)
    # Port Ardent across the bay (left), hills behind
    L.sheet(ridge(-M, W * 0.6, 812, 30, 31, bottom=HZ), "#6f6497", shadow=0.1, seed=1)
    rng = random.Random(3)
    city = []
    x = -M
    while x < 420:
        w = 10 + rng.random() * 16
        h = 10 + rng.random() * 34
        city.append(rect(x, HZ - h, w, h))
        x += w + rng.random() * 3
    L.sheet(city, "#5a4f84", shadow=0.1, seed=2)
    for i in range(70):
        lx = -M + rng.random() * 500
        ly = HZ - 4 - rng.random() * 34
        L.glow(lx, ly, 5 + rng.random() * 5, "#ffcf7a", 0.8)
    # a crane
    L.ink([(330, HZ), (330, 760), (390, 760)], "#5a4f84", 3)
    # distant island in the middle
    L.sheet(ridge(560, 820, 828, 14, 33, step=8, bottom=HZ), "#7a6c9c", shadow=0.05, seed=4)
    L.tint("#f0a07f", 0.1)
    p = L.save(f"{out}/far.png")
    return layer_meta("far.png", L, p, f, -40)


def mid(out):
    f = 0.35
    W = _w(f)
    L = Layer(W, 620, x0=-M, y0=260, scale=0.75)
    # headland with the lighthouse (right)
    pts = [(860, HZ), (920, 760), (990, 700), (1060, 640), (1150, 600), (1260, 590), (1360, 610), (W, 620), (W, HZ)]
    L.sheet(wobble(pts, 3, 5, 12), "#3f3866", grad=0.2, shadow=0.2, seed=10)
    L.sheet(wobble([(900, HZ), (960, 780), (1040, 740), (1100, 760), (1160, HZ)], 3, 6, 12), "#352f5a", shadow=0.15, seed=11)
    # lighthouse
    lx = 1148
    L.sheet([(lx - 26, 604), (lx + 26, 604), (lx + 18, 380), (lx - 18, 380)], "#e6e0d6", grad=0.14, seed=12)
    L.sheet([(lx - 23, 520), (lx + 23, 520), (lx + 21, 480), (lx - 21, 480)], "#b4423c", seed=13)
    L.sheet(rect(lx - 24, 372, 48, 10), "#2a2638", seed=14)
    L.sheet(rect(lx - 16, 340, 32, 32), "#ffe9b8", grad_color="#ffc070", shadow=0, edge=0, seed=15)
    L.sheet([(lx - 22, 342), (lx, 318), (lx + 22, 342)], "#2a2638", seed=16)
    # keeper's cottage
    L.sheet(rect(lx - 110, 572, 60, 34), "#d8d2c6", seed=17)
    L.sheet([(lx - 116, 574), (lx - 80, 552), (lx - 44, 574)], "#3a3450", seed=18)
    L.sheet(rect(lx - 96, 584, 10, 12), "#ffd18a", shadow=0, edge=0, seed=19)
    # fishing boats far out on the left
    for i, bx in enumerate((120, 360, 600)):
        L.sheet([(bx, HZ - 12), (bx + 60, HZ - 12), (bx + 50, HZ - 2), (bx + 8, HZ - 2)], "#2f2a52", shadow=0.05, seed=30 + i)
        L.ink([(bx + 30, HZ - 12), (bx + 30, HZ - 58)], "#2f2a52", 2)
        L.sheet([(bx + 32, HZ - 56), (bx + 32, HZ - 16), (bx + 56, HZ - 18)], "#e8dccb", shadow=0.05, seed=40 + i)
        L.glow(bx + 30, HZ - 20, 10, "#ffd28a", 0.9)
    L.tint("#c88aa0", 0.06)
    p = L.save(f"{out}/mid.png")
    return layer_meta("mid.png", L, p, f, -30), {"x": lx, "y": 356, "factor": f, "scale": 0.45}


def post_office_back(L):
    x0, x1 = -M, 268
    L.sheet(wobble([(x0, QUAY + 4), (x0, 180), (x1 - 4, 196), (x1, QUAY + 4)], 0.8, 1), "#8c5a4e", grad=0.14, seed=1)
    for y in range(200, QUAY, 28):
        L.ink([(x0, y), (x1 - 2, y + 2)], "#76493f", 2, alpha=0.5)
    L.sheet([(x0 - 10, 196), (x1 - 40, 120), (x1 + 14, 200)], "#3d3756", seed=2)
    window(L, 30, 300, 64, 90, lit=True, panes=(2, 2), seed=3)
    window(L, 150, 296, 64, 90, lit=True, panes=(2, 2), seed=6, curtain="#7a5aa6")
    window(L, 160, 460, 56, 80, lit=False, seed=9)
    # back door with a round porthole
    door(L, 92, 652, 136, QUAY - 652 - 6, "#3a5f8a", arch=True, glass=False, seed=12, frame="#d8c9ad")
    L.sheet(ellipse(160, 720, 26, 26, 30), "#b8a080", seed=13)
    L.sheet(ellipse(160, 720, 20, 20, 30), LIT_HOT, grad_color="#ffb45a", shadow=0, edge=0, seed=14)
    L.glow(160, 720, 60, "#ffb04a", 0.4)
    L.ink([(160, 586), (160, 572), (186, 572)], IRON, 5)
    L.sheet([(144, 588), (176, 588), (170, 620), (150, 620)], LIT_HOT, grad_color="#ffb45a", shadow=0.15, edge=0.03, seed=15)
    L.sheet([(138, 590), (160, 570), (182, 590)], IRON, seed=16)
    L.glow(160, 604, 90, "#ffb04a", 0.55)
    layer_text(L, 160, 640, "P.O. · OUTGOING & UNSENT", "Cinzel.ttf", 10, "#f0dcae")
    crate(L, 236, QUAY + 8, 46, seed=17)


def shed(L):
    x0, x1 = 330, 712
    L.sheet(wobble([(x0, QUAY + 4), (x0, 600), (x1, 584), (x1, QUAY + 4)], 0.8, 30), "#6c7c8e", grad=0.12, seed=30)
    for i, x in enumerate(range(x0 + 22, x1, 24)):
        L.ink([(x, 596 - (x - x0) * 0.04), (x, QUAY)], "#56657a", 2, alpha=0.7)
    L.sheet([(x0 - 20, 604), (x0 + 30, 540), (x1 + 20, 540), (x1 + 26, 588)], "#4a3f5a", seed=31)
    L.sheet(rect(x0 - 24, 584, x1 - x0 + 54, 12), "#3a3248", seed=32)
    # sign
    L.sheet(rect(370, 618, 230, 42), "#e9dcc0", seed=33)
    layer_text(L, 485, 632, "LOST & FOUND", "Cinzel.ttf", 18, "#3a2e3a")
    layer_text(L, 485, 651, "what the sea gives back", "Caveat.ttf", 13, "#5a4a5a")
    # open doorway with a dark interior full of odd objects
    L.sheet(rect(380, 690, 150, QUAY - 690), "#221d2e", shadow=0, seed=34)
    L.sheet(ellipse(420, 860, 24, 30, 16), "#3a3446", shadow=0.1, seed=35)
    L.sheet(rect(450, 800, 50, 70), "#3a3446", shadow=0.1, seed=36)
    L.sheet(ellipse(475, 790, 18, 10, 12), "#4a4458", shadow=0.1, seed=37)
    L.sheet([(392, 760), (430, 744), (436, 756), (398, 772)], "#4a4458", shadow=0.1, seed=38)
    L.glow(450, 820, 70, "#ffc070", 0.15)
    L.ink(rect(380, 690, 150, QUAY - 690), "#4a3a2a", 6, closed=True)
    # life ring (Marguerite)
    L.sheet(ellipse(654, 744, 44, 44, 40), "#efe7dc", seed=39, holes=[ellipse(654, 744, 24, 24, 30)])
    for a0 in (0.3, 1.87, 3.44, 5.01):
        seg = arc_pts(654, 744, 44, 44, a0, a0 + 0.7, 8)[::-1] + arc_pts(654, 744, 24, 24, a0, a0 + 0.7, 8)
        L.sheet(seg, "#b4423c", shadow=0, edge=0.05, seed=40 + int(a0 * 10))
    rope(L, sag(610, 744, 698, 744, 18, 10), "#c8b48a", 3)
    # nets, pots
    L.sheet(wobble([(600, QUAY), (612, 840), (690, 836), (708, QUAY)], 2, 41), "#5a6a5a", alpha=0.85, seed=41)
    for k in range(6):
        L.ink([(604 + k * 17, QUAY), (614 + k * 14, 842)], "#3a4a3a", 1.5, alpha=0.7)
    barrel(L, 556, QUAY + 10, seed=42)


def ferry(out):
    L = Layer(500, 360, x0=760, y0=600, scale=1.0)
    hull = [(790, 830), (1222, 826), (1196, 912), (820, 916)]
    L.sheet(hull, "#2f4a6a", grad=0.2, seed=1)
    L.sheet([(840, 860), (960, 858), (958, 896), (846, 898)], "#3a5a80", shadow=0.05, edge=0.08, seed=2)
    L.sheet([(1040, 862), (1150, 860), (1146, 890), (1046, 892)], "#2a4262", shadow=0.05, edge=0.08, seed=3)
    L.sheet(rect(786, 822, 440, 12), "#e9dcc0", seed=4)
    for i, px in enumerate(range(830, 1200, 46)):
        L.sheet(ellipse(px, 846, 8, 8, 14), LIT if i % 2 == 0 else "#d8c08a", shadow=0.1, edge=0.03, seed=10 + i)
        if i % 2 == 0:
            L.glow(px, 846, 18, "#ffb04a", 0.5)
    # the name sits on the stern's plate (the hull's slanted end left no room)
    layer_text(L, 1095, 876, "MORNING LARK", "Cinzel.ttf", 12, "#efe2c4")
    # cabin + wheelhouse
    L.sheet(rrect(900, 740, 230, 86, 8), "#e3d8c2", seed=20)
    for i, wx in enumerate(range(916, 1110, 44)):
        L.sheet(rrect(wx, 760, 30, 34, 6), LIT_HOT, grad_color="#ffb45a", shadow=0.05, edge=0.02, seed=21 + i)
        L.glow(wx + 15, 777, 28, "#ffb04a", 0.4)
    L.sheet(rrect(1060, 680, 96, 66, 8), "#efe6d4", seed=30)
    L.sheet(rrect(1070, 692, 76, 30, 5), "#2a3050", seed=31)
    L.sheet([(1050, 684), (1166, 684), (1160, 670), (1056, 670)], "#a33a32", seed=32)
    # funnel
    L.sheet([(960, 742), (1010, 742), (1004, 650), (966, 650)], "#e9dcc0", seed=33)
    L.sheet(rect(966, 668, 38, 16), "#b4423c", shadow=0, edge=0.05, seed=34)
    L.sheet(rect(963, 644, 44, 10), "#1f1c28", seed=35)
    # mast & flag
    L.ink([(870, 826), (870, 640)], "#3a3040", 4)
    L.sheet([(872, 646), (912, 654), (872, 664)], "#d9b46c", shadow=0.1, seed=36)
    rope(L, [(870, 650), (790, 826)], "#c8b48a", 2)
    rope(L, [(870, 650), (1060, 690)], "#c8b48a", 2)
    p = L.save(f"{out}/ferry.png")
    m = layer_meta("ferry.png", L, p, 1.0, -6)
    m["if"] = "not $lantern_night or $ferry_home"
    return m


def booth(L):
    x0 = 1240
    L.sheet(wobble(rect(x0, 720, 150, QUAY - 716), 0.8, 60), "#a3644e", grad=0.1, seed=60)
    L.sheet([(x0 - 16, 724), (x0 + 75, 676), (x0 + 166, 724)], "#3d3756", seed=61)
    L.sheet(rect(x0 + 18, 744, 114, 70), LIT_HOT, grad_color="#ffb45a", shadow=0, edge=0, seed=62)
    L.glow(x0 + 75, 780, 110, "#ffb04a", 0.4)
    L.ink(rect(x0 + 18, 744, 114, 70), "#5a3a2a", 5, closed=True)
    layer_text(L, x0 + 75, 734, "TICKETS", "Cinzel.ttf", 13, "#f0dcae")
    L.sheet(rect(x0 + 10, 830, 130, 70), "#22262c", seed=63)
    # (no arrow glyphs: the chalk font doesn't have them)
    for i, t in enumerate(("6:10 · PORT ARDENT", "8:15 · HOME")):
        layer_text(L, x0 + 75, 854 + i * 24, t, "Caveat.ttf", 14, "#f2efe6", alpha=0.9)
    L.sheet(rect(x0 + 112, 808, 22, 24), "#efe6d2", shadow=0.25, shadow_off=(2, 2), shadow_blur=1.5, seed=64)


def memorial(L):
    x, base = 1446, QUAY + 4
    L.sheet(wobble([(x, base), (x + 6, 830), (x + 30, 808), (x + 92, 806), (x + 116, 828), (x + 122, base)], 1.2, 70), "#8c8a9a", grad=0.18, seed=70)
    for i in range(6):
        L.ink([(x + 22, 850 + i * 14), (x + 100 - (i % 2) * 18, 850 + i * 14)], "#5a5868", 2, alpha=0.7)
    layer_text(L, x + 61, 836, "MARGUERITE", "Cinzel.ttf", 10, "#4a4858")
    # jar of sea lavender
    L.sheet(rrect(x + 46, base - 34, 26, 30, 6), "#9ab8c8", alpha=0.75, seed=71)
    for k in range(9):
        L.sheet(ellipse(x + 50 + (k % 4) * 6, base - 44 - (k // 4) * 9, 4, 4, 8), "#9a7ac8", shadow=0.1, seed=72 + k)


def cliff_steps(L):
    rock = [(1530, QUAY + 4), (1560, 860), (1610, 760), (1660, 650), (1720, 540), (1790, 450), (1870, 390), (1960, 370), (1990, QUAY + 4)]
    L.sheet(wobble(rock, 4, 80, 14), "#3b3a54", grad=0.2, seed=80)
    L.sheet(wobble([(1570, QUAY + 4), (1630, 870), (1700, 780), (1770, 700), (1840, 640), (1990, 600), (1990, QUAY + 4)], 4, 81, 14), "#45445e", seed=81)
    # carved steps climbing the rock face, bottom-left to top-right
    steps = []
    for i in range(10):
        sx = 1586 + i * 24
        sy = QUAY - 20 - i * 46
        steps.append(rect(sx, sy, 58, 11))
        steps.append(rect(sx + 6, sy + 11, 46, 8))
    L.sheet(steps, "#8a86a0", shadow=0.35, shadow_off=(2, 5), shadow_blur=3, seed=82)
    rope(L, [(1600, 880)] + [(1622 + i * 24, 838 - i * 46) for i in range(10)], "#c8b48a", 3)
    for i in range(0, 10, 3):
        L.sheet(rect(1620 + i * 24, 846 - i * 46, 6, 40), WOOD_DARK, seed=85 + i)
    # signpost stands just right of the memorial, its board above the stone,
    # so it never covers the name carved on it
    L.sheet(rect(1572, 790, 8, 140), WOOD_DARK, seed=83)
    L.sheet(rect(1516, 762, 120, 34), "#e9dcc0", seed=84)
    layer_text(L, 1576, 779, "KEEPER'S PATH", "Cinzel.ttf", 12, "#3a2e3a")


def main_layer(out):
    L = Layer(S + 2 * M, 1500, x0=-M, y0=100, scale=1.0)
    # quay deck (wood) and its front beam
    planks(L, -M, 1760, QUAY, 1112, "#6a5248", seed=1)
    L.sheet(rect(-M, 1104, 1840, 22), "#3a2c2a", seed=2)
    for i, x in enumerate(range(-40, 1760, 150)):
        L.sheet(rect(x, 1120, 26, 480), "#2e2426", grad=0.25, seed=10 + i)
    # stone quay wall under the shed area
    stone_wall(L, -M, 1126, 1840, 120, color="#5d5a72", seed=3)
    # pier: narrower deck on pilings
    planks(L, 1760, S + M, 966, 1032, "#6a5248", seed=4)
    L.sheet(rect(1760, 1028, S + M - 1760, 16), "#3a2c2a", seed=5)
    for i, x in enumerate(range(1790, S + M, 140)):
        L.sheet(rect(x, 1040, 22, 560), "#2e2426", grad=0.25, seed=30 + i)
        L.sheet(rect(x - 2, 930, 26, 40), "#3a2c2a", seed=60 + i)
    # pier railing
    L.ink([(1790, 936), (S + M, 936)], "#3a2c2a", 5)
    L.ink([(1790, 952), (S + M, 952)], "#3a2c2a", 3)
    post_office_back(L)
    shed(L)
    booth(L)
    memorial(L)
    cliff_steps(L)
    # bollards & rope along the quay edge
    for i, bx in enumerate((760, 1230, 1420)):
        L.sheet(rrect(bx, QUAY - 26, 30, 34, 10), "#26222f", seed=90 + i)
    rope(L, sag(774, QUAY - 18, 820, 880, 6, 6), "#c8b48a", 3)
    crate(L, 1180, QUAY + 14, 50, seed=95)
    crate(L, 1196, QUAY - 34, 34, seed=96)
    barrel(L, 720, QUAY + 12, seed=97)
    # pier lamps
    for i, lx in enumerate((1905, 2160)):
        lamp_post(L, lx, 972, 220, lit=True, seed=100 + i)
    # bench at the pier end
    L.sheet(rrect(2250, 940, 110, 12, 4), WOOD, seed=110)
    for gx, gy, rx, ry in [(1905, 990, 120, 30), (2160, 990, 120, 30), (160, 960, 150, 40), (1315, 960, 110, 30)]:
        ground_light(L, gx, gy, rx, ry, "#ffb45a", 0.32)
    p = L.save(f"{out}/main.png")
    return layer_meta("main.png", L, p, 1.0, -10)


def fg_layer(out):
    f = 1.25
    W = _w(f)
    L = Layer(W, 520, x0=-M, y0=1150, scale=1.0)
    rng = random.Random(8)
    for i in range(int(W / 260) + 1):
        x = -40 + i * 260 + rng.random() * 60
        L.sheet(rect(x, 1260 + rng.random() * 60, 40, 500), "#17131f", grad=0.3, seed=i)
        L.sheet(ellipse(x + 20, 1262, 22, 8, 16), "#211c2a", seed=40 + i)
        # seaweed
        for k in range(3):
            L.sheet([(x + 4 + k * 10, 1500), (x + 10 + k * 10, 1430 - rng.random() * 40), (x + 14 + k * 10, 1500)], "#1d2a26", seed=80 + i * 3 + k)
    L.sheet(ellipse(W * 0.45, 1420, 40, 40, 30), "#a33a32", seed=200)
    L.sheet(ellipse(W * 0.45, 1420, 40, 12, 30), "#e9dcc0", seed=201, shadow=0)
    rope(L, sag(-M, 1330, W * 0.45, 1400, 30), "#8a7a5a", 5)
    p = L.save(f"{out}/fg.png")
    return layer_meta("fg.png", L, p, f, 10, group="fg")


def build(out):
    midm, beam = mid(out)
    layers = [far(out), midm, main_layer(out), fg_layer(out)]
    return {"width": S, "height": 1600, "horizon": HZ, "sea": True, "beam": beam,
            "layers": [l for l in layers if l], "props": [ferry(out)]}
