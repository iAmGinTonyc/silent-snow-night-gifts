# Выравнивание кадров клиента по телу (нижняя часть кадра) к кадру 0: при смене лица персонаж не дёргается.
# Холст расширяется до общего прямоугольника. У Лео на сдвинутых кадрах перчатка обрезана краем панели:
# её дорисовывает кадр 0 (поза рук одна и та же). Пишет RGBA в out и печатает новые доли рта.
import glob, json, os, sys
import numpy as np
from PIL import Image

SRC = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
MOUTHS = json.loads(sys.argv[3])          # {id: [fx, fy, frame]} — кадр, на котором мерили рот


def body_mask(a):
    m = a[:, :, 3] > 128
    H = m.shape[0]
    out = np.zeros_like(m)
    out[int(H * 0.62):, :] = m[int(H * 0.62):, :]
    return out


def shift(m, dx, dy):
    o = np.zeros_like(m)
    h, w = m.shape
    xs0, xs1 = max(0, dx), min(w, w + dx); ys0, ys1 = max(0, dy), min(h, h + dy)
    o[ys0:ys1, xs0:xs1] = m[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return o


ids = sorted(set(os.path.basename(p).rsplit("_", 1)[0] for p in glob.glob(SRC + "/*_0.png")))
new_mouths = {}
for cid in ids:
    files = sorted(glob.glob(SRC + "/%s_*.png" % cid), key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
    fr = [np.asarray(Image.open(f).convert("RGBA")) for f in files]
    if cid == "santa":
        for f, a in zip(files, fr):
            Image.fromarray(a).save(OUT + "/" + os.path.basename(f))
        new_mouths[cid] = MOUTHS[cid][:2]
        continue
    ref = body_mask(fr[0])
    shifts = [(0, 0)]
    for a in fr[1:]:
        b = body_mask(a)
        best = (-1, 0, 0)
        for dy in range(-10, 11, 2):
            for dx in range(-100, 101, 2):
                s = shift(b, dx, dy)
                v = (s & ref).sum() / max(1, (s | ref).sum())
                if v > best[0]:
                    best = (v, dx, dy)
        shifts.append((best[1], best[2]))
    H, W = fr[0].shape[:2]
    x0 = min(0, min(s[0] for s in shifts)); x1 = max(W, max(W + s[0] for s in shifts))
    y0 = min(0, min(s[1] for s in shifts)); y1 = max(H, max(H + s[1] for s in shifts))
    NW, NH = x1 - x0, y1 - y0
    out = []
    for a, (dx, dy) in zip(fr, shifts):
        can = Image.new("RGBA", (NW, NH), (0, 0, 0, 0))
        can.paste(Image.fromarray(a), (dx - x0, dy - y0))
        out.append(np.asarray(can).copy())
    if cid == "leo":
        # перчатка справа: где кадр обрезан, подкладываем кадр 0 (только нижняя половина, без капель пота)
        base = out[0]
        for i in (2, 4, 5, 6):
            a = out[i]
            al = a[:, :, 3]
            cols = np.nonzero((al > 128).any(axis=0))[0]
            cut = cols.max()
            if cut >= NW - 1 - (shifts[0][0] - x0) - 2 or True:
                yh = int(NH * 0.45)
                region = np.zeros(al.shape, bool)
                region[yh:, max(0, cut - 3):] = True
                take = region & (base[:, :, 3] > al)
                a[take] = base[take]
                out[i] = a
    for f, a in zip(files, out):
        Image.fromarray(a).save(OUT + "/" + os.path.basename(f))
    m = MOUTHS[cid]
    fidx = int(m[2])
    dx, dy = shifts[fidx]
    px = (m[0] * W + dx - x0) / NW
    py = (m[1] * H + dy - y0) / NH
    new_mouths[cid] = [round(px, 3), round(py, 3)]
    print(cid, "size", (W, H), "->", (NW, NH), "shifts", shifts, flush=True)
print("MOUTHS", json.dumps(new_mouths))
