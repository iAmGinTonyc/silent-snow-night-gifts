# Упаковка по контуру: из сгенерированного листа вырезает 4 свёртка в белой бумаге, подгоняет к точному
# силуэту игры (маски target_*.png), переводит в координаты вещи (2 px на единицу) и раскрашивает
# во все бумаги игры с их узорами. Пишет art/wrap/shape_<вид>_<бумага>.png и печатает прямоугольники.
import json, math, os, re, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
Image.MAX_IMAGE_PIXELS = None
SCR = "/private/tmp/claude-501/-Users-anton-Desktop-spoon-it/d9d7f96f-f433-4f73-99e0-e93020e0a7a6/scratchpad/"
sys.path.insert(0, SCR)
from recut_customers import flood_fast, components, pool, up
from pal_alpha import save as pal_save

P = "/Users/anton/Desktop/spoon it/lentochka/"
S = SCR + "shape/"
PX = 2.0          # пикселей на единицу вещи
layout = json.load(open(S + "layout.json"))
sheet = Image.open(S + "shape_out.png").convert("RGB").resize((3840, 2160), Image.LANCZOS)
A = np.asarray(sheet).astype(np.float32)

# бумаги игры
data = open(P + "scripts/data.gd", encoding="utf-8").read()
papers = []
for m in re.finditer(r'\{"id": "([a-z_]+)", "name": "[^"]+", "tag": "[a-z]+", "base": "(#[0-9a-f]{6})", "accent": "(#[0-9a-f]{6})", "pattern": "([a-z]+)"', data):
    papers.append(m.groups())
print(len(papers), "papers")


def hexc(h):
    return np.array([int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)], np.float32)


def pattern_mask(kind, w, h):
    """Маска узора 0..1 в пикселях текстуры (узор в единицах вещи, одинаковый масштаб у всех)."""
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    u = PX
    if kind == "stars":
        step = 34 * u
        for j in range(-1, int(h / step) + 2):
            for i in range(-1, int(w / step) + 2):
                cx = i * step + (step / 2 if j % 2 else 0); cy = j * step
                pts = []
                for k in range(10):
                    r = (7 if k % 2 == 0 else 3) * u
                    a = -math.pi / 2 + k * math.pi / 5
                    pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
                d.polygon(pts, fill=255)
    elif kind == "stripes":
        per = 22 * u
        for t in range(-int(h / per) - 2, int((w + h) / per) + 2):
            x0 = t * per
            d.polygon([(x0, 0), (x0 + 9 * u, 0), (x0 + 9 * u - h, h), (x0 - h, h)], fill=255)
    elif kind == "lines":
        per = 14 * u
        for t in range(-int(h / per) - 2, int((w + h) / per) + 2):
            x0 = t * per
            d.line([(x0, 0), (x0 - h, h)], fill=200, width=max(1, int(2 * u)))
    elif kind == "polka":
        step = 26 * u
        for j in range(-1, int(h / step) + 2):
            for i in range(-1, int(w / step) + 2):
                cx = i * step + (step / 2 if j % 2 else 0); cy = j * step
                r = 5 * u
                d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    elif kind == "snow":
        step = 32 * u
        for j in range(-1, int(h / step) + 2):
            for i in range(-1, int(w / step) + 2):
                cx = i * step + (step / 2 if j % 2 else 0); cy = j * step
                for k in range(3):
                    a = k * math.pi / 3
                    dx, dy = math.cos(a) * 6 * u, math.sin(a) * 6 * u
                    d.line([(cx - dx, cy - dy), (cx + dx, cy + dy)], fill=255, width=max(1, int(1.6 * u)))
    elif kind == "check":
        sq = 16 * u
        for j in range(0, int(h / sq) + 1):
            for i in range(0, int(w / sq) + 1):
                if (i + j) % 2 == 0:
                    d.rectangle((i * sq, j * sq, i * sq + sq, j * sq + sq), fill=120)
    return np.asarray(m).astype(np.float32) / 255.0


rects = {}
for kind, L in layout.items():
    tgt = np.asarray(Image.open(S + "target_%s.png" % kind)) > 127
    ys, xs = np.nonzero(tgt)
    x0, x1, y0, y1 = xs.min() - 120, xs.max() + 120, ys.min() - 120, ys.max() + 120
    x0, y0 = max(0, x0), max(0, y0)
    reg = A[y0:y1, x0:x1]
    # вырезка с серого фона
    h, w, _ = reg.shape
    ring = np.zeros((h, w), bool); ring[:6] = ring[-6:] = True; ring[:, :6] = ring[:, -6:] = True
    bg = np.median(reg[ring], axis=0)
    cand = np.sqrt(((reg - bg) ** 2).sum(axis=2)) < 30.0
    obj = ~flood_fast(cand, ring)
    # оставляем самую большую область (сам свёрток)
    f = 2
    small = pool(obj, f, "any")
    comps = components(small)
    big = max(comps, key=lambda c: len(c[0]))
    keep = np.zeros_like(small); keep[big] = True
    obj &= up(keep, f, obj.shape)
    t = tgt[y0:y1, x0:x1]
    # подгонка: масштаб вокруг центра цели и сдвиг
    ty, tx = np.nonzero(t); tcy, tcx = ty.mean(), tx.mean()
    best = (-1, 1.0, 0, 0)
    oimg = Image.fromarray((obj * 255).astype(np.uint8))
    for sc in [0.9 + 0.02 * i for i in range(11)]:
        nw, nh = round(w * sc), round(h * sc)
        mm = np.asarray(oimg.resize((nw, nh), Image.BILINEAR)) > 127
        # центр масштаба — центр цели
        ox = round(tcx - tcx * sc); oy = round(tcy - tcy * sc)
        base = np.zeros((h, w), bool)
        xa, ya = max(0, ox), max(0, oy); xb, yb = min(w, ox + nw), min(h, oy + nh)
        base[ya:yb, xa:xb] = mm[ya - oy:yb - oy, xa - ox:xb - ox]
        for dy in range(-40, 41, 4):
            for dx in range(-40, 41, 4):
                sh = np.zeros_like(base)
                sxa, sya = max(0, dx), max(0, dy); sxb, syb = min(w, w + dx), min(h, h + dy)
                sh[sya:syb, sxa:sxb] = base[sya - dy:syb - dy, sxa - dx:sxb - dx]
                v = (sh & t).sum() / max(1, (sh | t).sum())
                if v > best[0]:
                    best = (v, sc, ox + dx, oy + dy)
    v, sc, ox, oy = best
    print(kind, "iou", round(float(v), 3), "scale", round(sc, 2))
    rgba = np.dstack([reg, obj.astype(np.float32) * 255]).astype(np.uint8)
    im = Image.fromarray(rgba).resize((round(w * sc), round(h * sc)), Image.LANCZOS)
    al = Image.fromarray((obj * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.0)).resize(im.size, Image.LANCZOS)
    im.putalpha(al)
    can = Image.new("RGBA", (w, h), (0, 0, 0, 0)); can.paste(im, (ox, oy))
    # в координаты вещи: точка листа (X, Y) -> ((X - L.ox) / k, (Y - L.oy) / k)
    k = L["k"]
    cb = can.getbbox()
    ux0 = (x0 + cb[0] - L["ox"]) / k; uy0 = (y0 + cb[1] - L["oy"]) / k
    ux1 = (x0 + cb[2] - L["ox"]) / k; uy1 = (y0 + cb[3] - L["oy"]) / k
    crop = can.crop(cb)
    tw, th = round((ux1 - ux0) * PX), round((uy1 - uy0) * PX)
    neutral = np.asarray(crop.resize((tw, th), Image.LANCZOS)).astype(np.float32)
    rects[kind] = [round(ux0, 2), round(uy0, 2), round(ux1 - ux0, 2), round(uy1 - uy0, 2)]
    Image.fromarray(neutral.astype(np.uint8)).save(S + "neutral_%s.png" % kind)
    # раскраска
    lum = neutral[:, :, :3].mean(axis=2)
    alpha = neutral[:, :, 3]
    inside = alpha > 200
    white = np.percentile(lum[inside], 92) if inside.any() else 240.0
    shade = np.clip(lum / max(white, 1.0), 0.0, 1.06)
    ink = lum < 95
    for pid, base_hex, acc_hex, pat in papers:
        b = hexc(base_hex); a = hexc(acc_hex)
        col = b[None, None, :] * shade[:, :, None]
        if pat != "plain":
            pm = pattern_mask(pat, tw, th)[:, :, None]
            col = col * (1 - pm) + (a[None, None, :] * np.clip(shade, 0, 1.0)[:, :, None]) * pm
        # контур остаётся тёмным
        col = np.where(ink[:, :, None], neutral[:, :, :3] * 0.85 + b[None, None, :] * 0.05, col)
        out = np.dstack([np.clip(col, 0, 255), alpha]).astype(np.uint8)
        pal_save(Image.fromarray(out), P + "art/wrap/shape_%s_%s.png" % (kind, pid))
print("RECTS", json.dumps(rects))
