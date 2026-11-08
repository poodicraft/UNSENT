"""
synth — a tiny offline synthesizer for UNSENT's music, ambience and effects.

Instruments: Karplus-Strong harp, FM electric piano, additive piano, bells and
celesta, detuned string/pad ensembles, breathy flute, soft drums.
Effects: biquad-style filters (scipy), convolution reverb, echo, panning.
Everything renders to float32 numpy arrays at SR.
"""
import math

import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(1234)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note(n):
    """'F#5' -> midi number."""
    if isinstance(n, (int, float)):
        return n
    name = n[0].upper()
    i = 1
    acc = 0
    while i < len(n) and n[i] in "#b":
        acc += 1 if n[i] == "#" else -1
        i += 1
    octave = int(n[i:])
    return 12 * (octave + 1) + NOTE[name] + acc


def t(seconds):
    return np.arange(int(seconds * SR)) / SR


# ─── filters ─────────────────────────────────────────────────────────

def lowpass(x, fc, order=2):
    fc = min(fc, SR * 0.45)
    sos = signal.butter(order, fc, "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0).astype(np.float32)


def highpass(x, fc, order=2):
    sos = signal.butter(order, fc, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0).astype(np.float32)


def bandpass(x, lo, hi, order=2):
    hi = min(hi, SR * 0.45)
    sos = signal.butter(order, [lo, hi], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0).astype(np.float32)


def noise(seconds, color="white"):
    n = int(seconds * SR)
    w = RNG.standard_normal(n).astype(np.float32)
    if color == "pink":
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        w = signal.lfilter(b, a, w).astype(np.float32) * 4
    elif color == "brown":
        w = np.cumsum(w) / SR * 30
        w = highpass(w, 20)
    return w


def env(n, a=0.01, d=0.1, s=0.7, r=0.2, total=None):
    """ADSR over n samples (r counted inside n)."""
    A, D, R = int(a * SR), int(d * SR), int(r * SR)
    S = max(0, n - A - D - R)
    e = np.concatenate([
        np.linspace(0, 1, max(A, 1), endpoint=False),
        np.linspace(1, s, max(D, 1), endpoint=False),
        np.full(S, s),
        np.linspace(s, 0, max(R, 1)),
    ])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n].astype(np.float32)


def expdecay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR)).astype(np.float32)


# ─── instruments (mono) ──────────────────────────────────────────────

def harp(freq, dur, bright=0.5, decay=0.996):
    """Karplus-Strong plucked string, vectorised via lfilter."""
    n = int((dur + 0.05) * SR)
    N = max(2, int(round(SR / freq)))
    exc = RNG.uniform(-1, 1, N).astype(np.float32)
    exc = lowpass(np.concatenate([exc, np.zeros(16, np.float32)]), 1500 + bright * 5000)[:N]
    x = np.zeros(n, np.float32)
    x[:N] = exc
    g = decay ** (440.0 / freq) if freq > 0 else decay
    a = np.zeros(N + 2)
    a[0] = 1.0
    a[N] = -0.5 * g
    a[N + 1] = -0.5 * g
    y = signal.lfilter([1.0], a, x).astype(np.float32)
    y *= env(n, 0.002, 0.05, 1.0, 0.04)
    return y / (np.max(np.abs(y)) + 1e-6)


def bell(freq, dur, partials=((1, 1.0, 1.0), (2.0, 0.5, 0.6), (2.76, 0.4, 0.5), (5.4, 0.25, 0.3), (8.93, 0.12, 0.2)), tau=1.2):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    y = np.zeros(n, np.float32)
    for ratio, amp, td in partials:
        y += amp * np.sin(2 * np.pi * freq * ratio * tt + RNG.random() * 6) * np.exp(-tt / (tau * td))
    y *= env(n, 0.002, 0.0, 1.0, 0.05)
    return y.astype(np.float32) / (np.max(np.abs(y)) + 1e-6)


def celesta(freq, dur):
    return bell(freq, dur, partials=((1, 1.0, 1.0), (2, 0.35, 0.4), (3, 0.12, 0.25), (4.2, 0.06, 0.15)), tau=0.9)


def epiano(freq, dur, vel=0.8):
    """FM electric piano (Rhodes-ish)."""
    n = int((dur + 0.4) * SR)
    tt = np.arange(n) / SR
    idx = (1.6 + vel * 1.2) * np.exp(-tt / 0.35)
    mod = np.sin(2 * np.pi * freq * tt) * idx
    y = np.sin(2 * np.pi * freq * tt + mod) + 0.25 * np.sin(2 * np.pi * freq * 2 * tt) * np.exp(-tt / 0.2)
    y *= np.exp(-tt / (1.6 if freq < 400 else 1.1))
    y *= env(n, 0.004, 0.0, 1.0, 0.25)
    return y.astype(np.float32) * 0.8


def piano(freq, dur, vel=0.8):
    """Additive piano-ish tone with hammer noise and slight inharmonicity."""
    n = int((dur + 0.8) * SR)
    tt = np.arange(n) / SR
    y = np.zeros(n)
    B = 0.0004
    for k in range(1, 12):
        fk = freq * k * math.sqrt(1 + B * k * k)
        if fk > SR * 0.45:
            break
        amp = (1.0 / k ** 1.1) * (0.6 + 0.4 * vel)
        tau = (2.8 if freq < 300 else 1.8) / (1 + k * 0.35)
        y += amp * np.sin(2 * np.pi * fk * tt + RNG.random()) * np.exp(-tt / tau)
    ham = noise(0.02)
    ham = bandpass(ham, freq * 2, min(freq * 8, 9000)) * 0.3
    y[: len(ham)] += ham
    y *= env(n, 0.002, 0.0, 1.0, min(0.6, dur * 0.5 + 0.2))
    return (y / (np.max(np.abs(y)) + 1e-6)).astype(np.float32) * (0.5 + 0.5 * vel)


def saw(freq, tt, harmonics=None):
    if harmonics is None:
        harmonics = max(1, min(40, int(SR * 0.45 / freq)))
    y = np.zeros_like(tt)
    for k in range(1, harmonics + 1):
        y += np.sin(2 * np.pi * freq * k * tt) / k
    return y


def strings(freqs, dur, attack=0.6, release=0.8, cutoff=2200, vib=0.004):
    """Detuned saw ensemble with vibrato: string section / pad."""
    n = int((dur + release) * SR)
    tt = np.arange(n) / SR
    y = np.zeros(n)
    for f in freqs:
        for det in (-0.006, 0.0, 0.0065):
            # Proper vibrato: integrate the frequency modulation into the phase.
            w = 2 * np.pi * (4.8 + RNG.random() * 0.8)
            ph = RNG.random() * 6
            delay_in = np.clip(tt / 0.5, 0, 1)
            warped = tt - delay_in * (vib / w) * np.cos(w * tt + ph)
            y += saw(f * (1 + det), warped, harmonics=min(24, int(SR * 0.3 / f)))
    y = lowpass(y.astype(np.float32), cutoff)
    y *= env(n, attack, 0.2, 0.85, release)
    return y / (np.max(np.abs(y)) + 1e-6)


def pad(freqs, dur, attack=1.2, release=1.5, cutoff=1400):
    return strings(freqs, dur, attack=attack, release=release, cutoff=cutoff, vib=0.002)


def flute(freq, dur, breath=0.08):
    n = int((dur + 0.15) * SR)
    tt = np.arange(n) / SR
    w = 2 * np.pi * 5.2
    warped = tt - np.clip(tt / 0.4, 0, 1) * (0.005 / w) * np.cos(w * tt)
    y = np.sin(2 * np.pi * freq * warped) + 0.18 * np.sin(4 * np.pi * freq * warped) + 0.06 * np.sin(6 * np.pi * freq * warped)
    y += bandpass(noise(n / SR), freq * 0.9, freq * 3) * breath * 3
    y *= env(n, 0.06, 0.1, 0.8, 0.15)
    return y.astype(np.float32) * 0.6


def bass(freq, dur):
    n = int((dur + 0.2) * SR)
    tt = np.arange(n) / SR
    y = np.sin(2 * np.pi * freq * tt) + 0.3 * np.sin(4 * np.pi * freq * tt) * np.exp(-tt / 0.3)
    y = np.tanh(y * 1.4)
    y *= env(n, 0.01, 0.2, 0.6, 0.2)
    return y.astype(np.float32) * 0.7


def timpani(freq, dur=2.0):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    f = freq * (1 + 0.15 * np.exp(-tt / 0.05))
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.6)
    y += lowpass(noise(dur), 300) * np.exp(-tt / 0.08) * 0.8
    return y.astype(np.float32) / (np.max(np.abs(y)) + 1e-6)


def woodblock(freq=1200, dur=0.12):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    y = np.sin(2 * np.pi * freq * tt) * np.exp(-tt / 0.02) + 0.3 * np.sin(2 * np.pi * freq * 2.7 * tt) * np.exp(-tt / 0.01)
    return y.astype(np.float32)


# ─── effects & mixing ────────────────────────────────────────────────

_IR = {}


def _ir(seconds, damp, seed):
    key = (seconds, damp, seed)
    if key in _IR:
        return _IR[key]
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    tt = np.arange(n) / SR
    irs = []
    for ch in range(2):
        w = rng.standard_normal(n).astype(np.float32)
        w *= np.exp(-tt / (seconds / 5.5))
        w = lowpass(w, damp)
        w[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
        irs.append(w / np.sqrt(np.sum(w ** 2)))
    _IR[key] = np.stack(irs, axis=1)
    return _IR[key]


def reverb(x, seconds=2.6, wet=0.3, damp=5000, seed=7):
    """Stereo convolution reverb. x: (n,) or (n,2) -> (n + tail, 2)."""
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    ir = _ir(seconds, damp, seed)
    out = np.zeros((x.shape[0] + ir.shape[0] - 1, 2), np.float32)
    for ch in range(2):
        out[:, ch] = signal.fftconvolve(x[:, ch], ir[:, ch])
    dry = np.zeros_like(out)
    dry[: x.shape[0]] = x
    return dry * (1 - wet * 0.5) + out * wet


def pan(x, p):
    """p in [-1, 1]; constant power."""
    a = (p + 1) * math.pi / 4
    return np.stack([x * math.cos(a), x * math.sin(a)], axis=1)


def place(buf, x, start_s, gain=1.0, p=0.0):
    """Mixes mono/stereo x into stereo buf at start_s (wraps for loops)."""
    if x.ndim == 1:
        x = pan(x, p)
    s = int(start_s * SR)
    n = buf.shape[0]
    end = s + x.shape[0]
    if end <= n:
        buf[s:end] += x * gain
    else:
        k = n - s
        buf[s:] += x[:k] * gain
        rest = x[k:]
        while len(rest) > 0:
            m = min(len(rest), n)
            buf[:m] += rest[:m] * gain
            rest = rest[m:]


def wrap_tail(y, loop_len):
    """Folds anything past loop_len back to the start (seamless loops)."""
    n = int(loop_len * SR)
    out = y[:n].copy()
    rest = y[n:]
    while len(rest) > 0:
        m = min(len(rest), n)
        out[:m] += rest[:m]
        rest = rest[m:]
    return out


def master(y, peak=0.89, drive=1.1):
    y = np.tanh(y * drive / (np.max(np.abs(y)) + 1e-6) * 1.2) if drive else y
    return (y / (np.max(np.abs(y)) + 1e-6) * peak).astype(np.float32)


def fade(y, fin=0.005, fout=0.02):
    n = len(y)
    a, b = int(fin * SR), int(fout * SR)
    if a:
        y[:a] *= np.linspace(0, 1, a)[:, None] if y.ndim == 2 else np.linspace(0, 1, a)
    if b:
        y[-b:] *= np.linspace(1, 0, b)[:, None] if y.ndim == 2 else np.linspace(1, 0, b)
    return y
