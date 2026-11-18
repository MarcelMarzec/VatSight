#!/usr/bin/env python3
"""Generate the 1200x630 social preview cards for vatsight.com.

    python3 tools/make-og-images.py            # every page and guide
    python3 tools/make-og-images.py guides     # guides only

Writes public/images/og/<page>.jpg and public/images/og/guides/<slug>.jpg.
Feature pages are listed in PAGES below. Guides are read from
public/content/guides/*.md: the title is split at the first "?" or ":" into a
white and a green part, and `og_shot:` in the front matter picks the
screenshot (a name from public/images/screenshots, without .webp).
A guide with its own `image:` keeps it, and the page uses that instead.

Needs Pillow (pip install Pillow). Uses Google Sans if tools/fonts holds
GoogleSans-Bold.ttf and GoogleSans-Regular.ttf, otherwise Helvetica Neue.
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
PUBLIC = ROOT / 'public'
OUT = PUBLIC / 'images' / 'og'
SHOTS = PUBLIC / 'images' / 'screenshots'

W, H = 1200, 630
BG = (9, 9, 9)
ACCENT = (134, 203, 14)
WHITE = (255, 255, 255)
DIM = (168, 168, 168)

PAGES = {
    'vatsim-map': {
        'white': 'VATSIM live map', 'green': 'on your iPhone.',
        'sub': 'Every pilot and controller on the network, refreshed every 15 seconds.',
        'shot': 'uk-overview', 'pill': 'Free on the App Store',
    },
    'vatglasses': {
        'white': 'VATGlasses sectors,', 'green': 'live on your iPhone.',
        'sub': 'See which VATSIM ATC sectors are online. Merge them or filter by altitude.',
        'shot': 'merged-sectors', 'pill': 'Free on the App Store',
    },
    'vatsim-tracker': {
        'white': 'Track any VATSIM', 'green': 'flight or friend.',
        'sub': 'Flight plans, routes, airport traffic, and your friends in green.',
        'shot': 'pilot-details', 'pill': 'Free on the App Store',
    },
    'guides': {
        'white': 'VATSIM guides,', 'green': 'plainly explained.',
        'sub': 'ATC positions, VATGlasses and tracking flights, from the developer of VatSight.',
        'shot': 'atc-details', 'pill': 'vatsight.com/guides',
    },
    'roadmap': {
        'white': 'Roadmap &', 'green': 'release notes.',
        'sub': 'Every VatSight release so far, and what’s coming next.',
        'shot': 'light-mode', 'pill': 'vatsight.com/roadmap',
    },
}


def font(bold, size):
    custom = ROOT / 'tools' / 'fonts' / ('GoogleSans-Bold.ttf' if bold else 'GoogleSans-Regular.ttf')
    if custom.exists():
        return ImageFont.truetype(str(custom), size)
    return ImageFont.truetype('/System/Library/Fonts/HelveticaNeue.ttc', size, index=1 if bold else 0)


def wrap_words(words, fnt, width):
    """Words are (text, colour) pairs; returns lines of pairs that fit `width`."""
    lines, line = [], []
    for word in words:
        trial = ' '.join(w for w, _ in line + [word])
        if line and fnt.getlength(trial) > width:
            lines.append(line)
            line = [word]
        else:
            line.append(word)
    if line:
        lines.append(line)
    return lines


def background():
    img = Image.new('RGB', (W, H), BG)
    glow = Image.new('L', (W, H), 0)
    ImageDraw.Draw(glow).ellipse((-260, -320, 640, 420), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(140))
    img.paste(Image.new('RGB', (W, H), ACCENT), (0, 0), glow)
    grid = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(grid)
    for x in range(0, W, 48):
        draw.line((x, 0, x, H), fill=(255, 255, 255, 7))
    for y in range(0, H, 48):
        draw.line((0, y, W, y), fill=(255, 255, 255, 7))
    img.paste(grid, (0, 0), grid)
    return img


def phone(shot_name, height=700):
    frame = Image.open(PUBLIC / 'images' / 'outline.png').convert('RGBA')
    fw, fh = frame.size
    # The frame's screen area is opaque, so the screenshot goes on top of it.
    layer = frame.copy()
    left, top = round(fw * 0.049), round(fh * 0.017)
    right, bottom = fw - round(fw * 0.049), fh - round(fh * 0.016)
    screen = Image.open(SHOTS / f'{shot_name}.webp').convert('RGBA')
    sw, sh = right - left, bottom - top
    scale = max(sw / screen.width, sh / screen.height)
    screen = screen.resize((round(screen.width * scale), round(screen.height * scale)), Image.LANCZOS).crop((0, 0, sw, sh))
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), radius=round(sw * 0.123), fill=255)
    layer.paste(screen, (left, top), mask)
    width = round(fw * height / fh)
    return layer.resize((width, height), Image.LANCZOS).rotate(-4, resample=Image.BICUBIC, expand=True)


def card(white, green, sub, shot, pill, out_path):
    img = background()

    device = phone(shot)
    shadow = Image.new('L', (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((800, 90, 800 + device.width - 40, H + 200), radius=60, fill=150)
    img.paste((0, 0, 0), (0, 0), shadow.filter(ImageFilter.GaussianBlur(40)))
    img.paste(device, (790, 40), device)

    draw = ImageDraw.Draw(img)
    logo = Image.open(PUBLIC / 'images' / 'Vatsightlogo.png').convert('RGBA').resize((52, 52), Image.LANCZOS)
    img.paste(logo, (72, 66), logo)
    draw.text((138, 92), 'VatSight', font=font(True, 32), fill=WHITE, anchor='lm')

    # Subtitle first (two lines at most), then the largest title that fits
    # in what's left above the pill.
    sub_font = font(False, 25)
    sub_lines = [' '.join(w for w, _ in line) for line in wrap_words([(w, DIM) for w in sub.split()], sub_font, 590)]
    if len(sub_lines) > 2:
        sub_lines = sub_lines[:2]
        while sub_font.getlength(sub_lines[1] + '…') > 590:
            sub_lines[1] = sub_lines[1].rsplit(' ', 1)[0]
        sub_lines[1] = sub_lines[1].rstrip(',.;:') + '…'
    top, pill_top = 148, H - 112
    budget = pill_top - 28 - top - 18 - len(sub_lines) * 36

    words = [(w, WHITE) for w in white.split()] + [(w, ACCENT) for w in green.split()]
    text_w = 640
    for size in range(68, 36, -2):
        title_font = font(True, size)
        lines = wrap_words(words, title_font, text_w)
        line_h = round(size * 1.12)
        if len(lines) <= 4 and len(lines) * line_h <= budget:
            break
    y = top
    for line in lines:
        x = 72
        for i, (word, colour) in enumerate(line):
            draw.text((x, y), word, font=title_font, fill=colour)
            x += title_font.getlength(word + (' ' if i < len(line) - 1 else ''))
        y += line_h

    y += 18
    for line in sub_lines:
        draw.text((72, y), line, font=sub_font, fill=DIM)
        y += 36

    pill_font = font(False, 21)
    pw = round(pill_font.getlength(pill)) + 72
    py = H - 112
    pill_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(pill_layer).rounded_rectangle((72, py, 72 + pw, py + 50), radius=25,
                                                 fill=(*ACCENT, 34), outline=(*ACCENT, 110), width=2)
    img.paste(pill_layer, (0, 0), pill_layer)
    draw.ellipse((96, py + 20, 106, py + 30), fill=ACCENT)
    draw.text((120, py + 25), pill, font=pill_font, fill=ACCENT, anchor='lm')

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, 'JPEG', quality=86, optimize=True, progressive=True)
    print('wrote', out_path.relative_to(ROOT))


def front_matter(path):
    raw = path.read_text(encoding='utf-8')
    match = re.match(r'^---\r?\n(.*?)\r?\n---\r?\n?(.*)$', raw, re.S)
    if not match:
        return {}, raw
    meta = {}
    for line in match.group(1).splitlines():
        pair = re.match(r'^([A-Za-z0-9_-]+)\s*:\s*(.*)$', line)
        if pair and not line.lstrip().startswith('#'):
            meta[pair.group(1).lower()] = pair.group(2).strip().strip('"\'')
    return meta, match.group(2)


def guides():
    for path in sorted((PUBLIC / 'content' / 'guides').glob('*.md')):
        if path.name.startswith('_'):
            continue
        meta, body = front_matter(path)
        if meta.get('image'):
            continue
        slug = re.sub(r'[^a-z0-9]+', '-', (meta.get('slug') or path.stem).lower()).strip('-')
        title = meta.get('og_title') or meta.get('title') or path.stem
        split = re.search(r'[?:]\s', title)
        white, green = (title[:split.start() + 1], title[split.end():]) if split else (title, '')
        minutes = max(1, round(len(re.findall(r'\w+', body)) / 220))
        card(white, green, meta.get('summary') or meta.get('description', ''),
             meta.get('og_shot') or 'uk-overview', f'Guide · {minutes} min read',
             OUT / 'guides' / f'{slug}.jpg')


if __name__ == '__main__':
    only = sys.argv[1] if len(sys.argv) > 1 else ''
    if only in ('', 'pages'):
        for name, page in PAGES.items():
            card(page['white'], page['green'], page['sub'], page['shot'], page['pill'], OUT / f'{name}.jpg')
    if only in ('', 'guides'):
        guides()
