"""Composites a scene's layers at a camera position for quick art review.
Usage: python3 tools/art/preview.py <scene> <cam_left> [out.png]"""
import json, os, sys
from PIL import Image
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def grad(w, h, top, mid, hor, horizon):
    import numpy as np
    def c(s): s=s.lstrip('#'); return np.array([int(s[i:i+2],16) for i in (0,2,4)], float)
    y = np.linspace(0,1,h)[:,None]
    a = np.clip(y/(horizon*0.8),0,1); b=np.clip((y-horizon*0.5)/(horizon*0.5),0,1)
    col = c(top)*(1-a)+c(mid)*a
    col = col*(1-b)+c(hor)*b
    img = np.repeat(col[:,None,:], w, axis=1)
    return Image.fromarray(img.astype('uint8'), 'RGB').convert('RGBA')

def render(scene, cam_left, out, vw=720, vh=1280, cam_y=None):
    d = os.path.join(ROOT, "assets/art/scenes", scene)
    meta = json.load(open(os.path.join(d, "meta.json")))
    hz = meta.get("horizon", 840)
    if cam_y is None: cam_y = 990 - vh*0.13
    top = cam_y - vh/2
    img = grad(vw, vh, "#1b1d44", "#55467f", "#f1a27c", max(0.2,(hz-top)/vh))
    if meta.get("sea"):
        from PIL import ImageDraw
        dr = ImageDraw.Draw(img)
        for y in range(int(hz-top), vh):
            t=min(1,(y-(hz-top))/300)
            dr.line([(0,y),(vw,y)], fill=(int(217*(1-t)+32*t),int(144*(1-t)+40*t),int(126*(1-t)+79*t),255))
    for L in sorted(meta["layers"], key=lambda l: (l.get("group")=="fg", l.get("z",0))):
        t = Image.open(os.path.join(d, L["tex"])).convert("RGBA")
        s = L["scale"]
        if s != 1: t = t.resize((int(t.width*s), int(t.height*s)), Image.LANCZOS)
        x = L["x"] + cam_left*(1-L["factor"]) - cam_left
        y = L["y"] - top
        img.alpha_composite(t, (int(round(x)), int(round(y)))) if x>=0 and y>=0 else img.paste(t, (int(round(x)), int(round(y))), t)
    for P in meta.get("props", []):
        if "tex" not in P or "not" in P.get("if",""): continue
        t = Image.open(os.path.join(d, P["tex"])).convert("RGBA")
        img.paste(t, (int(P["x"]-cam_left), int(P["y"]-top)), t)
    img.convert("RGB").save(out)

if __name__ == "__main__":
    render(sys.argv[1], float(sys.argv[2]), sys.argv[3] if len(sys.argv)>3 else "/tmp/preview.png")
