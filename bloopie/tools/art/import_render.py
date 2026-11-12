"""Adds a freshly generated render to the game.

    python3 tools/art/import_render.py body       cosy     art_src/renders/hat_cosy.png
    python3 tools/art/import_render.py expression sad      art_src/renders/face_sad.png
    python3 tools/art/import_render.py pose       walk_a   art_src/renders/walk_a.png
    python3 tools/art/import_render.py stage      teen     art_src/renders/teen.png
    python3 tools/art/import_render.py room       joker:evening  art_src/renders/room_joker.png
    python3 tools/art/import_render.py capsule    dome     art_src/renders/dome.png

Character renders must show Bloopie on a flat magenta (#FF00FF) background in
the usual three-quarter view. The script removes the background, scales and
moves the character so its plush body sits exactly where the base sprite sits
in the room painting, and records the picture in art/painted/painted.json.
The game picks it up on the next start; nothing else has to be edited.

Needs numpy and Pillow."""
import sys

import numpy as np
from PIL import Image, ImageFilter

import lib
import manifest

W, H = manifest.SOURCE_SIZE
POSES = ("walk_a", "walk_b", "crouch", "air", "curl", "reach")
STAGES = ("teen", "adult")
TIMES = ("evening", "sunset", "night")
# Part of the painting that holds the face: brows, eyes, blush and mouth.
FACE_ZONE = (296, 838, 852, 1306)


def fail(message):
    sys.exit("import_render: " + message)


def plush(rgb):
    """Light blue plush pixels (Bloopie's body in the original theme)."""
    h, s, v = lib.hsv(rgb)
    body = (h > 195) & (h < 255) & (s > 0.16) & (s < 0.8) & (v > 0.66)
    body |= (h > 175) & (h < 285) & (s <= 0.2) & (v > 0.8)
    return body


def body_anchor(mask):
    """Width of the body at its widest row and the point under its feet. Hats,
    the curl and raised paws do not move either, so renders line up on it."""
    rows = np.where(mask.sum(axis=1) > 0)[0]
    if rows.size == 0:
        fail("no light blue plush found in the picture")
    widths = mask.sum(axis=1)
    widest = int(np.argmax(widths))
    xs = np.where(mask[widest])[0]
    return float(xs.max() - xs.min() + 1), float((xs.max() + xs.min()) / 2.0), float(rows.max())


def key_out(rgb):
    """Alpha from the distance to the flat background colour, with despill."""
    border = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3), rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3)])
    background = np.median(border, axis=0)
    if np.abs(border - background).sum(axis=1).mean() > 40:
        fail("the background is not flat; render the character on plain #FF00FF")
    distance = np.sqrt(((rgb - background) ** 2).sum(axis=2))
    solid = lib.fill_holes(distance > 70)
    solid = lib.erode(lib.dilate(solid, 2), 3)
    # Keep the main figure plus anything near it (tears, sparkles), drop specks.
    ys, xs = np.where(lib.erode(solid, 12))
    if ys.size == 0:
        fail("nothing but background in the picture")
    seed = (int(xs[xs.size // 2]), int(ys[ys.size // 2]))
    figure = lib.dilate(lib.component(lib.erode(solid, 2), seed), 60)
    solid &= figure
    alpha = lib.feather(solid, 1.2)
    # Pull the leftover background tint out of the soft edge.
    edge = (alpha > 0.02) & (alpha < 0.98)
    spill = np.clip(1.0 - distance / 160.0, 0.0, 1.0)[..., None] * edge[..., None]
    inside = np.asarray(Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))).astype(np.float32)
    return rgb * (1 - spill) + inside * spill, alpha, solid


def reference():
    data = manifest.load()
    if "sprite_box" not in data or "none" not in data["bodies"]:
        fail("run extract_mockups.py first: the base sprite is missing")
    box = data["sprite_box"]
    base = np.asarray(Image.open(manifest.PAINTED / data["bodies"]["none"])).astype(np.float32)
    canvas = np.zeros((H, W), bool)
    canvas[box[1]:box[3], box[0]:box[2]] = plush(base[..., :3]) & (base[..., 3] > 128)
    return data, body_anchor(canvas)


def place_character(path):
    """Returns (rgb, alpha) of the render on the full painting canvas, with
    the body where the base sprite has it."""
    data, (ref_width, ref_x, ref_bottom) = reference()
    rgb = lib.load(path)
    rgb, alpha, solid = key_out(rgb)
    width, center_x, bottom = body_anchor(plush(rgb) & solid)
    zoom = ref_width / width
    size = (max(1, round(rgb.shape[1] * zoom)), max(1, round(rgb.shape[0] * zoom)))
    scaled = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha * 255.0]).astype(np.uint8), "RGBA").resize(size, Image.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(scaled, (round(ref_x - center_x * zoom), round(ref_bottom - bottom * zoom)))
    out = np.asarray(canvas).astype(np.float32)
    return data, out[..., :3], out[..., 3] / 255.0


def save_sprite(rgb, alpha, name):
    ys, xs = np.where(alpha > 0.01)
    if ys.size == 0:
        fail("the character ended up outside the painting")
    pad = 12
    box = [max(0, int(xs.min()) - pad), max(0, int(ys.min()) - pad), min(W, int(xs.max()) + pad + 1), min(H, int(ys.max()) + pad + 1)]
    lib.save_rgba(rgb[box[1]:box[3], box[0]:box[2]], alpha[box[1]:box[3], box[0]:box[2]], str(manifest.PAINTED / name))
    return {"file": name, "box": box}


def preview(data, layers, name):
    """Old sprite next to the new one, both on the supporter room."""
    room = lib.load(str(manifest.PAINTED / "room_supporter.jpg"))
    sheets = []
    for rgb, alpha in layers:
        sheets.append(room * (1 - alpha[..., None]) + rgb * alpha[..., None])
    out = manifest.preview_dir() / f"{name}.png"
    lib.save_rgb(np.concatenate(sheets, axis=1)[::2, ::2], str(out))
    print("preview:", out)


def base_layer(data):
    box = data["sprite_box"]
    base = np.asarray(Image.open(manifest.PAINTED / data["bodies"]["none"])).astype(np.float32)
    rgb = np.zeros((H, W, 3), np.float32)
    alpha = np.zeros((H, W), np.float32)
    rgb[box[1]:box[3], box[0]:box[2]] = base[..., :3]
    alpha[box[1]:box[3], box[0]:box[2]] = base[..., 3] / 255.0
    return rgb, alpha


def import_character(kind, name, path):
    if kind == "pose" and name not in POSES:
        fail("pose must be one of: " + ", ".join(POSES))
    if kind == "stage" and name not in STAGES:
        fail("stage must be one of: " + ", ".join(STAGES))
    data, rgb, alpha = place_character(path)
    if kind == "expression":
        # Only the face is kept, so the expression fits any hat and any stage.
        zone = np.zeros((H, W), bool)
        zone[FACE_ZONE[1]:FACE_ZONE[3], FACE_ZONE[0]:FACE_ZONE[2]] = True
        _, base_alpha = base_layer(data)
        alpha = alpha * lib.feather(zone & lib.erode(base_alpha > 0.5, 8), 8)
    section = {"body": "bodies", "expression": "expressions", "pose": "poses", "stage": "stages"}[kind]
    file_name = {"body": "bloopie_hat_", "expression": "expression_", "pose": "pose_", "stage": "stage_"}[kind] + name + ".png"
    data[section][name] = save_sprite(rgb, alpha, file_name)
    manifest.save(data)
    new_layer = _over(base_layer(data), rgb, alpha) if kind == "expression" else (rgb, alpha)
    preview(data, [base_layer(data), new_layer], f"{kind}_{name}")
    print(f"added {section}.{name} -> {file_name}")


def _over(base, rgb, alpha):
    base_rgb, base_alpha = base
    return base_rgb * (1 - alpha[..., None]) + rgb * alpha[..., None], base_alpha


def find_bulbs(room):
    r, g, b = room[..., 0], room[..., 1], room[..., 2]
    bright = (r > 244) & (g > 205) & (b > 110) & (b < 215)
    bright[900:] = False
    bright = lib.erode(lib.dilate(bright, 3), 2)
    bulbs, seen = [], np.zeros(bright.shape, bool)
    ys, xs = np.where(bright)
    for y, x in zip(ys[::7], xs[::7]):
        if seen[y, x]:
            continue
        blob = lib.component(bright, (int(x), int(y)))
        seen |= blob
        if 120 <= blob.sum() <= 6000:
            cy, cx = np.where(blob)
            bulbs.append([int(cx.mean()), int(cy.mean())])
    return bulbs


def import_room(name, path):
    if ":" not in name:
        fail("room name must look like joker:evening")
    archetype, time = name.split(":", 1)
    if time not in TIMES:
        fail("time must be one of: " + ", ".join(TIMES))
    picture = Image.open(path).convert("RGB")
    # Cover the painting size, cropping whatever sticks out, centred.
    zoom = max(W / picture.width, H / picture.height)
    picture = picture.resize((round(picture.width * zoom), round(picture.height * zoom)), Image.LANCZOS)
    left, top = (picture.width - W) // 2, (picture.height - H) // 2
    picture = picture.crop((left, top, left + W, top + H))
    file_name = f"room_{archetype}_{time}.jpg"
    picture.save(manifest.PAINTED / file_name, quality=93)
    data = manifest.load()
    data["rooms"].setdefault(archetype, {})[time] = file_name
    data["bulbs"][file_name] = find_bulbs(np.asarray(picture).astype(np.float32))
    manifest.save(data)
    room = np.asarray(picture).astype(np.float32)
    rgb, alpha = base_layer(data)
    out = manifest.preview_dir() / f"room_{archetype}_{time}.png"
    lib.save_rgb(np.concatenate([room, room * (1 - alpha[..., None]) + rgb * alpha[..., None]], axis=1)[::2, ::2], str(out))
    print("preview:", out)
    print(f"added rooms.{archetype}.{time} -> {file_name} ({len(data['bulbs'][file_name])} bulbs)")


def import_capsule(path):
    """The stasis dome. On magenta it is keyed like a character; on black the
    brightness becomes the transparency, which keeps the glass see-through."""
    data, (ref_width, ref_x, ref_bottom) = reference()
    rgb = lib.load(path)
    corners = np.concatenate([rgb[:6, :6].reshape(-1, 3), rgb[-6:, -6:].reshape(-1, 3)])
    if corners.mean() < 24:
        alpha = np.clip(rgb.max(axis=2) / 255.0 * 1.25, 0.0, 1.0)
        rgb = rgb / np.maximum(alpha, 0.05)[..., None]
    else:
        rgb, alpha, _ = key_out(rgb)
        alpha = alpha * 0.82
    ys, xs = np.where(alpha > 0.04)
    if ys.size == 0:
        fail("the dome picture is empty")
    # The dome is 1.3 body widths wide and stands a little below the feet.
    zoom = ref_width * 1.3 / (xs.max() - xs.min() + 1)
    cut = np.dstack([np.clip(rgb, 0, 255), alpha * 255.0]).astype(np.uint8)[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    scaled = Image.fromarray(cut, "RGBA").resize((round(cut.shape[1] * zoom), round(cut.shape[0] * zoom)), Image.LANCZOS)
    left = round(ref_x - scaled.width / 2)
    top = round(ref_bottom + 36 - scaled.height)
    scaled.save(manifest.PAINTED / "capsule.png")
    data["capsule"] = {"file": "capsule.png", "box": [left, top, left + scaled.width, top + scaled.height]}
    manifest.save(data)
    print("added capsule -> capsule.png")


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    kind, name, path = sys.argv[1:]
    if kind in ("body", "expression", "pose", "stage"):
        import_character(kind, name, path)
    elif kind == "room":
        import_room(name, path)
    elif kind == "capsule":
        import_capsule(path)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
