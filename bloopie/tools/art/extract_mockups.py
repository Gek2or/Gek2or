"""Cuts game art out of the approved mock-ups in art_src/mockups: clean room
backgrounds, Bloopie sprites, face patches and UI icons.

    python3 tools/art/extract_mockups.py

Needs numpy and Pillow. Rewrites the files in art/painted and the base entries
of painted.json; entries added later by import_render.py are kept."""
import numpy as np
from PIL import Image, ImageFilter

import lib
import manifest

src = manifest.SOURCES / "mockups"
dst = manifest.PAINTED
pre = manifest.preview_dir()


def mockup(name):
    """The mock-up cut out of the phone gallery screenshot."""
    return np.asarray(Image.open(src / f"{name}.jpg").convert("RGB").crop(manifest.MOCKUP_BOX)).astype(np.float32)


H = mockup("home")
C = mockup("care")
V = mockup("vocal")
E = mockup("explorer")
SHAPE = H.shape[:2]


def rect_mask(x_a, y_a, x_b, y_b):
    m = np.zeros(SHAPE, bool)
    m[y_a:y_b, x_a:x_b] = True
    return m


def plush_mask(img):
    h, s, v = lib.hsv(img)
    body = (h > 195) & (h < 255) & (s > 0.16) & (s < 0.8) & (v > 0.66)
    body |= (h > 175) & (h < 285) & (s <= 0.2) & (v > 0.8)
    body |= (s < 0.06) & (v > 0.9)
    body[:560] = False
    body[1480:] = False
    body = lib.erode(lib.dilate(body, 6), 6)
    m = lib.fill_holes(lib.dilate(lib.component(body, (560, 1100)), 3))
    return lib.dilate(lib.component(lib.erode(m, 6), (560, 1100)), 7)


def column_fill(img, x_a, y_a, x_b, y_b, band=26):
    """Replaces a rectangle column by column, blending the typical colour just
    above it into the typical colour just below it. Vertical structures (the
    window frame, the wall, curtains) continue; thin wires simply end."""
    top = np.median(img[y_a - band:y_a, x_a:x_b], axis=0)
    bottom = np.median(img[y_b:y_b + band, x_a:x_b], axis=0)
    t = np.linspace(0.0, 1.0, y_b - y_a, dtype=np.float32)
    t = (t * t * (3.0 - 2.0 * t))[:, None, None]
    fill = top[None] * (1 - t) + bottom[None] * t
    fill = np.asarray(Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32)
    fill += np.random.default_rng(7).normal(0.0, 2.2, fill.shape[:2])[..., None]
    weight = np.zeros(SHAPE, np.float32)
    weight[y_a + 5:y_b - 5, x_a + 5:x_b - 5] = 255.0
    weight = np.asarray(Image.fromarray(weight.astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))).astype(np.float32)[..., None] / 255.0
    patch = img.copy()
    patch[y_a:y_b, x_a:x_b] = fill
    return img * (1 - weight) + patch * weight


def clean_room(img, character, bubble, pills, name):
    hole = lib.dilate(character, 16) | rect_mask(0, 1750, 1124, 1998)
    bg = lib.inpaint(img, hole)
    bg = column_fill(bg, *pills)
    bg = column_fill(bg, *bubble)
    Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8)).save(f"{dst}/{name}.jpg", quality=93)
    return bg


# --- Bloopie from the home mock-up ---------------------------------------------
M = plush_mask(H)
hh, ss, vv = lib.hsv(H)
# A fleck of window that sticks to the left side of the curl.
fleck = rect_mask(425, 650, 478, 720) & ~((hh > 195) & (hh < 255) & (vv > 0.75))
M &= ~lib.dilate(fleck, 2)

# The wizard variant from the explorer mock-up: same body, painted hat.
eh, es, ev = lib.hsv(E)
hat = (eh > 244) & (eh < 305) & (es > 0.27) & (ev > 0.34) & rect_mask(200, 550, 870, 980) & ~plush_mask(E)
hat = lib.erode(lib.dilate(hat, 4), 4)
seeds = [(x, y) for y in range(640, 800, 8) for x in range(380, 560, 8) if hat[y, x]]
hat = lib.fill_holes(lib.dilate(lib.component(hat, seeds[len(seeds) // 2]), 4))
raw_purple = (eh > 244) & (eh < 305) & (es > 0.27) & (ev > 0.34) & ~plush_mask(E)
hat |= lib.dilate(lib.erode(raw_purple & rect_mask(740, 815, 850, 905), 2), 4)   # the brim behind the curl
print("hat px", hat.sum())
hat = lib.dilate(lib.erode(hat, 3), 7)   # drops thin strays
W = lib.fill_holes(plush_mask(E) | hat)

both = M | W
ys, xs = np.where(both)
pad = 16
x0, y0, x1, y1 = xs.min() - pad, ys.min() - pad, xs.max() + pad + 1, ys.max() + pad + 1
print("sprite box", x0, y0, x1, y1, "size", x1 - x0, y1 - y0)


def cut(rgb, a, name):
    lib.save_rgba(rgb[y0:y1, x0:x1], a[y0:y1, x0:x1], f"{dst}/{name}.png")


cut(H, lib.feather(lib.erode(M, 1), 1.3), "bloopie_body")
cut(E, lib.feather(lib.erode(W, 1), 1.3), "bloopie_wizard")

plush = (hh > 190) & (hh < 262) & (vv > 0.62) & (ss > 0.1) & (ss < 0.75)
pink = ((hh > 300) | (hh < 25)) & (ss > 0.12) & (vv > 0.6)
# Only the blush under the eyes counts; the eye whites are pinkish too.
pink &= rect_mask(0, 1178, 1124, 1998)
inner = lib.erode(M, 4)


def blank_patch(region, name, grow=7):
    """Paints plush over the facial features inside `region` (blush stays)."""
    feature = lib.dilate(region & inner & ~plush & ~pink, grow) & inner
    # The rim right next to eyes and mouth is paler than the plush around it,
    # so the fill is taken from a little further out, then smoothed.
    hole = lib.dilate(feature, 14) & inner & ~lib.dilate(pink, 2)
    filled = lib.inpaint(H, hole)
    smooth = np.asarray(Image.fromarray(np.clip(filled, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9))).astype(np.float32)
    blend = lib.feather(hole, 4)[..., None]
    filled = filled * (1 - blend) + smooth * blend
    cut(filled, lib.feather(lib.dilate(hole, 2), 5), name)


def swap_patch(other, region, name, threshold=38.0):
    """Takes the pixels of another mock-up where its face differs."""
    diff = np.abs(other - H).sum(axis=2)
    changed = lib.fill_holes(lib.dilate((diff > threshold) & region & inner, 9) & inner & region)
    cut(other, lib.feather(changed, 4), name)


blank_patch(rect_mask(300, 935, 830, 1222) & ~rect_mask(540, 1132, 736, 1300), "face_eyes_blank", grow=15)
blank_patch(rect_mask(404, 858, 506, 928) | rect_mask(660, 850, 756, 918), "face_brows_blank", grow=8)
blank_patch(rect_mask(552, 1150, 726, 1290), "face_mouth_blank", grow=9)
swap_patch(C, rect_mask(290, 860, 840, 1300), "face_laugh")
swap_patch(V, rect_mask(430, 1110, 730, 1340), "face_sing")

# --- Rooms ------------------------------------------------------------------------
room_s = clean_room(H, M, (170, 310, 965, 600), (640, 50, 1110, 175), "room_supporter")
room_e = clean_room(E, W, (180, 310, 965, 600), (640, 50, 1110, 175), "room_explorer")


def find_bulbs(bg):
    r, g, b = bg[..., 0], bg[..., 1], bg[..., 2]
    bright = (r > 244) & (g > 205) & (b > 110) & (b < 215)
    bright[900:] = False
    bright = lib.erode(lib.dilate(bright, 3), 2)
    bulbs, seen = [], np.zeros(SHAPE, bool)
    ys2, xs2 = np.where(bright)
    for y, x in zip(ys2[::7], xs2[::7]):
        if seen[y, x]:
            continue
        comp = lib.component(bright, (int(x), int(y)))
        seen |= comp
        if 120 <= comp.sum() <= 6000:
            cy, cx = np.where(comp)
            bulbs.append([int(cx.mean()), int(cy.mean())])
    return bulbs


data = manifest.load()
data["sprite_box"] = [int(x0), int(y0), int(x1), int(y1)]
data["rooms"].setdefault("supporter", {})["evening"] = "room_supporter.jpg"
data["rooms"].setdefault("explorer", {})["night"] = "room_explorer.jpg"
data["bodies"]["none"] = "bloopie_body.png"
data["bodies"]["wizard"] = "bloopie_wizard.png"
data["bulbs"]["room_supporter.jpg"] = find_bulbs(room_s)
data["bulbs"]["room_explorer.jpg"] = find_bulbs(room_e)
manifest.save(data)
print("bulbs", {k: len(v) for k, v in data["bulbs"].items()})

# --- Icons: cut the painted pictograms off their cream tiles -----------------------
def icon(img, box, name):
    x_a, y_a, x_b, y_b = box
    patch = img[y_a:y_b, x_a:x_b]
    tile = np.median(np.concatenate([patch[:4].reshape(-1, 3), patch[-4:].reshape(-1, 3)]), axis=0)
    near = np.sqrt(((patch - tile) ** 2).sum(axis=2)) < 30.0
    # Only the tile that touches the border is removed; cream areas enclosed by
    # the pictogram's outline stay opaque.
    opaque = lib.fill_holes(~near)
    opaque = lib.erode(lib.dilate(opaque, 1), 1)
    lib.save_rgba(patch, lib.feather(opaque, 0.9), f"{dst}/icon_{name}.png")
    return tile


tiles = []
boxes = {
    "cocoa": (132, 1568, 272, 1692), "tart": (376, 1568, 508, 1692), "theme": (616, 1566, 750, 1692),
    "hat": (866, 1562, 980, 1692), "chat": (106, 1782, 234, 1888), "care": (362, 1782, 508, 1892),
    "play": (636, 1786, 754, 1888), "sleep": (896, 1778, 1014, 1874),
}
for name, box in boxes.items():
    tiles.append(icon(C, box, name))
print("tile colour", np.mean(tiles, axis=0).round())

# --- Previews ----------------------------------------------------------------------
def sprite_on(bg, name):
    sp = np.asarray(Image.open(f"{dst}/{name}.png")).astype(np.float32)
    out = bg.copy()
    a = sp[..., 3:4] / 255.0
    out[y0:y1, x0:x1] = out[y0:y1, x0:x1] * (1 - a) + sp[..., :3] * a
    return out


lib.save_rgb(np.concatenate([room_s, sprite_on(room_s, "bloopie_body"), room_e, sprite_on(room_e, "bloopie_wizard")], axis=1)[::3, ::3], f"{pre}/rooms.png")
sprite = np.asarray(Image.open(f"{dst}/bloopie_body.png")).astype(np.float32)


def over(base, name):
    p = np.asarray(Image.open(f"{dst}/{name}.png")).astype(np.float32)
    al = p[..., 3:4] / 255.0
    out = base.copy()
    out[..., :3] = out[..., :3] * (1 - al) + p[..., :3] * al
    return out


faces = [over(sprite, "face_eyes_blank"), over(over(over(sprite, "face_eyes_blank"), "face_brows_blank"), "face_mouth_blank"), over(sprite, "face_laugh"), over(sprite, "face_sing")]
back = np.array([60, 60, 90], np.float32)
lib.save_rgb(np.concatenate([f[..., :3] * (f[..., 3:4] / 255.0) + back * (1 - f[..., 3:4] / 255.0) for f in faces], axis=1)[::2, ::2], f"{pre}/faces.png")
icons = [np.asarray(Image.open(f"{dst}/icon_{n}.png").resize((120, 110)).convert('RGBA')).astype(np.float32) for n in ["cocoa", "tart", "theme", "hat", "chat", "care", "play", "sleep"]]
lib.save_rgb(np.concatenate([i[..., :3] * (i[..., 3:4] / 255.0) + back * (1 - i[..., 3:4] / 255.0) for i in icons], axis=1), f"{pre}/icons.png")
