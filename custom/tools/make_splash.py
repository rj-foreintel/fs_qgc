"""Build ForeView's Android start-up image (custom/android/res/drawable-*/foreview_splash.png).

The image is the app icon tile with "Powered by Foreintel" below it, drawn at every Android
screen density. Run it again after changing the icon:

    python3 custom/tools/make_splash.py

Needs Pillow (pip install pillow).
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
TILE_IMAGE = REPO / "custom/res/icons/ForeView_1024.png"
FONT_REGULAR = REPO / "resources/fonts/OpenSans-Regular.ttf"
FONT_BOLD = REPO / "resources/fonts/OpenSans-Semibold.ttf"

# Layout in dp (= pixels at mdpi)
WIDTH_DP = 240
TILE_DP = 176
GAP_DP = 22
FONT_DP = 17

DENSITIES = {"ldpi": 0.75, "mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def main() -> None:
    tile = Image.open(TILE_IMAGE).convert("RGBA")
    for name, scale in DENSITIES.items():
        regular = ImageFont.truetype(str(FONT_REGULAR), round(FONT_DP * scale))
        bold = ImageFont.truetype(str(FONT_BOLD), round(FONT_DP * scale))
        lead, brand = "Powered by ", "Foreintel"
        lead_width = regular.getlength(lead)
        brand_width = bold.getlength(brand)
        ascent, descent = bold.getmetrics()

        width = round(WIDTH_DP * scale)
        tile_size = round(TILE_DP * scale)
        gap = round(GAP_DP * scale)
        image = Image.new("RGBA", (width, tile_size + gap + ascent + descent), (0, 0, 0, 0))
        image.alpha_composite(
            tile.resize((tile_size, tile_size), Image.Resampling.LANCZOS),
            ((width - tile_size) // 2, 0),
        )

        draw = ImageDraw.Draw(image)
        x = (width - (lead_width + brand_width)) / 2
        y = tile_size + gap
        draw.text((x, y), lead, font=regular, fill=(176, 186, 196, 255))
        draw.text((x + lead_width, y), brand, font=bold, fill=(255, 255, 255, 255))

        out = REPO / f"custom/android/res/drawable-{name}/foreview_splash.png"
        image.save(out, optimize=True)
        print(f"{out.relative_to(REPO)} {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
