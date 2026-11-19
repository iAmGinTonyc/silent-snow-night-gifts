# Перерезка кадров клиентов с ровным контуром: маска считается на исходнике в полном размере,
# контур не съедается, цвет у края берётся только из пикселей персонажа (без кремового ореола),
# уменьшение до TARGET_H уже готового кадра. Пишет RGBA PNG.
import json, sys, os
from collections import deque
import numpy as np
from PIL import Image, ImageFilter
Image.MAX_IMAGE_PIXELS = None
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_customers import grid, flood

SRC = "/Users/anton/Desktop/spoon it/lentochka/art/source/"
SCR = os.path.dirname(os.path.abspath(__file__)) + "/"
T = 34.0
INSET = 16
SHEET_ROWS = {"sheet_C1.png": 5, "sheet_C2.png": 5, "sheet_C3.png": 5, "sheet_D.png": 4, "sheet_E1.png": 2,
              "sheet_E2.png": 2, "sheet_E3.png": 2, "sheet_A_5x7.png": 5, "sheet_B_2x7.png": 2}
_cache = {}


A_COLS = [(99, 828), (876, 1610), (1658, 2390), (2437, 3166), (3214, 3941), (3989, 4712), (4761, 5469)]
A_ROWS = [(63, 625), (667, 1228), (1272, 1833), (1877, 2439), (2480, 3041)]
B_COLS = [(85, 1183), (1248, 2348), (2414, 3517), (3580, 4686), (4751, 5854), (5921, 7018), (7092, 8181)]
B_ROWS = [(91, 993), (1060, 1987)]
FIXED = {"sheet_A_5x7.png": (A_COLS, A_ROWS), "sheet_B_2x7.png": (B_COLS, B_ROWS)}


def sheet(name):
    if name not in _cache:
        img = Image.open(SRC + name).convert("RGB")
        if name in FIXED:
            cols, rows = FIXED[name]
            _cache[name] = (img, [cols] * len(rows), rows)
        else:
            _cache[name] = (img,) + grid(img, 7, SHEET_ROWS[name])
    return _cache[name]


def components(mask):
    """Связные области маски: список массивов (ys, xs). Через scipy-подобную разметку на numpy-обходе."""
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    out = []
    ys, xs = np.nonzero(mask)
    n = 0
    for y0, x0 in zip(ys, xs):
        if lab[y0, x0]:
            continue
        n += 1
        q = deque([(y0, x0)]); lab[y0, x0] = n; py = [y0]; px = [x0]
        while q:
            cy, cx = q.popleft()
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n; q.append((ny, nx)); py.append(ny); px.append(nx)
        out.append((np.array(py), np.array(px)))
    return out


def dil(m):
    d = m.copy()
    d[1:, :] |= m[:-1, :]; d[:-1, :] |= m[1:, :]
    d[:, 1:] |= m[:, :-1]; d[:, :-1] |= m[:, 1:]
    return d


def pool(m, f, mode):
    h, w = m.shape
    hh, ww = h // f, w // f
    b = m[:hh * f, :ww * f].reshape(hh, f, ww, f)
    return b.all(axis=(1, 3)) if mode == "all" else b.any(axis=(1, 3))


def up(m, f, shape):
    big = np.repeat(np.repeat(m, f, axis=0), f, axis=1)
    out = np.zeros(shape, bool)
    out[:big.shape[0], :big.shape[1]] = big[:shape[0], :shape[1]]
    return out


def flood_fast(cand, seeds):
    """Заливка: грубо на копии в 4 раза меньше, потом уточнение в полном размере."""
    f = 4
    cs, ss = pool(cand, f, "all"), pool(seeds & cand, f, "any") & pool(cand, f, "all")
    r = ss
    for _ in range(4000):
        nxt = dil(r) & cs
        if (nxt == r).all():
            break
        r = nxt
    reach = (up(r, f, cand.shape) | seeds) & cand
    for i in range(400):
        nxt = dil(reach) & cand
        if i % 8 == 7 and (nxt == reach).all():
            break
        reach = nxt
    return reach


def matte(panel, k, speck=70):
    """Маска персонажа на панели в полном размере. k = во сколько раз панель больше кадра 360 px."""
    a = np.asarray(panel, dtype=np.float32)
    h, w, _ = a.shape
    ring = np.zeros((h, w), bool)
    b = max(6, int(6 * k))
    ring[:b, :] = ring[:, :b] = ring[:, -b:] = True
    full = ring.copy(); full[-b:, :] = True
    bg = np.median(a[full], axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    cand = dist < T
    reach = flood_fast(cand, ring)
    char = ~reach
    # разбор областей на копии около 360 px: соринки и кусочки фона между рукой и телом
    f = max(1, int(round(k)))
    small = pool(char, f, "any")
    lum = a.mean(axis=2)
    lum_s = lum[:small.shape[0] * f:f, :small.shape[1] * f:f]
    dist_s = dist[:small.shape[0] * f:f, :small.shape[1] * f:f]
    drop = np.zeros_like(small)
    for py, px in components(small):
        n = len(py)
        if n < speck:
            drop[py, px] = True
        elif n < 20000:
            if float((lum_s[py, px] < 100).mean()) < 0.012 and float(dist_s[py, px].mean()) < 75.0:
                drop[py, px] = True
    char &= ~up(drop, f, char.shape)
    return char


def cut_frame(img, cols, rows, row, c, frac, target_scale):
    x0, x1 = cols[row][c]; y0, y1 = rows[row]
    p = img.crop((x0 + INSET, y0 + INSET, x1 - INSET, y0 + INSET + round((y1 - y0 - 2 * INSET) * frac)))
    k = p.height / 360.0
    m = matte(p, k, 3000 if c == 6 else 70)   # в кадре смеха блёстки убираем: игра рисует свои
    # край персонажа на исходнике: одна ступень внутрь, чтобы смешанные с фоном пиксели не дали ореол
    mb = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3))
    mbin = np.asarray(mb, dtype=np.float32) / 255.0
    msoft = np.asarray(mb.filter(ImageFilter.GaussianBlur(0.5 / target_scale)), dtype=np.float32) / 255.0
    rgb = np.asarray(p, dtype=np.float32)
    nw, nh = max(1, round(p.width * target_scale)), max(1, round(p.height * target_scale))
    # цвет только из пикселей персонажа (без фона), прозрачность из сглаженной маски
    pre = np.dstack([np.asarray(Image.fromarray(np.clip(rgb[:, :, i] * mbin, 0, 255).astype(np.uint8)).resize((nw, nh), Image.BOX), np.float32) for i in range(3)])
    cov = np.asarray(Image.fromarray((mbin * 255).astype(np.uint8)).resize((nw, nh), Image.BOX), np.float32) / 255.0
    aa = np.asarray(Image.fromarray((msoft * 255).astype(np.uint8)).resize((nw, nh), Image.BOX), np.float32) / 255.0
    col = np.where(cov[:, :, None] > 0.02, pre / np.maximum(cov[:, :, None], 0.02), -1.0)
    # пиксели края без своего цвета берут средний цвет соседей-персонажа
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
    out = np.dstack([np.clip(col, 0, 255), np.clip(aa, 0, 1) * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def build(cid, sheet_name, row, frac=1.0, remap=None, target_h=480):
    img, cols, rows = sheet(sheet_name)
    y0, y1 = rows[row]
    ph = round((y1 - y0 - 2 * INSET) * frac)
    s = target_h / ph
    frames = [cut_frame(img, cols, rows, row, c, frac, s) for c in (remap or range(7))]
    ys, xs = [], []
    for f in frames:
        a = np.asarray(f)[:, :, 3] > 8
        yy, xx = np.nonzero(a)
        ys += [yy.min(), yy.max()]; xs += [xx.min(), xx.max()]
    pad = round(6 * target_h / 360)
    W = min(f.width for f in frames)
    X0, X1 = max(0, min(xs) - pad), min(W, max(xs) + pad + 1)
    Y0, Y1 = max(0, min(ys) - pad), min(frames[0].height, max(ys) + 1)
    return [f.crop((X0, Y0, X1, Y1)) for f in frames]


if __name__ == "__main__":
    jobs = json.loads(sys.argv[1])
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    for job in jobs:
        cid, sh, row = job[0], job[1], job[2]
        frac = job[3] if len(job) > 3 else 1.0
        remap = job[4] if len(job) > 4 else None
        fr = build(cid, sh, row, frac, remap)
        for i, f in enumerate(fr):
            f.save(os.path.join(out_dir, "%s_%d.png" % (cid, i)), optimize=True)
        print(cid, fr[0].size, flush=True)
