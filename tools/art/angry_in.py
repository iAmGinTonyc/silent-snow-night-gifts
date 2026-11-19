# Лист-образец для злых лиц: кадр 1 каждого клиента на кремовом фоне, 5×2 панели, тёмные рамки.
import json, sys
from PIL import Image, ImageDraw

CUST = "/Users/anton/Desktop/spoon it/lentochka/art/customers/"
SCR = "/private/tmp/claude-501/-Users-anton-Desktop-spoon-it/d9d7f96f-f433-4f73-99e0-e93020e0a7a6/scratchpad/"
SHEETS = [
    ["aaliyah", "alrashid", "anh", "dmitri", "fchristmas", "fernandez", "ingrid", "jin", "kwame", "leo"],
    ["lucia", "mateo", "meena", "murphy", "okafor", "pavel", "rosa", "sasha", "tanaka", "zeynep"],
]
W, H, COLS, ROWS, B = 3840, 2160, 5, 2, 14
BG, LINE = (250, 230, 210), (40, 26, 30)
BASE = 1

def build(n):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    cw, ch = W / COLS, H / ROWS
    for c in range(COLS + 1):
        x = round(c * cw); d.rectangle((x - B // 2, 0, x + B // 2, H), fill=LINE)
    for r in range(ROWS + 1):
        y = round(r * ch); d.rectangle((0, y - B // 2, W, y + B // 2), fill=LINE)
    place = {}
    for i, cid in enumerate(SHEETS[n]):
        r, c = divmod(i, COLS)
        x0, y0 = round(c * cw) + B // 2 + 1, round(r * ch) + B // 2 + 1
        x1, y1 = round((c + 1) * cw) - B // 2 - 1, round((r + 1) * ch) - B // 2 - 1
        f = Image.open(CUST + "%s_%d.png" % (cid, BASE)).convert("RGBA")
        s = min(0.88 * (x1 - x0) / f.width, 0.84 * (y1 - y0) / f.height)
        fw, fh = round(f.width * s), round(f.height * s)
        fx, fy = x0 + ((x1 - x0) - fw) // 2, y1 - fh
        img.paste(f.resize((fw, fh), Image.LANCZOS), (fx, fy), f.resize((fw, fh), Image.LANCZOS))
        place[cid] = {"cell": [x0, y0, x1, y1], "frame": [fx, fy, fw, fh], "s": s, "size": [f.width, f.height]}
    img.save(SCR + "angry_in_%d.png" % n)
    json.dump(place, open(SCR + "angry_in_%d.json" % n, "w"), indent=1)
    print("sheet", n, "ok")

for n in map(int, sys.argv[1:]):
    build(n)
