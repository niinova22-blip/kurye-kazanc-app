"""Kurye Kazanc uygulama ikonu (1024x1024, alfa kanalsiz — App Store sarti).

Tasarim (1.8'den beri): marka zemini, solda hiz cizgileri, ortada bantli beyaz koli, sag ustte yesil ₺ parasi.
1.11: zemin mor yerine lacivert -> okyanus mavisi (Theme.brandDeep / brandMid / brandBright ile ayni).
Calistirma: python scripts/design/make_app_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
SS = 2  # supersampling: kenarlar yumusak olsun
S = SIZE * SS
OUT = Path(__file__).resolve().parents[2] / "KuryeKazanc/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

DEEP = (11, 42, 107)       # #0B2A6B  Theme.brandDeep
MID = (30, 91, 216)        # #1E5BD8  Theme.brandMid
BRIGHT = (47, 140, 255)    # #2F8CFF  Theme.brandBright
TAPE = (31, 95, 224)       # #1F5FE0  AccentColor
MINT_TOP = (52, 211, 153)  # #34D399
MINT_LOW = (16, 185, 129)  # #10B981
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def background() -> Image.Image:
    """Sol ust lacivert, orta kobalt, sag alt okyanus mavisi; sag ustte hafif isik."""
    small = 256
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            px[x, y] = lerp(DEEP, MID, t / 0.6) if t < 0.6 else lerp(MID, BRIGHT, (t - 0.6) / 0.4)
    img = img.resize((S, S), Image.BICUBIC)
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([int(S * 0.45), int(S * -0.2), int(S * 1.25), int(S * 0.55)], fill=55)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.12))
    img.paste((140, 196, 255), mask=glow)
    return img


def font(size: int) -> ImageFont.FreeTypeFont:
    for name in ("seguibl.ttf", "segoeuib.ttf", "arialbd.ttf"):
        try:
            return ImageFont.truetype(f"C:/Windows/Fonts/{name}", size)
        except OSError:
            continue
    raise SystemExit("Kalin font bulunamadi")


def soft_shadow(img: Image.Image, shape: Image.Image, offset: int, blur: float, color, strength: float) -> None:
    shadow = Image.new("L", (S, S), 0)
    shadow.paste(shape, (0, offset))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    img.paste(color, mask=shadow.point(lambda v: int(v * strength)))


def main() -> None:
    img = background()
    draw = ImageDraw.Draw(img)

    # Hiz cizgileri (yari saydam beyaz, yuvarlak uclu)
    lines = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(lines)
    h = int(S * 0.033)
    for x1, y, x2 in [(0.145, 0.443, 0.29), (0.086, 0.53, 0.29), (0.175, 0.62, 0.29)]:
        d.rounded_rectangle([int(S * x1), int(S * y) - h // 2 - h // 2, int(S * x2), int(S * y) + h // 2], radius=h, fill=255)
    img.paste((214, 230, 255), mask=lines.point(lambda v: int(v * 0.75)))

    # Koli (golgeli beyaz kare + bant)
    box = Image.new("L", (S, S), 0)
    bx0, by0, bx1, by1 = int(S * 0.33), int(S * 0.345), int(S * 0.73), int(S * 0.745)
    ImageDraw.Draw(box).rounded_rectangle([bx0, by0, bx1, by1], radius=int(S * 0.06), fill=255)
    soft_shadow(img, box, int(S * 0.02), S * 0.03, (5, 20, 60), 0.45)
    img.paste(WHITE, mask=box)
    draw.rectangle([bx0, int(S * 0.462), bx1, int(S * 0.476)], fill=(219, 232, 255))
    draw.rounded_rectangle([int(S * 0.49), by0, int(S * 0.568), int(S * 0.55)], radius=int(S * 0.012), fill=TAPE)

    # Yesil ₺ parasi (zemin rengi halkayla)
    cx, cy, r = int(S * 0.73), int(S * 0.35), int(S * 0.165)
    ring = Image.new("L", (S, S), 0)
    ImageDraw.Draw(ring).ellipse([cx - r - int(S * 0.018), cy - r - int(S * 0.018), cx + r + int(S * 0.018), cy + r + int(S * 0.018)], fill=255)
    soft_shadow(img, ring, int(S * 0.015), S * 0.025, (5, 20, 60), 0.4)
    img.paste((22, 72, 175), mask=ring)
    coin = Image.new("RGB", (S, S))
    cd = ImageDraw.Draw(coin)
    for i in range(r, 0, -2):
        t = i / r
        cd.ellipse([cx - i, cy - i, cx + i, cy + i], fill=lerp(MINT_TOP, MINT_LOW, t))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    img.paste(coin, mask=mask)

    f = font(int(S * 0.2))
    glyph = "₺"
    bbox = draw.textbbox((0, 0), glyph, font=f)
    gw, gh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text((cx - gw / 2 - bbox[0], cy - gh / 2 - bbox[1]), glyph, font=f, fill=WHITE)

    final = img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")
    final.save(OUT, "PNG", optimize=True)
    print(f"Yazildi: {OUT}")


if __name__ == "__main__":
    main()
