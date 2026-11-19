# Злые кадры в новом качестве: вырезка с листов-результатов в полном размере (как recut_customers),
# масштаб и сдвиг подбираются по силуэту к новому кадру 1. Пишет <id>_7.png в папку out.
import json, os, sys
import numpy as np
from PIL import Image, ImageFilter
Image.MAX_IMAGE_PIXELS = None
SCR = os.path.dirname(os.path.abspath(__file__)) + "/"
sys.path.insert(0, SCR)
from recut_customers import matte

OLD = "/Users/anton/Desktop/spoon it/silent snow night gifts/art/customers/"


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


def bbox(m):
    ys, xs = np.nonzero(m)
    return xs.min(), xs.max(), ys.min(), ys.max()


def run(n, new_dir, out_dir):
    place_in = json.load(open(SCR + "angry_in_%d.json" % n))
    sheet = Image.open(SCR + "gen/angry_out_%d.png" % n).convert("RGB")
    sx, sy = sheet.width / 3840.0, sheet.height / 2160.0
    sm = (sx + sy) / 2
    for cid, p in place_in.items():
        cx0, cy0, cx1, cy1 = p["cell"]
        fx, fy, fw, fh = p["frame"]
        s = p["s"]
        M = 60
        rx0, ry0 = max(cx0 + 8, fx - M), max(cy0 + 8, fy - M)
        rx1, ry1 = min(cx1 - 8, fx + fw + M), cy1 - 6
        reg = sheet.crop((round(rx0 * sx), round(ry0 * sy), round(rx1 * sx), round(ry1 * sy)))
        k = reg.height / 360.0
        m = matte(reg, k, 70)
        ref = Image.open(os.path.join(new_dir, "%s_1.png" % cid)).convert("RGBA")
        ref_m = np.asarray(ref)[:, :, 3] > 127
        old1 = np.asarray(Image.open(OLD + "%s_1.png" % cid).convert("RGBA"))[:, :, 3] > 127
        ratio = (bbox(ref_m)[3] - bbox(ref_m)[2]) / max(1, (bbox(old1)[3] - bbox(old1)[2]))
        base = (1.0 / (s * sm)) * ratio            # пиксели листа -> пиксели нового кадра
        W, H = ref.size
        best = (-1, None)
        for sc in [0.95 + 0.01 * i for i in range(11)]:
            fr = finish(reg, m, base * sc)
            fm = np.asarray(fr)[:, :, 3] > 127
            fb, rb = bbox(fm), bbox(ref_m)
            # начальный сдвиг: совпадают середины по x и нижние края персонажа с кадром 1
            ox0 = round((rb[0] + rb[1]) / 2 - (fb[0] + fb[1]) / 2)
            oy0 = rb[3] - fb[3]
            P = 24
            big = np.zeros((H + 2 * P, W + 2 * P), bool)
            x0, y0 = ox0 + P, oy0 + P
            hh, ww = fm.shape
            xa, ya = max(0, x0), max(0, y0)
            xb, yb = min(big.shape[1], x0 + ww), min(big.shape[0], y0 + hh)
            big[ya:yb, xa:xb] = fm[ya - y0:yb - y0, xa - x0:xb - x0]
            for dy in range(-18, 19, 2):
                for dx in range(-18, 19, 2):
                    mm = big[P - dy:P - dy + H, P - dx:P - dx + W]
                    v = (mm & ref_m).sum() / max(1, (mm | ref_m).sum())
                    if v > best[0]:
                        best = (v, (sc, ox0 + dx, oy0 + dy, fr))
        v, (sc, ox, oy, fr) = best
        can = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        can.paste(fr, (ox, oy))   # холст пустой: без маски, иначе прозрачность возводится в квадрат
        os.makedirs(out_dir, exist_ok=True)
        can.save(os.path.join(out_dir, "%s_7.png" % cid), optimize=True)
        print(cid, "iou", round(float(v), 3), "scale", round(sc, 2), flush=True)


if __name__ == "__main__":
    for n in (0, 1):
        run(n, sys.argv[1], sys.argv[2])
