"""Lantern Square: clock tower & workshop, fountain, the bakery, the post office front."""
import math
import random

from paperlib import (Layer, arc_pts, darken_bottom, ellipse, ground_light, layer_meta, layer_text, mix, rect, ridge,
                      rrect, shade, wobble)
from props import (BRASS, INK, IRON, LIT, LIT_HOT, TRIM, WOOD, WOOD_DARK, awning, barrel, bench, cobbles, crate,
                   door, flowers, house, lamp_post, rope, sag, stone_wall, window)

S = 2200          # scene width
V = 720
M = 80            # side margin
BASE = 936        # building base line


def _w(f):
    return V + (S - V) * f + 2 * M


def far(out):
    f = 0.14
    L = Layer(_w(f), 420, x0=-M, y0=560, scale=0.5)
    L.sheet(ridge(-M, _w(f), 830, 55, 21, bottom=980), "#6c5f93", shadow=0.15, seed=1)
    rng = random.Random(4)
    # far hill cottages & a windmill
    for i in range(16):
        x = -40 + i * 75 + rng.random() * 30
        y = 812 - math.sin(x * 0.004 + 1.3) * 30 + rng.random() * 8
        L.sheet(rect(x, y - 16, 18, 16), "#5a4f80", shadow=0.1, seed=10 + i)
        L.sheet([(x - 3, y - 15), (x + 9, y - 26), (x + 21, y - 15)], "#4b4170", shadow=0.05, seed=30 + i)
        if rng.random() < 0.5:
            L.glow(x + 9, y - 8, 12, "#ffc070", 0.6)
    wx = 820
    L.sheet([(wx - 8, 790), (wx + 8, 790), (wx + 5, 740), (wx - 5, 740)], "#4b4170", seed=50)
    for a in range(4):
        ang = a * math.pi / 2 + 0.4
        L.ink([(wx, 742), (wx + math.cos(ang) * 46, 742 + math.sin(ang) * 46)], "#4b4170", 4)
    L.sheet(ridge(-M, _w(f), 880, 26, 23, bottom=980), "#56497e", shadow=0.2, seed=2)
    L.tint("#e9a07f", 0.12)
    p = L.save(f"{out}/far.png")
    return layer_meta("far.png", L, p, f, -40)


def mid(out):
    f = 0.42
    W = _w(f)
    L = Layer(W, 560, x0=-M, y0=420, scale=0.75)
    rng = random.Random(9)
    x = -M
    i = 0
    cols = ["#433a6c", "#4a3f72", "#3d3566", "#463c6f"]
    while x < W:
        w = 70 + rng.random() * 70
        h = 130 + rng.random() * 170
        top = 900 - h
        c = cols[i % len(cols)]
        L.sheet(wobble(rect(x, top, w, h + 80), 0.8, i), c, shadow=0.25, seed=i)
        rt = rng.choice(["gable", "gable", "steep", "flat"])
        if rt == "gable":
            L.sheet([(x - 6, top + 2), (x + w / 2, top - 40 - rng.random() * 20), (x + w + 6, top + 2)], shade(c, -0.18), shadow=0.1, seed=i + 100)
        elif rt == "steep":
            L.sheet([(x - 4, top + 2), (x + w / 2, top - 80), (x + w + 4, top + 2)], shade(c, -0.2), shadow=0.1, seed=i + 100)
        if rng.random() < 0.6:
            cx = x + w * rng.random() * 0.7 + 8
            L.sheet(rect(cx, top - 40, 12, 40), shade(c, -0.25), shadow=0.05, seed=i + 200)
        for _ in range(int(h / 50)):
            wx = x + 10 + rng.random() * (w - 30)
            wy = top + 20 + rng.random() * (h - 60)
            lit = rng.random() < 0.55
            L.sheet(rect(wx, wy, 13, 18), "#ffd18a" if lit else "#2d2a4c", shadow=0, edge=0, seed=i + 300)
            if lit:
                L.glow(wx + 6, wy + 9, 26, "#ffb050", 0.45)
        x += w - 4
        i += 1
    # church spire
    sx = W * 0.62
    L.sheet(rect(sx, 560, 60, 360), "#3b3364", seed=900)
    L.sheet([(sx - 6, 562), (sx + 30, 400), (sx + 66, 562)], "#332c5a", seed=901)
    L.sheet(rect(sx + 22, 600, 16, 26), "#ffd18a", shadow=0, edge=0, seed=902)
    L.glow(sx + 30, 612, 40, "#ffb050", 0.5)
    L.tint("#c98aa0", 0.08)
    p = L.save(f"{out}/mid.png")
    return layer_meta("mid.png", L, p, f, -30)


def clock_tower(L):
    x0, x1 = 210, 510
    # tower body
    L.sheet(wobble(rect(x0, 120, x1 - x0, BASE - 120), 0.8, 1), "#8a7f9a", grad=0.14, seed=1)
    L.sheet(rect(x1 - 18, 120, 18, BASE - 120), "#6d6382", shadow=0, edge=0, alpha=0.8, seed=2)
    # stone courses
    for i, y in enumerate(range(150, BASE - 20, 46)):
        L.ink([(x0 + 4, y), (x1 - 4, y)], "#6f6585", 2, alpha=0.5)
    # copper spire
    L.sheet([(x0 - 22, 126), (x0 + 30, 40), (x1 - 30, 40), (x1 + 22, 126)], "#4f7a6e", grad=0.18, seed=3)
    L.sheet([(x0 + 20, 44), ((x0 + x1) / 2, -110), (x1 - 20, 44)], "#456c62", grad=0.2, seed=4)
    L.sheet(rect(x0 - 26, 120, x1 - x0 + 52, 14), "#cfc0a6", seed=5)
    L.ink([((x0 + x1) / 2, -110), ((x0 + x1) / 2, -160)], IRON, 4)
    # clock face
    cx, cy = 360, 300
    L.sheet(ellipse(cx, cy, 98, 98, 64), "#cfc0a6", seed=6)
    L.sheet(ellipse(cx, cy, 86, 86, 64), "#f0e4c8", grad=0.06, shadow=0.15, shadow_off=(-2, -2), shadow_blur=3, seed=7)
    for h in range(12):
        a = h / 12 * math.tau - math.pi / 2
        r0, r1 = (68, 80) if h % 3 else (60, 80)
        L.ink([(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * r1, cy + math.sin(a) * r1)], "#2a2232", 4 if h % 3 == 0 else 2.5)
    layer_text(L, cx, cy + 40, "HARROW", "Cinzel.ttf", 11, "#6a5a4a")
    # balcony + telescope
    L.sheet(rect(x0 - 14, 470, x1 - x0 + 70, 16), "#5f566f", seed=8)
    for bx in range(x0 - 8, x1 + 56, 16):
        L.ink([(bx, 438), (bx, 470)], IRON, 3)
    L.ink([(x0 - 12, 438), (x1 + 54, 438)], IRON, 4)
    L.sheet([(470, 452), (580, 410), (586, 424), (476, 466)], BRASS, grad=0.2, shadow=0.3, seed=9)
    L.sheet(ellipse(583, 417, 9, 9, 12), "#8a6a2a", seed=10)
    L.ink([(500, 456), (492, 470)], IRON, 3)
    L.ink([(500, 456), (512, 470)], IRON, 3)
    # tall arched window
    window(L, 330, 560, 60, 110, lit=True, arch=True, panes=(2, 3), frame="#cfc0a6", seed=11)
    # workshop front at the base
    L.sheet(rect(186, 690, 320, BASE - 690), "#4a3a46", seed=12)
    L.sheet(rect(176, 676, 340, 30), "#2f2530", seed=13)
    layer_text(L, 346, 691, "HARROW · CLOCKS & INSTRUMENTS", "Cinzel.ttf", 13, "#e8c77a")
    # shop window: lit, with clock silhouettes and the typewriter
    L.sheet(rect(200, 716, 190, 170), LIT_HOT, grad_color="#ffae58", shadow=0, edge=0, seed=14)
    for i, (ccx, ccy, r) in enumerate([(232, 760, 20), (282, 750, 26), (338, 768, 18), (240, 820, 14), (360, 820, 22)]):
        L.sheet(ellipse(ccx, ccy, r, r, 24), "#6a4a3a", shadow=0.15, shadow_off=(1, 2), shadow_blur=1, seed=20 + i)
        L.sheet(ellipse(ccx, ccy, r * 0.75, r * 0.75, 24), "#f3e6c8", shadow=0, edge=0, seed=40 + i)
        L.ink([(ccx, ccy), (ccx, ccy - r * 0.5)], INK, 2)
        L.ink([(ccx, ccy), (ccx + r * 0.4, ccy)], INK, 2)
    L.ink([(200, 716), (390, 716), (390, 886), (200, 886), (200, 716)], "#2f2530", 6)
    L.ink([(295, 716), (295, 886)], "#2f2530", 4)
    L.glow(295, 800, 190, "#ffb04a", 0.4)
    # typewriter in the window
    tx, ty = 410, 896
    L.sheet(rect(396, 840, 92, 60), LIT_HOT, grad_color="#ffb45a", shadow=0, edge=0, seed=60)
    L.sheet([(404, 896), (482, 896), (476, 870), (410, 870)], "#1e1a20", seed=61)
    L.sheet(rect(414, 852, 58, 18), "#f6f0e2", seed=62)
    L.ink([(400, 840), (490, 840), (490, 900), (400, 900), (400, 840)], "#2f2530", 5)
    # workshop door
    door(L, 434, 742, 58, BASE - 742 - 10, "#6a4a3a", arch=False, glass=True, seed=63)


def bakery(L):
    x, w = 1180, 480
    top = house(L, x, BASE, w, 470, "#c9955f", "#6b3d48", roof_h=120, roof_type="mansard", seed=70, chimney=True)
    # sign board — over the shop window, clear of the lamp above the door
    # (the lamp hangs at x 1420..1470, so the board must end before it)
    L.sheet(rect(1190, 626, 214, 46), "#3a2a2a", seed=71)
    L.ink(rect(1194, 630, 206, 38), "#e8c77a", 2, closed=True)
    layer_text(L, 1297, 649, "THE SLEEPLESS LOAF", "Cinzel.ttf", 18, "#f3dfb0")
    # upstairs windows
    for i, wx in enumerate((1210, 1330, 1450, 1560)):
        window(L, wx, 500, 66, 86, lit=(i != 2), panes=(2, 2), seed=72 + i * 3, curtain="#b0605a")
    flowers(L, 1204, 606, 82, seed=90)
    flowers(L, 1444, 606, 82, seed=91)
    # display window with awning + loaves
    L.sheet(rect(1196, 708, 168, 206), "#3a2a2a", seed=92)
    L.sheet(rect(1204, 716, 152, 190), LIT_HOT, grad_color="#ffad55", shadow=0, edge=0, seed=93)
    for r in range(3):
        L.sheet(rect(1206, 760 + r * 50, 148, 6), "#7a5a40", seed=94 + r)
        for k in range(4):
            lx = 1218 + k * 34
            ly = 744 + r * 50
            L.sheet(ellipse(lx + 13, ly + 8, 15, 10, 16), "#b9783e", shadow=0.25, shadow_off=(1, 2), shadow_blur=1.5, seed=100 + r * 4 + k)
            L.ink([(lx + 5, ly + 5), (lx + 21, ly + 3)], "#e9b880", 2, alpha=0.8)
    L.glow(1280, 810, 170, "#ffa64a", 0.45)
    awning(L, 1186, 690, 186, depth=44, seed=110)
    # the blue door
    door(L, 1380, 700, 130, BASE - 700 - 10, "#3f6faa", arch=True, glass=True, seed=120, frame="#e9dcc0")
    # iron lamp bracket over the door (the lamp itself is a prop)
    L.ink([(1445, 640), (1445, 612), (1474, 612)], IRON, 5)
    L.ink([(1458, 640), (1474, 616)], IRON, 3)
    # green umbrella hanging on a hook
    L.ink([(1546, 770), (1546, 782)], IRON, 3)
    L.sheet([(1532, 786), (1560, 786), (1552, 942), (1540, 942)], "#3f7a5a", grad=0.18, seed=125)
    L.ink([(1540, 800), (1546, 940)], "#2d5a42", 2)
    L.ink([(1553, 800), (1548, 940)], "#2d5a42", 2)
    L.sheet(ellipse(1546, 783, 8, 5, 10), "#7a4a2a", seed=126)
    # chalkboard A-frame
    # (wide enough that every chalk line sits inside the board)
    L.sheet([(1570, 992), (1588, 846), (1666, 846), (1684, 992)], "#5a4030", seed=127)
    L.sheet([(1580, 972), (1595, 858), (1659, 858), (1674, 972)], "#24262c", seed=128, edge=0.05)
    for i, t in enumerate(("CINNAMON", "LOAVES", "4 o'clock", "every morning")):
        layer_text(L, 1627, 880 + i * 22, t, "Caveat.ttf", 14 if i < 2 else 12, "#f2efe6", alpha=0.9)


def post_office_front(L):
    x, w = 1880, 340
    # crooked tall building, leaning slightly
    pts = [(x, BASE), (x + 8, 230), (x + w + 4, 210), (x + w, BASE)]
    L.sheet(wobble(pts, 0.8, 140), "#6e7ea2", grad=0.12, seed=140)
    L.sheet([(x + w - 14, BASE), (x + w - 6, 212), (x + w + 4, 210), (x + w, BASE)], "#5a6a8c", shadow=0, edge=0, seed=141)
    L.sheet([(x - 18, 236), (x + w / 2 + 6, 110), (x + w + 22, 214)], "#3d3756", seed=142)
    L.sheet(rect(x + 230, 120, 30, 90), "#4a4260", seed=143)
    for i, wx in enumerate((1912, 2040, 2150)):
        window(L, wx, 300 - i * 4, 54, 84, lit=True, panes=(2, 2), seed=144 + i * 3)
        window(L, wx + 2, 450 - i * 4, 54, 84, lit=(i != 1), panes=(2, 2), seed=160 + i * 3)
    # sign
    L.sheet(rect(1950, 590, 250, 44), "#1f2a44", seed=180)
    L.ink(rect(1954, 594, 242, 36), "#e8c77a", 2, closed=True)
    layer_text(L, 2075, 612, "POST OFFICE", "Cinzel.ttf", 22, "#f0d89a", spacing=2)
    # blue door + lamp bracket (lamp always lit)
    door(L, 2005, 690, 130, BASE - 690 - 10, "#2f5f9a", arch=True, glass=True, seed=181, frame="#e9dcc0")
    L.ink([(2071, 652), (2071, 638), (2096, 638)], IRON, 5)
    L.sheet([(2052, 652), (2090, 652), (2084, 690), (2058, 690)], LIT_HOT, grad_color="#ffb45a", shadow=0.15, edge=0.04, seed=182)
    L.sheet([(2046, 654), (2071, 632), (2096, 654)], IRON, seed=183)
    L.glow(2071, 670, 110, "#ffb04a", 0.6)
    # letterbox slot
    L.sheet(rrect(2148, 800, 40, 14, 3), BRASS, seed=184)
    layer_text(L, 2168, 826, "LETTERS", "Cinzel.ttf", 8, "#e8d6a8")


def main_layer(out):
    L = Layer(S + 2 * M, 1600 + 200, x0=-M, y0=-200, scale=1.0)
    # ground
    cobbles(L, -M, S + M, BASE - 8, 1600, seed=300)
    # far kerb line
    L.sheet(rect(-M, BASE - 14, S + 2 * M, 12), "#6c6680", shadow=0.25, shadow_off=(0, 4), seed=301)
    # left: lane arch / stone wall
    stone_wall(L, -M, 640, 200, BASE - 640, seed=302)
    L.sheet(arc_pts(40, 760, 50, 70, math.pi, 2 * math.pi, 18) + [(90, BASE - 12), (-10, BASE - 12)], "#1d1a2e", shadow=0, seed=303)
    # buildings in the gaps (behind the main set)
    house(L, 520, BASE, 140, 360, "#7d8aa8", "#3d3756", roof_h=90, seed=310)
    window(L, 548, 640, 40, 60, lit=True, seed=311)
    window(L, 600, 640, 40, 60, lit=False, seed=312)
    window(L, 560, 760, 70, 90, lit=True, panes=(3, 2), seed=313, curtain="#6a7a5a")
    house(L, 1640, BASE, 250, 300, "#b98088", "#5a3a44", roof_h=80, seed=320)
    window(L, 1680, 700, 50, 70, lit=True, seed=321)
    window(L, 1790, 700, 50, 70, lit=True, seed=322, curtain="#d6c08a")
    clock_tower(L)
    bakery(L)
    post_office_front(L)
    # notice board
    L.sheet(rect(650, 820, 10, 150), WOOD_DARK, seed=330)
    L.sheet(rect(760, 820, 10, 150), WOOD_DARK, seed=331)
    L.sheet(rect(640, 758, 140, 110), WOOD, seed=332)
    L.sheet([(632, 760), (710, 730), (788, 760)], WOOD_DARK, seed=333)
    for i, (nx, ny, nw, nh, c) in enumerate([(652, 772, 56, 70, "#efe6d2"), (714, 770, 54, 44, "#f3dcb0"), (716, 818, 52, 40, "#e7eef3")]):
        L.sheet(rect(nx, ny, nw, nh), c, shadow=0.25, shadow_off=(2, 3), shadow_blur=2, seed=334 + i)
        first = 22 if i == 0 else 10     # the first notice has a title; lines start below it
        for k in range(int((nh - first) / 9)):
            L.ink([(nx + 6, ny + first + k * 9), (nx + nw - 8, ny + first + k * 9)], "#6a6070", 1.4, alpha=0.6)
    layer_text(L, 680, 782, "LANTERN", "Cinzel.ttf", 7, "#8a3a30")
    # fountain
    fx = 980
    L.sheet(ellipse(fx, 900, 130, 26, 40), "#77718c", seed=340)
    L.sheet(rect(fx - 128, 900, 256, 60), "#827c98", seed=341)
    L.sheet(ellipse(fx, 960, 128, 26, 40, 0, math.pi), "#6c6684", seed=342)
    L.sheet(ellipse(fx, 902, 112, 18, 40), "#4a6a8a", grad_color="#7aa0b8", shadow=0, edge=0.04, seed=343)
    L.sheet(rect(fx - 16, 760, 32, 140), "#8a84a0", seed=344)
    L.sheet(ellipse(fx, 772, 54, 12, 30), "#8a84a0", seed=345)
    L.sheet([(fx - 18, 760), (fx - 30, 720), (fx, 700), (fx + 30, 714), (fx + 18, 760)], "#9a94ad", seed=346)
    for k in range(5):
        a = math.pi * (0.15 + k * 0.17)
        L.ink(arc_pts(fx, 706, 40 + k * 4, 60, math.pi + 0.3, math.pi + 1.2, 10) if k % 2 else arc_pts(fx, 706, 40 + k * 4, 60, -1.2, -0.3, 10), "#c8e0ee", 2, alpha=0.5)
    # lamp posts
    lamp_post(L, 820, 980, 300, lit=True, seed=350)
    lamp_post(L, 1700, 985, 300, lit=True, seed=351)
    bench(L, 1720, 992, seed=352)
    barrel(L, 1120, 960, seed=353)
    crate(L, 150, 970, 52, seed=354)
    flowers(L, 1110, 980, 60, seed=355, box="#5a4a5a")
    # festoon lights across the square
    pts = sag(560, 470, 1186, 560, 70)
    L.ink(pts, "#1a1622", 2.5)
    for i, (px, py) in enumerate(pts[1:-1:2]):
        c = ["#ffd38a", "#ffb0a0", "#c8f0d0", "#ffd38a"][i % 4]
        L.sheet(ellipse(px, py + 9, 6, 8, 12), c, shadow=0.1, edge=0, seed=360 + i)
        L.glow(px, py + 9, 26, "#ffc070", 0.5)
    pts2 = sag(1660, 520, 1880, 470, 40)
    L.ink(pts2, "#1a1622", 2.5)
    for i, (px, py) in enumerate(pts2[1:-1:3]):
        L.sheet(ellipse(px, py + 9, 6, 8, 12), "#ffd38a", shadow=0.1, edge=0, seed=380 + i)
        L.glow(px, py + 9, 26, "#ffc070", 0.5)
    # pools of light on the cobbles, puddles, and a soft falloff towards the viewer
    for (gx, gy, rx, ry, st) in [(820, 1000, 170, 44, 0.32), (1700, 1004, 170, 44, 0.32), (1278, 960, 150, 34, 0.3),
                                 (295, 962, 170, 36, 0.28), (2071, 962, 130, 32, 0.28), (360, 960, 60, 14, 0.15)]:
        ground_light(L, gx, gy, rx, ry, "#ffb45a", st)
    rng = random.Random(5)
    for i, (px, py, pw) in enumerate([(610, 1180, 120), (1350, 1240, 160), (1880, 1150, 110), (200, 1300, 140)]):
        L.sheet(ellipse(px, py, pw, pw * 0.16, 30), "#3a3a5c", grad_color="#5a5070", shadow=0, edge=0.02, alpha=0.85, seed=400 + i)
        L.ink([(px - pw * 0.5, py - 2), (px + pw * 0.3, py - 4)], "#c8a8a0", 2, alpha=0.4)
    leaves = []
    for i in range(40):
        lx, ly = rng.random() * S, 960 + rng.random() * 560
        leaves.append(ellipse(lx, ly, 7, 3.5, 8))
    L.sheet(leaves, "#b0603a", shadow=0.25, shadow_off=(1, 2), shadow_blur=1, seed=420)
    darken_bottom(L, 1120, 1600, amount=0.55)
    p = L.save(f"{out}/main.png")
    return layer_meta("main.png", L, p, 1.0, -10)


def fg_layer(out):
    f = 1.28
    W = V + (S - V) * f + 2 * M
    L = Layer(W, 700, x0=-M, y0=1080, scale=1.0)
    rng = random.Random(77)
    # dark kerb & cobble lip at the very bottom
    L.sheet(ridge(-M, W, 1500, 10, 5, step=10, bottom=1800), "#15122a", shadow=0.4, seed=1)
    # foreground objects: bollards, a cart wheel, flower pots
    for i, x in enumerate((160, 820, 1460, 2240, 2840)):
        if x > W - 60:
            continue
        L.sheet(rrect(x, 1380, 54, 140, 18), "#191630", seed=10 + i)
        L.sheet(ellipse(x + 27, 1384, 30, 10, 20), "#221e3a", seed=30 + i)
    wx = 1200
    L.sheet(ellipse(wx, 1420, 96, 96, 48), "#191630", seed=50)
    L.sheet(ellipse(wx, 1420, 78, 78, 48), "#100d20", shadow=0, edge=0, seed=51, holes=None)
    for k in range(8):
        a = k * math.pi / 4
        L.ink([(wx, 1420), (wx + math.cos(a) * 82, 1420 + math.sin(a) * 82)], "#191630", 9)
    for i in range(12):
        x = rng.random() * W
        L.sheet(ellipse(x, 1560 + rng.random() * 40, 26 + rng.random() * 20, 14, 16), "#120f22", shadow=0.3, seed=60 + i)
    p = L.save(f"{out}/fg.png")
    return layer_meta("fg.png", L, p, f, 10, group="fg")


def props(out):
    meta = []
    # bakery lamp: dark and lit versions
    L = Layer(80, 90, x0=1405, y0=600, scale=1.0)
    L.sheet([(1426, 640), (1464, 640), (1458, 680), (1432, 680)], "#3a3f5c", grad_color="#2a2e48", shadow=0.25, seed=1)
    L.sheet([(1420, 642), (1445, 620), (1470, 642)], IRON, seed=2)
    L.sheet(rect(1430, 678, 30, 6), IRON, seed=3)
    p = L.save(f"{out}/lamp_dark.png")
    m = layer_meta("lamp_dark.png", L, p, 1.0, -5)
    m["if"] = "not $bakery_lamp_lit"
    meta.append(m)
    L = Layer(80, 90, x0=1405, y0=600, scale=1.0)
    L.sheet([(1426, 640), (1464, 640), (1458, 680), (1432, 680)], LIT_HOT, grad_color="#ffb45a", shadow=0.15, edge=0.03, seed=4)
    L.sheet([(1420, 642), (1445, 620), (1470, 642)], IRON, seed=5)
    L.sheet(rect(1430, 678, 30, 6), IRON, seed=6)
    L.ink([(1445, 644), (1445, 676)], IRON, 2)
    p = L.save(f"{out}/lamp_lit.png")
    m = layer_meta("lamp_lit.png", L, p, 1.0, -5)
    m["if"] = "$bakery_lamp_lit"
    meta.append(m)
    meta.append({"kind": "clock", "mode": "tower", "x": 360, "y": 300, "r": 78, "z": -4})
    return meta


def build(out):
    layers = [far(out), mid(out), main_layer(out), fg_layer(out)]
    return {"width": S, "height": 1600, "horizon": 900, "layers": [l for l in layers if l], "props": props(out)}
