"""Generates Daybreak's app icon: a white half-sun rising over a horizon on a
deep orange/amber rounded square.

Run from the project root:
    python3 tool/generate_icon.py
    dart run flutter_launcher_icons

Writes:
    assets/icon/icon.png             1024x1024 rounded square (Android, web)
    assets/icon/icon_ios.png         1024x1024 full square, no transparency
                                     (iOS rounds the corners itself)
    assets/icon/icon_foreground.png  1024x1024 sun only on transparent, sized
                                     for Android adaptive icons' safe zone
Requires Pillow (pip install pillow).
"""

import math
import os

from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4  # draw big, then shrink, for smooth edges
TOP = (255, 167, 38)  # amber
BOTTOM = (230, 81, 0)  # deep orange (close to the app's seed color)
WHITE = (255, 255, 255, 255)

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")


def gradient(size):
    """Vertical amber -> deep orange gradient."""
    img = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
        draw.line([(0, y), (size, y)], fill=color + (255,))
    return img


def draw_sun(img, scale_content=1.0):
    """White half-sun, horizon line, and rays, centered in the image.
    [scale_content] shrinks the drawing (for the adaptive-icon safe zone)."""
    size = img.size[0]
    draw = ImageDraw.Draw(img)
    s = size / 1024 * scale_content
    cx = size / 2
    horizon_y = size / 2 + 90 * s

    # Half sun: a circle cut off at the horizon.
    r = 210 * s
    sun = Image.new("L", img.size, 0)
    ImageDraw.Draw(sun).ellipse(
        [cx - r, horizon_y - r, cx + r, horizon_y + r], fill=255
    )
    ImageDraw.Draw(sun).rectangle([0, horizon_y, size, size], fill=0)
    img.paste(WHITE, mask=sun)

    # Horizon line with rounded ends.
    line_w = 44 * s
    half = 330 * s
    y = horizon_y + 6 * s
    draw.rounded_rectangle(
        [cx - half, y, cx + half, y + line_w], radius=line_w / 2, fill=WHITE
    )

    # Five short rays fanning out above the sun.
    ray_w = 40 * s
    inner, outer = r + 60 * s, r + 150 * s
    for angle in (180 - 22, 180 - 61, 90, 61, 22):
        a = math.radians(angle)
        x1, y1 = cx + inner * math.cos(a), horizon_y - inner * math.sin(a)
        x2, y2 = cx + outer * math.cos(a), horizon_y - outer * math.sin(a)
        draw.line([(x1, y1), (x2, y2)], fill=WHITE, width=round(ray_w))
        for x, yy in ((x1, y1), (x2, y2)):  # round caps
            draw.ellipse(
                [x - ray_w / 2, yy - ray_w / 2, x + ray_w / 2, yy + ray_w / 2],
                fill=WHITE,
            )


def rounded_mask(size, radius_ratio=0.225):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=size * radius_ratio, fill=255
    )
    return mask


def shrink(img):
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    big = SIZE * SCALE

    # Full square (iOS): gradient + sun, no transparency.
    square = gradient(big)
    draw_sun(square)
    shrink(square).convert("RGB").save(os.path.join(OUT_DIR, "icon_ios.png"))

    # Rounded square (Android legacy, web).
    rounded = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    rounded.paste(square, mask=rounded_mask(big))
    shrink(rounded).save(os.path.join(OUT_DIR, "icon.png"))

    # Adaptive foreground: sun only, scaled into the central safe zone.
    foreground = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw_sun(foreground, scale_content=0.62)
    shrink(foreground).save(os.path.join(OUT_DIR, "icon_foreground.png"))

    print("Wrote icons to", os.path.normpath(OUT_DIR))


if __name__ == "__main__":
    main()
