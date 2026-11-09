"""Renders UNSENT's music, ambience and sound effects to OGG Vorbis.
Usage: python3 tools/audio/build_audio.py [music|ambience|sfx|<track>...]"""
import os
import subprocess
import sys
import tempfile
import time

import numpy as np
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(__file__))
from synth import SR  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")


def write_ogg(y, path, quality=4):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    y = np.clip(y, -1, 1)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        wavfile.write(tf.name, SR, (y * 32767).astype(np.int16))
        tmp = tf.name
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.unlink(tmp)


def build_music(names=None):
    import music
    for name, fn in music.TRACKS.items():
        if names and name not in names:
            continue
        t = time.time()
        y = fn()
        write_ogg(y, os.path.join(OUT, "music", name + ".ogg"), quality=4)
        print(f"  music/{name}: {len(y) / SR:.1f}s ({time.time() - t:.1f}s)")


def build_ambience(names=None):
    import ambience
    for name, fn in ambience.AMBIENCE.items():
        if names and name not in names:
            continue
        y = fn()
        write_ogg(y, os.path.join(OUT, "ambience", name + ".ogg"), quality=3)
        print(f"  ambience/{name}: {len(y) / SR:.1f}s")


def build_sfx(names=None):
    import sfx
    for name, fn in sfx.SFX.items():
        if names and name not in names:
            continue
        y = fn()
        write_ogg(y, os.path.join(OUT, "sfx", name + ".ogg"), quality=4)
    print(f"  sfx: {len(sfx.SFX)} effects")


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or "music" in args:
        build_music()
    if not args or "ambience" in args:
        build_ambience()
    if not args or "sfx" in args:
        build_sfx()
    rest = [a for a in args if a not in ("music", "ambience", "sfx")]
    if rest:
        build_music(rest)
