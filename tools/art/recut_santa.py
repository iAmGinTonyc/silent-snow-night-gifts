# Санта с ровным контуром: тот же лист и та же раскладка поз, что в make_santa.py, но маска в полном размере.
import os, sys
import numpy as np
from PIL import Image, ImageFilter
Image.MAX_IMAGE_PIXELS = None
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recut_customers import flood_fast, components, pool, up, T

SRC = "/Users/anton/Desktop/spoon it/silent snow night gifts/art/source/santa_sheet.png"
OUT = sys.argv[1]
TARGET_H = 480
KEEP = 0.66
MAPPING = [1, 4, 0, 3, 5, 5, 2]

im = Image.open(SRC).convert("RGB")
a = np.asarray(im, dtype=np.float32)
H, W, _ = a.shape
ring = np.zeros((H, W), bool); ring[:12] = ring[-12:] = True; ring[:, :12] = ring[:, -12:] = True
bg = np.median(a[ring], axis=0)
dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
cand = dist < T
obj = ~flood_fast(cand, ring)
# соринки убираем на копии в 3 раза меньше
f = 3
small = pool(obj, f, "any")
drop = np.zeros_like(small)
for py, px in components(small):
    if len(py) < 70:
        drop[py, px] = True
obj &= ~up(drop, f, obj.shape)

cw, ch = W // 3, H // 2
poses = []
for i in range(6):
    r, c = divmod(i, 3)
    m = np.zeros_like(obj); m[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] = obj[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw]
    # обрывки соседних поз: кроме самой большой области, всё, что касается края клетки
    cell = m[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw]
    cs = pool(cell, f, "any")
    comps = components(cs)
    big = max(range(len(comps)), key=lambda j: len(comps[j][0]))
    dropc = np.zeros_like(cs)
    for j, (py, px) in enumerate(comps):
        if j != big and (px.min() <= 1 or px.max() >= cs.shape[1] - 2 or py.min() <= 1 or py.max() >= cs.shape[0] - 2):
            dropc[py, px] = True
    cell &= ~up(dropc, f, cell.shape)
    m[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] = cell
    ys, xs = np.nonzero(m)
    poses.append((m, xs.min(), xs.max(), ys.min(), ys.max()))
heights = sorted(p[4] - p[3] for p in poses)
med = heights[len(heights) // 2]
k = TARGET_H / (KEEP * med)


def finish(rgb_img, mask, scale):
    mb = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3))
    mbin = np.asarray(mb, dtype=np.float32) / 255.0
    msoft = np.asarray(mb.filter(ImageFilter.GaussianBlur(0.5 / scale)), dtype=np.float32) / 255.0
    rgb = np.asarray(rgb_img, dtype=np.float32)
    nw, nh = max(1, round(rgb_img.width * scale)), max(1, round(rgb_img.height * scale))
    pre = np.dstack([np.asarray(Image.fromarray(np.clip(rgb[:, :, i] * mbin, 0, 255).astype(np.uint8)).resize((nw, nh), Image.BOX), np.float32) for i in range(3)])
    cov = np.asarray(Image.fromarray((mbin * 255).astype(np.uint8)).resize((nw, nh), Image.BOX), np.float32) / 255.0
    aa = np.asarray(Image.fromarray((msoft * 255).astype(np.uint8)).resize((nw, nh), Image.BOX), np.float32) / 255.0
    col = np.where(cov[:, :, None] > 0.02, pre / np.maximum(cov[:, :, None], 0.02), -1.0)
    for _ in range(3):
        miss = col[:, :, 0] < 0
        if not miss.any():
            break
        acc = np.zeros_like(col); n = np.zeros(col.shape[:2], np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            sh = np.roll(np.roll(col, dy, axis=0), dx, axis=1)
            ok = sh[:, :, 0] >= 0
            acc += np.where(ok[:, :, None], sh, 0); n += ok
        fill = miss & (n > 0)
        col[fill] = acc[fill] / n[fill][:, None]
    col[col < 0] = 0
    return Image.fromarray(np.dstack([np.clip(col, 0, 255), np.clip(aa, 0, 1) * 255]).astype(np.uint8))


frames = []
for (m, x0, x1, y0, y1) in poses:
    cut = y0 + int(KEEP * (y1 - y0))
    mm = m.copy(); mm[cut:, :] = False
    box = (x0 - 4, y0 - 4, x1 + 6, cut)
    frames.append(finish(im.crop(box), mm[box[1]:box[3], box[0]:box[2]], k))
canvas_w = max(fr.width for fr in frames)
os.makedirs(OUT, exist_ok=True)
for idx, src in enumerate(MAPPING):
    fr = frames[src]
    can = Image.new("RGBA", (canvas_w, TARGET_H), (0, 0, 0, 0))
    can.paste(fr, ((canvas_w - fr.width) // 2, TARGET_H - fr.height))
    can.save(os.path.join(OUT, "santa_%d.png" % idx), optimize=True)
print("santa", canvas_w, TARGET_H)
