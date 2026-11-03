"""Draws the Lumi OS wallpaper: the pixel ghost on the dark green glow of the Lumi videos. Run: python3 tools/wallpaper.py"""
import random
from PIL import Image, ImageDraw, ImageFilter

W, H = 3840, 2160
BG, TEAL, EYE = (14, 15, 15), (93, 202, 165), (30, 30, 28)
GHOST = [
    "....BBBBBB....",
    "..BBBBBBBBBB..",
    ".BBBBBBBBBBBB.",
    ".BBBBBBBBBBBB.",
    "BBBEEBBBBEEBBB",
    "BBBEEBBBBEEBBB",
    "BBBBBBBBBBBBBB",
    "BBBBBBEEBBBBBB",
    "BBBBBBBBBBBBBB",
    "BBBBBBBBBBBBBB",
    "BB..BBBBBB..BB",
]

img = Image.new("RGB", (W, H), BG)
glow = Image.new("RGB", (W, H), BG)
ImageDraw.Draw(glow).ellipse((W * 0.18, H * 0.05, W * 0.82, H * 0.95), fill=(26, 58, 49))
img = glow.filter(ImageFilter.GaussianBlur(520))

d = ImageDraw.Draw(img, "RGBA")
random.seed(15)
for _ in range(90):
    s = random.choice((10, 14, 18, 24))
    x, y = random.uniform(0, W), random.uniform(0, H)
    d.rectangle((x, y, x + s, y + s), fill=TEAL + (random.randint(40, 120),))

u = 34
gw, gh = len(GHOST[0]) * u, len(GHOST) * u
halo = Image.new("L", (W, H), 0)
ImageDraw.Draw(halo).ellipse((W / 2 - gw, H / 2 - gh * 1.1, W / 2 + gw, H / 2 + gh * 1.1), fill=70)
halo = halo.filter(ImageFilter.GaussianBlur(160))
img.paste(Image.new("RGB", (W, H), TEAL), (0, 0), halo)

d = ImageDraw.Draw(img)
x0, y0 = W / 2 - gw / 2, H / 2 - gh / 2
for r, row in enumerate(GHOST):
    for c, ch in enumerate(row):
        if ch != ".":
            d.rectangle((x0 + c * u, y0 + r * u, x0 + (c + 1) * u - 1, y0 + (r + 1) * u - 1), fill=TEAL if ch == "B" else EYE)

img.save("system_files/usr/share/backgrounds/lumi/lumi.png", optimize=True)
