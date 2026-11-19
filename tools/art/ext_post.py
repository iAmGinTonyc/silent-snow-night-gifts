# Расширенные фоны: результат генерации к размеру холста, центр вклеивается из оригинала с мягким швом,
# из магазина вырезается слой прилавка. Пишет файлы *_ext в проект.
import sys
import numpy as np
from PIL import Image, ImageFilter
Image.MAX_IMAGE_PIXELS = None

S = "/private/tmp/claude-501/-Users-anton-Desktop-spoon-it/d9d7f96f-f433-4f73-99e0-e93020e0a7a6/scratchpad/ext/"
P = "/Users/anton/Desktop/spoon it/lentochka/"
FEATHER = 28

JOBS = {
    # имя: (исходник центра, холст, место центра, куда сохранить)
    "order": (S + "order_flat_1920.png", (2560, 1440), (320, 180), P + "art/shop/order_back_ext.jpg"),
    "shelf": (P + "art/shop/shelf_closeup.jpg", (2640, 1131), (360, 0), P + "art/shop/shelf_closeup_ext.jpg"),
    "wrap": (P + "art/wrap/wrap_back.jpg", (2560, 1440), (320, 180), P + "art/wrap/wrap_back_ext.jpg"),
    "menu": (P + "art/ui/menu.jpg", (2134, 1200), (267, 150), P + "art/ui/menu_ext.jpg"),
}


def blend_center(out, center, pos):
    """Оригинал поверх, края оригинала растворяются на FEATHER px (только там, где есть дорисовка)."""
    W, H = out.size
    w, h = center.size
    x, y = pos
    m = np.ones((h, w), np.float32)
    ramp = np.linspace(0.0, 1.0, FEATHER, dtype=np.float32)
    if x > 0:
        m[:, :FEATHER] *= ramp[None, :]
    if x + w < W:
        m[:, -FEATHER:] *= ramp[::-1][None, :]
    if y > 0:
        m[:FEATHER, :] *= ramp[:, None]
    if y + h < H:
        m[-FEATHER:, :] *= ramp[::-1][:, None]
    mask = Image.fromarray((m * 255).astype(np.uint8))
    res = out.copy()
    res.paste(center.convert("RGB"), (x, y), mask)
    return res


def run(name):
    src, size, pos, dst = JOBS[name]
    out = Image.open(S + name + "_out.png").convert("RGB").resize(size, Image.LANCZOS)
    res = blend_center(out, Image.open(src), pos)
    res.save(dst, quality=90, optimize=True)
    res.save(S + name + "_ext_preview.jpg", quality=80)
    print(name, "->", dst, res.size)
    if name == "order":
        # слой прилавка: от верха прилавка (y 482.7 рамки) до низа, во всю ширину
        top = 180 + round(482.7 * 1.5)
        layer = res.crop((0, top, size[0], size[1])).convert("RGBA")
        a = np.full((layer.height, layer.width), 255, np.uint8)
        cnt = Image.open(P + "art/shop/order_counter.png").convert("RGBA").resize((1920, round(237.3 * 1.5)), Image.LANCZOS)
        ca = np.asarray(cnt)[:, :, 3]
        # по краям, где прилавок дорисован, верхний край ровный: как в среднем у оригинала
        edge = int(round(np.mean([np.argmax(ca[:, xx] > 128) for xx in range(0, 1920, 8)])))
        a[:edge, :] = 0
        a[edge:edge + 2, :] = 128
        a[:ca.shape[0], 320:320 + 1920] = ca    # в рамке ровно как раньше
        layer.putalpha(Image.fromarray(a))
        layer.save(P + "art/shop/order_counter_ext.png", optimize=True)
        print("counter layer", layer.size, "edge", edge)


if __name__ == "__main__":
    for n in sys.argv[1:]:
        run(n)
