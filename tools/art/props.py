"""Reusable cut-paper props for UNSENT scenes."""
import math
import random

from paperlib import (Layer, arc_pts, ellipse, layer_text, mix, rect, ridge, rrect,
                      shade, wobble)

TRIM = "#e3d5b8"
GLASS_DARK = "#2b3050"
LIT = "#ffd387"
LIT_HOT = "#fff0c2"
INK = "#1d1830"
IRON = "#26222f"
WOOD = "#5c4334"
WOOD_DARK = "#3f2d24"
BRASS = "#c9a14a"


def window(L: Layer, x, y, w, h, lit=True, arch=False, panes=(2, 2), frame=TRIM, seed=0, sill=True, curtain=None):
    """A window with frame, glass, glazing bars and sill. Lit windows glow."""
    fr = 6
    outer = rrect(x - fr, y - fr, w + fr * 2, h + fr * 2, w / 2 + fr if arch else 3)
    if arch:
        outer = arc_pts(x + w / 2, y + w / 2, w / 2 + fr, w / 2 + fr, math.pi, 2 * math.pi, 16) + [(x + w + fr, y + h + fr), (x - fr, y + h + fr)]
    L.sheet(wobble(outer, 0.6, seed), frame, shadow=0.25, shadow_off=(3, 4), shadow_blur=4, seed=seed)
    glass = rect(x, y, w, h)
    if arch:
        glass = arc_pts(x + w / 2, y + w / 2, w / 2, w / 2, math.pi, 2 * math.pi, 16) + [(x + w, y + h), (x, y + h)]
    if lit:
        L.sheet(glass, LIT_HOT, grad_color="#ffb45a", shadow=0, edge=0, grain=0.02, mottle=0.06, seed=seed + 1)
    else:
        L.sheet(glass, GLASS_DARK, grad_color="#3c4266", shadow=0, edge=0, grain=0.03, seed=seed + 1)
    if curtain and lit:
        L.sheet([(x, y), (x + w * 0.28, y), (x + w * 0.16, y + h * 0.7), (x, y + h)], curtain, shadow=0.1, shadow_off=(2, 2), shadow_blur=2, seed=seed + 2)
        L.sheet([(x + w, y), (x + w * 0.72, y), (x + w * 0.84, y + h * 0.7), (x + w, y + h)], curtain, shadow=0.1, shadow_off=(-2, 2), shadow_blur=2, seed=seed + 3)
    cols, rows = panes
    bar = shade(frame, -0.15)
    for i in range(1, cols):
        xx = x + w * i / cols
        L.ink([(xx, y + (w / 2 if arch else 0) * 0), (xx, y + h)], bar, 3)
    for j in range(1, rows):
        yy = y + h * j / rows
        L.ink([(x, yy), (x + w, yy)], bar, 3)
    if sill:
        L.sheet(rect(x - fr - 6, y + h + fr - 2, w + fr * 2 + 12, 9), shade(frame, -0.08), shadow=0.3, shadow_off=(2, 4), shadow_blur=3, seed=seed + 4)
    if lit:
        L.glow(x + w / 2, y + h / 2, max(w, h) * 1.2, "#ffb04a", 0.35)


def door(L: Layer, x, y, w, h, color, arch=True, glass=True, knob=BRASS, seed=0, frame=TRIM, lit_glass=True):
    fr = 8
    outer = rrect(x - fr, y - fr, w + fr * 2, h + fr + 2, (w / 2 + fr) if arch else 4)
    L.sheet(wobble(outer, 0.5, seed), frame, shadow=0.28, shadow_off=(3, 4), shadow_blur=5, seed=seed)
    body = rrect(x, y, w, h, w / 2 if arch else 3)
    L.sheet(body, color, grad=0.12, shadow=0.0, edge=0.1, seed=seed + 1)
    # panels
    pc = shade(color, -0.12)
    ph = h * 0.26
    L.sheet(rrect(x + w * 0.16, y + h * 0.58, w * 0.68, ph, 3), pc, shadow=0.12, shadow_off=(-1, -1), shadow_blur=1.5, edge=0.18, seed=seed + 2)
    if glass:
        gy = y + (w * 0.35 if arch else h * 0.12)
        gh = h * 0.28
        gw = w * 0.56
        if lit_glass:
            L.sheet(rrect(x + (w - gw) / 2, gy, gw, gh, 4), LIT, grad_color="#ffb45a", shadow=0, edge=0, seed=seed + 3)
            L.glow(x + w / 2, gy + gh / 2, gw * 1.3, "#ffa040", 0.25)
        else:
            L.sheet(rrect(x + (w - gw) / 2, gy, gw, gh, 4), GLASS_DARK, shadow=0, edge=0, seed=seed + 3)
        L.ink([(x + w / 2, gy), (x + w / 2, gy + gh)], shade(color, -0.3), 3)
    L.sheet(ellipse(x + w * 0.82, y + h * 0.52, 5, 5, 12), knob, shadow=0.3, shadow_off=(1, 2), shadow_blur=1.5, seed=seed + 4)
    # step
    L.sheet(rect(x - fr - 10, y + h, w + fr * 2 + 20, 10), "#8d8496", shadow=0.3, shadow_off=(2, 4), shadow_blur=3, seed=seed + 5)


def house(L: Layer, x, base, w, h, wall, roof, roof_h=110, roof_type="gable", seed=0, overhang=16,
          chimney=True, trim=TRIM, quoins=False):
    """Wall + roof. Returns the wall's top y."""
    top = base - h
    L.sheet(wobble(rect(x, top, w, h), 0.9, seed), wall, grad=0.12, seed=seed)
    # side shade on the right (light from the sunset on the left)
    L.sheet(rect(x + w - 14, top, 14, h), shade(wall, -0.12), shadow=0, edge=0, alpha=0.7, seed=seed + 1)
    if quoins:
        for i in range(int(h / 34)):
            yy = top + i * 34 + 4
            ww = 22 if i % 2 == 0 else 14
            L.sheet(rect(x, yy, ww, 26), shade(wall, 0.08), shadow=0.12, shadow_off=(1, 2), shadow_blur=1.5, edge=0.12, seed=seed + 10 + i)
    if chimney:
        cx = x + w * (0.72 if seed % 2 else 0.24)
        L.sheet(wobble(rect(cx, top - roof_h - 30, 30, roof_h + 20), 0.6, seed + 2), shade(wall, -0.25), seed=seed + 2)
        L.sheet(rect(cx - 5, top - roof_h - 38, 40, 12), shade(wall, -0.35), seed=seed + 3)
    if roof_type == "gable":
        pts = [(x - overhang, top + 4), (x + w / 2, top - roof_h), (x + w + overhang, top + 4)]
    elif roof_type == "mansard":
        pts = [(x - overhang, top + 4), (x + 10, top - roof_h * 0.75), (x + w * 0.2, top - roof_h), (x + w * 0.8, top - roof_h),
               (x + w - 10, top - roof_h * 0.75), (x + w + overhang, top + 4)]
    elif roof_type == "shed":
        pts = [(x - overhang, top + 4), (x - overhang, top - roof_h * 0.4), (x + w + overhang, top - roof_h), (x + w + overhang, top + 4)]
    else:  # flat with parapet
        pts = rect(x - 6, top - 26, w + 12, 30)
    L.sheet(wobble(pts, 0.8, seed + 4), roof, grad=0.1, seed=seed + 4)
    # roof tiles: scalloped lines
    if roof_type in ("gable", "mansard"):
        rl = shade(roof, -0.18)
        for i in range(1, int(roof_h / 18)):
            yy = top - i * 18
            frac = i * 18 / roof_h
            if roof_type == "gable":
                half = (w / 2 + overhang) * (1 - frac)
                xa, xb = x + w / 2 - half + 4, x + w / 2 + half - 4
            else:
                xa, xb = x + 8, x + w - 8
            if xb - xa > 10:
                L.ink([(xa, yy), (xb, yy)], rl, 2, alpha=0.6)
    # eave trim
    L.sheet(rect(x - overhang - 2, top - 2, w + overhang * 2 + 4, 9), trim, shadow=0.3, shadow_off=(2, 4), shadow_blur=3, seed=seed + 5)
    return top


def lamp_post(L: Layer, x, base, h=330, lit=True, seed=0, arm=False):
    L.sheet(rect(x - 7, base - h, 14, h), IRON, grad=0.2, seed=seed)
    L.sheet(rrect(x - 20, base - 24, 40, 24, 6), IRON, seed=seed + 1)
    ly = base - h - 52
    if arm:
        L.ink([(x, base - h + 10), (x + 46, base - h - 6)], IRON, 6)
        x = x + 46
        ly = base - h - 36
    L.sheet([(x - 24, ly + 10), (x + 24, ly + 10), (x + 16, ly + 52), (x - 16, ly + 52)], LIT_HOT if lit else GLASS_DARK, grad_color="#ffb45a" if lit else None, shadow=0.2, edge=0.05, seed=seed + 2)
    L.sheet([(x - 30, ly + 12), (x, ly - 14), (x + 30, ly + 12)], IRON, seed=seed + 3)
    L.sheet(rect(x - 20, ly + 50, 40, 8), IRON, seed=seed + 4)
    L.ink([(x, ly + 10), (x, ly + 52)], IRON, 3)
    if lit:
        L.glow(x, ly + 30, 120, "#ffb04a", 0.55)
    return (x, ly + 30)


def awning(L: Layer, x, y, w, depth=46, colors=("#e9dcc0", "#a34a3c"), seed=0):
    n = max(4, int(w / 34))
    sw = w / n
    for i in range(n):
        c = colors[i % 2]
        pts = [(x + i * sw, y), (x + (i + 1) * sw, y), (x + (i + 1) * sw + 6, y + depth), (x + i * sw + 6, y + depth)]
        L.sheet(pts, c, shadow=0.35 if i == 0 else 0.0, shadow_off=(4, 10), shadow_blur=8, edge=0.08, seed=seed + i)
        # scalloped edge
        L.sheet(ellipse(x + i * sw + sw / 2 + 6, y + depth, sw / 2, 9, 12, 0, math.pi), c, shadow=0.15, shadow_off=(1, 3), shadow_blur=2, seed=seed + 20 + i)


def cobbles(L: Layer, x0, x1, y0, y1, base="#4a4560", stone="#5b5571", seed=0):
    L.sheet(rect(x0, y0, x1 - x0, y1 - y0), base, grad_color=shade(base, -0.25), shadow=0, edge=0, seed=seed)
    rng = random.Random(seed)
    stones = []
    y = y0 + 6
    row = 0
    while y < y1:
        persp = 1.0 + (y - y0) / 260.0
        sh = 9 * persp
        sw = 22 * persp
        x = x0 - (row % 2) * sw * 0.5
        while x < x1:
            w = sw * (0.7 + rng.random() * 0.5)
            stones.append(ellipse(x + w / 2, y + sh / 2, w / 2 - 1.5, sh / 2 - 1, 10))
            x += w + 3
        y += sh + 3
        row += 1
    L.sheet(stones, stone, shadow=0.35, shadow_off=(1, 2), shadow_blur=1.5, edge=0.18, grain=0.06, seed=seed + 1)


def planks(L: Layer, x0, x1, y0, y1, color="#6a5146", seed=0, horizontal=True, gap="#3a2c2a"):
    L.sheet(rect(x0, y0, x1 - x0, y1 - y0), color, grad_color=shade(color, -0.3), shadow=0, edge=0, seed=seed)
    rng = random.Random(seed)
    y = y0
    i = 0
    while y < y1:
        hgt = 14 + (y - y0) * 0.09
        L.ink([(x0, y), (x1, y)], gap, 2.2, alpha=0.8)
        # board ends
        xx = x0 + rng.random() * 200
        while xx < x1:
            L.ink([(xx, y), (xx, y + hgt)], gap, 2, alpha=0.6)
            xx += 160 + rng.random() * 220
        y += hgt
        i += 1


def stone_wall(L: Layer, x, y, w, h, color="#7b7690", seed=0):
    L.sheet(rect(x, y, w, h), shade(color, -0.25), seed=seed, shadow=0.3)
    rng = random.Random(seed)
    blocks = []
    yy = y + 3
    r = 0
    while yy < y + h - 4:
        bh = 18 + rng.random() * 8
        xx = x + 3 - (r % 2) * 18
        while xx < x + w - 4:
            bw = 30 + rng.random() * 26
            blocks.append(rrect(max(x + 3, xx), yy, min(bw, x + w - 3 - max(x + 3, xx)), bh - 3, 4))
            xx += bw + 3
        yy += bh
        r += 1
    L.sheet(blocks, color, shadow=0.25, shadow_off=(1, 2), shadow_blur=1.5, edge=0.2, seed=seed + 1)


def bench(L: Layer, x, base, w=170, color=WOOD, seed=0):
    L.sheet(rect(x + 10, base - 40, 10, 40), IRON, seed=seed)
    L.sheet(rect(x + w - 20, base - 40, 10, 40), IRON, seed=seed + 1)
    L.sheet(rrect(x, base - 52, w, 14, 4), color, seed=seed + 2)
    L.sheet(rrect(x + 4, base - 96, w - 8, 12, 4), color, seed=seed + 3)
    L.sheet(rrect(x + 4, base - 76, w - 8, 12, 4), color, seed=seed + 4)
    L.ink([(x + 14, base - 98), (x + 14, base - 52)], IRON, 5)
    L.ink([(x + w - 14, base - 98), (x + w - 14, base - 52)], IRON, 5)


def crate(L: Layer, x, base, s=60, color="#7a5a40", seed=0):
    L.sheet(wobble(rect(x, base - s, s, s), 0.6, seed), color, seed=seed)
    d = shade(color, -0.3)
    L.ink([(x + 4, base - s + 4), (x + s - 4, base - 4)], d, 4, alpha=0.7)
    L.ink(rect(x + 3, base - s + 3, s - 6, s - 6), d, 3, alpha=0.6, closed=True)


def barrel(L: Layer, x, base, w=56, h=78, color="#6e4a32", seed=0):
    pts = [(x + 6, base - h), (x + w - 6, base - h), (x + w, base - h / 2), (x + w - 6, base), (x + 6, base), (x, base - h / 2)]
    L.sheet(pts, color, seed=seed)
    for f in (0.2, 0.8):
        L.ink([(x + 3, base - h * f), (x + w - 3, base - h * f)], IRON, 4)


def flowers(L: Layer, x, base, w, colors=("#d9708a", "#f0c060", "#e6e0f0"), seed=0, box="#6a4a3a"):
    L.sheet(rect(x, base - 22, w, 22), box, seed=seed)
    rng = random.Random(seed)
    leaves = [ellipse(x + rng.random() * w, base - 24 - rng.random() * 16, 9, 6, 8) for _ in range(int(w / 8))]
    L.sheet(leaves, "#3f6a4e", shadow=0.2, shadow_off=(1, 2), shadow_blur=2, seed=seed + 1)
    dots = []
    for i in range(int(w / 10)):
        dots.append(ellipse(x + rng.random() * w, base - 28 - rng.random() * 18, 5, 5, 8))
    L.sheet(dots, colors[seed % len(colors)], shadow=0.2, shadow_off=(1, 2), shadow_blur=1.5, seed=seed + 2)


def grass_tufts(L: Layer, x0, x1, y, color="#2c3a3a", h=26, density=0.12, seed=0):
    rng = random.Random(seed)
    blades = []
    x = x0
    while x < x1:
        hh = h * (0.5 + rng.random())
        lean = (rng.random() - 0.5) * 14
        blades.append([(x - 3, y + 2), (x + lean, y - hh), (x + 3, y + 2)])
        x += 1.0 / density * (0.4 + rng.random())
    L.sheet(blades, color, shadow=0.2, shadow_off=(2, 3), shadow_blur=2, edge=0.05, seed=seed)


def rope(L: Layer, pts, color="#c8b48a", width=4):
    L.ink(pts, shade(color, -0.3), width + 2)
    L.ink(pts, color, width)


def sag(x0, y0, x1, y1, depth, n=24):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + math.sin(t * math.pi) * depth))
    return pts
