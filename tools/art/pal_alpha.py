# Палитровый PNG с гладким краем: 192 цвета для непрозрачных пикселей, 8 цветов края × 7 уровней прозрачности,
# индекс 0 полностью прозрачный. Обычная палитра Pillow схлопывает прозрачность до нескольких уровней.
import sys, os
import numpy as np
from PIL import Image

N_OPAQUE, N_EDGE, LEVELS = 192, 8, 7


def strip_quant(px, n):
    """px: (N,3) uint8 -> (palette (n,3), indices (N,))."""
    if len(px) == 0:
        return np.zeros((0, 3), np.uint8), np.zeros(0, np.int64)
    img = Image.fromarray(px.reshape(-1, 1, 3))
    q = img.quantize(colors=min(n, max(1, len(np.unique(px.view([('', px.dtype)] * 3))))), method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[:3 * n], np.uint8).reshape(-1, 3)
    return pal, np.asarray(q).reshape(-1).astype(np.int64)


def save(im, path):
    a = np.asarray(im.convert("RGBA"))
    rgb, al = a[:, :, :3].reshape(-1, 3), a[:, :, 3].reshape(-1)
    idx = np.zeros(len(al), np.int64)
    opaque = al >= 247
    semi = (al >= 12) & ~opaque
    pal_o, io = strip_quant(rgb[opaque], N_OPAQUE)
    idx[opaque] = 1 + io
    pal_e, ie = strip_quant(rgb[semi], N_EDGE)
    lev = np.clip(np.round(al[semi] / 255.0 * (LEVELS + 1)).astype(np.int64), 1, LEVELS)
    idx[semi] = 1 + N_OPAQUE + ie * LEVELS + (lev - 1)
    palette = np.zeros((256, 3), np.uint8)
    trns = np.zeros(256, np.uint8)
    palette[1:1 + len(pal_o)] = pal_o
    trns[1:1 + N_OPAQUE] = 255
    for e in range(len(pal_e)):
        for l in range(LEVELS):
            j = 1 + N_OPAQUE + e * LEVELS + l
            palette[j] = pal_e[e]
            trns[j] = int(round(255.0 * (l + 1) / (LEVELS + 1)))
    out = Image.fromarray(idx.reshape(a.shape[:2]).astype(np.uint8), "P")
    out.putpalette(palette.reshape(-1).tolist())
    out.info["transparency"] = bytes(trns.tolist())
    out.save(path, optimize=True, transparency=bytes(trns.tolist()))


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    tot = 0
    for f in sorted(os.listdir(src)):
        if f.endswith(".png"):
            save(Image.open(os.path.join(src, f)), os.path.join(dst, f))
            tot += os.path.getsize(os.path.join(dst, f))
    print("total MB", round(tot / 1e6, 2))
