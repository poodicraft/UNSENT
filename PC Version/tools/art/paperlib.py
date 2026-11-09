"""
paperlib — renders layered "cut paper" diorama art for UNSENT.

Every shape is a sheet of paper: a gradient fill with fibre grain and
mottling, a thin lit edge where the cut catches the light, and a soft drop
shadow cast onto whatever was drawn before it. Layers are rendered
supersampled in premultiplied RGBA and downsampled for clean edges.

Coordinates are design pixels (the game's 720-wide portrait space).
"""
from __future__ import annotations

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 2  # supersampling factor

# ─── shared noise tiles ──────────────────────────────────────────────
_NOISE = {}


def _value_noise(n: int, cells: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    g = rng.random((cells + 1, cells + 1)).astype(np.float32)
    g[-1, :] = g[0, :]
    g[:, -1] = g[:, 0]
    img = Image.fromarray((g * 255).astype(np.uint8), "L").resize((n, n), Image.BICUBIC)
    return np.asarray(img, np.float32) / 255.0


def grain_tile(n: int = 1024) -> np.ndarray:
    """Fine paper fibre grain in [-1, 1] (tileable)."""
    if "grain" in _NOISE:
        return _NOISE["grain"]
    rng = np.random.default_rng(7)
    fine = rng.random((n, n)).astype(np.float32)
    fine = np.asarray(Image.fromarray((fine * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255.0
    # fibres: short random strokes
    fib = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(fib)
    for _ in range(int(n * n / 900)):
        x, y = rng.random() * n, rng.random() * n
        a = rng.random() * math.pi
        ln = 6 + rng.random() * 22
        d.line([(x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln)], fill=int(90 + rng.random() * 120), width=1)
    fib = np.asarray(fib.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    mid = _value_noise(n, 48, 11)
    g = (fine - 0.5) * 0.9 + fib * 0.5 + (mid - 0.5) * 0.6
    g = (g - g.mean()) / (np.abs(g).max() + 1e-6)
    _NOISE["grain"] = g.astype(np.float32)
    return _NOISE["grain"]


def mottle_tile(n: int = 1024) -> np.ndarray:
    """Large soft blotches in [-1, 1] (tileable)."""
    if "mottle" in _NOISE:
        return _NOISE["mottle"]
    m = _value_noise(n, 6, 3) * 0.6 + _value_noise(n, 14, 5) * 0.4
    m = (m - m.mean()) / (np.abs(m - m.mean()).max() + 1e-6)
    _NOISE["mottle"] = m.astype(np.float32)
    return _NOISE["mottle"]


def _tile(t: np.ndarray, x0: int, y0: int, w: int, h: int, scale: float = 1.0) -> np.ndarray:
    n = t.shape[0]
    ys = (np.arange(y0, y0 + h) / scale).astype(np.int64) % n
    xs = (np.arange(x0, x0 + w) / scale).astype(np.int64) % n
    return t[np.ix_(ys, xs)]


def hexc(c) -> np.ndarray:
    if isinstance(c, str):
        c = c.lstrip("#")
        return np.array([int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)
    return np.array(c[:3], np.float32)


def mix(a, b, t) -> str:
    a, b = hexc(a), hexc(b)
    c = a + (b - a) * t
    return "#%02x%02x%02x" % tuple(int(max(0, min(1, v)) * 255) for v in c)


def shade(c, k) -> str:
    """k<0 darkens, k>0 lightens."""
    return mix(c, "#000000", -k) if k < 0 else mix(c, "#ffffff", k)


# ─── geometry helpers ────────────────────────────────────────────────

def rect(x, y, w, h):
    return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]


def ellipse(cx, cy, rx, ry, n=48, a0=0.0, a1=math.tau):
    pts = []
    for i in range(n):
        a = a0 + (a1 - a0) * i / n
        pts.append((cx + math.cos(a) * rx, cy + math.sin(a) * ry))
    return pts


def arc_pts(cx, cy, rx, ry, a0, a1, n=24):
    return [(cx + math.cos(a0 + (a1 - a0) * i / n) * rx, cy + math.sin(a0 + (a1 - a0) * i / n) * ry) for i in range(n + 1)]


def rrect(x, y, w, h, r, n=6):
    r = min(r, w / 2, h / 2)
    pts = []
    for cx, cy, a0 in ((x + w - r, y + r, -math.pi / 2), (x + w - r, y + h - r, 0), (x + r, y + h - r, math.pi / 2), (x + r, y + r, math.pi)):
        for i in range(n + 1):
            a = a0 + (math.pi / 2) * i / n
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def wobble(pts, amt=1.2, seed=0, step=18.0):
    """Subdivide and jitter edges so shapes look hand-cut."""
    rng = random.Random(seed)
    out = []
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        dist = math.hypot(b[0] - a[0], b[1] - a[1])
        k = max(1, int(dist / step))
        for j in range(k):
            t = j / k
            x = a[0] + (b[0] - a[0]) * t + (rng.random() - 0.5) * amt * 2
            y = a[1] + (b[1] - a[1]) * t + (rng.random() - 0.5) * amt * 2
            out.append((x, y))
    return out


def ridge(x0, x1, base, amp, seed, step=14.0, freqs=((0.004, 1.0), (0.011, 0.45), (0.03, 0.18)), bottom=None):
    """A landmass with a noisy top edge from x0..x1, closed at `bottom`."""
    rng = random.Random(seed)
    ph = [rng.random() * 100 for _ in freqs]
    pts = []
    x = x0
    while x <= x1 + step:
        y = base
        for (f, a), p in zip(freqs, ph):
            y -= math.sin(x * f + p) * amp * a
        pts.append((min(x, x1), y))
        x += step
    b = bottom if bottom is not None else base + amp * 3 + 400
    return pts + [(x1, b), (x0, b)]


def translate(pts, dx, dy):
    return [(x + dx, y + dy) for x, y in pts]


# ─── the layer ───────────────────────────────────────────────────────

class Layer:
    """An RGBA canvas covering design-space x∈[x0, x0+w], y∈[y0, y0+h]."""

    def __init__(self, w, h, x0=0.0, y0=0.0, scale=1.0, light=(-0.6, -0.8)):
        self.w, self.h, self.x0, self.y0 = w, h, x0, y0
        self.scale = scale
        self.k = scale * SS
        self.W = int(math.ceil(w * self.k))
        self.H = int(math.ceil(h * self.k))
        self.px = np.zeros((self.H, self.W, 4), np.float32)  # premultiplied
        self.light = light

    # coordinate transform
    def P(self, pts):
        return [((x - self.x0) * self.k, (y - self.y0) * self.k) for x, y in pts]

    def _bbox(self, polys, margin):
        xs = [p[0] for poly in polys for p in poly]
        ys = [p[1] for poly in polys for p in poly]
        x0 = max(0, int(math.floor(min(xs) - margin)))
        y0 = max(0, int(math.floor(min(ys) - margin)))
        x1 = min(self.W, int(math.ceil(max(xs) + margin)))
        y1 = min(self.H, int(math.ceil(max(ys) + margin)))
        return x0, y0, x1, y1

    def _mask(self, polys, holes, bx0, by0, bw, bh):
        m = Image.new("L", (bw, bh), 0)
        d = ImageDraw.Draw(m)
        for poly in polys:
            d.polygon([(x - bx0, y - by0) for x, y in poly], fill=255)
        for poly in holes or []:
            d.polygon([(x - bx0, y - by0) for x, y in poly], fill=0)
        return m

    def _over(self, region, src):
        """region (view) := src over region; both premultiplied."""
        a = src[..., 3:4]
        region *= (1.0 - a)
        region += src

    def sheet(self, polys, color, *, holes=None, grad=0.07, grain=0.05, mottle=0.035,
              shadow=0.32, shadow_off=(5, 7), shadow_blur=7, edge=0.12, alpha=1.0,
              grad_color=None, texture=None, tex_strength=0.0, seed=0):
        """Adds a paper sheet. polys: list of polygons (or one polygon)."""
        if polys and isinstance(polys[0], tuple):
            polys = [polys]
        P = [self.P(p) for p in polys]
        Hh = [self.P(p) for p in (holes or [])]
        k = self.k
        sox, soy = shadow_off[0] * k, shadow_off[1] * k
        margin = (abs(sox) + abs(soy) + shadow_blur * k * 3 + 4) if shadow > 0 else 4
        bx0, by0, bx1, by1 = self._bbox(P, margin)
        bw, bh = bx1 - bx0, by1 - by0
        if bw <= 0 or bh <= 0:
            return
        m_img = self._mask(P, Hh, bx0, by0, bw, bh)
        m = np.asarray(m_img, np.float32) / 255.0
        region = self.px[by0:by1, bx0:bx1]

        # 1. drop shadow
        if shadow > 0:
            sh = m_img.filter(ImageFilter.GaussianBlur(shadow_blur * k))
            sh = np.asarray(sh, np.float32) / 255.0
            dx, dy = int(round(sox)), int(round(soy))
            s2 = np.zeros_like(sh)
            ys0, ys1 = max(0, dy), min(bh, bh + dy)
            xs0, xs1 = max(0, dx), min(bw, bw + dx)
            s2[ys0:ys1, xs0:xs1] = sh[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
            sa = (s2 * shadow * alpha)[..., None]
            shadow_rgb = hexc("#0d0a1c")
            src = np.concatenate([shadow_rgb * sa, sa], axis=2)
            self._over(region, src)

        # 2. fill colour: vertical gradient + mottle + grain
        base = hexc(color)
        top_y = min(p[1] for poly in P for p in poly)
        bot_y = max(p[1] for poly in P for p in poly)
        ys = (np.arange(by0, by1, dtype=np.float32)[:, None] - top_y) / max(1.0, bot_y - top_y)
        ys = np.clip(ys, 0, 1)
        if grad_color is not None:
            gc = hexc(grad_color)
            col = base[None, None, :] + (gc - base)[None, None, :] * ys[..., None]
        else:
            col = base[None, None, :] * (1.0 + grad * (0.5 - ys))[..., None]
        if mottle:
            col = col * (1.0 + mottle * _tile(mottle_tile(), bx0 + seed * 37, by0 + seed * 53, bw, bh, k / 2.0))[..., None]
        if grain:
            col = col * (1.0 + grain * _tile(grain_tile(), bx0 + seed * 91, by0 + seed * 17, bw, bh, max(1.0, k / 2.0)))[..., None]
        if texture is not None and tex_strength:
            col = col * (1.0 + tex_strength * texture(bx0, by0, bw, bh, self))[..., None]

        # 3. cut edge: light catches the top-left rim, bottom-right darkens
        if edge:
            e = max(1, int(round(1.6 * k)))
            sh_dn = np.zeros_like(m)
            sh_dn[e:, e:] = m[:-e, :-e]
            rim_light = np.clip(m - sh_dn, 0, 1)
            sh_up = np.zeros_like(m)
            sh_up[:-e, :-e] = m[e:, e:]
            rim_dark = np.clip(m - sh_up, 0, 1)
            col = col * (1.0 + edge * rim_light[..., None] * 1.6 - edge * rim_dark[..., None] * 1.2)
        col = np.clip(col, 0, 1)
        a = (m * alpha)[..., None]
        src = np.concatenate([col * a, a], axis=2)
        self._over(region, src)

    def ink(self, lines, color, width=2.0, alpha=1.0, closed=False):
        """Thin strokes (window frames, cracks, rope)."""
        if lines and isinstance(lines[0], tuple):
            lines = [lines]
        P = [self.P(l) for l in lines]
        bx0, by0, bx1, by1 = self._bbox(P, width * self.k + 4)
        bw, bh = bx1 - bx0, by1 - by0
        if bw <= 0 or bh <= 0:
            return
        m_img = Image.new("L", (bw, bh), 0)
        d = ImageDraw.Draw(m_img)
        w = max(1, int(round(width * self.k)))
        for l in P:
            pts = [(x - bx0, y - by0) for x, y in l]
            if closed:
                pts = pts + [pts[0]]
            d.line(pts, fill=255, width=w, joint="curve")
        m = np.asarray(m_img, np.float32)[..., None] / 255.0 * alpha
        c = hexc(color)
        src = np.concatenate([c * m, m], axis=2)
        self._over(self.px[by0:by1, bx0:bx1], src)

    def glow(self, cx, cy, r, color, strength=0.8):
        """Additive soft light (lit windows, lamps)."""
        cxp, cyp = (cx - self.x0) * self.k, (cy - self.y0) * self.k
        rp = r * self.k
        x0, y0 = max(0, int(cxp - rp)), max(0, int(cyp - rp))
        x1, y1 = min(self.W, int(cxp + rp)), min(self.H, int(cyp + rp))
        if x1 <= x0 or y1 <= y0:
            return
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        d = np.sqrt((xx - cxp) ** 2 + (yy - cyp) ** 2) / rp
        f = np.clip(1.0 - d, 0, 1) ** 2.2 * strength
        c = hexc(color)
        region = self.px[y0:y1, x0:x1]
        add = c[None, None, :] * f[..., None]
        region[..., :3] += add * np.clip(region[..., 3:4] + f[..., None], 0, 1)
        region[..., 3:4] = np.clip(region[..., 3:4] + f[..., None] * 0.6, 0, 1)
        np.clip(region, 0, 1, out=region)

    def gradient_rect(self, x, y, w, h, top, bottom, alpha=1.0):
        P = self.P(rect(x, y, w, h))
        bx0, by0, bx1, by1 = self._bbox([P], 0)
        bh = by1 - by0
        ys = np.linspace(0, 1, bh, dtype=np.float32)[:, None, None]
        c = hexc(top)[None, None, :] * (1 - ys) + hexc(bottom)[None, None, :] * ys
        a = np.full((bh, bx1 - bx0, 1), alpha, np.float32)
        src = np.concatenate([np.broadcast_to(c, (bh, bx1 - bx0, 3)) * a, a], axis=2)
        self._over(self.px[by0:by1, bx0:bx1], src)

    def blur(self, radius):
        """Soften the whole layer (atmospheric distance)."""
        img = self.to_image(premul=True)
        img = img.filter(ImageFilter.GaussianBlur(radius * self.k))
        self.px = np.asarray(img, np.float32) / 255.0

    def tint(self, color, amount):
        """Push colours towards `color` (aerial perspective)."""
        c = hexc(color)
        a = self.px[..., 3:4]
        self.px[..., :3] = self.px[..., :3] * (1 - amount) + c * a * amount

    def to_image(self, premul=False):
        px = np.clip(self.px, 0, 1)
        if not premul:
            a = px[..., 3:4]
            rgb = np.where(a > 1e-4, px[..., :3] / np.maximum(a, 1e-4), 0)
            px = np.concatenate([rgb, a], axis=2)
        return Image.fromarray((px * 255 + 0.5).astype(np.uint8), "RGBA")

    def save(self, path, opaque=False):
        """Downsamples (premultiplied) and writes a PNG. Returns (w, h) in px."""
        img = self.to_image(premul=True)
        tw, th = max(1, round(self.W / SS)), max(1, round(self.H / SS))
        img = img.resize((tw, th), Image.LANCZOS)
        px = np.asarray(img, np.float32) / 255.0
        a = px[..., 3:4]
        rgb = np.where(a > 1e-4, px[..., :3] / np.maximum(a, 1e-4), 0)
        if opaque:
            out = Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
        else:
            out = Image.fromarray((np.clip(np.concatenate([rgb, a], axis=2), 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
            # crop transparent margins
            bbox = out.getbbox()
            if bbox is None:
                return None
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if not opaque:
            out = out.crop(bbox)
        out.save(path, optimize=True)
        if opaque:
            return (0, 0, out.size[0], out.size[1])
        return bbox + (out.size[0], out.size[1])


def layer_meta(name, layer: Layer, saved, factor, z, group="world", blend=None):
    """Meta entry for a saved layer (position in design space)."""
    if saved is None:
        return None
    bx0, by0 = saved[0], saved[1]
    inv = 1.0 / layer.scale
    m = {
        "tex": name,
        "x": round(layer.x0 + bx0 * inv, 2),
        "y": round(layer.y0 + by0 * inv, 2),
        "scale": round(inv, 4),
        "factor": factor,
        "z": z,
        "group": group,
    }
    if blend:
        m["blend"] = blend
    return m


# ─── text (shop signs, labels) ───────────────────────────────────────
from PIL import ImageFont

FONT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fonts")


def _font(name, size):
    return ImageFont.truetype(os.path.join(FONT_DIR, name), size)


def layer_text(L: Layer, x, y, text, font="Cinzel.ttf", size=28, color="#f0e2c4", anchor="mm",
               rotation=0.0, alpha=1.0, spacing=0, weight=None):
    """Draws text centred (by default) at design-space (x, y)."""
    k = L.k
    f = _font(font, max(4, int(size * k)))
    if weight is not None:
        try:
            f.set_variation_by_axes([weight])
        except Exception:
            pass
    tmp = Image.new("L", (int(len(text) * size * k * 1.2 + 40), int(size * k * 2.2 + 20)), 0)
    d = ImageDraw.Draw(tmp)
    if spacing:
        cx = 10
        for ch in text:
            d.text((cx, tmp.height / 2), ch, font=f, fill=255, anchor="lm")
            cx += d.textlength(ch, font=f) + spacing * k
        bbox = tmp.getbbox()
    else:
        d.text((tmp.width / 2, tmp.height / 2), text, font=f, fill=255, anchor="mm")
        bbox = tmp.getbbox()
    if bbox is None:
        return
    tmp = tmp.crop(bbox)
    if rotation:
        tmp = tmp.rotate(rotation, resample=Image.BICUBIC, expand=True)
    px = (x - L.x0) * k
    py = (y - L.y0) * k
    w, h = tmp.size
    if anchor == "mm":
        ox, oy = int(px - w / 2), int(py - h / 2)
    elif anchor == "lm":
        ox, oy = int(px), int(py - h / 2)
    else:
        ox, oy = int(px - w), int(py - h / 2)
    x0, y0 = max(0, ox), max(0, oy)
    x1, y1 = min(L.W, ox + w), min(L.H, oy + h)
    if x1 <= x0 or y1 <= y0:
        return
    m = np.asarray(tmp, np.float32)[y0 - oy:y1 - oy, x0 - ox:x1 - ox, None] / 255.0 * alpha
    c = hexc(color)
    src = np.concatenate([c * m, m], axis=2)
    L._over(L.px[y0:y1, x0:x1], src)


def ground_light(L: Layer, cx, cy, rx, ry, color="#ffb45a", strength=0.35):
    """Elliptical pool of light on the ground (additive, only over existing paint)."""
    k = L.k
    cxp, cyp, rxp, ryp = (cx - L.x0) * k, (cy - L.y0) * k, rx * k, ry * k
    x0, y0 = max(0, int(cxp - rxp)), max(0, int(cyp - ryp))
    x1, y1 = min(L.W, int(cxp + rxp)), min(L.H, int(cyp + ryp))
    if x1 <= x0 or y1 <= y0:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    d = np.sqrt(((xx - cxp) / rxp) ** 2 + ((yy - cyp) / ryp) ** 2)
    f = np.clip(1.0 - d, 0, 1) ** 1.8 * strength
    region = L.px[y0:y1, x0:x1]
    a = region[..., 3:4]
    region[..., :3] += hexc(color)[None, None, :] * f[..., None] * a
    np.clip(region, 0, 1, out=region)


def darken_bottom(L: Layer, y0, y1, color="#0c0a18", amount=0.55):
    """Multiplies the layer towards `color` from y0 (none) to y1 (full)."""
    k = L.k
    a0, a1 = int((y0 - L.y0) * k), int((y1 - L.y0) * k)
    a0, a1 = max(0, a0), min(L.H, a1)
    if a1 <= a0:
        return
    t = np.linspace(0, 1, a1 - a0, dtype=np.float32)[:, None, None] ** 1.3 * amount
    c = hexc(color)[None, None, :]
    region = L.px[a0:a1]
    alpha = region[..., 3:4]
    region[..., :3] = region[..., :3] * (1 - t) + c * alpha * t
    if a1 < L.H:
        rest = L.px[a1:]
        rest[..., :3] = rest[..., :3] * (1 - amount) + c * rest[..., 3:4] * amount
