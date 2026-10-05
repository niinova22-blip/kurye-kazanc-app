"""Kurye Kazanc uygulama ikonu (1024x1024, alfa kanalsiz — App Store sarti).

Tasarim: turuncu -> kirmizi diyagonal gradyan, ortada kalin beyaz ₺, solunda hiz cizgileri
(kurye hareketi) ve ₺'nin sag ustunde yukari ok (kazanc artisi).
Calistirma: python scripts/design/make_app_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
SS = 2  # supersampling: kenarlar yumusak olsun
S = SIZE * SS
OUT = Path(__file__).resolve().parents[2] / "KuryeKazanc/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

TOP_LEFT = (255, 138, 31)     # #FF8A1F
BOTTOM_RIGHT = (226, 55, 32)  # #E23720
WHITE = (255, 255, 255)


def gradient() -> Image.Image:
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * (S - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP_LEFT, BOTTOM_RIGHT))
    return img


def font(size: int) -> ImageFont.FreeTypeFont:
    for name in ("seguibl.ttf", "segoeuib.ttf", "arialbd.ttf"):
        try:
            return ImageFont.truetype(f"C:/Windows/Fonts/{name}", size)
        except OSError:
            continue
    raise SystemExit("Kalin font bulunamadi")


def main() -> None:
    img = gradient()

    # Yumusak golge katmani
    shadow = Image.new("L", (S, S), 0)
    layer = Image.new("L", (S, S), 0)
    d_layer = ImageDraw.Draw(layer)

    # ₺ isareti (ortanin biraz sagina; solda hiz cizgilerine yer)
    f = font(int(S * 0.62))
    glyph = "₺"
    bbox = d_layer.textbbox((0, 0), glyph, font=f)
    gw, gh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    gx = int(S * 0.585 - gw / 2) - bbox[0]
    gy = int(S * 0.54 - gh / 2) - bbox[1]
    d_layer.text((gx, gy), glyph, font=f, fill=255)

    # Hiz cizgileri (yuvarlak uclu)
    w = int(S * 0.045)
    left = int(S * 0.11)
    for i, (y_frac, length) in enumerate([(0.42, 0.14), (0.54, 0.19), (0.66, 0.11)]):
        y = int(S * y_frac)
        x2 = left + int(S * length)
        d_layer.line([(left, y), (x2, y)], fill=255, width=w)
        r = w // 2
        d_layer.ellipse([left - r, y - r, left + r, y + r], fill=255)
        d_layer.ellipse([x2 - r, y - r, x2 + r, y + r], fill=255)

    # Kazanc oku (sag ust)
    ax, ay = int(S * 0.79), int(S * 0.27)
    a = int(S * 0.075)
    d_layer.polygon([(ax, ay - a), (ax + a, ay + int(a * 0.15)), (ax - a, ay + int(a * 0.15))], fill=255)
    d_layer.rectangle([ax - int(a * 0.32), ay, ax + int(a * 0.32), ay + int(a * 1.25)], fill=255)

    shadow.paste(layer, (int(S * 0.008), int(S * 0.016)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.012))
    img.paste((150, 30, 10), mask=shadow.point(lambda v: int(v * 0.35)))
    img.paste(WHITE, mask=layer)

    final = img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")
    final.save(OUT, "PNG", optimize=True)
    print(f"Yazildi: {OUT}")


if __name__ == "__main__":
    main()
