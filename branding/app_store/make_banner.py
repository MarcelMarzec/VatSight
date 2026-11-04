"""Universal header / search-results creative asset (5244x2950)."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

src = Path(sys.argv[1])
out = Path(sys.argv[2])
W, H = 5244, 2950
BG = (9, 9, 9)
FONT = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


# blurred, darkened map backdrop
bg = Image.open(src / "uk-overview.png").convert("RGB")
scale = W / bg.width
bg = bg.resize((W, int(bg.height * scale)), Image.LANCZOS)
top = (bg.height - H) // 2
bg = bg.crop((0, top, W, top + H)).filter(ImageFilter.GaussianBlur(40))
bg = ImageEnhance.Brightness(bg).enhance(0.35)
canvas = bg

glow = Image.new("L", (W, H), 0)
ImageDraw.Draw(glow).ellipse((W * 0.25, H * 0.3, W * 0.75, H * 1.1), fill=255)
glow = glow.filter(ImageFilter.GaussianBlur(350))
green = Image.new("RGB", (W, H), (60, 100, 8))
canvas = Image.composite(green, canvas, glow.point(lambda v: int(v * 0.55)))

# vignette
vig = Image.new("L", (W, H), 0)
ImageDraw.Draw(vig).rectangle((0, 0, W, H), fill=255)
inner = Image.new("L", (W, H), 0)
ImageDraw.Draw(inner).ellipse((-W * 0.1, -H * 0.2, W * 1.1, H * 1.2), fill=255)
inner = inner.filter(ImageFilter.GaussianBlur(300))
canvas = Image.composite(canvas, Image.new("RGB", (W, H), BG), inner)


def phone(name, h, angle):
    s = Image.open(src / f"{name}.png").convert("RGB")
    w = int(s.width * h / s.height)
    s = s.resize((w, h), Image.LANCZOS)
    r = int(w * 0.075)
    b = 10
    framed = Image.new("RGBA", (w + 2 * b, h + 2 * b), (0, 0, 0, 0))
    ImageDraw.Draw(framed).rounded_rectangle((0, 0, *framed.size), r + b, fill=(255, 255, 255, 60))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), r, fill=255)
    framed.paste(s, (b, b), mask)
    shadow = Image.new("RGBA", (framed.width + 300, framed.height + 300), (0, 0, 0, 0))
    sm = Image.new("L", shadow.size, 0)
    ImageDraw.Draw(sm).rounded_rectangle((150, 170, 150 + framed.width, 170 + framed.height), r, fill=200)
    sm = sm.filter(ImageFilter.GaussianBlur(60))
    shadow.putalpha(sm)
    shadow.alpha_composite(framed, (150, 150))
    return shadow.rotate(angle, resample=Image.BICUBIC, expand=True)


canvas = canvas.convert("RGBA")
center_h = 1900
for name, h, angle, cx in [
    ("merged-sectors", 1650, 7, W * 0.5 - 1050),
    ("pilot-details", 1650, -7, W * 0.5 + 1050),
    ("uk-overview", center_h, 0, W * 0.5),
]:
    p = phone(name, h, angle)
    cy = 1000 + center_h / 2 + (90 if h < center_h else 0)
    canvas.alpha_composite(p, (int(cx - p.width / 2), int(cy - p.height / 2)))

d = ImageDraw.Draw(canvas)
# App Store crops the top ~600px under its nav bar and the sides on iPhone, so keep the headline low and narrow
tf = font(150, "Bold")
title = "The VATSIM network, live."
tw = d.textlength(title, font=tf)
d.text(((W - tw) / 2, 720), title, font=tf, fill=(255, 255, 255))
print("headline width", tw)

canvas.convert("RGB").save(out, quality=92)
print(out, canvas.size)
