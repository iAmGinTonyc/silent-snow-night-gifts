# Лист-образец для упаковки по контуру: 4 точных силуэта (как в shapes.gd + отступ SHAPE_PAD + хвост-веер),
# белая бумага с контуром на сером фоне, внутри бледная игрушка. Сохраняет маски и раскладку для подгонки.
import json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

P = "/Users/anton/Desktop/spoon it/silent snow night gifts/"
S = "/private/tmp/claude-501/-Users-anton-Desktop-spoon-it/d9d7f96f-f433-4f73-99e0-e93020e0a7a6/scratchpad/shape/"
import os
os.makedirs(S, exist_ok=True)
PAD = 6.0
TAILS = {"ball": (75, 0, 1, 0, 40), "bear": (0, -88, 0, -1, 44), "ornament": (0, -62, 0, -1, 34), "train": (118, 0, 1, 0, 40)}
TOP = {"ball": "top_ball.png", "bear": "top_bear.png", "ornament": "top_ornament.png", "train": "top_train.png"}
ITEM = {"ball": (150, 150), "bear": (150, 180), "ornament": (110, 124), "train": (232, 66)}


def ellipse(c, rx, ry, rot=0.0, n=48):
    return [(c[0] + math.cos(t) * rx * math.cos(rot) - math.sin(t) * ry * math.sin(rot),
             c[1] + math.cos(t) * rx * math.sin(rot) + math.sin(t) * ry * math.cos(rot)) for t in [2 * math.pi * k / n for k in range(n)]]


def rect(x, y, w, h):
    return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]


def parts(kind):
    if kind == "ball":
        return [ellipse((0, 0), 75, 75)]
    if kind == "bear":
        return [ellipse((0, 26), 50, 54), ellipse((0, -46), 36, 34), ellipse((-27, -74), 13, 13), ellipse((27, -74), 13, 13),
                ellipse((-58, 12), 16, 30, 0.35), ellipse((58, 12), 16, 30, -0.35), ellipse((-28, 72), 22, 19), ellipse((28, 72), 22, 19)]
    if kind == "ornament":
        return [ellipse((0, 6), 55, 55), rect(-13, -62, 26, 20)]
    if kind == "train":
        ps = [rect(-115, -26, 100, 52), rect(-16, -5, 26, 10), rect(8, -27, 100, 54), ellipse((108, 0), 10, 27)]
        for x in (-100, -52, 20, 70):
            ps += [rect(x, -32, 18, 8), rect(x, 24, 18, 8)]
        return ps


def fan(kind):
    bx, by, dx, dy, ln = TAILS[kind]
    b = np.array([bx, by], float); d = np.array([dx, dy], float); pp = np.array([-dy, dx], float)
    L = ln * 1.0; sp = 36.0
    pts = [b - d * 10 + pp * -13, b + d * L + pp * -sp, b + d * (L * 0.88) + pp * (-sp * 0.45), b + d * (L * 1.06),
           b + d * (L * 0.88) + pp * (sp * 0.45), b + d * L + pp * sp, b - d * 10 + pp * 13]
    return [tuple(p) for p in pts]


def mask(kind, k, ox, oy, W, H):
    """Маска силуэта с отступом и хвостом: k пикселей на единицу, (ox, oy) — где ноль координат вещи."""
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    w = int(round(2 * PAD * k))
    for poly in parts(kind):
        pts = [(ox + x * k, oy + y * k) for x, y in poly]
        d.polygon(pts, fill=255)
        d.line(pts + [pts[0]], fill=255, width=w, joint="curve")   # отступ PAD вокруг каждой части
        for p in pts:
            d.ellipse((p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2), fill=255)
    d.polygon([(ox + x * k, oy + y * k) for x, y in fan(kind)], fill=255)
    return m


if __name__ == "__main__":
    W, H = 3840, 2160
    sheet = Image.new("RGB", (W, H), (128, 128, 128))
    layout = {}
    kinds = ["ball", "bear", "ornament", "train"]
    for i, kind in enumerate(kinds):
        r, c = divmod(i, 2)
        cx, cy = c * W // 2 + W // 4, r * H // 2 + H // 4
        # размер вещи с хвостом в единицах
        k = 4.6 if kind != "train" else 4.6
        if kind == "train":
            k = 5.0
        if kind == "bear":
            k = 3.8
        m = mask(kind, k, cx, cy, W, H)
        bb = m.getbbox()
        # сдвигаем, чтобы маска была по центру клетки
        sx, sy = cx - (bb[0] + bb[2]) // 2, cy - (bb[1] + bb[3]) // 2
        ox, oy = cx + sx, cy + sy
        m = mask(kind, k, ox, oy, W, H)
        edge = Image.new("L", m.size, 0)
        ImageDraw.Draw(edge).bitmap((0, 0), m, fill=255)
        bbm = m.getbbox()
        crop = m.crop(bbm).filter(ImageFilter.MaxFilter(13))
        edge = Image.new("L", m.size, 0); edge.paste(crop, bbm[:2])
        sheet.paste((40, 26, 30), mask=edge)
        sheet.paste((246, 244, 238), mask=m)
        if kind == "ornament":
            m.save(S + "target_%s.png" % kind); layout[kind] = {"k": k, "ox": ox, "oy": oy}; continue
        top = Image.open(P + "art/wrap/" + TOP[kind]).convert("RGBA")
        iw, ih = ITEM[kind]
        top = top.resize((round(iw * k), round(ih * k)), Image.LANCZOS)
        a = np.asarray(top).copy(); a[:, :, 3] = (a[:, :, 3] * 0.32).astype(np.uint8)
        top = Image.fromarray(a)
        sheet.paste(top, (round(ox - iw * k / 2), round(oy - ih * k / 2)), top)
        m.save(S + "target_%s.png" % kind)
        layout[kind] = {"k": k, "ox": ox, "oy": oy}
    sheet.save(S + "shape_in.png")
    json.dump(layout, open(S + "layout.json", "w"), indent=1)
    sheet.resize((1280, 720)).save(S + "shape_in_s.jpg", quality=85)
    print(layout)
