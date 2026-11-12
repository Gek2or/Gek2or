"""Small image toolkit on numpy + PIL (no OpenCV available)."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32)


def hsv(rgb):
    r, g, b = rgb[..., 0] / 255.0, rgb[..., 1] / 255.0, rgb[..., 2] / 255.0
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rr = (mx == r) & m
    gg = (mx == g) & m & ~rr
    bb = m & ~rr & ~gg
    h[rr] = ((g - b)[rr] / d[rr]) % 6
    h[gg] = (b - r)[gg] / d[gg] + 2
    h[bb] = (r - g)[bb] / d[bb] + 4
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h * 60.0, s, mx


def to_img(mask):
    return Image.fromarray((mask > 0).astype(np.uint8) * 255, "L")


def from_img(img):
    return np.asarray(img) > 127


def dilate(mask, r):
    return from_img(to_img(mask).filter(ImageFilter.MaxFilter(2 * r + 1)))


def erode(mask, r):
    return from_img(to_img(mask).filter(ImageFilter.MinFilter(2 * r + 1)))


def component(mask, seed):
    """Connected component of `mask` containing seed (x, y)."""
    img = to_img(mask).convert("L")
    ImageDraw.floodfill(img, seed, 128, thresh=0)
    return np.asarray(img) == 128


def fill_holes(mask):
    padded = np.pad(mask, 1, constant_values=False)
    img = to_img(padded).copy()
    ImageDraw.floodfill(img, (0, 0), 128, thresh=0)
    outside = np.asarray(img) == 128
    return ~outside[1:-1, 1:-1]


def feather(mask, r):
    return np.asarray(to_img(mask).filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255.0


def inpaint(rgb, mask, passes=6):
    """Fills `mask` by coarse-to-fine diffusion from the surrounding pixels."""
    h, w = mask.shape
    out = rgb.copy()
    known = (~mask).astype(np.float32)
    levels = []
    img, kn = out * known[..., None], known
    # Push: build a pyramid of weighted averages.
    while min(img.shape[:2]) > 4:
        levels.append((img, kn))
        hh, ww = img.shape[0] // 2 * 2, img.shape[1] // 2 * 2
        a = img[:hh, :ww]
        k = kn[:hh, :ww]
        img = a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]
        kn = k[0::2, 0::2] + k[1::2, 0::2] + k[0::2, 1::2] + k[1::2, 1::2]
    fill = img / np.maximum(kn, 1e-6)[..., None]
    fill[kn < 1e-6] = fill[kn >= 1e-6].mean(axis=0) if (kn >= 1e-6).any() else 0
    # Pull: upsample and keep known pixels.
    for img, kn in reversed(levels):
        up = np.asarray(Image.fromarray(np.clip(fill, 0, 255).astype(np.uint8)).resize((img.shape[1], img.shape[0]), Image.BILINEAR)).astype(np.float32)
        weight = np.clip(kn, 0, 1)[..., None]
        own = img / np.maximum(kn, 1e-6)[..., None]
        fill = own * weight + up * (1 - weight)
    result = out.copy()
    result[mask] = fill[mask]
    # Soften the seam.
    soft = np.asarray(Image.fromarray(np.clip(result, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))).astype(np.float32)
    edge = feather(dilate(mask, 3), 3)[..., None] * mask[..., None]
    return result * (1 - edge * 0.6) + soft * edge * 0.6


def save_rgb(arr, path):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").save(path)


def save_rgba(rgb, alpha, path):
    a = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), a]), "RGBA").save(path)
