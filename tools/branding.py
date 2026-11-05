"""Draws Lumi OS branding from the pixel ghost of the Lumi site (site/site.js in AlbertS15/Lumi):
the Plymouth boot splash frames, the logo for About / first setup, and the GDM login logo.
Run: python3 tools/branding.py   (needs Pillow)"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "system_files" / "usr" / "share"
TEAL, EYE = (0x5F, 0xD3, 0xAD, 255), (0x0B, 0x15, 0x14, 255)
BG = "#0e0f0f"
BODY = ["....BBBBBB....", "..BBBBBBBBBB..", ".BBBBBBBBBBBB.", ".BBBBBBBBBBBB.", "BBBBBBBBBBBBBB", "BBBBBBBBBBBBBB",
        "BBBBBBBBBBBBBB", "BBBBBBBBBBBBBB", "BBBBBBBBBBBBBB", "BBBBBBBBBBBBBB"]
HEMS = ["BB..BBBBBB..BB", "..BBBB..BBBB.."]
W, H = 14, 13


def sprite(step):
    """The 14x13 ghost, as site.js drawGhost() draws it: step 0 is lifted by one pixel."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lift = 0 if step else 1
    px = im.load()
    for y, row in enumerate(BODY + [HEMS[step]]):
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y + lift] = TEAL
    for x0, y0, w, h in ((3, 4, 2, 2), (9, 4, 2, 2), (6, 7, 2, 1)):
        for yy in range(y0, y0 + h):
            for xx in range(x0, x0 + w):
                px[xx, yy + lift] = EYE
    return im


def scaled(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def svg(fill, eye, step=1):
    rects = []
    lift = 0 if step else 1
    for y, row in enumerate(BODY + [HEMS[step]]):
        for x, ch in enumerate(row):
            if ch != ".":
                rects.append((x, y + lift, 1, 1, fill))
    if eye:
        for x0, y0, w, h in ((3, 4, 2, 2), (9, 4, 2, 2), (6, 7, 2, 1)):
            rects.append((x0, y0 + lift, w, h, eye))
    body = "".join(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}"/>' for x, y, w, h, c in rects)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
            f'shape-rendering="crispEdges">{body}</svg>\n')


def main():
    # Plymouth: two frames, the ghost floats up and down.
    ply = ROOT / "plymouth" / "themes" / "lumi"
    ply.mkdir(parents=True, exist_ok=True)
    for i in (0, 1):
        scaled(sprite(i), 12).save(ply / f"ghost{i}.png", optimize=True)

    # Logo for Settings → About and first setup (LOGO=lumi-logo in os-release), on a transparent square.
    for size in (16, 22, 24, 32, 48, 64, 96, 128, 256, 512):
        k = max(1, (size * 3 // 4) // W)
        g = scaled(sprite(1), k) if size >= 32 else sprite(1)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.paste(g, ((size - g.width) // 2, (size - g.height) // 2), g)
        d = ROOT / "icons" / "hicolor" / f"{size}x{size}" / "apps"
        d.mkdir(parents=True, exist_ok=True)
        canvas.save(d / "lumi-logo.png", optimize=True)
    sc = ROOT / "icons" / "hicolor" / "scalable" / "apps"
    sc.mkdir(parents=True, exist_ok=True)
    (sc / "lumi-logo.svg").write_text(svg("#5fd3ad", "#0b1514"))
    sym = ROOT / "icons" / "hicolor" / "symbolic" / "apps"
    sym.mkdir(parents=True, exist_ok=True)
    (sym / "lumi-logo-symbolic.svg").write_text(svg("#bebebe", None))

    # GDM login screen and legacy pixmaps users of the Fedora logo look for.
    pm = ROOT / "pixmaps"
    pm.mkdir(parents=True, exist_ok=True)
    # GDM draws its logo under the user list; at 256 px it covered "Not listed?", so it is small and wide.
    gdm = Image.new("RGBA", (192, 64), (0, 0, 0, 0))
    g = scaled(sprite(1), 4)
    gdm.paste(g, ((192 - g.width) // 2, (64 - g.height) // 2), g)
    gdm.save(pm / "lumi-gdm-logo.png", optimize=True)
    big = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    g = scaled(sprite(1), 14)
    big.paste(g, ((256 - g.width) // 2, (256 - g.height) // 2), g)
    big.save(pm / "lumi-logo.png", optimize=True)


if __name__ == "__main__":
    main()
