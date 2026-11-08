"""Builds every scene's art layers + meta.json, and UI/FX textures.
Usage: python3 tools/art/build_art.py [scene ...]"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "art")

SCENES = ["square", "harbor", "cliff", "post_office", "lamp_room"]
MODULES = {"square": "scene_square", "harbor": "scene_harbor", "cliff": "scene_cliff",
           "post_office": "scene_post_office", "lamp_room": "scene_lamp_room"}


def build_scene(name):
    mod = __import__(MODULES[name])
    out = os.path.join(OUT, "scenes", name)
    os.makedirs(out, exist_ok=True)
    t = time.time()
    meta = mod.build(out)
    with open(os.path.join(out, "meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print(f"  {name}: {len(meta['layers'])} layers, {len(meta.get('props', []))} props ({time.time() - t:.1f}s)")


if __name__ == "__main__":
    which = sys.argv[1:] or SCENES + ["ui"]
    for w in which:
        if w == "ui":
            import ui_art
            ui_art.build(OUT)
        else:
            build_scene(w)
