"""UI textures (letter papers, panels), FX sprites, splash screen and app icons."""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from paperlib import (FONT_DIR, Layer, _value_noise, ellipse, grain_tile, hexc, layer_text, mottle_tile, rect,
                      rrect, shade, wobble)


def _save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def _tileable_noise(n, cells, seed, octaves=4):
    acc = np.zeros((n, n), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        acc += _value_noise(n, cells * (2 ** o), seed + o) * amp
        tot += amp
        amp *= 0.5
    acc /= tot
    acc = (acc - acc.min()) / (acc.max() - acc.min() + 1e-6)
    return acc


# ─── FX ─────────────────────────────────────────────────────────────

def fx(out):
    d = os.path.join(out, "fx")
    n = 256
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.sqrt((xx - n / 2 + 0.5) ** 2 + (yy - n / 2 + 0.5) ** 2) / (n / 2)
    a = np.clip(1 - r, 0, 1) ** 2.4
    img = np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a])
    _save(Image.fromarray((img * 255).astype(np.uint8), "RGBA"), f"{d}/glow.png")
    n = 32
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.sqrt((xx - n / 2 + 0.5) ** 2 + (yy - n / 2 + 0.5) ** 2) / (n / 2)
    a = np.clip(1 - r, 0, 1) ** 1.6
    img = np.dstack([np.ones_like(a)] * 3 + [a])
    _save(Image.fromarray((img * 255).astype(np.uint8), "RGBA"), f"{d}/dot.png")
    # leaf
    im = Image.new("RGBA", (48, 30), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    dr.polygon([(2, 15), (16, 3), (38, 6), (46, 15), (38, 24), (16, 27)], fill=(196, 104, 58, 255))
    dr.line([(4, 15), (44, 15)], fill=(140, 70, 40, 255), width=2)
    _save(im, f"{d}/leaf.png")
    # rain streak
    im = Image.new("RGBA", (6, 96), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    for y in range(96):
        dr.point([(2, y), (3, y)], fill=(255, 255, 255, int(255 * (y / 96) ** 1.5)))
    _save(im, f"{d}/rain.png")
    # mist puff
    n = 128
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.sqrt((xx - n / 2) ** 2 + (yy - n / 2) ** 2) / (n / 2)
    nz = _tileable_noise(n, 4, 3, 3)
    a = np.clip(1 - r, 0, 1) ** 1.5 * (0.6 + 0.4 * nz)
    img = np.dstack([np.ones_like(a)] * 3 + [a])
    _save(Image.fromarray((img * 255).astype(np.uint8), "RGBA"), f"{d}/mist.png")
    # clouds (tileable, greyscale) for the sky shader
    c = _tileable_noise(512, 4, 21, 5)
    _save(Image.fromarray((c * 255).astype(np.uint8), "L").convert("RGB"), f"{d}/clouds.png")
    # noise for the film grain overlay
    rng = np.random.default_rng(5)
    nz = rng.random((256, 256)).astype(np.float32)
    _save(Image.fromarray((nz * 255).astype(np.uint8), "L").convert("RGB"), f"{d}/noise.png")
    # paper grain for puppets
    g = grain_tile(256)
    g = (g - g.min()) / (g.max() - g.min())
    _save(Image.fromarray((g * 255).astype(np.uint8), "L").convert("RGB"), f"{d}/grain.png")


# ─── paper ──────────────────────────────────────────────────────────

def _paper(w, h, color, seed, deckle=True, shadow=True, grain=0.07, mottle=0.06, stains=0, fold=True):
    """A sheet of paper with soft shadow, deckled edge, grain, mottling and an optional fold."""
    pad = 24
    L = Layer(w + pad * 2, h + pad * 2, x0=-pad, y0=-pad, scale=1.0)
    pts = wobble(rect(0, 0, w, h), 1.6 if deckle else 0.3, seed, step=10)
    L.sheet(pts, color, grad=0.05, grain=grain, mottle=mottle, shadow=0.45 if shadow else 0,
            shadow_off=(0, 6), shadow_blur=10, edge=0.06, seed=seed)
    rng = random.Random(seed)
    for i in range(stains):
        cx, cy = rng.random() * w, rng.random() * h
        r = 30 + rng.random() * 60
        L.sheet(ellipse(cx, cy, r, r * (0.7 + rng.random() * 0.5), 30), shade(color, -0.12), shadow=0, edge=0,
                alpha=0.18, grain=0.1, seed=seed + 10 + i)
    if fold:
        L.ink([(6, h * 0.34), (w - 6, h * 0.34)], shade(color, -0.1), 2, alpha=0.5)
        L.ink([(6, h * 0.34 + 2), (w - 6, h * 0.34 + 2)], shade(color, 0.12), 2, alpha=0.5)
        L.ink([(6, h * 0.67), (w - 6, h * 0.67)], shade(color, -0.1), 2, alpha=0.5)
    return L


def papers(out):
    d = os.path.join(out, "ui")
    W, H = 600, 860
    # fine cream stationery (Odile) with a deckle edge
    L = _paper(W, H, "#f4ead6", 1, stains=2)
    L.save(f"{d}/paper_fine.png")
    # hotel stationery with letterhead (Theo)
    L = _paper(W, H, "#f2ead9", 2, deckle=False, stains=1)
    layer_text(L, W / 2, 34, "HARBOR ARMS HOTEL", "Cinzel.ttf", 22, "#7a3a3a", spacing=3)
    layer_text(L, W / 2, 62, "Dockside · Port Ardent · Rooms by the Night", "Lora-Italic.ttf", 13, "#8a6a5a")
    L.ink([(40, 80), (W - 40, 80)], "#7a3a3a", 2, alpha=0.7)
    L.sheet(ellipse(W - 90, H - 120, 54, 50, 40), "#b88a5a", shadow=0, edge=0, alpha=0.18, holes=[ellipse(W - 90, H - 120, 44, 40, 40)], seed=3)
    L.save(f"{d}/paper_hotel.png")
    # airmail (June, far shore) with red/blue chevrons
    L = _paper(W, H, "#eef3f7", 3, deckle=False, grain=0.05, fold=True)
    for i in range(0, W + H, 34):
        for (x0, y0, dx, dy) in ((i, 0, 1, 0), (i - W, H, 1, 0)):
            pass
    k = 0
    for x in range(-20, W + 20, 26):
        c = "#c8403a" if k % 2 == 0 else "#2f5aa0"
        L.sheet([(x, 0), (x + 14, 0), (x + 4, 14), (x - 10, 14)], c, shadow=0, edge=0, seed=100 + k)
        L.sheet([(x, H), (x + 14, H), (x + 24, H - 14), (x + 10, H - 14)], c, shadow=0, edge=0, seed=200 + k)
        k += 1
    layer_text(L, W - 110, 40, "PAR AVION", "Cinzel.ttf", 14, "#2f5aa0")
    L.save(f"{d}/paper_airmail.png")
    # lighthouse logbook page (June, lamp room)
    L = _paper(W, H, "#efe6cf", 4, deckle=True, stains=3)
    layer_text(L, W / 2, 40, "HUSHWATER LIGHT — LOG", "Cinzel.ttf", 18, "#2a3a5a", spacing=2)
    L.ink([(30, 62), (W - 30, 62)], "#2a3a5a", 2)
    for y in range(110, H - 20, 40):
        L.ink([(30, y), (W - 30, y)], "#8aa0c0", 1.4, alpha=0.6)
    L.ink([(84, 66), (84, H - 10)], "#c86a6a", 1.6, alpha=0.6)
    L.sheet(ellipse(W - 140, H - 200, 70, 40, 30), "#c8b080", shadow=0, edge=0, alpha=0.2, seed=5)
    L.save(f"{d}/paper_logbook.png")
    # ferry ticket book page (Bram)
    L = _paper(W, H, "#f1dfbe", 5, deckle=False, stains=1, fold=False)
    L.sheet(rect(0, 0, W, 70), "#e3c690", shadow=0, edge=0, seed=6)
    layer_text(L, W / 2, 26, "MORNING LARK", "Cinzel.ttf", 20, "#5a2a26", spacing=3)
    layer_text(L, W / 2, 52, "PASSENGER TICKET · No. 0417", "Cinzel.ttf", 12, "#5a2a26")
    for x in range(10, W, 16):
        L.sheet(ellipse(x, 78, 3, 3, 8), "#c8aa78", shadow=0, edge=0, seed=7)
    L.save(f"{d}/paper_ticket.png")
    # typed sheet, water-stained (Felix)
    L = _paper(W, H, "#f6f2ea", 6, deckle=False, stains=5, grain=0.05)
    rng = random.Random(4)
    for i in range(6):
        x = rng.random() * W
        L.ink([(x, 0), (x + rng.random() * 30 - 15, H)], "#e0d6c6", 3, alpha=0.4)
    L.save(f"{d}/paper_typed.png")
    # bakery paper bag (Mari)
    L = _paper(W, H, "#cdaa7c", 7, deckle=True, grain=0.09, mottle=0.08, fold=True)
    L.sheet(ellipse(W - 110, 90, 70, 70, 40), "#8a3a2a", shadow=0, edge=0, alpha=0.18, holes=[ellipse(W - 110, 90, 60, 60, 40)], seed=8)
    layer_text(L, W - 110, 82, "THE SLEEPLESS", "Cinzel.ttf", 11, "#6a2a1a", alpha=0.45)
    layer_text(L, W - 110, 100, "LOAF", "Cinzel.ttf", 15, "#6a2a1a", alpha=0.45)
    for i in range(40):
        L.sheet(ellipse(rng.random() * W, rng.random() * H, 2 + rng.random() * 3, 2 + rng.random() * 3, 8), "#f6efe0", shadow=0, edge=0, alpha=0.4, seed=9)
    L.save(f"{d}/paper_kraft.png")
    # silver future paper (W.)
    L = _paper(W, H, "#e9eef5", 8, deckle=False, grain=0.04, mottle=0.05)
    for i in range(30):
        x, y = rng.random() * W, rng.random() * H
        L.glow(x, y, 30 + rng.random() * 40, "#c8dcff", 0.12)
    L.ink(rect(16, 16, W - 32, H - 32), "#a8b8d0", 2, alpha=0.7, closed=True)
    L.save(f"{d}/paper_silver.png")
    # generic UI panel (consequence cards)
    L = _paper(256, 256, "#f2e8d5", 9, deckle=True, stains=0, fold=False)
    L.save(f"{d}/panel_paper.png")


# ─── splash & icon ──────────────────────────────────────────────────

def _envelope(L, cx, cy, w, h, angle=0.0, seed=1):
    def rot(pts):
        ca, sa = math.cos(angle), math.sin(angle)
        return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in pts]
    x0, y0 = cx - w / 2, cy - h / 2
    L.sheet(rot(rect(x0, y0, w, h)), "#f3e8d2", shadow=0.5, shadow_off=(4, 10), shadow_blur=14, seed=seed)
    L.sheet(rot([(x0, y0 + h), (cx, cy + h * 0.02), (x0 + w, y0 + h)]), "#e8dcc2", shadow=0.15, shadow_off=(0, -2), shadow_blur=3, seed=seed + 1)
    L.sheet(rot([(x0, y0), (cx, cy + h * 0.16), (x0 + w, y0)]), "#ebdfc6", shadow=0.3, shadow_off=(0, 4), shadow_blur=5, seed=seed + 2)
    # wax seal
    sx, sy = cx, cy + h * 0.14
    pts = []
    for i in range(36):
        a = i / 36 * math.tau
        r = w * 0.13 * (1 + 0.06 * math.sin(i * 2.7))
        pts.append((sx + math.cos(a) * r, sy + math.sin(a) * r))
    L.sheet(rot(pts), "#a3322c", shadow=0.4, shadow_off=(2, 4), shadow_blur=4, grad=0.2, seed=seed + 3)
    L.sheet(rot(ellipse(sx, sy, w * 0.085, w * 0.085, 30)), "#8e2a25", shadow=0.15, shadow_off=(-1, -1), shadow_blur=2, edge=0.2, seed=seed + 4)
    return rot


def icon(out):
    d = os.path.join(out, "icon")
    os.makedirs(d, exist_ok=True)
    N = 432
    # background: dusk gradient with stars and a low sun glow
    L = Layer(N, N, scale=1.0)
    L.gradient_rect(0, 0, N, N, "#1d1f48", "#e99a78")
    rng = random.Random(3)
    for i in range(26):
        x, y = rng.random() * N, rng.random() * N * 0.55
        L.glow(x, y, 4 + rng.random() * 4, "#fff4d8", 0.9)
    L.glow(N * 0.5, N * 1.02, N * 0.6, "#ffd29c", 0.55)
    bg = L.save(f"{d}/icon_bg_432.png", opaque=True)
    # foreground: envelope + seal, inside the adaptive-icon safe zone
    F = Layer(N, N, scale=1.0)
    _envelope(F, N / 2, N / 2 + 6, 210, 140, angle=-0.12, seed=10)
    img = F.to_image()
    img = img.resize((N, N), Image.LANCZOS)
    _save(img, f"{d}/icon_fg_432.png")
    # monochrome: white silhouette
    mono = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    a = img.split()[3]
    mono.putalpha(a)
    white = Image.new("RGBA", (N, N), (255, 255, 255, 255))
    white.putalpha(a)
    _save(white, f"{d}/icon_mono_432.png")
    # flattened legacy icons
    base = Image.open(f"{d}/icon_bg_432.png").convert("RGBA")
    base.alpha_composite(img)
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, N - 1, N - 1], radius=96, fill=255)
    flat = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    flat.paste(base, (0, 0), mask)
    _save(flat.resize((192, 192), Image.LANCZOS), f"{d}/icon_192.png")
    _save(flat.resize((256, 256), Image.LANCZOS), f"{d}/icon.png")


def splash(out):
    W, H = 720, 1280
    L = Layer(W, H, scale=1.0)
    L.gradient_rect(0, 0, W, H, "#121225", "#121225")
    L.glow(W / 2, H * 0.43, 300, "#2a2a55", 0.6)
    _envelope(L, W / 2, H * 0.4, 230, 152, angle=-0.08, seed=20)
    layer_text(L, W / 2 + 7, H * 0.56, "UNSENT", "Cinzel.ttf", 64, "#f3ead9", spacing=12)
    L.ink([(W / 2 - 90, H * 0.6), (W / 2 + 90, H * 0.6)], "#d9b46c", 2)
    layer_text(L, W / 2, H * 0.625, "CHAPTER ONE · THE LONG DUSK", "Cinzel.ttf", 16, "#d9b46c")
    L.save(os.path.join(out, "ui", "splash.png"), opaque=True)


def build(out):
    fx(out)
    papers(out)
    icon(out)
    splash(out)
    print("  ui: fx, papers, icon, splash")
