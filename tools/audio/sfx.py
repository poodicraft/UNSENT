"""Sound effects (mono, short)."""
import numpy as np

from synth import (RNG, SR, bandpass, bell, celesta, harp, highpass, lowpass, midi_hz, noise, note, piano, reverb,
                   strings, timpani, woodblock)


def _n(d):
    return np.arange(int(d * SR)) / SR


def _norm(y, peak=0.9):
    y = np.asarray(y, np.float32)
    m = np.max(np.abs(y)) + 1e-9
    return (y / m * peak).astype(np.float32)


def _mono_verb(y, s=1.2, wet=0.25, damp=5000):
    st = reverb(y, s, wet, damp)
    return st.mean(axis=1).astype(np.float32)


def _mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n, np.float32)
    for p in parts:
        out[: len(p)] += p
    return out


def _shift(y, sec):
    return np.concatenate([np.zeros(int(sec * SR), np.float32), y])


def rustle(dur=0.35, seed=0, bright=1.0):
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    x = np.zeros(n, np.float32)
    # many tiny crackles shaped by an envelope = paper
    for k in range(int(dur * 260)):
        p = int(rng.random() * (n - 300))
        L = int(80 + rng.random() * 220)
        x[p:p + L] += rng.standard_normal(L).astype(np.float32) * np.exp(-np.arange(L) / (L / 4)) * rng.random()
    x = bandpass(x, 1200 * bright, 9500)
    e = np.sin(np.pi * np.arange(n) / n) ** 0.7
    return _norm(x * e, 0.8)


def ui_open():
    w = bandpass(noise(0.25), 800, 5000) * np.sin(np.pi * _n(0.25) / 0.25) ** 2
    return _norm(_mix(w, rustle(0.22, 3) * 0.5), 0.5)


def letter_open():
    tear = bandpass(noise(0.18), 1500, 7000) * np.exp(-_n(0.18) / 0.08) * (1 + 0.5 * np.sin(2 * np.pi * 60 * _n(0.18)))
    return _norm(_mix(tear * 0.8, _shift(rustle(0.5, 4), 0.12)), 0.75)


def letter_fold():
    return _norm(_mix(rustle(0.3, 5), _shift(bandpass(noise(0.05), 300, 2000) * np.exp(-_n(0.05) / 0.015), 0.25)), 0.6)


def clue():
    y = np.zeros(int(1.4 * SR), np.float32)
    for i, m in enumerate(("E6", "G#6", "B6")):
        c = celesta(midi_hz(note(m)), 1.0)
        y[int(i * 0.07 * SR): int(i * 0.07 * SR) + len(c)] += c * (0.8 - i * 0.1)
    return _norm(_mono_verb(y, 1.6, 0.35), 0.6)


def item():
    y = _mix(celesta(midi_hz(note("A5")), 0.9), _shift(celesta(midi_hz(note("E6")), 1.0), 0.12))
    return _norm(_mono_verb(y, 1.4, 0.3), 0.6)


def deliver():
    chord = [midi_hz(note(n)) for n in ("D4", "F#4", "A4", "D5")]
    sw = strings(chord, 1.6, attack=0.25, release=0.9, cutoff=2600)
    h = np.zeros(int(2.6 * SR), np.float32)
    for i, n in enumerate(("D5", "F#5", "A5", "D6")):
        p = harp(midi_hz(note(n)), 1.5, 0.6)
        s = int(i * 0.06 * SR)
        h[s:s + len(p)] += p * 0.5
    return _norm(_mono_verb(_mix(sw * 0.6, h), 2.0, 0.35), 0.75)


def stamp():
    thump = lowpass(noise(0.15), 220) * np.exp(-_n(0.15) / 0.03) * 3
    knock = np.sin(2 * np.pi * 95 * _n(0.15)) * np.exp(-_n(0.15) / 0.04)
    snap = bandpass(noise(0.03), 2000, 6000) * np.exp(-_n(0.03) / 0.006)
    return _norm(_mix(thump, knock, snap * 0.4), 0.85)


def chute():
    d = 1.1
    tt = _n(d)
    whoosh = bandpass(noise(d), 300, 2500) * np.sin(np.pi * tt / d) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * tt))
    rattle = np.zeros_like(whoosh)
    for k in range(10):
        p = int((0.3 + RNG.random() * 0.6) * SR)
        L = int(0.02 * SR)
        rattle[p:p + L] += bandpass(noise(0.02), 1500, 6000) * np.exp(-np.arange(L) / (L / 5))
    ding = bell(midi_hz(note("A6")), 1.6, tau=0.7)
    return _norm(_mix(whoosh * 0.7, rattle * 0.5, _shift(ding * 0.6, 0.95)), 0.8)


def chute_collect():
    return _norm(_mix(rustle(0.6, 9), bandpass(noise(0.4), 500, 3000) * np.sin(np.pi * _n(0.4) / 0.4) * 0.4), 0.7)


def counter_bell():
    return _norm(_mono_verb(bell(midi_hz(note("E6")), 2.5, partials=((1, 1, 1), (2.7, 0.6, 0.6), (5.1, 0.3, 0.4), (8.2, 0.15, 0.25)), tau=1.1), 1.0, 0.2), 0.7)


def footstep(kind, seed):
    rng = np.random.default_rng(seed)
    if kind == "wood":
        thump = np.sin(2 * np.pi * (110 + rng.random() * 20) * _n(0.12)) * np.exp(-_n(0.12) / 0.025)
        click = bandpass(noise(0.04), 900, 3500) * np.exp(-_n(0.04) / 0.008)
        creak = bandpass(noise(0.08), 400, 900) * np.exp(-_n(0.08) / 0.03) * 0.3
        y = _mix(thump * 1.0, click * 0.6, creak)
    elif kind == "stone":
        click = bandpass(noise(0.06), 1800, 7000) * np.exp(-_n(0.06) / 0.01)
        grit = bandpass(noise(0.1), 2500, 9000) * np.exp(-_n(0.1) / 0.03) * 0.4
        thud = lowpass(noise(0.08), 300) * np.exp(-_n(0.08) / 0.02) * 1.5
        y = _mix(click, grit, thud)
    elif kind == "grass":
        sw = bandpass(noise(0.18), 1500, 8000) * np.sin(np.pi * _n(0.18) / 0.18) ** 1.5
        thud = lowpass(noise(0.1), 200) * np.exp(-_n(0.1) / 0.03)
        y = _mix(sw * 0.7, thud * 0.8)
    else:  # metal grating
        ring = sum(np.sin(2 * np.pi * f * _n(0.3)) * np.exp(-_n(0.3) / td) for f, td in ((420 + rng.random() * 40, 0.08), (1130, 0.05), (2240, 0.03)))
        clank = bandpass(noise(0.05), 1500, 6000) * np.exp(-_n(0.05) / 0.01)
        y = _mix(ring * 0.5, clank * 0.7)
    return _norm(y, 0.6 + rng.random() * 0.2)


def door():
    d = 0.9
    tt = _n(d)
    f = 240 + 120 * np.sin(np.pi * tt / d)
    creak = np.sin(2 * np.pi * np.cumsum(f) / SR) * (np.sin(2 * np.pi * 38 * tt) > 0) * np.sin(np.pi * tt / d)
    creak = bandpass(creak.astype(np.float32), 200, 2400)
    latch = _shift(bandpass(noise(0.05), 1500, 5000) * np.exp(-_n(0.05) / 0.01), 0.8)
    return _norm(_mix(creak * 0.5, latch), 0.6)


def match():
    strike = bandpass(noise(0.15), 2000, 8000) * np.exp(-_n(0.15) / 0.05)
    flare = bandpass(noise(0.6), 300, 3000) * np.sin(np.pi * _n(0.6) / 0.6) * 0.5
    return _norm(_mix(strike, _shift(flare, 0.08)), 0.7)


def ignite():
    d = 1.6
    tt = _n(d)
    whoomph = lowpass(noise(d), 600) * (1 - np.exp(-tt / 0.05)) * np.exp(-tt / 0.6) * 3
    roar = bandpass(noise(d), 200, 1500) * np.exp(-tt / 0.9) * 0.5
    hum = np.sin(2 * np.pi * 110 * tt) * 0.2 * np.clip(tt / 0.5, 0, 1)
    return _norm(_mono_verb(_mix(whoomph, roar, hum), 1.8, 0.3, 3000), 0.85)


def lamp_die():
    d = 1.2
    tt = _n(d)
    fizz = bandpass(noise(d), 2000, 8000) * np.exp(-tt / 0.3) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * tt))
    clunk = np.sin(2 * np.pi * 80 * _n(0.4)) * np.exp(-_n(0.4) / 0.08)
    grind = bandpass(noise(0.5), 300, 1200) * np.sign(np.sin(2 * np.pi * 40 * _n(0.5))) * 0.3
    return _norm(_mix(_shift(grind, 0.0), _shift(clunk, 0.45), fizz * 0.6), 0.8)


def valve():
    d = 0.9
    tt = _n(d)
    squeak = np.sin(2 * np.pi * (900 + 300 * tt / d) * tt) * np.sin(np.pi * tt / d) * 0.3
    gurgle = np.zeros(int(1.4 * SR), np.float32)
    for k in range(14):
        b = np.sin(2 * np.pi * (300 + RNG.random() * 500) * _n(0.06)) * np.exp(-_n(0.06) / 0.015)
        s = int((0.5 + k * 0.06) * SR)
        gurgle[s:s + len(b)] += b * 0.4
    return _norm(_mix(squeak.astype(np.float32), gurgle), 0.6)


def snip():
    c = bandpass(noise(0.03), 3000, 9000) * np.exp(-_n(0.03) / 0.004)
    return _norm(_mix(c, _shift(c * 0.8, 0.07)), 0.55)


def thunder():
    d = 5.0
    tt = _n(d)
    crack = bandpass(noise(0.4), 500, 5000) * np.exp(-_n(0.4) / 0.08)
    rumble = lowpass(noise(d, "brown"), 160) * np.exp(-tt / 1.6) * (1 + 0.5 * np.sin(2 * np.pi * 1.3 * tt)) * 4
    return _norm(_mono_verb(_mix(crack * 0.6, rumble), 2.5, 0.35, 2000), 0.9)


def horn():
    d = 2.2
    tt = _n(d)
    y = np.zeros_like(tt)
    for f in (146.8, 220.0):
        for k in range(1, 8):
            y += np.sin(2 * np.pi * f * k * tt) / k ** 1.2
    y *= np.clip(tt / 0.15, 0, 1) * np.clip((d - tt) / 0.4, 0, 1)
    return _norm(_mono_verb(lowpass(y.astype(np.float32), 1200), 2.6, 0.4, 2500), 0.8)


def lantern():
    w = bandpass(noise(0.8), 400, 3000) * np.sin(np.pi * _n(0.8) / 0.8) ** 2 * 0.4
    return _norm(_mono_verb(_mix(w, _shift(celesta(midi_hz(note("G5")), 1.5) * 0.6, 0.3)), 2.0, 0.4), 0.6)


def clock_start():
    y = np.zeros(int(3.2 * SR), np.float32)
    tpos = 0.0
    gap = 0.18
    k = 0
    while tpos < 2.6:
        tick = woodblock(2200 if k % 2 == 0 else 1700, 0.05) * 0.8
        s = int(tpos * SR)
        y[s:s + len(tick)] += tick
        tpos += gap
        gap = max(0.5, gap * 1.12) if tpos > 1.0 else gap
        k += 1
    whirr = bandpass(noise(1.0), 2000, 6000) * np.sin(np.pi * _n(1.0)) * 0.2
    return _norm(_mono_verb(_mix(whirr, y), 1.2, 0.25), 0.7)


def clock_chime():
    y = np.zeros(int(11.0 * SR), np.float32)
    for i, n in enumerate(("E4", "C4", "D4", "G3")):
        b = bell(midi_hz(note(n)), 3.5, tau=1.8)
        s = int(i * 0.75 * SR)
        y[s:s + len(b)] += b * 0.7
    for i in range(3):
        b = bell(midi_hz(note("C3")), 3.0, tau=2.0)
        s = int((3.6 + i * 1.6) * SR)
        y[s:s + len(b)] += b
    return _norm(_mono_verb(y, 3.0, 0.4, 3000), 0.85)


def fire():
    y = np.zeros(int(0.8 * SR), np.float32)
    for k in range(18):
        p = int(RNG.random() * 0.7 * SR)
        L = int(0.01 * SR)
        y[p:p + L] += bandpass(noise(0.01), 800, 6000) * np.exp(-np.arange(L) / (L / 4)) * RNG.random()
    y += lowpass(noise(0.8), 400) * np.sin(np.pi * _n(0.8) / 0.8) * 0.4
    return _norm(y, 0.6)


def purr():
    d = 1.6
    tt = _n(d)
    y = lowpass(noise(d), 300) * (0.5 + 0.5 * np.sin(2 * np.pi * 26 * tt)) * np.sin(np.pi * tt / d) ** 0.5
    return _norm(y, 0.55)


def post():
    flap = np.sin(2 * np.pi * 300 * _n(0.12)) * np.exp(-_n(0.12) / 0.02)
    drop = _shift(rustle(0.25, 12) * 0.6, 0.15)
    thunk = _shift(lowpass(noise(0.1), 250) * np.exp(-_n(0.1) / 0.02) * 2, 0.32)
    return _norm(_mix(flap.astype(np.float32), drop, thunk), 0.7)


def ripple():
    d = 2.4
    tt = _n(d)
    rev = np.zeros(int(d * SR), np.float32)
    for i, n in enumerate(("C6", "G5", "E6", "B5")):
        c = celesta(midi_hz(note(n)), 1.2)[::-1]
        s = int(i * 0.18 * SR)
        rev[s:s + len(c)] += c[: len(rev) - s] * 0.5
    shimmer = bandpass(noise(d), 4000, 10000) * np.sin(np.pi * tt / d) ** 2 * 0.15
    swell = strings([midi_hz(note("E4")), midi_hz(note("B4"))], 1.6, attack=1.2, release=0.6, cutoff=2400)
    return _norm(_mono_verb(_mix(rev, shimmer, swell * 0.4), 2.6, 0.45), 0.7)


def consequence():
    chord = [midi_hz(note(n)) for n in ("F3", "C4", "A4")]
    sw = strings(chord, 2.0, attack=0.6, release=1.0, cutoff=2000)
    b = _shift(bell(midi_hz(note("C6")), 2.5) * 0.3, 0.2)
    return _norm(_mono_verb(_mix(sw * 0.5, b), 2.4, 0.4), 0.6)


def night():
    g = bell(midi_hz(note("D3")), 5.0, partials=((1, 1, 1), (2.01, 0.4, 0.6), (2.98, 0.2, 0.4)), tau=2.4)
    w = bandpass(noise(4.0), 200, 1200) * np.sin(np.pi * _n(4.0) / 4.0) ** 2 * 0.3
    return _norm(_mono_verb(_mix(g, w), 3.5, 0.5, 2500), 0.75)


def blip():
    tt = _n(0.035)
    y = np.sin(2 * np.pi * 520 * tt) * np.exp(-tt / 0.008) + bandpass(noise(0.035), 2000, 6000) * np.exp(-tt / 0.004) * 0.3
    return _norm(y, 0.5)


SFX = {
    "ui_tap": lambda: _norm(woodblock(1350, 0.07), 0.5),
    "ui_open": ui_open,
    "paper_1": lambda: rustle(0.32, 1),
    "paper_2": lambda: rustle(0.28, 2, 1.2),
    "paper_3": lambda: rustle(0.4, 3, 0.8),
    "letter_open": letter_open,
    "letter_fold": letter_fold,
    "clue": clue,
    "item": item,
    "deliver": deliver,
    "stamp": stamp,
    "chute": chute,
    "chute_collect": chute_collect,
    "bell": counter_bell,
    "door": door,
    "match": match,
    "ignite": ignite,
    "lamp_die": lamp_die,
    "valve": valve,
    "snip": snip,
    "thunder": thunder,
    "horn": horn,
    "lantern": lantern,
    "clock_start": clock_start,
    "clock_chime": clock_chime,
    "fire": fire,
    "purr": purr,
    "post": post,
    "ripple": ripple,
    "consequence": consequence,
    "night": night,
    "blip": blip,
}
for _kind in ("wood", "stone", "grass", "metal"):
    for _i in range(1, 5):
        SFX[f"step_{_kind}_{_i}"] = (lambda k=_kind, s=_i: footstep(k, s * 7 + len(k)))
