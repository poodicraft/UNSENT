"""The Lamp Room at the top of the Hushwater Light (sky and sea show through the glass)."""
import math
import random

from paperlib import (Layer, arc_pts, darken_bottom, ellipse, ground_light, layer_meta, layer_text, rect, rrect,
                      shade, wobble)
from props import BRASS, INK, IRON, LIT, LIT_HOT, WOOD, WOOD_DARK

S = 1200
M = 60
FLOOR = 990
IRON_C = "#2a2836"
IRON_L = "#3a3848"


def main_layer(out):
    L = Layer(S + 2 * M, 1900, x0=-M, y0=-200, scale=1.0)
    # the glass gallery: an iron frame with big transparent panes
    panes = []
    for i, x in enumerate(range(470, S + M, 150)):
        panes.append(rect(x + 10, 250, 130, 600))
    L.sheet([rect(-M, -200, S + 2 * M, FLOOR + 200)], IRON_C, holes=panes, grad=0.1, shadow=0, seed=1)
    # faint reflections on the glass
    for i, x in enumerate(range(470, S + M, 150)):
        L.sheet([(x + 24, 262), (x + 52, 262), (x + 22, 520), (x + 14, 520)], "#ffffff", shadow=0, edge=0, alpha=0.06, seed=10 + i)
        L.ink([(x + 10, 250), (x + 140, 250), (x + 140, 850), (x + 10, 850), (x + 10, 250)], IRON_L, 4)
    # riveted dome band
    L.sheet(rect(-M, 196, S + 2 * M, 40), IRON_L, seed=2)
    for x in range(-M + 10, S + M, 26):
        L.sheet(ellipse(x, 216, 3, 3, 8), "#5a586a", shadow=0.1, seed=3 + x)
    # left: solid wall section (stair housing) with the star chart
    L.sheet(rect(-M, 250, 520, FLOOR - 250), "#3a3242", grad=0.12, seed=4)
    for y in range(280, FLOOR, 60):
        L.ink([(-M, y), (460, y)], "#2e2836", 2, alpha=0.6)
    # star chart pinned to the wall
    L.sheet(rect(268, 466, 176, 238), "#e8dcc0", grad=0.08, shadow=0.35, seed=5)
    rng = random.Random(14)
    for i in range(60):
        L.sheet(ellipse(280 + rng.random() * 152, 480 + rng.random() * 200, 1.8, 1.8, 6), "#3a3a5a", shadow=0, edge=0, seed=20 + i)
    crown = [(320, 620), (350, 598), (382, 612)]
    L.ink(crown, "#8a3a3a", 1.5, alpha=0.7)
    for (cx, cy) in crown:
        L.ink(arc_pts(cx, cy, 10, 10, 0, math.tau, 16), "#a33a32", 1.6)
        L.sheet(ellipse(cx, cy, 3, 3, 8), "#2a2a4a", shadow=0, edge=0, seed=90 + cx)
    layer_text(L, 356, 652, "ROSA'S CROWN", "Caveat.ttf", 17, "#8a3a3a")
    layer_text(L, 356, 672, "14 · X · 85", "Caveat.ttf", 14, "#8a3a3a")
    layer_text(L, 356, 488, "WESTERN SKY", "Cinzel.ttf", 9, "#5a4a5a")
    for (px, py) in ((274, 470), (438, 470)):
        L.sheet(ellipse(px, py, 4, 4, 8), "#a33a32", seed=100 + px)
    # a little shelf: oil can & matches
    L.sheet(rect(60, 560, 150, 12), WOOD, seed=110)
    L.sheet([(80, 560), (116, 560), (110, 504), (86, 504)], "#4a6a5a", seed=111)
    L.ink([(110, 516), (136, 496)], "#4a6a5a", 4)
    L.sheet(rect(150, 538, 40, 22), "#c84a32", seed=112)
    # the floor: iron grating
    L.sheet(rect(-M, FLOOR, S + 2 * M, 800), "#2a2734", grad_color="#16141e", seed=113)
    for x in range(-M, S + M, 28):
        L.ink([(x, FLOOR + 4), (x - (x - 600) * 0.4, 1700)], "#3a3746", 2, alpha=0.6)
    for k in range(10):
        y = FLOOR + 10 + k * k * 7
        L.ink([(-M, y), (S + M, y)], "#3a3746", 2, alpha=0.6)
    # low iron wall under the windows
    L.sheet(rect(460, 850, S + M - 460, FLOOR - 850), IRON_L, seed=114)
    for x in range(480, S + M, 150):
        L.sheet(rrect(x, 866, 120, FLOOR - 890, 6), IRON_C, shadow=0.2, shadow_off=(-2, -2), shadow_blur=2, edge=0.15, seed=115 + x)
    # railing
    L.ink([(460, 800), (S + M, 800)], "#4a4858", 5)
    # stair hatch with the top of the spiral stair
    L.sheet(ellipse(146, FLOOR + 10, 96, 24, 30), "#0e0c14", seed=120)
    L.ink(arc_pts(146, FLOOR + 10, 96, 24, math.pi, 2 * math.pi, 20), "#5a586a", 4)
    for k in range(5):
        L.ink([(70 + k * 34, FLOOR - 70), (70 + k * 34, FLOOR + 4)], "#4a4858", 4)
    L.ink([(66, FLOOR - 70), (226, FLOOR - 70)], "#4a4858", 5)
    # pedestal + the great Fresnel lens
    cx = 600
    L.sheet([(cx - 120, FLOOR), (cx - 90, 810), (cx + 90, 810), (cx + 120, FLOOR)], IRON_L, seed=130)
    L.sheet(rect(cx - 110, 796, 220, 20), BRASS, seed=131)
    lens_out = [(cx - 140, 800)] + arc_pts(cx, 520, 140, 290, math.pi * 0.98, math.pi * 2.02, 30)[::1] + [(cx + 140, 800)]
    L.sheet(lens_out, "#cfe2ea", alpha=0.42, shadow=0.15, seed=132)
    for k in range(7):
        y = 330 + k * 66
        half = 140 * math.sqrt(max(0.0, 1 - ((y - 520) / 300) ** 2))
        L.sheet([(cx - half, y - 6), (cx + half, y - 6), (cx + half, y + 6), (cx - half, y + 6)], BRASS, alpha=0.85, shadow=0.1, seed=140 + k)
    for k in range(6):
        y = 360 + k * 66
        half = 132 * math.sqrt(max(0.0, 1 - ((y - 520) / 300) ** 2))
        L.sheet([(cx - half + 8, y - 22), (cx + half - 8, y - 22), (cx + half - 2, y + 22), (cx - half + 2, y + 22)], "#e8f4f8", alpha=0.18, shadow=0, edge=0.1, seed=160 + k)
    L.ink([(cx, 230), (cx, 180)], BRASS, 6)
    # brass burner inside the lens
    L.sheet(rrect(cx - 26, 600, 52, 90, 8), BRASS, grad=0.25, seed=170)
    L.sheet(rrect(cx - 10, 576, 20, 28, 6), "#5a4220", seed=171)
    # the auto-lamp box
    bx = 846
    L.sheet(rrect(bx, 760, 150, 220, 8), "#8a6a2a", grad=0.2, seed=180)
    L.sheet(rrect(bx + 16, 790, 118, 90, 6), "#1e1a1e", seed=181)
    for (gx, gy, r) in ((bx + 52, 836, 28), (bx + 96, 826, 20), (bx + 100, 860, 14)):
        L.sheet(ellipse(gx, gy, r, r, 24), "#c9a14a", seed=182 + gx)
        L.sheet(ellipse(gx, gy, r * 0.35, r * 0.35, 12), "#5a4220", shadow=0, seed=190 + gx)
    L.sheet(rect(bx + 20, 900, 110, 30), "#e8dcc0", seed=195)
    layer_text(L, bx + 75, 910, "AUTO-LAMP MK II", "Cinzel.ttf", 9, "#3a2a1a")
    layer_text(L, bx + 75, 922, "INSTALLED 1998", "Cinzel.ttf", 7, "#3a2a1a")
    for k in range(6):
        L.sheet(ellipse(bx + 10 + k * 26, 976, 7, 4, 8), "#e8e4dc", alpha=0.7, shadow=0, edge=0, seed=196 + k)
    darken_bottom(L, 1100, 1700, amount=0.5)
    p = L.save(f"{out}/main.png")
    return layer_meta("main.png", L, p, 1.0, -10)


def build(out):
    return {"width": S, "height": 1600, "horizon": 700, "sky": True, "sea": True,
            "layers": [main_layer(out)], "props": []}
