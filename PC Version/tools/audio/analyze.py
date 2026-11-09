"""Objective checks for rendered audio: level, clipping, DC, loop seam, spectrogram."""
import subprocess, sys, tempfile, os
import numpy as np
from scipy.io import wavfile
from scipy import signal

def load(path):
    tmp = tempfile.mktemp(suffix=".wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, tmp], check=True)
    sr, y = wavfile.read(tmp); os.unlink(tmp)
    y = y.astype(np.float32) / 32768
    return sr, y if y.ndim == 1 else y.mean(axis=1)

def report(path, spec_png=None):
    sr, y = load(path)
    peak = np.max(np.abs(y)); rms = np.sqrt(np.mean(y**2))
    dc = np.mean(y)
    seam = abs(y[-1] - y[0])
    n = int(0.05*sr)
    seam_rms = np.sqrt(np.mean((y[-n:])**2)), np.sqrt(np.mean((y[:n])**2))
    clip = np.mean(np.abs(y) > 0.99)
    F = np.abs(np.fft.rfft(y[: sr * 20]))**2; fr = np.fft.rfftfreq(min(len(y), sr*20), 1/sr)
    hf = 10*np.log10(F[fr > 8000].sum() / F.sum() + 1e-12)
    f, t, S = signal.spectrogram(y, sr, nperseg=4096, noverlap=2048)
    cen = np.sum(f[:,None]*S, axis=0)/(np.sum(S, axis=0)+1e-12)
    print(f"{os.path.basename(path):24s} {len(y)/sr:6.1f}s peak {peak:.2f} rms {20*np.log10(rms+1e-9):6.1f}dB dc {dc:+.4f} "
          f"seam {seam:.3f} end/start rms {seam_rms[0]:.3f}/{seam_rms[1]:.3f} clip {clip*100:.2f}% centroid {np.median(cen):5.0f}Hz HF>8k {hf:5.1f}dB")
    if spec_png:
        from PIL import Image
        Sd = 10*np.log10(S[:400]+1e-10)
        Sd = np.clip((Sd - Sd.max() + 70)/70, 0, 1)[::-1]
        Image.fromarray((Sd*255).astype(np.uint8)).resize((1000, 300)).save(spec_png)

if __name__ == "__main__":
    for p in sys.argv[1:]:
        report(p, spec_png=os.environ.get("SPEC") if len(sys.argv) == 2 else None)
