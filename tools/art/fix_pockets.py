# Убирает кремовый фон между колёсами паровозиков (нижняя треть) и внутри петельки ёлочного шара (верх по центру).
import glob, sys
import numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, "/private/tmp/claude-501/-Users-anton-Desktop-spoon-it/d9d7f96f-f433-4f73-99e0-e93020e0a7a6/scratchpad")
from pockets import comps

def fix(path, rule):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    rgb, al = a[:, :, :3], a[:, :, 3]
    lum = rgb.mean(axis=2); sat = rgb.max(axis=2) - rgb.min(axis=2)
    cream = (al > 150) & (lum > 180) & (sat < 70) & (rgb[:, :, 0] >= rgb[:, :, 2])
    H, W = cream.shape
    kill = np.zeros_like(cream)
    n = 0
    for ys, xs in comps(cream):
        if len(ys) < 6:
            continue
        cy, cx = ys.mean() / H, xs.mean() / W
        if rule == "train" and cy > 0.62:
            kill[ys, xs] = True; n += 1
        if rule == "ornament" and cy < 0.16 and 0.38 < cx < 0.65 and len(ys) < 400:
            kill[ys, xs] = True; n += 1
    if n == 0:
        return 0
    # край дырки: светлые смешанные пиксели на 1 px вокруг тоже прозрачнее
    ring = np.asarray(Image.fromarray((kill * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
    ring &= ~kill & (lum > 120)
    out = a.copy()
    out[:, :, 3][kill] = 0
    out[:, :, 3][ring] *= 0.45
    Image.fromarray(out.astype(np.uint8)).save(path, optimize=True)
    return n

for f in sorted(glob.glob("art/shop/item_train*.png") + glob.glob("art/wrap/top_train*.png")):
    print(f, fix(f, "train"))
for f in sorted(glob.glob("art/shop/item_ornament*.png")):
    print(f, fix(f, "ornament"))
