# Выравнивание кадров загрузчика: коробка не должна ездить по кадру.
import numpy as np
from PIL import Image
SRC = "/Users/anton/Desktop/spoon it/silent snow night gifts/web/loader.png"
im = Image.open(SRC).convert("RGBA")
N, C = 6, 256
fr = [im.crop(((i % N) * C, (i // N) * C, (i % N + 1) * C, (i // N + 1) * C)) for i in range(N * N)]
al = [np.asarray(f)[:, :, 3] > 60 for f in fr]

def shifted(m, dx, dy):
    out = np.zeros_like(m)
    h, w = m.shape
    xs0, xs1 = max(0, dx), min(w, w + dx); ys0, ys1 = max(0, dy), min(h, h + dy)
    out[ys0:ys1, xs0:xs1] = m[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out

corr = [(0, 0)]
for i in range(1, 29):
    ref = shifted(al[i - 1], *corr[i - 1])
    best = (-1, 0, 0)
    for dy in range(-24, 25, 2):
        for dx in range(-56, 57, 2):
            m = shifted(al[i], dx, dy)
            v = (m & ref).sum() / max(1, (m | ref).sum())
            if v > best[0]:
                best = (v, dx, dy)
    v, bx, by = best
    for dy in range(by - 1, by + 2):
        for dx in range(bx - 1, bx + 2):
            m = shifted(al[i], dx, dy)
            vv = (m & ref).sum() / max(1, (m | ref).sum())
            if vv > best[0]:
                best = (vv, dx, dy)
    corr.append((best[1], best[2]))
    print(i, "col", i % N, "corr", best[1], best[2], "iou", round(float(best[0]), 3))
np.save("loader_corr.npy", np.array(corr))
