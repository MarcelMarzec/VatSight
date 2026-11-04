"""Illustrated App Store creative assets built from VatSight's map language.
make_art.py <plane_svg> <out_dir>
Produces header-5244x2950.png and search-3840x2560.png.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 2  # supersample factor
FONT = "/System/Library/Fonts/SFNS.ttf"
MONO = "/System/Library/Fonts/SFNSMono.ttf"

# app colours
RED = (255, 59, 48)
GREEN = (52, 199, 89)
GREY = (142, 142, 147)
WHITE = (255, 255, 255)
SELECTED = (0, 158, 255)
FRIEND = (52, 199, 89)
NAVY_STROKE = (51, 64, 102)
BADGE = {"T": (51, 153, 255), "G": (51, 199, 89), "D": (255, 148, 0), "A": (176, 82, 222)}
SECTOR_BLUE = (74, 144, 217)
SECTOR_RED = (232, 84, 52)
SECTOR_PURPLE = (150, 90, 230)
ACCENT = (134, 203, 14)


def font(size, weight="Regular", path=FONT):
    f = ImageFont.truetype(path, int(size * SS))
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


# MARK: - SVG plane path

def parse_path(d):
    toks = re.findall(r"[MmCcLlHhVvZz]|-?\d*\.?\d+(?:e-?\d+)?", d)
    pts, i, cmd = [], 0, None
    x = y = sx = sy = 0.0

    def num():
        nonlocal i
        v = float(toks[i]); i += 1
        return v

    while i < len(toks):
        t = toks[i]
        if re.match(r"[A-Za-z]", t):
            cmd = t; i += 1
            if cmd in "Zz":
                x, y = sx, sy
                continue
        if cmd in "Mm":
            nx, ny = num(), num()
            x, y = (x + nx, y + ny) if cmd == "m" else (nx, ny)
            sx, sy = x, y
            pts.append((x, y))
            cmd = "l" if cmd == "m" else "L"
        elif cmd in "Ll":
            nx, ny = num(), num()
            x, y = (x + nx, y + ny) if cmd == "l" else (nx, ny)
            pts.append((x, y))
        elif cmd in "Hh":
            v = num(); x = x + v if cmd == "h" else v
            pts.append((x, y))
        elif cmd in "Vv":
            v = num(); y = y + v if cmd == "v" else v
            pts.append((x, y))
        elif cmd in "Cc":
            c = [num() for _ in range(6)]
            if cmd == "c":
                c = [c[0] + x, c[1] + y, c[2] + x, c[3] + y, c[4] + x, c[5] + y]
            p0 = (x, y)
            for k in range(1, 13):
                tt = k / 12
                a = (1 - tt) ** 3; b = 3 * (1 - tt) ** 2 * tt; cc = 3 * (1 - tt) * tt ** 2; e = tt ** 3
                pts.append((a * p0[0] + b * c[0] + cc * c[2] + e * c[4], a * p0[1] + b * c[1] + cc * c[3] + e * c[5]))
            x, y = c[4], c[5]
    return pts


PLANE = None
_plane_cache = {}


def plane_sprite(size, color, heading):
    key = (size, color, heading)
    if key not in _plane_cache:
        big = size * 4
        img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.polygon([(px / 20 * big, py / 20 * big) for px, py in PLANE], fill=color + (255,))
        img = img.resize((size, size), Image.LANCZOS).rotate(-heading, resample=Image.BICUBIC, expand=True)
        _plane_cache[key] = img
    return _plane_cache[key]


# MARK: - Canvas helpers

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGB", (w * SS, h * SS), (8, 13, 30))
        self.d = ImageDraw.Draw(self.img, "RGBA")

    def s(self, v):
        return int(round(v * SS))

    def pts(self, pts):
        return [(self.s(x), self.s(y)) for x, y in pts]

    def background(self):
        w, h = self.w, self.h
        # vertical gradient
        small = Image.new("RGB", (64, 64))
        sd = ImageDraw.Draw(small)
        for yy in range(64):
            t = yy / 63
            sd.line([(0, yy), (63, yy)], fill=(int(12 - 4 * t), int(19 - 6 * t), int(42 - 14 * t)))
        # abstract "land" masses in a slightly lighter slate, blurred at low res
        land = Image.new("L", (256, 256), 0)
        ld = ImageDraw.Draw(land)
        for poly in LAND:
            ld.polygon([(x * 256, y * 256) for x, y in poly], fill=255)
        land = land.filter(ImageFilter.GaussianBlur(3))
        landcol = Image.new("RGB", (256, 256), (30, 36, 48))
        base = small.resize((256, 256), Image.BILINEAR)
        base = Image.composite(landcol, base, land.point(lambda v: int(v * 0.85)))
        self.img.paste(base.resize(self.img.size, Image.BICUBIC))
        # graticule
        step = 260
        for gx in range(0, w + step, step):
            self.d.line([(self.s(gx), 0), (self.s(gx), self.s(h))], fill=(255, 255, 255, 9), width=self.s(2))
        for gy in range(0, h + step, step):
            self.d.line([(0, self.s(gy)), (self.s(w), self.s(gy))], fill=(255, 255, 255, 9), width=self.s(2))

    def glow(self, cx, cy, r, color, strength):
        g = Image.new("L", (200, int(200 * self.h / self.w)), 0)
        gd = ImageDraw.Draw(g)
        sx = 200 / self.w
        gd.ellipse(((cx - r) * sx, (cy - r * 0.7) * sx, (cx + r) * sx, (cy + r * 0.7) * sx), fill=255)
        g = g.filter(ImageFilter.GaussianBlur(18)).resize(self.img.size, Image.BICUBIC)
        col = Image.new("RGB", self.img.size, color)
        self.img = Image.composite(col, self.img, g.point(lambda v: int(v * strength)))
        self.d = ImageDraw.Draw(self.img, "RGBA")

    def sector(self, poly, color, fill_a=46, stroke_w=5, stroke_a=230):
        self.d.polygon(self.pts(poly), fill=color + (fill_a,))
        p = self.pts(poly + [poly[0]])
        self.d.line(p, fill=color + (stroke_a,), width=self.s(stroke_w), joint="curve")

    def rings(self, cx, cy, radii, color):
        for r in radii:
            self.d.ellipse((self.s(cx - r), self.s(cy - r), self.s(cx + r), self.s(cy + r)),
                           fill=color + (22,), outline=color + (200,), width=self.s(4))

    def dashed(self, a, b, color, width=6, dash=26, gap=22, alpha=190):
        (x1, y1), (x2, y2) = a, b
        L = math.hypot(x2 - x1, y2 - y1)
        n = 0.0
        while n < L:
            e = min(n + dash, L)
            p = (x1 + (x2 - x1) * n / L, y1 + (y2 - y1) * n / L)
            q = (x1 + (x2 - x1) * e / L, y1 + (y2 - y1) * e / L)
            self.d.line(self.pts([p, q]), fill=color + (alpha,), width=self.s(width))
            n += dash + gap

    def line(self, pts, color, width=7, alpha=235):
        self.d.line(self.pts(pts), fill=color + (alpha,), width=self.s(width), joint="curve")

    def plane(self, x, y, heading, color=WHITE, size=64):
        spr = plane_sprite(self.s(size), color, heading)
        self.img.paste(spr, (self.s(x) - spr.width // 2, self.s(y) - spr.height // 2), spr)

    def text(self, x, y, s, f, color=WHITE, anchor="la"):
        self.d.text((self.s(x), self.s(y)), s, font=f, fill=color, anchor=anchor)

    def textlen(self, s, f):
        return self.d.textlength(s, font=f) / SS

    def airport(self, x, y, icao, badges="", label_size=40, r=15, color=WHITE, label_side="right"):
        self.d.ellipse((self.s(x - r), self.s(y - r), self.s(x + r), self.s(y + r)),
                       fill=color + (255,), outline=NAVY_STROKE + (255,), width=self.s(4))
        f = font(label_size, "Medium")
        lx = x + r + 14 if label_side == "right" else x - r - 14 - self.textlen(icao, f)
        # thin dark halo like the map labels
        for ox, oy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            self.text(lx + ox, y + oy, icao, f, (8, 12, 26), "lm")
        self.text(lx, y, icao, f, WHITE, "lm")
        bs, gap = label_size * 1.05, 8
        for i, letter in enumerate(badges):
            bx = x - bs / 2 + i * (bs + gap) + (r + 14 if badges and label_side == "right" else 0)
            by = y + r + 14
            self.d.rounded_rectangle((self.s(bx), self.s(by), self.s(bx + bs), self.s(by + bs)), radius=self.s(9),
                                     fill=BADGE[letter] + (255,), outline=(0, 0, 0, 255), width=self.s(2))
            self.text(bx + bs / 2, by + bs / 2 + 1, letter, font(label_size * 0.72, "Semibold"), WHITE, "mm")

    def pill(self, x, y, label, size=40, color=SECTOR_BLUE):
        f = font(size, "Medium")
        w = self.textlen(label, f) + size * 1.1
        h = size * 1.7
        self.d.rounded_rectangle((self.s(x - w / 2), self.s(y - h / 2), self.s(x + w / 2), self.s(y + h / 2)),
                                 radius=self.s(h * 0.32), fill=(16, 28, 66, 245), outline=color + (255,), width=self.s(4))
        self.text(x, y + 1, label, f, WHITE, "mm")

    def card(self, x, y, w, h, radius=56):
        # soft shadow
        sh = Image.new("L", (int(w / 8) + 40, int(h / 8) + 40), 0)
        ImageDraw.Draw(sh).rounded_rectangle((20, 24, 20 + w / 8, 24 + h / 8), radius=radius / 8, fill=170)
        sh = sh.filter(ImageFilter.GaussianBlur(7)).resize((self.s(w + 320), self.s(h + 320)), Image.BICUBIC)
        black = Image.new("RGB", sh.size, (0, 0, 0))
        self.img.paste(black, (self.s(x - 160), self.s(y - 160)), sh)
        self.d = ImageDraw.Draw(self.img, "RGBA")
        self.d.rounded_rectangle((self.s(x), self.s(y), self.s(x + w), self.s(y + h)), radius=self.s(radius),
                                 fill=(30, 32, 38, 242), outline=(255, 255, 255, 34), width=self.s(3))

    def tile(self, x, y, w, h, radius=30):
        self.d.rounded_rectangle((self.s(x), self.s(y), self.s(x + w), self.s(y + h)), radius=self.s(radius),
                                 fill=(255, 255, 255, 14))

    def save(self, path):
        self.img.resize((self.w, self.h), Image.LANCZOS).save(path, optimize=True)


# rough, abstract land shapes in unit coords (not a real map)
LAND = [
    [(0.0, 0.0), (0.18, 0.0), (0.22, 0.12), (0.16, 0.3), (0.2, 0.46), (0.12, 0.58), (0.0, 0.62)],
    [(0.3, 0.08), (0.38, 0.04), (0.42, 0.18), (0.4, 0.34), (0.44, 0.5), (0.36, 0.56), (0.31, 0.44), (0.33, 0.28)],
    [(0.52, 0.42), (0.62, 0.34), (0.74, 0.3), (0.86, 0.22), (1.0, 0.2), (1.0, 1.0), (0.44, 1.0), (0.46, 0.78), (0.54, 0.62)],
    [(0.6, 0.0), (0.72, 0.0), (0.7, 0.1), (0.62, 0.12)],
]


# MARK: - Shared content blocks

def airport_card(c, x, y, scale=1.0):
    w, h = 860 * scale, 470 * scale
    c.card(x, y, w, h, radius=60 * scale)
    pad = 52 * scale
    c.text(x + pad, y + pad, "EGLL", font(78 * scale, "Bold"))
    c.text(x + pad, y + pad + 96 * scale, "Heathrow", font(44 * scale, "Regular"), (160, 160, 168))
    # badges on the card
    for i, letter in enumerate("DGTA"):
        bs = 50 * scale
        bx = x + w - pad - (4 - i) * (bs + 10 * scale) + 10 * scale
        by = y + pad + 14 * scale
        c.d.rounded_rectangle((c.s(bx), c.s(by), c.s(bx + bs), c.s(by + bs)), radius=c.s(10 * scale), fill=BADGE[letter] + (255,))
        c.text(bx + bs / 2, by + bs / 2 + 1, letter, font(34 * scale, "Semibold"), WHITE, "mm")
    cols = [("Departures", "24"), ("On Ground", "17"), ("Arrivals", "19")]
    cw = (w - 2 * pad) / 3
    for i, (label, value) in enumerate(cols):
        cx = x + pad + cw * i + cw / 2
        c.text(cx, y + 268 * scale, label, font(36 * scale, "Medium"), (160, 160, 168), "mm")
        c.text(cx, y + 352 * scale, value, font(84 * scale, "Bold"), WHITE, "mm")


def flight_card(c, x, y, scale=1.0):
    w, h = 980 * scale, 400 * scale
    c.card(x, y, w, h, radius=60 * scale)
    pad = 52 * scale
    c.text(x + pad, y + pad, "VSA101", font(78 * scale, "Bold"))
    c.text(x + pad + c.textlen("VSA101", font(78 * scale, "Bold")) + 30 * scale, y + pad + 22 * scale, "A320",
           font(50 * scale, "Regular"), (160, 160, 168))
    tiles = [("Altitude", "36,000 ft"), ("Speed", "452 kt"), ("Heading", "078°")]
    tw = (w - 2 * pad - 2 * 16 * scale) / 3
    for i, (label, value) in enumerate(tiles):
        tx = x + pad + i * (tw + 16 * scale)
        ty = y + 168 * scale
        c.tile(tx, ty, tw, 180 * scale, radius=28 * scale)
        c.text(tx + tw / 2, ty + 52 * scale, label, font(34 * scale, "Regular"), (160, 160, 168), "mm")
        c.text(tx + tw / 2, ty + 120 * scale, value, font(52 * scale, "Medium"), WHITE, "mm")


def atc_chip(c, x, y, callsign, freq, scale=1.0):
    f1 = font(46 * scale, "Semibold")
    f2 = font(40 * scale, "Regular", MONO)
    w = 110 * scale + c.textlen(callsign, f1) + 40 * scale + c.textlen(freq, f2) + 50 * scale
    h = 108 * scale
    c.card(x, y, w, h, radius=h / 2)
    cx = x + 58 * scale
    c.d.ellipse((c.s(cx - 16 * scale), c.s(y + h / 2 - 16 * scale), c.s(cx + 16 * scale), c.s(y + h / 2 + 16 * scale)),
                fill=GREEN + (255,))
    c.d.ellipse((c.s(cx - 30 * scale), c.s(y + h / 2 - 30 * scale), c.s(cx + 30 * scale), c.s(y + h / 2 + 30 * scale)),
                outline=GREEN + (90,), width=c.s(5 * scale))
    tx = x + 110 * scale
    c.text(tx, y + h / 2, callsign, f1, WHITE, "lm")
    c.text(tx + c.textlen(callsign, f1) + 40 * scale, y + h / 2, freq, f2, (160, 160, 168), "lm")


def headline(c, y, size, line="The VATSIM network, live."):
    f = font(size, "Bold")
    tw = c.textlen(line, f)
    # dark halo for legibility over the map
    halo = Image.new("L", (c.img.width // 8, c.img.height // 8), 0)
    hd = ImageDraw.Draw(halo)
    hd.rounded_rectangle(((c.w / 2 - tw / 2 - size) * SS / 8, (y - size * 0.4) * SS / 8,
                          (c.w / 2 + tw / 2 + size) * SS / 8, (y + size * 1.5) * SS / 8), radius=size * SS / 8, fill=160)
    halo = halo.filter(ImageFilter.GaussianBlur(size * SS / 8 / 2)).resize(c.img.size, Image.BICUBIC)
    c.img.paste(Image.new("RGB", c.img.size, (6, 10, 24)), (0, 0), halo)
    c.d = ImageDraw.Draw(c.img, "RGBA")
    c.text(c.w / 2, y, line, f, WHITE, "ma")
    bar_y = y + size * 1.3
    c.d.rounded_rectangle((c.s(c.w / 2 - size * 0.45), c.s(bar_y), c.s(c.w / 2 + size * 0.45), c.s(bar_y + size * 0.08)),
                          radius=c.s(size * 0.04), fill=ACCENT + (255,))
    return tw


def scatter(c, planes):
    for x, y, hdg in planes:
        c.plane(x, y, hdg, WHITE, 54)


# MARK: - Header 5244x2950 (safe band roughly x 1120-4120, y 650-1840)

def header(out):
    c = Canvas(5244, 2950)
    c.background()
    c.glow(2622, 1500, 1500, (40, 70, 10), 0.35)

    # sectors
    c.sector([(300, 380), (1300, 260), (1650, 900), (1450, 1650), (700, 1900), (180, 1300)], SECTOR_BLUE)
    c.sector([(1650, 900), (2500, 640), (2950, 1050), (2850, 1700), (2250, 2050), (1450, 1650)], SECTOR_RED, fill_a=40)
    c.sector([(3500, 520), (4500, 420), (5000, 1100), (4700, 1900), (3900, 2000), (3450, 1300)], SECTOR_PURPLE, fill_a=34)
    c.sector([(2950, 1050), (3450, 1300), (3900, 2000), (3300, 2500), (2850, 1700)], SECTOR_BLUE, fill_a=30, stroke_a=150)
    c.rings(1180, 1180, [90, 170, 250], SECTOR_BLUE)
    c.pill(820, 900, "EGTT_W_CTR", 44)
    c.pill(2420, 1880, "LON_S_CTR", 44, SECTOR_RED)
    c.pill(4300, 1060, "EDGG_CTR", 44, SECTOR_PURPLE)

    # background traffic
    scatter(c, [(560, 620, 40), (980, 1450, 120), (1560, 520, 210), (2080, 1500, 300), (2350, 2350, 60),
                (2900, 2200, 150), (3300, 2000, 250), (3700, 1600, 20), (4100, 700, 95), (4600, 1500, 200),
                (4950, 2300, 310), (520, 2300, 75), (1250, 2550, 180), (3550, 2650, 280), (4800, 650, 135),
                (1900, 2700, 30), (300, 1700, 355), (3150, 2750, 90)])
    c.plane(4380, 2380, 250, FRIEND, 62)

    # the selected flight: red behind, green ahead, dashed rest of route
    dep, mid, arr = (1760, 1280), (2700, 1150), (3820, 1300)
    c.line([dep, (2220, 1190), mid], RED, 9)
    c.line([mid, (3250, 1180), arr], GREEN, 9)
    c.dashed(arr, (4500, 1700), GREY, 7)
    c.plane(mid[0], mid[1], 78, SELECTED, 92)

    # airports
    c.airport(dep[0], dep[1], "EGLL", "GTA", 44, 18)
    c.airport(arr[0], arr[1], "EHAM", "DTA", 44, 18)
    c.airport(1180, 1180, "EIDW", "TA", 40)
    c.airport(2080, 980, "EGKK", "GA", 38)
    c.airport(1420, 760, "EGCC", "", 38)
    c.airport(3180, 1560, "EBBR", "T", 38)
    c.airport(4300, 1500, "EDDF", "GTA", 38)
    c.airport(4020, 820, "EDDH", "TA", 38)
    c.airport(2600, 2150, "LFPG", "DGTA", 38)
    c.airport(700, 2100, "EGFF", "", 36)
    c.airport(4700, 2000, "EDDM", "", 36)
    c.airport(3500, 2300, "LFSB", "", 36)

    # cards in the safe band
    airport_card(c, 1150, 1430, 0.88)
    atc_chip(c, 2900, 1520, "EHAM_APP", "121.200", 1.0)

    headline(c, 700, 150)
    c.save(out)


# MARK: - Search results 3840x2560 (shown small, so bigger type and fewer details)

def search(out):
    c = Canvas(3840, 2560)
    c.background()
    c.glow(1920, 1500, 1300, (40, 70, 10), 0.35)

    c.sector([(150, 640), (1100, 520), (1400, 1200), (1100, 1900), (300, 2050), (60, 1350)], SECTOR_BLUE)
    c.sector([(1400, 1200), (2300, 900), (2700, 1450), (2450, 2200), (1700, 2350), (1100, 1900)], SECTOR_RED, fill_a=40)
    c.sector([(2700, 1450), (3500, 820), (3840, 900), (3840, 2560), (2900, 2560), (2450, 2200)], SECTOR_PURPLE, fill_a=34)
    c.rings(700, 1150, [90, 170, 250], SECTOR_BLUE)
    c.pill(700, 2230, "EGTT_W_CTR", 50)
    c.pill(2000, 2200, "LON_S_CTR", 50, SECTOR_RED)
    c.pill(3330, 1020, "EDGG_CTR", 50, SECTOR_PURPLE)

    scatter(c, [(420, 900, 40), (900, 1500, 120), (1500, 820, 210), (1800, 1900, 300), (2300, 2400, 60),
                (2800, 1900, 150), (3100, 1100, 250), (3500, 2100, 20), (3650, 650, 95), (300, 2300, 75),
                (1200, 2400, 180), (2550, 750, 280), (3400, 2450, 200)])
    c.plane(3200, 2350, 250, FRIEND, 62)

    dep, mid, arr = (1050, 1380), (1900, 1180), (2950, 1350)
    c.line([dep, (1480, 1260), mid], RED, 10)
    c.line([mid, (2420, 1220), arr], GREEN, 10)
    c.dashed(arr, (3500, 1750), GREY, 7)
    c.plane(mid[0], mid[1], 78, SELECTED, 104)

    c.airport(dep[0], dep[1], "EGLL", "GTA", 52, 20)
    c.airport(arr[0], arr[1], "EHAM", "DTA", 52, 20)
    c.airport(700, 1150, "EIDW", "TA", 46)
    c.airport(1550, 1000, "EGKK", "GA", 44)
    c.airport(2350, 1750, "EBBR", "T", 44)
    c.airport(3300, 1750, "EDDF", "GTA", 44)
    c.airport(2200, 2050, "LFPG", "DGTA", 44)

    airport_card(c, 420, 1560, 1.05)
    atc_chip(c, 2150, 1520, "EHAM_APP", "121.200", 1.15)

    headline(c, 330, 190)
    c.save(out)


if __name__ == "__main__":
    svg = Path(sys.argv[1]).read_text()
    PLANE = parse_path(re.search(r' d="([^"]+)"', svg).group(1))
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    header(out / "header-5244x2950.png")
    search(out / "search-3840x2560.png")
    print("done")
