#!/usr/bin/env python3
"""Makes the Google Play listing graphics in docs/play-store/.

  icon-512.png             512 x 512 store icon (full-bleed, no alpha)
  feature-graphic.png      1024 x 500 feature graphic (no alpha)

The icon is scaled down from design/app-icon.png's source (assets/app_icon.png
is only 360 px, so pass the 1024 px original with --icon). The feature graphic
uses two of the phone screenshots, which come from
`SCREENSHOTS=1 flutter test test/screenshots --update-goldens --plain-name 'play store'`.

  python3 tools/make-play-graphics.py --icon /path/to/app-icon.png

Needs Pillow. Fonts: Roboto from the Flutter SDK ($FLUTTER_ROOT), else DejaVu.
No TrueNAS logo anywhere: it is iXsystems' trademark.
"""
import argparse
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "play-store"


def font(weight: str, size: int) -> ImageFont.FreeTypeFont:
    flutter = os.environ.get("FLUTTER_ROOT", "")
    for path in (
        f"{flutter}/bin/cache/artifacts/material_fonts/Roboto-{weight}.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        for x in range(w):
            # Mostly vertical like the icon, tilted a little.
            t = min(1.0, max(0.0, (y / h) * 0.8 + (x / w) * 0.2))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))
    return img


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *img.size), radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def paste_phone(canvas, shot, x, y, width):
    height = round(width * shot.height / shot.width)
    screen = rounded(shot.convert("RGB").resize((width, height), Image.LANCZOS), 26)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x + 4, y + 14, x + width + 4, y + height + 14), 26, fill=(0, 20, 50, 120)
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    border = Image.new("RGBA", (width + 8, height + 8), (255, 255, 255, 255))
    canvas.alpha_composite(rounded(border, 30), (x - 4, y - 4))
    canvas.alpha_composite(screen, (x, y))


def feature_graphic(icon: Image.Image):
    w, h = 1024, 500
    canvas = gradient((w, h), (26, 167, 236), (0, 85, 150)).convert("RGBA")
    shots = ROOT / "docs" / "play-store" / "screenshots"
    paste_phone(canvas, Image.open(shots / "5-dashboard-dark.png"), 760, 150, 215)
    paste_phone(canvas, Image.open(shots / "1-dashboard.png"), 540, 80, 215)
    tile = icon.resize((96, 96), Image.LANCZOS)
    canvas.alpha_composite(rounded(tile, 22), (56, 96))
    draw = ImageDraw.Draw(canvas)
    draw.text((56, 214), "NAS Companion", font=font("Bold", 62), fill="white")
    draw.text((58, 288), "for TrueNAS", font=font("Medium", 38), fill=(214, 238, 255))
    draw.text(
        (58, 372),
        "Monitor and manage your servers,\nstorage, apps and shares.",
        font=font("Regular", 26),
        fill="white",
        spacing=8,
    )
    canvas.convert("RGB").save(OUT / "feature-graphic.png", optimize=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--icon", required=True, help="1024 px app icon source")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    icon = Image.open(args.icon).convert("RGB")
    icon.resize((512, 512), Image.LANCZOS).save(OUT / "icon-512.png", optimize=True)
    feature_graphic(icon.convert("RGBA"))


if __name__ == "__main__":
    main()
