"""UNSENT's original score. Each piece renders to a seamless stereo loop."""
import numpy as np

from synth import (SR, bass, bell, celesta, epiano, flute, harp, lowpass, master, midi_hz, note, pad, piano,
                   place, reverb, strings, timpani, woodblock, wrap_tail)


class Track:
    def __init__(self, bpm, bars, bpb=4):
        self.bpm, self.bars, self.bpb = bpm, bars, bpb
        self.beat = 60.0 / bpm
        self.length = bars * bpb * self.beat
        self.buf = np.zeros((int(self.length * SR), 2), np.float32)

    def s(self, beat):
        return beat * self.beat

    def add(self, x, beat, gain=1.0, p=0.0):
        place(self.buf, x, self.s(beat), gain, p)

    def melody(self, seq, inst, start=0.0, gain=0.5, p=0.0, octave=0, legato=1.0):
        b = start
        for n, d in seq:
            if n != "r":
                f = midi_hz(note(n) + 12 * octave)
                self.add(inst(f, self.s(d) * legato), b, gain, p)
            b += d
        return b

    def arp(self, chords, pattern, inst, gain=0.3, p=0.0, octave=0, bar_beats=None, dur=1.0):
        bb = bar_beats or self.bpb
        for i in range(self.bars):
            ch = [note(n) + 12 * octave for n in chords[i % len(chords)]]
            for (beat, idx) in pattern:
                m = ch[idx % len(ch)] + 12 * (idx // len(ch))
                self.add(inst(midi_hz(m), self.s(dur)), i * bb + beat, gain, p)

    def pads(self, chords, gain=0.25, bars_per=1, inst=None, cutoff=1400, attack=1.0):
        inst = inst or (lambda fs, d: pad(fs, d, attack=attack, cutoff=cutoff))
        for i in range(0, self.bars, bars_per):
            ch = chords[(i // bars_per) % len(chords)]
            fs = [midi_hz(note(n)) for n in ch]
            self.add(inst(fs, self.s(self.bpb * bars_per) * 0.98), i * self.bpb, gain, 0.0)

    def render(self, wet=0.32, seconds=2.8, damp=5200, lp=None):
        y = reverb(self.buf, seconds=seconds, wet=wet, damp=damp)
        y = wrap_tail(y, self.length)
        if lp:
            y = lowpass(y, lp)
        return master(y, peak=0.86, drive=0.9)


# ═══════════════════════════════════════════════════════════════════

def theme():
    """Title: lyrical B minor / D major, piano + strings + celesta."""
    T = Track(66, 16)
    prog = [["B2", "F#3", "B3", "D4"], ["G2", "D3", "G3", "B3"], ["D3", "A3", "D4", "F#4"], ["A2", "E3", "A3", "C#4"]]
    T.pads([[n.replace("2", "3").replace("3", "3") for n in c[1:]] for c in prog], gain=0.22, cutoff=1800)
    T.arp(prog, [(0, 0), (1, 1), (1.5, 2), (2, 3), (3, 2), (3.5, 1)], lambda f, d: piano(f, d, 0.55), gain=0.32, p=-0.2)
    for i in range(T.bars):
        root = note(prog[i % 4][0]) - 12
        T.add(bass(midi_hz(root), T.s(3.5)), i * 4, 0.35)
    mel = [("F#5", 2), ("E5", 1), ("D5", 1), ("B4", 3), ("D5", 1), ("A4", 2), ("F#4", 1), ("A4", 1), ("E5", 4),
           ("F#5", 1.5), ("G5", 0.5), ("F#5", 1), ("E5", 1), ("D5", 2), ("B4", 2), ("D5", 2), ("C#5", 2), ("B4", 4)]
    end = T.melody(mel, celesta, start=16, gain=0.34, p=0.15)
    mel2 = [("B5", 2), ("A5", 1), ("F#5", 1), ("G5", 3), ("B5", 1), ("A5", 2), ("F#5", 1), ("D5", 1), ("E5", 4),
            ("F#5", 1.5), ("G5", 0.5), ("A5", 1), ("B5", 1), ("D6", 2), ("C#6", 1), ("A5", 1), ("B5", 4)]
    T.melody(mel2, lambda f, d: strings([f], d, attack=0.3, release=0.6, cutoff=3000), start=48, gain=0.2, p=0.1)
    T.melody(mel2, celesta, start=48, gain=0.18, p=0.3)
    return T.render(wet=0.38, seconds=3.2)


def office():
    """The post office: cosy F major, e-piano chords, music box, clock ticks."""
    T = Track(76, 16)
    prog = [["F3", "A3", "C4", "E4"], ["D3", "F3", "A3", "C4"], ["Bb2", "D3", "F3", "A3"], ["C3", "E3", "G3", "Bb3"]]
    for i in range(T.bars):
        ch = prog[i % 4]
        for b in (0, 1.5, 2.5):
            for n in ch[1:]:
                T.add(epiano(midi_hz(note(n)), T.s(0.9), 0.5), i * 4 + b, 0.13, -0.15)
        T.add(bass(midi_hz(note(ch[0]) - 12), T.s(1.8)), i * 4, 0.32)
        T.add(bass(midi_hz(note(ch[0]) - 5), T.s(1.5)), i * 4 + 2, 0.22)
    mel = [("A5", 1), ("C6", 1), ("A5", 1), ("F5", 1), ("D5", 2), ("F5", 1), ("A5", 1), ("G5", 1.5), ("F5", 0.5), ("D5", 2),
           ("E5", 2), ("G5", 2), ("A5", 1), ("C6", 1), ("D6", 1), ("C6", 1), ("A5", 2), ("F5", 2), ("G5", 1), ("A5", 1),
           ("Bb5", 1), ("D5", 1), ("C5", 3), ("r", 1)]
    T.melody(mel, celesta, start=0, gain=0.3, p=0.25)
    T.melody(mel, celesta, start=32, gain=0.22, p=-0.25, octave=1)
    for i in range(T.bars * 4):
        T.add(woodblock(1500 if i % 2 == 0 else 1100, 0.08), i, 0.05, 0.6)
    return T.render(wet=0.28, seconds=2.2)


def town():
    """Lantern Square: a gentle G major waltz for harp and flute."""
    T = Track(92, 32, bpb=3)
    prog = [["G2", "D3", "G3", "B3"], ["E2", "B2", "E3", "G3"], ["C3", "G3", "C4", "E4"], ["D3", "A3", "D4", "F#4"]]
    for i in range(T.bars):
        ch = [note(n) for n in prog[i % 4]]
        T.add(harp(midi_hz(ch[0]), T.s(2.5), 0.4), i * 3, 0.42, -0.1)
        T.add(harp(midi_hz(ch[2]), T.s(1.0), 0.5), i * 3 + 1, 0.25, 0.1)
        T.add(harp(midi_hz(ch[3]), T.s(1.0), 0.5), i * 3 + 2, 0.25, 0.15)
    T.pads([[n for n in c[1:]] for c in prog], gain=0.12, cutoff=1200)
    mel = [("B4", 1), ("D5", 1), ("G5", 1), ("F#5", 2), ("E5", 1), ("E5", 1), ("G5", 1), ("C5", 1), ("D5", 3),
           ("B4", 1), ("D5", 1), ("G5", 1), ("A5", 2), ("G5", 1), ("E5", 1), ("D5", 1), ("C5", 1), ("D5", 2), ("F#4", 1)]
    end = T.melody(mel, flute, start=24, gain=0.3, p=0.2, legato=0.95)
    mel2 = [("G5", 2), ("B5", 1), ("A5", 2), ("G5", 1), ("E5", 2), ("G5", 1), ("F#5", 3), ("G5", 1), ("B5", 1), ("D6", 1),
            ("C6", 2), ("B5", 1), ("A5", 1), ("G5", 1), ("E5", 1), ("G5", 3)]
    T.melody(mel2, celesta, start=60, gain=0.26, p=-0.2)
    return T.render(wet=0.3, seconds=2.4)


def harbor():
    """The harbour: wistful A minor, harp arpeggios and a distant bell."""
    T = Track(64, 16)
    prog = [["A2", "E3", "A3", "C4", "E4"], ["F2", "C3", "F3", "A3", "C4"], ["C3", "G3", "C4", "E4", "G4"], ["G2", "D3", "G3", "B3", "D4"]]
    T.arp(prog, [(0, 0), (0.5, 1), (1, 2), (1.5, 3), (2, 4), (2.5, 3), (3, 2), (3.5, 1)], lambda f, d: harp(f, d * 2, 0.45), gain=0.26, p=-0.15)
    T.pads([c[1:4] for c in prog], gain=0.18, cutoff=1100, attack=1.6)
    mel = [("E5", 3), ("C5", 1), ("A4", 4), ("F5", 2), ("E5", 1), ("D5", 1), ("C5", 4), ("E5", 2), ("G5", 2), ("E5", 4),
           ("D5", 2), ("B4", 2), ("G4", 4)]
    T.melody(mel, lambda f, d: flute(f, d, 0.05), start=16, gain=0.24, p=0.25)
    for i in range(0, T.bars, 4):
        T.add(bell(midi_hz(note("E5")), 5.0), i * 4 + 2, 0.08, 0.7)
    return T.render(wet=0.42, seconds=3.4, damp=4200)


def cliff():
    """The lighthouse cliff: lonely E minor, sparse piano, wide pad."""
    T = Track(56, 12)
    prog = [["E3", "B3", "G4"], ["C3", "G3", "E4", "B4"], ["E3", "B3", "G4"], ["D3", "A3", "F#4"]]
    T.pads(prog, gain=0.26, cutoff=900, attack=2.0)
    notes = [("B4", 2), ("G4", 1), ("E5", 3), ("D5", 1), ("B4", 1), ("C5", 2), ("B4", 2), ("G4", 4),
             ("A4", 2), ("B4", 1), ("D5", 1), ("E5", 4), ("F#5", 2), ("E5", 1), ("D5", 1), ("B4", 4), ("r", 8)]
    T.melody(notes, lambda f, d: piano(f, d, 0.5), start=0, gain=0.34, p=-0.1)
    for i in range(T.bars):
        T.add(piano(midi_hz(note(prog[i % 4][0]) - 12), T.s(4), 0.4), i * 4, 0.22)
    return T.render(wet=0.48, seconds=4.0, damp=3800)


def storm():
    """Lantern Night: C minor ostinato, timpani, brass-ish stabs."""
    T = Track(100, 16)
    prog = [["C3", "Eb3", "G3"], ["Ab2", "C3", "Eb3"], ["Bb2", "D3", "F3"], ["G2", "B2", "D3"]]
    for i in range(T.bars):
        ch = [note(n) for n in prog[i % 4]]
        for k in range(8):
            m = ch[k % 3] + (12 if k in (3, 7) else 0)
            T.add(strings([midi_hz(m)], T.s(0.45), attack=0.02, release=0.12, cutoff=2400), i * 4 + k * 0.5, 0.11, -0.2)
        T.add(timpani(midi_hz(ch[0] - 12), 1.6), i * 4, 0.36)
        if i % 2 == 1:
            T.add(timpani(midi_hz(ch[0] - 5), 1.2), i * 4 + 2.5, 0.22)
        T.add(strings([midi_hz(n) for n in ch], T.s(3.6), attack=0.4, release=0.4, cutoff=1300), i * 4, 0.16, 0.2)
        T.add(bass(midi_hz(ch[0] - 12), T.s(3.8)), i * 4, 0.3)
    mel = [("G4", 3), ("Ab4", 1), ("Eb4", 4), ("F4", 3), ("D4", 1), ("G4", 4)]
    T.melody(mel * 2, lambda f, d: strings([f], d, attack=0.25, release=0.5, cutoff=2600), start=32, gain=0.18, p=0.15)
    return T.render(wet=0.3, seconds=2.2, damp=3500)


def lantern():
    """The finale on the quay: a hymn in E-flat, strings and bells."""
    T = Track(64, 16)
    prog = [["Eb3", "G3", "Bb3", "Eb4"], ["C3", "Eb3", "G3", "C4"], ["Ab2", "C3", "Eb3", "Ab3"], ["Bb2", "D3", "F3", "Bb3"]]
    for i in range(T.bars):
        ch = prog[i % 4]
        T.add(strings([midi_hz(note(n)) for n in ch], T.s(3.9), attack=0.8, release=0.8, cutoff=1800), i * 4, 0.24)
        T.add(bass(midi_hz(note(ch[0]) - 12), T.s(3.8)), i * 4, 0.3)
    mel = [("G5", 2), ("Bb5", 2), ("C6", 3), ("Bb5", 1), ("Ab5", 2), ("G5", 2), ("F5", 4), ("G5", 2), ("Eb5", 2),
           ("F5", 3), ("G5", 1), ("Ab5", 2), ("F5", 2), ("Eb5", 4)]
    T.melody(mel, bell, start=16, gain=0.2, p=0.2)
    T.melody(mel, lambda f, d: piano(f, d, 0.5), start=16, gain=0.2, p=-0.2, octave=-1)
    T.arp(prog, [(0, 0), (1, 2), (2, 3), (3, 2)], lambda f, d: harp(f, d * 2, 0.4), gain=0.16, p=-0.4, octave=1)
    return T.render(wet=0.44, seconds=3.6)


def dawn():
    """First light: the title theme reborn in D major, swelling."""
    T = Track(72, 16)
    prog = [["D3", "A3", "D4", "F#4"], ["A2", "E3", "A3", "C#4"], ["B2", "F#3", "B3", "D4"], ["G2", "D3", "G3", "B3"]]
    for i in range(T.bars):
        ch = prog[i % 4]
        swell = 0.14 + 0.12 * (i / T.bars)
        T.add(strings([midi_hz(note(n)) for n in ch[1:]] + [midi_hz(note(ch[1]) + 12)], T.s(3.95), attack=1.0, release=0.8, cutoff=2600), i * 4, swell)
        T.add(bass(midi_hz(note(ch[0]) - 12), T.s(3.8)), i * 4, 0.3)
    T.arp(prog, [(0, 0), (0.5, 1), (1, 2), (1.5, 3), (2, 4), (2.5, 3), (3, 2), (3.5, 1)], lambda f, d: piano(f, d * 1.5, 0.5), gain=0.2, p=-0.2, octave=1)
    mel = [("F#5", 2), ("E5", 1), ("D5", 1), ("C#5", 3), ("E5", 1), ("D5", 2), ("F#5", 1), ("A5", 1), ("B5", 4),
           ("A5", 1.5), ("B5", 0.5), ("A5", 1), ("F#5", 1), ("D5", 2), ("E5", 2), ("F#5", 2), ("E5", 2), ("D5", 4)]
    T.melody(mel, bell, start=0, gain=0.24, p=0.25)
    T.melody(mel, lambda f, d: strings([f], d, attack=0.3, release=0.6, cutoff=3200), start=32, gain=0.2, p=0.1, octave=1)
    return T.render(wet=0.42, seconds=3.4)


def sad():
    """Emotional moments: solo piano in A minor."""
    T = Track(60, 8)
    prog = [["A2", "E3", "A3", "C4"], ["D3", "A3", "D4", "F4"], ["E2", "B2", "E3", "G#3"], ["A2", "E3", "A3", "C4"]]
    T.arp(prog, [(0, 0), (1, 1), (1.5, 2), (2, 3), (3, 2)], lambda f, d: piano(f, d * 1.8, 0.4), gain=0.3, p=-0.15)
    mel = [("E5", 2), ("C5", 1), ("B4", 1), ("A4", 3), ("C5", 1), ("D5", 2), ("F5", 1), ("E5", 1), ("E5", 4),
           ("C5", 2), ("B4", 1), ("A4", 1), ("G#4", 2), ("B4", 2), ("A4", 4), ("r", 4)]
    T.melody(mel, lambda f, d: piano(f, d, 0.6), start=0, gain=0.38, p=0.1)
    T.pads([c[1:] for c in prog], gain=0.1, cutoff=900, attack=2.0)
    return T.render(wet=0.45, seconds=3.6, damp=4200)


def hope():
    """Things mending: warm C major, harp and strings."""
    T = Track(70, 8)
    prog = [["C3", "G3", "C4", "E4"], ["G2", "D3", "G3", "B3"], ["A2", "E3", "A3", "C4"], ["F2", "C3", "F3", "A3"]]
    T.arp(prog, [(0, 0), (0.5, 1), (1, 2), (1.5, 3), (2, 2), (2.5, 3), (3, 1), (3.5, 2)], lambda f, d: harp(f, d * 2, 0.5), gain=0.26, p=-0.2)
    T.pads([c[1:] for c in prog], gain=0.22, cutoff=2000, attack=1.2)
    mel = [("E5", 2), ("G5", 2), ("D5", 3), ("B4", 1), ("C5", 2), ("E5", 2), ("A5", 3), ("G5", 1)]
    T.melody(mel, celesta, start=0, gain=0.28, p=0.25)
    T.melody(mel, celesta, start=16, gain=0.22, p=-0.25, octave=1)
    return T.render(wet=0.38, seconds=3.0)


TRACKS = {"theme": theme, "office": office, "town": town, "harbor": harbor, "cliff": cliff, "storm": storm,
          "lantern": lantern, "dawn": dawn, "sad": sad, "hope": hope}
