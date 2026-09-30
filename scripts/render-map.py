"""Renders the exported island (scripts/export-map.luau) to images.

  python3 scripts/render-map.py map.json out_dir

Writes:
  map_top.png   top-down map: hillshaded terrain, every visible part by its
                real footprint and color, dig spots (clues starred), labels
  map_view.png  perspective view from above the base looking north (a
                heightfield renderer; parts are drawn as raised blocks)

Needs Pillow and numpy. Approximate by design: it shows layout, scale,
color and composition, not Roblox's actual lighting.
"""

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

TERRAIN_COLORS = {
    "Sand": (247, 224, 165),
    "Grass": (96, 186, 72),
    "LeafyGrass": (58, 150, 62),
    "Sandstone": (212, 176, 120),
    "Basalt": (62, 55, 55),
    "CrackedLava": (255, 110, 30),
    "Rock": (128, 128, 128),
    "Slate": (110, 110, 115),
    "Ground": (120, 90, 60),
    "Mud": (90, 70, 50),
    "Water": (30, 190, 205),
    "Air": (20, 90, 140),
}
AREA_COLORS = {
    "Beach": (255, 214, 80),
    "Jungle": (80, 255, 120),
    "Ruins": (90, 235, 255),
    "Volcano": (255, 110, 60),
}


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def load(path):
    with open(path) as f:
        return json.load(f)


def terrain_arrays(m):
    rows, cols = m["rows"], m["cols"]
    heights = np.array(m["heights"], dtype=np.float32).reshape(rows, cols)
    mats = np.array(m["materials"], dtype=np.int32).reshape(rows, cols)
    palette = m["palette"]
    colors = np.zeros((rows, cols, 3), dtype=np.float32)
    for i, name in enumerate(palette, start=1):
        colors[mats == i] = TERRAIN_COLORS.get(name, (255, 0, 255))
    water = np.zeros((rows, cols), dtype=bool)
    if "Water" in palette:
        water = mats == (palette.index("Water") + 1)
    return heights, colors, water


def part_footprint(p):
    """XZ convex footprint of a (possibly rotated) box, plus its top height."""
    right = np.array(p["right"])
    up = np.array(p["up"])
    back = np.cross(right, up)
    center = np.array([p["x"], p["y"], p["z"]])
    corners = []
    for a in (-0.5, 0.5):
        for b in (-0.5, 0.5):
            for c in (-0.5, 0.5):
                corners.append(center + right * p["sx"] * a + up * p["sy"] * b + back * p["sz"] * c)
    corners = np.array(corners)
    pts = corners[:, [0, 2]]
    # convex hull (monotone chain)
    pts = sorted(set(map(tuple, np.round(pts, 3))))
    if len(pts) < 3:
        return pts, corners[:, 1].max()

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for q in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], q) <= 0:
            lower.pop()
        lower.append(q)
    for q in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], q) <= 0:
            upper.pop()
        upper.append(q)
    return lower[:-1] + upper[:-1], corners[:, 1].max()


def render_top(m, out_path, px=3):
    b = m["bounds"]
    heights, colors, water = terrain_arrays(m)
    step = m["step"]
    # hillshade
    gy, gx = np.gradient(heights, step)
    shade = np.clip(0.75 + (-gx * 0.6 - gy * 0.45) * 0.15, 0.45, 1.25)
    img = colors * shade[..., None]
    depth_tint = np.clip((heights + 30) / 30, 0.35, 1.0)
    img[water] = np.array(TERRAIN_COLORS["Water"]) * depth_tint[water][..., None]
    img = np.clip(img, 0, 255).astype(np.uint8)
    base = Image.fromarray(img, "RGB").resize(
        (int((b["maxX"] - b["minX"]) * px), int((b["maxZ"] - b["minZ"]) * px)), Image.BILINEAR
    )
    draw = ImageDraw.Draw(base, "RGBA")

    def to_px(x, z):
        return ((x - b["minX"]) * px, (z - b["minZ"]) * px)

    parts = sorted(m["parts"], key=lambda p: p["y"] + p["sy"] / 2)
    for p in parts:
        hull, top = part_footprint(p)
        if len(hull) < 3:
            continue
        rgb = hex_to_rgb(p["color"])
        alpha = int(255 * (1 - min(0.9, p["t"])))
        poly = [to_px(x, z) for x, z in hull]
        if p["shape"] == "Ball":
            xs = [q[0] for q in poly]
            zs = [q[1] for q in poly]
            draw.ellipse([min(xs), min(zs), max(xs), max(zs)], fill=rgb + (alpha,), outline=(0, 0, 0, 60))
        else:
            draw.polygon(poly, fill=rgb + (alpha,), outline=(0, 0, 0, 70))

    for s in m["spots"]:
        x, z = to_px(s["x"], s["z"])
        c = AREA_COLORS.get(s["area"], (255, 255, 255))
        r = 5 if s.get("clue") else 3.5
        draw.ellipse([x - r, z - r, x + r, z + r], fill=c + (255,), outline=(40, 20, 0, 255), width=2)
        if s.get("clue"):
            draw.line([x - 8, z, x + 8, z], fill=(255, 255, 255, 230), width=2)
            draw.line([x, z - 8, x, z + 8], fill=(255, 255, 255, 230), width=2)

    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 28)
        small = ImageFont.truetype("DejaVuSans-Bold.ttf", 18)
    except OSError:
        font = small = ImageFont.load_default()
    lay = m["layout"]
    labels = [
        ("BEACH", 60, 40),
        ("JUNGLE", -70, -70),
        ("RUINS", 65, -95),
        ("VOLCANO", 0, -175),
        ("BASE", 0, 158),
    ]
    for text, x, z in labels:
        tx, tz = to_px(x, z)
        draw.text((tx, tz), text, font=font, fill=(255, 255, 255, 255), anchor="mm", stroke_width=4, stroke_fill=(30, 20, 10, 255))
    for area, g in lay["gates"].items():
        tx, tz = to_px(g["x"], g["z"])
        draw.text((tx, tz + 22), area + " gate", font=small, fill=(255, 240, 200, 255), anchor="mm", stroke_width=3, stroke_fill=(30, 20, 10, 255))
    draw.text((12, 10), "north ^  (1 px = %.2f studs)" % (1 / px), font=small, fill=(255, 255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0, 255))
    base.save(out_path)


def rasterize_parts(m, heights, colors):
    """Raise the heightfield where parts stand so they show in the view."""
    b, step = m["bounds"], m["step"]
    h = heights.copy()
    c = colors.copy()
    rows, cols = h.shape
    for p in sorted(m["parts"], key=lambda p: p["y"] + p["sy"] / 2):
        if p["t"] > 0.6:
            continue
        hull, top = part_footprint(p)
        if len(hull) < 3:
            continue
        xs = [q[0] for q in hull]
        zs = [q[1] for q in hull]
        c0 = max(0, int((min(xs) - b["minX"]) / step))
        c1 = min(cols - 1, int((max(xs) - b["minX"]) / step) + 1)
        r0 = max(0, int((min(zs) - b["minZ"]) / step))
        r1 = min(rows - 1, int((max(zs) - b["minZ"]) / step) + 1)
        if c1 < c0 or r1 < r0:
            continue
        rgb = np.array(hex_to_rgb(p["color"]), dtype=np.float32)
        # simple point-in-convex-polygon test on the cell centers
        gx = b["minX"] + np.arange(c0, c1 + 1) * step
        gz = b["minZ"] + np.arange(r0, r1 + 1) * step
        X, Z = np.meshgrid(gx, gz)
        inside = np.ones_like(X, dtype=bool)
        n = len(hull)
        for i in range(n):
            x1, z1 = hull[i]
            x2, z2 = hull[(i + 1) % n]
            inside &= (x2 - x1) * (Z - z1) - (z2 - z1) * (X - x1) >= -1e-6
        if p["shape"] == "Ball":
            cx, cz = p["x"], p["z"]
            rad = max(p["sx"], p["sz"]) / 2
            inside = (X - cx) ** 2 + (Z - cz) ** 2 <= rad * rad
        sub_h = h[r0 : r1 + 1, c0 : c1 + 1]
        mask = inside & (top > sub_h)
        sub_h[mask] = top
        c[r0 : r1 + 1, c0 : c1 + 1][mask] = rgb
    return h, c


def render_view(m, out_path, width=1280, height=720):
    b, step = m["bounds"], m["step"]
    heights, colors, water = terrain_arrays(m)
    colors[water] = TERRAIN_COLORS["Water"]
    heights = np.maximum(heights, np.where(water, 0.0, heights))
    heights, colors = rasterize_parts(m, heights, colors)
    rows, cols = heights.shape

    lay = m["layout"]
    cam_x, cam_z = 0.0, lay["spawn"]["z"] + 45
    cam_y = 55.0
    horizon = height * 0.32
    scale = 520.0
    fov = math.radians(75)

    # sky
    sky_top = np.array([110, 180, 245], dtype=np.float32)
    sky_bottom = np.array([215, 238, 255], dtype=np.float32)
    t = np.linspace(0, 1, height)[:, None]
    img = np.zeros((height, width, 3), dtype=np.float32)
    img[:] = (sky_top * (1 - t) + sky_bottom * t)[:, None, :]
    fog = np.array([200, 230, 250], dtype=np.float32)

    ybuffer = np.full(width, height, dtype=np.int32)
    angles = np.linspace(-fov / 2, fov / 2, width)
    dirx = np.sin(angles)
    dirz = -np.cos(angles)
    dist = 1.0
    while dist < 650:
        px = cam_x + dirx * dist / np.cos(angles)
        pz = cam_z + dirz * dist / np.cos(angles)
        ci = ((px - b["minX"]) / step).astype(np.int32)
        ri = ((pz - b["minZ"]) / step).astype(np.int32)
        valid = (ci >= 0) & (ci < cols) & (ri >= 0) & (ri < rows)
        hgt = np.full(width, -12.0, dtype=np.float32)
        col = np.tile(np.array(TERRAIN_COLORS["Water"], dtype=np.float32), (width, 1))
        hgt[valid] = np.maximum(heights[ri[valid], ci[valid]], 0.0)
        col[valid] = colors[ri[valid], ci[valid]]
        screen_y = ((cam_y - hgt) / dist * scale + horizon).astype(np.int32)
        f = min(1.0, (dist / 650) ** 1.4) * 0.75
        shaded = col * (1 - f) + fog * f
        for x in np.nonzero(screen_y < ybuffer)[0]:
            y0 = max(0, screen_y[x])
            img[y0 : ybuffer[x], x] = shaded[x]
            ybuffer[x] = y0
        dist += 0.5 if dist < 80 else (1.0 if dist < 250 else 2.0)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(out_path)


def main():
    data = load(sys.argv[1] if len(sys.argv) > 1 else "map.json")
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "."
    os.makedirs(out_dir, exist_ok=True)
    render_top(data, os.path.join(out_dir, "map_top.png"))
    render_view(data, os.path.join(out_dir, "map_view.png"))
    print("wrote", os.path.join(out_dir, "map_top.png"), "and", os.path.join(out_dir, "map_view.png"))


if __name__ == "__main__":
    main()
