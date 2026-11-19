import os, sys, json
from collections import deque
import numpy as np
from PIL import Image, ImageFilter
Image.MAX_IMAGE_PIXELS = None

SRC = "/Users/anton/Desktop/spoon it/silent snow night gifts/art/source/"
OUT = "/Users/anton/Desktop/spoon it/silent snow night gifts/art/customers/"
SCR = "/private/tmp/claude-501/-Users-anton-Desktop-spoon-it/d9d7f96f-f433-4f73-99e0-e93020e0a7a6/scratchpad/"
TARGET_H, INSET, T = 360, 16, 34.0
SPECK_MIN = 70

def dilate4(m):
    d = m.copy()
    d[1:, :] |= m[:-1, :]; d[:-1, :] |= m[1:, :]
    d[:, 1:] |= m[:, :-1]; d[:, :-1] |= m[:, 1:]
    return d

def flood(cand, seeds):
    reach = cand & seeds
    for _ in range(3000):
        nxt = dilate4(reach) & cand
        if (nxt == reach).all():
            break
        reach = nxt
    return reach

def drop_specks(char, min_area):
    h, w = char.shape
    seen = np.zeros_like(char)
    for y in range(h):
        for x in np.where(char[y] & ~seen[y])[0]:
            if seen[y, x]:
                continue
            q = deque([(y, x)]); seen[y, x] = True; pts = [(y, x)]
            while q:
                cy, cx = q.popleft()
                for ny, nx in ((cy+1,cx),(cy-1,cx),(cy,cx+1),(cy,cx-1)):
                    if 0 <= ny < h and 0 <= nx < w and char[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx)); pts.append((ny, nx))
            if len(pts) < min_area:
                for py, px in pts:
                    char[py, px] = False
    return char

def clusters(proj, thresh):
    idx = np.where(proj > thresh)[0]
    out = []; start = prev = idx[0]
    for i in idx[1:]:
        if i - prev > 4:
            out.append((start, prev)); start = i
        prev = i
    out.append((start, prev))
    return out

def grid(img, ncols, nrows):
    """Возвращает (cols_per_row, rows): границы столбцов считаются для каждой строки отдельно (панели могут чуть смещаться)."""
    g = np.asarray(img.convert("L"))
    dark = g < 95
    H, W = dark.shape
    cy = [c for c in clusters(dark.sum(axis=1), 0.8 * W) if c[1] - c[0] <= 16]
    if len(cy) != 2 * nrows:
        print("  grid rows fallback:", len(cy))
        rows = [(round(r * H / nrows) + 14, round((r + 1) * H / nrows) - 14) for r in range(nrows)]
    else:
        rows = [(cy[2*r][1] + 1, cy[2*r+1][0] - 1) for r in range(nrows)]
    gx = [c for c in clusters(dark.sum(axis=0), 0.8 * H) if c[1] - c[0] <= 16]
    cols_per_row = []
    for (y0, y1) in rows:
        band = dark[y0:y1, :]
        cx = [c for c in clusters(band.sum(axis=0), 0.8 * band.shape[0]) if c[1] - c[0] <= 16]
        if len(cx) == 2 * ncols:
            cols_per_row.append([(cx[2*c][1] + 1, cx[2*c+1][0] - 1) for c in range(ncols)])
        elif len(gx) == 2 * ncols:
            cols_per_row.append([(gx[2*c][1] + 1, gx[2*c+1][0] - 1) for c in range(ncols)])
        else:
            print("  grid cols fallback in row:", len(cx), len(gx))
            cols_per_row.append([(round(c * W / ncols) + 14, round((c + 1) * W / ncols) - 14) for c in range(ncols)])
    return cols_per_row, rows

def cutout(small):
    a = np.asarray(small, dtype=np.float32)
    h, w, _ = a.shape
    ring = np.zeros((h, w), bool)
    ring[:6, :] = ring[:, :6] = ring[:, -6:] = True
    full = ring.copy(); full[-6:, :] = True
    bg = np.median(a[full], axis=0)
    cand = np.sqrt(((a - bg) ** 2).sum(axis=2)) < T
    reach = flood(cand, ring)
    char = drop_specks(~reach, SPECK_MIN)
    # кусочки фона, оставшиеся между рукой и телом: однородно светлые и без тёмного контура
    lum = a.mean(axis=2)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    h, w = char.shape
    seen = np.zeros_like(char)
    for y in range(h):
        for x in np.where(char[y] & ~seen[y])[0]:
            if seen[y, x]:
                continue
            q = deque([(y, x)]); seen[y, x] = True; pts = [(y, x)]
            while q:
                cy, cx = q.popleft()
                for ny, nx in ((cy+1,cx),(cy-1,cx),(cy,cx+1),(cy,cx-1)):
                    if 0 <= ny < h and 0 <= nx < w and char[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx)); pts.append((ny, nx))
            if len(pts) < 20000:
                ys = np.array([p[0] for p in pts]); xs = np.array([p[1] for p in pts])
                darkf = float((lum[ys, xs] < 100).mean())
                md = float(dist[ys, xs].mean())
                if darkf < 0.012 and md < 75.0:
                    for py, px in pts:
                        char[py, px] = False
    return char

def build(cid, sheet, row, cache, frac=1.0, remap=None):
    if sheet not in cache:
        img = Image.open(SRC + sheet).convert("RGB")
        cache[sheet] = (img,) + grid(img, 7, SHEET_ROWS[sheet])
    img, cols, rows = cache[sheet]
    frames = []
    for c in (remap or range(7)):
        x0, x1 = cols[row][c]; y0, y1 = rows[row]
        p = img.crop((x0 + INSET, y0 + INSET, x1 - INSET, y0 + INSET + round((y1 - y0 - 2 * INSET) * frac)))
        s = TARGET_H / p.height
        small = p.resize((round(p.width * s), TARGET_H), Image.LANCZOS)
        m = cutout(small)
        if c == 6:
            m = drop_specks(m, 3000)
        frames.append((small, m))
    ys, xs = [], []
    for _, m in frames:
        yy, xx = np.where(m)
        ys += [yy.min(), yy.max()]; xs += [xx.min(), xx.max()]
    pad = 6
    X0, X1 = max(0, min(xs) - pad), min(frames[0][0].width, max(xs) + pad)
    Y0, Y1 = max(0, min(ys) - pad), min(TARGET_H, max(ys) + pad)
    out = []
    for i, (small, m) in enumerate(frames):
        mi = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
        rgba = small.convert("RGBA"); rgba.putalpha(mi)
        rgba = rgba.crop((X0, Y0, X1, Y1))
        rgba.quantize(colors=200, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(OUT + "%s_%d.png" % (cid, i), optimize=True)
        out.append(rgba)
    print(cid, "frames", out[0].size, flush=True)
    return out

SHEET_ROWS = {"sheet_C1.png": 5, "sheet_C2.png": 5, "sheet_C3.png": 5, "sheet_D.png": 4, "sheet_E1.png": 2, "sheet_E2.png": 2, "sheet_E3.png": 2}
if __name__ == "__main__":
    jobs = json.loads(sys.argv[1])    # [[id, sheet, row], ...]
    cache = {}
    allf = {}
    for job in jobs:
        cid, sheet, row = job[0], job[1], job[2]
        allf[cid] = build(cid, sheet, row, cache, job[3] if len(job) > 3 else 1.0, job[4] if len(job) > 4 else None)
    cw = max(f.width for fr in allf.values() for f in fr); chh = max(f.height for fr in allf.values() for f in fr)
    cs = Image.new("RGB", (cw * 7, chh * len(allf)), (38, 32, 60))
    for r, (cid, fr) in enumerate(allf.items()):
        for c, f in enumerate(fr):
            cs.paste(f, (c * cw + (cw - f.width) // 2, r * chh + (chh - f.height)), f)
    name = sys.argv[2] if len(sys.argv) > 2 else "contact_customers.png"
    cs.convert("RGB").resize((cs.width // 2, cs.height // 2)).save(SCR + name)
    print("contact", cs.size)
