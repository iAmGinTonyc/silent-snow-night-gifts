import numpy as np
from PIL import Image
SRC = "loader_before_align.png"
OUT = "/Users/anton/Desktop/spoon it/lentochka/web/loader.png"
im = Image.open(SRC).convert("RGBA")
N, C = 6, 256
corr = [tuple(int(v) for v in c) for c in np.load("loader_corr.npy")]
corr += [(0, 0)] * (36 - len(corr))
# кадры 3 и 4: клапаны бумаги путают подгонку, берём линию ряда 0 (около 11 px на кадр)
corr[3] = (33, -3); corr[4] = (44, -5)
# улёт подарка (29..33): та же линия, что у рядов 4 и 5, собственное движение кадров остаётся
for k, b in {22: 192, 23: 208, 24: 208, 25: 208, 26: 207, 27: 206, 28: 203}.items():
    corr[k] = (corr[k][0], corr[k][1] + 215 - b)   # подарок стоит на той же линии, что и раньше
corr[29] = (48, 5); corr[30] = (12, 5); corr[31] = (21, 5); corr[32] = (30, 5); corr[33] = (39, 5)
GX = -32                      # весь ряд кадров к центру ячейки
out = Image.new("RGBA", im.size, (0, 0, 0, 0))
for i in range(34):
    r, c = divmod(i, N)
    f = im.crop((c * C, r * C, (c + 1) * C, (r + 1) * C))
    dx, dy = corr[i]
    cell = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    cell.paste(f, (dx + GX, dy), f)
    out.paste(cell, (c * C, r * C))
q = out.quantize(colors=160, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
q.save(OUT, optimize=True)
a = np.asarray(out)[:, :, 3] > 60
for i in range(34):
    r, c = divmod(i, N)
    m = a[r * C:(r + 1) * C, c * C:(c + 1) * C]
    ys, xs = np.where(m)
    print(i, "x", xs.min(), xs.max(), "cx", round(xs.mean(), 1), "bottom", ys.max())
