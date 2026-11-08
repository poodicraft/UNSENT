"""The Office of Unsent Letters (interior)."""
import math
import random

from paperlib import (Layer, arc_pts, darken_bottom, ellipse, ground_light, layer_meta, layer_text, rect, ridge,
                      rrect, shade, wobble)
from props import BRASS, INK, IRON, LIT, LIT_HOT, TRIM, WOOD, WOOD_DARK, crate, door, planks, rope, sag, window

S = 1800
M = 60
FLOOR = 962
WALL = "#4c6862"
WALL2 = "#557069"
WAINSCOT = "#4a3428"


def wall_and_floor(L):
    L.sheet(rect(-M, -200, S + 2 * M, FLOOR + 210), WALL, grad=0.1, shadow=0, edge=0, seed=1)
    # wallpaper: vertical stripes with tiny diamonds
    stripes = []
    for x in range(-M, S + M, 44):
        stripes.append(rect(x, -200, 14, 780))
    L.sheet(stripes, WALL2, shadow=0, edge=0, alpha=0.7, seed=2)
    dots = []
    for x in range(-M + 29, S + M, 44):
        for y in range(-180, 560, 52):
            dots.append([(x, y - 6), (x + 5, y), (x, y + 6), (x - 5, y)])
    L.sheet(dots, "#6f8a80", shadow=0, edge=0, alpha=0.6, seed=3)
    # picture rail + wainscoting
    L.sheet(rect(-M, 572, S + 2 * M, 14), WOOD, seed=4)
    L.sheet(rect(-M, 586, S + 2 * M, FLOOR - 586), WAINSCOT, grad=0.12, seed=5)
    panels = [rrect(x, 618, 116, FLOOR - 660, 6) for x in range(-M + 20, S + M, 140)]
    L.sheet(panels, shade(WAINSCOT, 0.06), shadow=0.25, shadow_off=(-2, -3), shadow_blur=3, edge=0.2, seed=6)
    L.sheet(rect(-M, FLOOR - 22, S + 2 * M, 22), shade(WAINSCOT, -0.25), seed=7)
    # ceiling beams
    L.sheet(rect(-M, -200, S + 2 * M, 150), "#2e221e", seed=8)
    for x in range(-M, S + M, 300):
        L.sheet(rect(x, -60, 50, 70), "#3a2a24", seed=9 + x)
    L.sheet(rect(-M, -60, S + 2 * M, 34), "#3a2a24", seed=10)
    # floor
    planks(L, -M, S + M, FLOOR, 1700, "#6b4a3a", seed=11)
    # rug
    rug = [(640, 1004), (1320, 1004), (1360, 1110), (600, 1110)]
    L.sheet(rug, "#7a2f36", grad=0.15, seed=12)
    L.sheet([(660, 1012), (1300, 1012), (1336, 1100), (624, 1100)], "#8f3a40", shadow=0, seed=13)
    L.ink([(676, 1022), (1288, 1022), (1318, 1090), (642, 1090), (676, 1022)], "#d9b46c", 2.5, alpha=0.7)


def hanging_lamp(L, x, cord_top=-40, y=200):
    L.ink([(x, cord_top), (x, y - 30)], "#1e1a1a", 3)
    L.sheet([(x - 46, y), (x - 20, y - 34), (x + 20, y - 34), (x + 46, y)], "#2f5a4a", grad=0.2, seed=int(x))
    L.sheet(ellipse(x, y + 4, 18, 14, 16), LIT_HOT, grad_color="#ffc070", shadow=0, edge=0, seed=int(x) + 1)
    L.glow(x, y + 10, 160, "#ffbe70", 0.55)


def front_door(L):
    door(L, 62, 650, 128, FLOOR - 650 - 12, "#2f5f9a", arch=True, glass=False, seed=20, frame="#d8c9ad")
    # window in the door shows the dusky square
    L.sheet(rrect(96, 690, 60, 90, 28), "#f0a07c", grad_color="#55467f", shadow=0, edge=0, seed=21)
    L.ink([(126, 690), (126, 780)], "#24406a", 3)
    L.sheet(rect(70, FLOOR - 10, 120, 14), "#7a5a40", seed=22)
    # coat rack with a coat and scarf
    L.sheet(rect(28, 480, 8, 470), WOOD_DARK, seed=23)
    L.sheet([(18, 520), (60, 520), (54, 700), (22, 700)], "#3a3046", seed=24)
    L.sheet([(30, 524), (44, 524), (40, 640), (34, 640)], "#b84a3c", seed=25)


def umbrella_stand(L):
    x = 216
    L.sheet(rrect(x + 6, 880, 64, 84, 8), BRASS, grad=0.25, seed=30)
    L.ink([(x + 10, 900), (x + 66, 900)], "#8a6a2a", 2)
    L.sheet([(x + 22, 884), (x + 34, 884), (x + 30, 760), (x + 26, 760)], "#2e6a4e", seed=31)
    L.sheet([(x + 26, 760), (x + 30, 760), (x + 30, 738), (x + 26, 738)], "#5a3a2a", seed=32)
    L.sheet(arc_pts(x + 34, 740, 8, 8, math.pi, 2 * math.pi, 8), "#5a3a2a", seed=33)
    L.sheet([(x + 44, 884), (x + 56, 884), (x + 54, 790), (x + 48, 790)], "#22202a", seed=34)


def counter_back(L):
    # shelves behind the counter with parcels and jars
    L.sheet(rect(340, 380, 420, 14), WOOD, seed=40)
    L.sheet(rect(340, 486, 420, 14), WOOD, seed=41)
    rng = random.Random(4)
    x = 350
    while x < 740:
        w = 30 + rng.random() * 40
        h = 30 + rng.random() * 50
        c = rng.choice(["#b88a5a", "#a87a4a", "#c8a070", "#8a6a8a"])
        L.sheet(rect(x, 380 - h, w, h), c, shadow=0.3, shadow_off=(2, 3), shadow_blur=2, seed=50 + int(x))
        L.ink([(x + w / 2, 380 - h), (x + w / 2, 380)], "#e8dcc0", 2, alpha=0.7)
        x += w + 6
    x = 352
    while x < 740:
        L.sheet(rrect(x, 440, 26, 46, 6), rng.choice(["#6a8aa0", "#8a6aa0", "#a0886a"]), alpha=0.85, shadow=0.25, shadow_off=(2, 3), shadow_blur=2, seed=90 + int(x))
        x += 36
    # calendar
    L.sheet(rect(660, 520, 70, 90), "#efe6d2", shadow=0.3, seed=100)
    L.sheet(rect(660, 520, 70, 20), "#a33a32", seed=101)
    layer_text(L, 695, 530, "OCTOBER", "Cinzel.ttf", 9, "#f3e6cc")
    layer_text(L, 695, 570, "14", "Cinzel.ttf", 28, "#3a2a2a")


def wall_clock(L):
    cx, cy = 565, 360
    L.sheet(ellipse(cx, cy, 64, 64, 48), WOOD, seed=110)
    L.sheet(ellipse(cx, cy, 54, 54, 48), "#f2e6cc", shadow=0.1, shadow_off=(-2, -2), shadow_blur=2, seed=111)
    for h in range(12):
        a = h / 12 * math.tau - math.pi / 2
        L.ink([(cx + math.cos(a) * 42, cy + math.sin(a) * 42), (cx + math.cos(a) * 50, cy + math.sin(a) * 50)], INK, 2.5 if h % 3 == 0 else 1.5)
    layer_text(L, cx, cy + 24, "?", "Cinzel.ttf", 10, "#8a7a6a")


def archive(L):
    x0, x1, y0, y1 = 780, 1140, 300, 932
    L.sheet(rect(x0 - 14, y0 - 30, x1 - x0 + 28, y1 - y0 + 44), "#4a3226", seed=120)
    L.sheet(rect(x0 - 24, y0 - 44, x1 - x0 + 48, 22), "#3a261e", seed=121)
    cols, rows = 9, 13
    cw, ch = (x1 - x0) / cols, (y1 - y0) / rows
    holes = [rect(x0 + i * cw + 3, y0 + j * ch + 3, cw - 6, ch - 6) for i in range(cols) for j in range(rows)]
    L.sheet(holes, "#1e1612", shadow=0, edge=0, seed=122)
    rng = random.Random(9)
    env = []
    labels = []
    for i in range(cols):
        for j in range(rows):
            if rng.random() < 0.82:
                ex = x0 + i * cw + 6 + rng.random() * 4
                ey = y0 + j * ch + 10 + rng.random() * 6
                env.append([(ex, ey + 6), (ex + cw - 16, ey), (ex + cw - 14, ey + ch - 18), (ex + 2, ey + ch - 14)])
                labels.append(rect(x0 + i * cw + cw / 2 - 8, y0 + (j + 1) * ch - 9, 16, 5))
    L.sheet(env, "#efe4cc", shadow=0.3, shadow_off=(1, 2), shadow_blur=1.5, edge=0.1, seed=123)
    L.sheet(labels, "#8a6ab8", shadow=0, edge=0, seed=124)
    # sign above
    L.sheet(rect(x0 - 10, y0 - 120, x1 - x0 + 20, 58), "#1d2236", seed=125)
    L.ink(rect(x0 - 4, y0 - 114, x1 - x0 + 8, 46), "#d9b46c", 2, closed=True)
    layer_text(L, (x0 + x1) / 2, y0 - 91, "THE OFFICE OF UNSENT LETTERS", "Cinzel.ttf", 17, "#e8c77a")
    # rolling ladder
    L.ink([(1060, 260), (1010, FLOOR - 4)], "#6a4a34", 7)
    L.ink([(1100, 260), (1050, FLOOR - 4)], "#6a4a34", 7)
    for k in range(9):
        t = (k + 1) / 10
        L.ink([(1060 - 50 * t, 260 + (FLOOR - 264) * t), (1100 - 50 * t, 260 + (FLOOR - 264) * t)], "#6a4a34", 5)


def stairs(L):
    x0 = 1150
    L.sheet(rect(x0, 300, 100, FLOOR - 300), "#3a2a22", seed=130)
    steps = []
    for k in range(12):
        sy = FLOOR - 20 - k * 52
        steps.append(rect(x0 + 6, sy, 88, 12))
    L.sheet(steps, "#6a4a34", shadow=0.4, shadow_off=(2, 5), shadow_blur=3, seed=131)
    L.ink([(x0 + 96, FLOOR - 20), (x0 + 96, 300)], "#5a3e2c", 6)
    L.sheet(rect(x0 - 20, 286, 140, 18), "#2e221e", seed=132)
    layer_text(L, x0 + 50, 330, "PRIVATE", "Cinzel.ttf", 9, "#8a7a6a")


def chute(L):
    cx = 1355
    pipe = [(cx - 42, -200), (cx + 42, -200), (cx + 42, 700), (cx - 42, 700)]
    L.sheet(pipe, BRASS, grad_color="#8a6a2a", grad=0.0, seed=140)
    L.sheet(rect(cx - 42, -200, 20, 900), "#e8c878", shadow=0, edge=0, alpha=0.45, seed=141)
    for y in (40, 230, 420, 610):
        L.sheet(rect(cx - 50, y, 100, 22), "#a8822e", seed=142 + y)
        for k in range(5):
            L.sheet(ellipse(cx - 40 + k * 20, y + 11, 3, 3, 8), "#e8c878", shadow=0.1, seed=150 + y + k)
    # pressure gauge + little bell
    L.sheet(ellipse(cx + 66, 300, 26, 26, 30), "#8a6a2a", seed=160)
    L.sheet(ellipse(cx + 66, 300, 20, 20, 30), "#f2e6cc", shadow=0, seed=161)
    L.ink([(cx + 66, 300), (cx + 78, 290)], "#a33a32", 2)
    L.ink([(cx + 42, 300), (cx + 40, 300)], "#8a6a2a", 6)
    L.sheet(arc_pts(cx - 70, 470, 16, 16, math.pi, 2 * math.pi, 12) + [(cx - 54, 486), (cx - 86, 486)], BRASS, seed=162)
    L.ink([(cx - 70, 450), (cx - 42, 440)], "#8a6a2a", 3)
    # funnel mouth
    L.sheet([(cx - 42, 700), (cx + 42, 700), (cx + 70, 780), (cx - 70, 780)], BRASS, grad=0.25, seed=163)
    L.sheet(ellipse(cx, 780, 70, 14, 30), "#5a4220", seed=164)
    # wire basket
    bx0, bx1, by0, by1 = cx - 66, cx + 66, 808, 884
    L.sheet([(bx0, by0), (bx1, by0), (bx1 - 10, by1), (bx0 + 10, by1)], "#3a3a3a", alpha=0.25, seed=165)
    for k in range(9):
        x = bx0 + k * (bx1 - bx0) / 8
        L.ink([(x, by0), (x + (cx - x) * 0.15, by1)], "#2a2a2a", 2)
    for y in (by0, (by0 + by1) / 2, by1):
        L.ink([(bx0 + (y - by0) * 0.13, y), (bx1 - (y - by0) * 0.13, y)], "#2a2a2a", 3)
    L.ink([(cx - 60, 884), (cx - 70, FLOOR - 6)], "#2a2a2a", 4)
    L.ink([(cx + 60, 884), (cx + 70, FLOOR - 6)], "#2a2a2a", 4)
    layer_text(L, cx, 760, "THE CHUTE", "Cinzel.ttf", 9, "#3a2a10")


def outbox(L):
    x = 1472
    L.sheet(rrect(x, 770, 80, 190, 14), "#a83a32", grad=0.2, seed=170)
    L.sheet(arc_pts(x + 40, 790, 46, 30, math.pi, 2 * math.pi, 14) + [(x + 86, 792), (x - 6, 792)], "#8e2f29", seed=171)
    L.sheet(rrect(x + 16, 812, 48, 10, 3), "#1e1a1a", seed=172)
    L.sheet(rect(x + 14, 840, 52, 30), "#efe2c4", seed=173)
    layer_text(L, x + 40, 850, "OUTGOING", "Cinzel.ttf", 8, "#5a2a26")
    layer_text(L, x + 40, 862, "& BRAVE", "Cinzel.ttf", 7, "#5a2a26")


def stove(L):
    x = 1568
    L.ink([(x + 60, -200), (x + 60, 720)], "#1e1a1e", 22)
    L.sheet(ellipse(x + 60, 820, 62, 92, 36), "#24202a", seed=180)
    L.sheet(rect(x + 8, 900, 104, 40), "#24202a", seed=181)
    L.sheet(rrect(x + 26, 800, 68, 44, 10), "#ff8a3a", grad_color="#ffd27a", shadow=0, edge=0, seed=182)
    for k in range(4):
        L.ink([(x + 30 + k * 18, 800), (x + 30 + k * 18, 844)], "#1e1a1e", 3)
    L.glow(x + 60, 822, 150, "#ff8a3a", 0.5)
    L.sheet(rect(x + 14, 936, 12, 26), "#24202a", seed=183)
    L.sheet(rect(x + 94, 936, 12, 26), "#24202a", seed=184)
    # log basket
    L.sheet(rrect(x - 50, 910, 50, 46, 6), "#7a5a40", seed=185)
    for k in range(3):
        L.sheet(ellipse(x - 40 + k * 15, 906, 8, 8, 10), "#9a7a5a", seed=186 + k)


def back_door(L):
    door(L, 1700, 640, 96, FLOOR - 640 - 12, "#4a5f7a", arch=True, glass=False, seed=190, frame="#d8c9ad")
    L.sheet(ellipse(1748, 712, 30, 30, 30), "#b8a080", seed=191)
    L.sheet(ellipse(1748, 712, 23, 23, 30), "#e79a76", grad_color="#3f4a7a", shadow=0, edge=0, seed=192)
    L.ink([(1726, 718), (1770, 714)], "#2a3050", 2, alpha=0.7)


def wall_decor(L):
    # framed map of the coast
    L.sheet(rect(250, 160, 160, 120), WOOD, seed=200)
    L.sheet(rect(260, 170, 140, 100), "#e8dcc0", shadow=0.1, seed=201)
    L.ink([(270, 240), (300, 220), (330, 236), (360, 210), (390, 226)], "#5a7a9a", 3)
    L.sheet(ellipse(372, 200, 5, 5, 8), "#a33a32", seed=202)
    layer_text(L, 330, 182, "HUSHWATER", "Cinzel.ttf", 9, "#5a4a3a")
    # poster
    L.sheet(rect(1470, 170, 120, 160), "#e6d0a8", shadow=0.3, seed=203)
    layer_text(L, 1530, 196, "ROYAL", "Cinzel.ttf", 11, "#7a2a26")
    layer_text(L, 1530, 214, "MAIL", "Cinzel.ttf", 18, "#7a2a26")
    L.sheet([(1500, 250), (1560, 250), (1560, 300), (1500, 300)], "#efe4cc", shadow=0.1, seed=204)
    L.ink([(1500, 250), (1530, 274), (1560, 250)], "#7a2a26", 2)
    # potted fern
    L.sheet(rrect(1610, 524, 50, 46, 6), "#a0583a", seed=205)
    for k in range(7):
        a = -math.pi / 2 + (k - 3) * 0.32
        L.sheet([(1635, 526), (1635 + math.cos(a) * 60, 526 + math.sin(a) * 60 - 6), (1640, 526)], "#3f6a4e", shadow=0.2, seed=206 + k)
    L.sheet(rect(1590, 570, 90, 10), WOOD, seed=214)


def main_layer(out):
    L = Layer(S + 2 * M, 1900, x0=-M, y0=-200, scale=1.0)
    wall_and_floor(L)
    wall_decor(L)
    counter_back(L)
    wall_clock(L)
    archive(L)
    stairs(L)
    chute(L)
    outbox(L)
    stove(L)
    front_door(L)
    umbrella_stand(L)
    back_door(L)
    for x in (450, 1000, 1520):
        hanging_lamp(L, x)
    for gx, gy, rx, ry in [(450, 1000, 220, 50), (1000, 1000, 260, 56), (1520, 1000, 220, 50), (1628, 980, 160, 40)]:
        ground_light(L, gx, gy, rx, ry, "#ffb45a", 0.3)
    darken_bottom(L, 1130, 1700, amount=0.5)
    p = L.save(f"{out}/main.png", opaque=False)
    return layer_meta("main.png", L, p, 1.0, -10)


def counter_prop(out):
    """The counter: y-sorted so Odile stands behind it and Wren in front."""
    L = Layer(470, 300, x0=318, y0=700, scale=1.0)
    x0, x1, top, base = 330, 770, 760, 996
    L.sheet(rect(x0, top, x1 - x0, base - top), "#6a4632", grad=0.15, seed=1)
    panels = [rrect(x, top + 40, 120, base - top - 64, 6) for x in range(x0 + 16, x1 - 100, 140)]
    L.sheet(panels, "#7a5240", shadow=0.25, shadow_off=(-2, -3), shadow_blur=3, edge=0.2, seed=2)
    L.sheet(rect(x0 - 12, top - 14, x1 - x0 + 24, 20), "#8a5e44", seed=3)
    L.ink([(x0, top + 22), (x1, top + 22)], BRASS, 4)
    # bell
    L.sheet(arc_pts(372, 742, 20, 22, math.pi, 2 * math.pi, 14) + [(392, 746), (352, 746)], BRASS, grad=0.3, seed=4)
    L.sheet(ellipse(372, 718, 4, 4, 8), "#8a6a2a", seed=5)
    L.sheet(rect(350, 744, 44, 6), "#4a3226", seed=6)
    # ledger & letters
    L.sheet([(430, 744), (530, 740), (532, 748), (430, 752)], "#efe4cc", seed=7)
    L.sheet([(436, 736), (520, 732), (522, 742), (436, 744)], "#3a4a6a", seed=8)
    # violet inkwell + pen
    L.sheet(rrect(612, 718, 40, 30, 6), "#c8c8d8", alpha=0.85, seed=9)
    L.sheet(rrect(616, 728, 32, 18, 4), "#5b3a8c", shadow=0, edge=0, seed=10)
    L.ink([(636, 718), (660, 690)], "#2a2a2a", 3)
    # teacup + saucer
    L.sheet(ellipse(704, 750, 26, 6, 20), "#efe4d6", seed=11)
    L.sheet([(686, 726), (722, 726), (716, 748), (692, 748)], "#efe4d6", seed=12)
    L.sheet(ellipse(704, 727, 18, 4, 16), "#8a5a32", shadow=0, edge=0, seed=13)
    L.ink(arc_pts(724, 736, 7, 8, -math.pi / 2, math.pi / 2, 8), "#efe4d6", 3)
    # small desk lamp
    L.ink([(746, 748), (746, 700)], BRASS, 3)
    L.sheet([(732, 702), (760, 702), (754, 684), (738, 684)], "#2f5a4a", seed=14)
    L.glow(746, 712, 60, "#ffb04a", 0.45)
    p = L.save(f"{out}/counter.png")
    m = layer_meta("counter.png", L, p, 1.0, 0)
    m["sort_y"] = 992
    return m


def fg_layer(out):
    f = 1.15
    W = 720 + (S - 720) * f + 2 * M
    L = Layer(W, 500, x0=-M, y0=1200, scale=1.0)
    # front edge of a sorting table + parcels, bottom left; a chair back, bottom right
    L.sheet(rect(-M, 1460, 420, 300), "#1d1512", seed=1)
    L.sheet(rect(-M, 1440, 440, 30), "#2a1e18", seed=2)
    for i, (x, w, h) in enumerate([(30, 90, 70), (130, 60, 50), (210, 80, 90)]):
        L.sheet(rect(x, 1440 - h, w, h), "#241a16", seed=3 + i)
    L.sheet(rrect(W - 380, 1380, 60, 400, 10), "#1d1512", seed=10)
    L.sheet(rrect(W - 260, 1380, 60, 400, 10), "#1d1512", seed=11)
    L.sheet(rrect(W - 400, 1360, 220, 40, 14), "#24191a", seed=12)
    p = L.save(f"{out}/fg.png")
    return layer_meta("fg.png", L, p, f, 10, group="fg")


def build(out):
    layers = [main_layer(out), fg_layer(out)]
    props = [counter_prop(out), {"kind": "clock", "mode": "wall", "x": 565, "y": 360, "r": 44, "z": -4}]
    return {"width": S, "height": 1600, "horizon": 840, "layers": [l for l in layers if l], "props": props}
