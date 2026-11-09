"""Looping ambience beds (stereo)."""
import numpy as np

from synth import (RNG, SR, bandpass, bell, highpass, lowpass, master, noise, pan, place, reverb, wrap_tail)

LEN = 24.0


def _bed():
    return np.zeros((int(LEN * SR), 2), np.float32)


def _loopnoise(color, lo=None, hi=None, gain=1.0, length=LEN):
    """Noise that loops seamlessly (crossfaded ends)."""
    x = noise(length + 2.0, color)
    if lo and hi:
        x = bandpass(x, lo, hi)
    elif hi:
        x = lowpass(x, hi)
    elif lo:
        x = highpass(x, lo)
    n = int(length * SR)
    k = int(2.0 * SR)
    head = x[:k] * np.linspace(0, 1, k)
    tail = x[n:n + k] * np.linspace(1, 0, k)
    out = x[:n].copy()
    out[:k] = head + tail
    return out * gain


def _lfo(rate, depth, base=1.0, phase=0.0):
    tt = np.arange(int(LEN * SR)) / SR
    # whole cycles per loop so the modulation is seamless
    cyc = max(1, round(rate * LEN))
    return base + depth * np.sin(2 * np.pi * cyc / LEN * tt + phase)


def _stereo(a, b):
    return np.stack([a, b], axis=1)


def waves(intensity=1.0):
    """Surf: brown/pink noise swelling every few seconds."""
    a = _loopnoise("pink", 120, 2400, 0.6) * _lfo(1 / 6.0, 0.55, 0.6) * intensity
    b = _loopnoise("pink", 120, 2400, 0.6) * _lfo(1 / 6.0, 0.55, 0.6, 2.2) * intensity
    lap = _loopnoise("white", 600, 3500, 0.12) * np.clip(_lfo(1 / 3.0, 1.0, 0.0), 0, 1)
    return _stereo(a + lap, b + lap * 0.8)


def wind(strength=1.0, howl=0.0):
    a = _loopnoise("pink", 200, 1400, 0.5) * _lfo(1 / 8.0, 0.4, 0.7) * strength
    b = _loopnoise("pink", 200, 1400, 0.5) * _lfo(1 / 8.0, 0.4, 0.7, 1.7) * strength
    out = _stereo(a, b)
    if howl:
        h = bandpass(_loopnoise("white"), 600, 760) * 1.6 * howl * _lfo(1 / 12.0, 0.6, 0.5)
        out += _stereo(h, h * 0.7)
    return out


def gulls(bed, count=4, gain=0.18):
    for i in range(count):
        st = RNG.random() * (LEN - 2)
        for k in range(RNG.integers(2, 4)):
            d = 0.25 + RNG.random() * 0.2
            tt = np.arange(int(d * SR)) / SR
            f0 = 1300 + RNG.random() * 500
            f = f0 * (1 + 0.35 * np.sin(np.pi * tt / d)) * (1 - 0.3 * tt / d)
            ph = 2 * np.pi * np.cumsum(f) / SR
            y = (np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)) * np.sin(np.pi * tt / d) ** 0.6
            y = bandpass(y.astype(np.float32), 700, 5000)
            place(bed, y, st + k * (d + 0.08), gain, RNG.uniform(-0.8, 0.8))


def interior():
    bed = _bed()
    room = _loopnoise("brown", 40, 300, 0.25)
    bed += _stereo(room, room)
    # fire crackle
    for i in range(int(LEN * 7)):
        st = RNG.random() * LEN
        d = 0.004 + RNG.random() * 0.02
        pop = noise(d) * np.exp(-np.arange(int(d * SR)) / (0.003 * SR))
        place(bed, bandpass(pop, 900, 6000), st, 0.25 + RNG.random() * 0.4, 0.55)
    # clock tick (backwards clock, of course it still ticks)
    for k in range(int(LEN)):
        tick = bandpass(noise(0.02), 1800, 5000) * np.exp(-np.arange(int(0.02 * SR)) / (0.003 * SR))
        place(bed, tick, k + 0.0, 0.35 if k % 2 == 0 else 0.25, -0.4)
    # occasional pipe groan from the Chute
    tt = np.arange(int(2.5 * SR)) / SR
    groan = np.sin(2 * np.pi * (70 + 6 * np.sin(2 * np.pi * 0.5 * tt)) * tt) * np.sin(np.pi * tt / 2.5) ** 2
    place(bed, lowpass(groan.astype(np.float32), 300), 9.0, 0.12, 0.3)
    y = reverb(bed, 1.2, 0.2, 4000)
    return master(wrap_tail(y, LEN), peak=0.5, drive=0)


def town():
    bed = wind(0.35)
    gulls(bed, 2, 0.08)
    leaves = _loopnoise("pink", 1800, 6000, 0.05) * np.clip(_lfo(1 / 4.0, 1.0, 0.1), 0, 1)
    bed += _stereo(leaves, leaves * 0.8)
    # distant wind chime
    for i in range(5):
        f = [1568, 1760, 2093, 2349, 2637][RNG.integers(0, 5)]
        place(bed, bell(f, 3.0, tau=0.8) * 0.5, RNG.random() * (LEN - 3), 0.05, 0.5)
    y = reverb(bed, 2.0, 0.25, 5000)
    return master(wrap_tail(y, LEN), peak=0.5, drive=0)


def harbor():
    bed = waves(0.9)
    gulls(bed, 5, 0.16)
    # rope creak
    for i in range(3):
        d = 0.6
        tt = np.arange(int(d * SR)) / SR
        cr = np.sin(2 * np.pi * (180 + 60 * tt / d) * tt) * (1 + np.sign(np.sin(2 * np.pi * 30 * tt))) * 0.5
        cr *= np.sin(np.pi * tt / d)
        place(bed, bandpass(cr.astype(np.float32), 150, 1500), RNG.random() * (LEN - 1), 0.12, -0.5)
    # bell buoy
    place(bed, bell(523.25, 4.0, tau=1.4), 4.0, 0.06, 0.8)
    place(bed, bell(523.25, 4.0, tau=1.4), 15.5, 0.05, 0.8)
    y = reverb(bed, 2.4, 0.2, 4500)
    return master(wrap_tail(y, LEN), peak=0.55, drive=0)


def cliff():
    bed = wind(0.9, howl=0.25)
    w = waves(0.35)
    bed += lowpass(w, 900)
    # crickets
    for i in range(int(LEN * 1.5)):
        st = RNG.random() * (LEN - 1)
        d = 0.18
        tt = np.arange(int(d * SR)) / SR
        c = np.sin(2 * np.pi * 4300 * tt) * (np.sin(2 * np.pi * 32 * tt) > 0.2) * np.sin(np.pi * tt / d)
        place(bed, c.astype(np.float32), st, 0.025, RNG.uniform(-0.9, 0.9))
    y = reverb(bed, 2.0, 0.2, 4000)
    return master(wrap_tail(y, LEN), peak=0.55, drive=0)


def storm():
    rain_l = _loopnoise("white", 700, 5200, 0.32) + _loopnoise("pink", 180, 2000, 0.55)
    rain_r = _loopnoise("white", 700, 5200, 0.32) + _loopnoise("pink", 180, 2000, 0.55)
    bed = _stereo(rain_l, rain_r)
    bed += wind(1.0, howl=0.4)
    # heavy drops
    for i in range(int(LEN * 40)):
        st = RNG.random() * LEN
        d = 0.01
        drop = bandpass(noise(d), 1500, 7000) * np.exp(-np.arange(int(d * SR)) / (0.002 * SR))
        place(bed, drop, st, 0.15 + RNG.random() * 0.2, RNG.uniform(-1, 1))
    # distant rumbles
    for st in (5.0, 16.0):
        d = 4.0
        r = lowpass(noise(d, "brown"), 120) * np.sin(np.pi * np.arange(int(d * SR)) / (d * SR)) ** 2
        place(bed, r * 3, st, 0.5, 0.0)
    y = reverb(bed, 1.6, 0.15, 3500)
    return master(wrap_tail(y, LEN), peak=0.6, drive=0)


def lamp():
    bed = wind(0.6, howl=0.6)
    tt = np.arange(int(LEN * SR)) / SR
    hum = (np.sin(2 * np.pi * 50 * tt) * 0.5 + np.sin(2 * np.pi * 100 * tt) * 0.25 + np.sin(2 * np.pi * 150 * tt) * 0.1)
    hum = (hum * 0.08).astype(np.float32)
    bed += _stereo(hum, hum)
    y = reverb(bed, 3.0, 0.3, 3500)
    return master(wrap_tail(y, LEN), peak=0.5, drive=0)


AMBIENCE = {"interior": interior, "town": town, "harbor": harbor, "cliff": cliff, "storm": storm, "lamp": lamp}
