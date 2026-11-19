# Кусочки кремового фона внутри картинок игрушек: области непрозрачных пикселей цвета фона, отделённые контуром.
import glob, sys
from collections import deque
import numpy as np
from PIL import Image

def comps(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32); out = []; n = 0
    for y0, x0 in zip(*np.nonzero(mask)):
        if lab[y0, x0]: continue
        n += 1; q = deque([(y0, x0)]); lab[y0, x0] = n; ys = [y0]; xs = [x0]
        while q:
            cy, cx = q.popleft()
            for ny, nx in ((cy+1,cx),(cy-1,cx),(cy,cx+1),(cy,cx-1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n; q.append((ny, nx)); ys.append(ny); xs.append(nx)
        out.append((np.array(ys), np.array(xs)))
    return out

def find(path):
    a = np.asarray(Image.open(path).convert('RGBA')).astype(np.float32)
    rgb, al = a[:, :, :3], a[:, :, 3]
    lum = rgb.mean(axis=2); sat = rgb.max(axis=2) - rgb.min(axis=2)
    # кремовый фон листов: светлый, тёплый, мало насыщенный
    cream = (al > 200) & (lum > 205) & (sat < 60) & (rgb[:, :, 0] >= rgb[:, :, 2])
    H, W = cream.shape
    res = []
    for ys, xs in comps(cream):
        if len(ys) < 12: continue
        res.append((len(ys), round(xs.mean() / W, 2), round(ys.mean() / H, 2), xs.min(), xs.max(), ys.min(), ys.max()))
    return H, W, res

if __name__ == "__main__":
    for f in sys.argv[1:]:
        H, W, res = find(f)
        print(f, W, H, [r[:3] for r in sorted(res, reverse=True)[:8]])
