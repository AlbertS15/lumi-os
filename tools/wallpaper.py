"""Draws the Lumi OS wallpapers: the pixel ghost on a dark glow, once per GNOME accent colour.

lumi.png is the default (Lumi's teal); lumi-<accent>.png follow Settings → Appearance → accent colour
(see system_files/usr/libexec/lumi-accent-wallpaper). Run: python3 tools/wallpaper.py"""
import random
from PIL import Image, ImageDraw, ImageFilter

W, H = 3840, 2160
BG, EYE = (14, 15, 15), (30, 30, 28)
# GNOME's accent colours, as lighter tints that read well on the dark background. Teal stays Lumi's own.
ACCENTS = {
    "teal": (93, 202, 165), "blue": (98, 160, 234), "green": (87, 214, 137), "yellow": (240, 210, 90),
    "orange": (255, 163, 72), "red": (246, 97, 81), "pink": (240, 140, 200), "purple": (192, 120, 220),
    "slate": (153, 173, 193),
}
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

def draw(TEAL):
    img = Image.new("RGB", (W, H), BG)
    glow = Image.new("RGB", (W, H), BG)
    ImageDraw.Draw(glow).ellipse((W * 0.18, H * 0.05, W * 0.82, H * 0.95), fill=tuple(round(BG[i] + (TEAL[i] - BG[i]) * 0.22) for i in range(3)))
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

    return img


OUT = "system_files/usr/share/backgrounds/lumi"
for name, colour in ACCENTS.items():
    img = draw(colour)
    img.save(f"{OUT}/lumi-{name}.png", optimize=True)
    if name == "teal":
        img.save(f"{OUT}/lumi.png", optimize=True)
