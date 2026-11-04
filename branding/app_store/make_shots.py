"""Compose captioned App Store screenshots: make_shots.py <src_dir> <out_dir> <W> <H> <suffix>"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SHOTS = [
    ("uk-overview", "Live VATSIM traffic", "Every pilot and controller, in real time"),
    ("show-inactive-sectors", "VATGlasses sectors", "See exactly who covers which airspace"),
    ("zoom-details", "Zoom in for more", "More detail the closer you look"),
    ("pilot-details", "Full flight details", "Altitude, speed, squawk and flight plan"),
    ("track-overlay", "Follow any flight", "Its route and only the sectors that matter"),
    ("merged-sectors", "Merge sectors", "Combine controller areas into one outline"),
    ("blended-sectors", "Every active sector", "No altitude filtering or merging"),
    ("atc-details", "Know every sector", "Controllers and ownership at a glance"),
    ("light-mode", "Light mode too", "Dark or light, your map your way"),
]

IPAD_SHOTS = [
    ("uk-overview", "Live VATSIM traffic", "Every pilot and controller, in real time"),
    ("show-inactive-sectors", "VATGlasses sectors", "See exactly who covers which airspace"),
    ("pilot-details", "Full flight details", "Route, altitude, squawk and flight plan"),
    ("airport-traffic", "Explore airports", "Departures, arrivals and traffic on the ground"),
    ("search", "Find anything fast", "Any callsign, controller or airport"),
    ("light-mode", "Light mode too", "Dark or light, your map your way"),
]

BG = (9, 9, 9)
ACCENT = (134, 203, 14)
FONT = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def rounded(img, r):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *img.size), r, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out, mask


def compose(src, title, sub, W, H, landscape_shot=False):
    canvas = Image.new("RGB", (W, H), BG)
    # soft accent glow behind the screenshot
    glow = Image.new("RGB", (W, H), BG)
    gd = ImageDraw.Draw(glow)
    gd.ellipse((W * 0.1, H * 0.35, W * 0.9, H * 0.95), fill=(30, 48, 6))
    glow = glow.filter(ImageFilter.GaussianBlur(W * 0.12))
    canvas.paste(glow)

    d = ImageDraw.Draw(canvas)
    unit = min(W, H)
    tf = font(int(unit * 0.088), "Bold")
    sf = font(int(unit * 0.042), "Medium")
    top = int(H * 0.055)
    tw = d.textlength(title, font=tf)
    d.text(((W - tw) / 2, top), title, font=tf, fill=(255, 255, 255))
    sy = top + int(unit * 0.088 * 1.3)
    sw = d.textlength(sub, font=sf)
    d.text(((W - sw) / 2, sy), sub, font=sf, fill=(200, 200, 200))
    bar_y = sy + int(unit * 0.042 * 1.7)
    d.rounded_rectangle(((W - unit * 0.08) / 2, bar_y, (W + unit * 0.08) / 2, bar_y + unit * 0.008), 8, fill=ACCENT)

    shot = Image.open(src).convert("RGB")
    area_top = bar_y + int(unit * 0.06)
    max_h = H - area_top - int(H * 0.035)
    max_w = int(W * 0.84)
    scale = min(max_w / shot.width, max_h / shot.height)
    shot = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
    r = int(shot.width * 0.075) if not landscape_shot else int(shot.height * 0.03)
    shot_rgba, mask = rounded(shot, r)
    x = (W - shot.width) // 2
    y = area_top
    # border ring
    border = 6
    ring = Image.new("RGBA", (shot.width + border * 2, shot.height + border * 2), (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle((0, 0, *ring.size), r + border, fill=(255, 255, 255, 40))
    canvas.paste(ring, (x - border, y - border), ring)
    canvas.paste(shot_rgba, (x, y), shot_rgba)
    return canvas


if __name__ == "__main__":
    src_dir, out_dir, W, H, suffix = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
    out_dir.mkdir(parents=True, exist_ok=True)
    for i, (name, title, sub) in enumerate(IPAD_SHOTS if suffix == "ipad" else SHOTS, 1):
        src = src_dir / f"{name}.png"
        if not src.exists():
            print("missing", src)
            continue
        img = compose(src, title, sub, W, H)
        p = out_dir / f"{i:02d}-{name}-{suffix}.png"
        img.save(p)
        print(p.name, img.size)
