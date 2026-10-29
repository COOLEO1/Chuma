from PIL import Image, ImageDraw
import os

S, K = 1024, 4
NAVY = (14, 59, 46, 255)
GOLD = (227, 167, 47, 255)
TEAL = (31, 157, 99, 255)

def mark(size):
    n = size * K
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c, r = n / 2, n * 0.25
    d.ellipse([c - r, c - r, c + r, c + r], fill=GOLD)
    w = int(r * 0.2)
    pts = []
    for i in range(41):
        t = i / 40
        pts.append((c - r * 0.55 + t * r * 1.1,
                    c + r * 0.3 - (t ** 1.8) * r * 0.75))
    d.line(pts, fill=TEAL, width=w, joint="curve")
    for p in (pts[0], pts[-1]):
        d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=TEAL)
    return im.resize((size, size), Image.LANCZOS)

os.makedirs("assets/icon", exist_ok=True)
fg = mark(S)
fg.save("assets/icon/foreground.png")

n = S * K
bg = Image.new("RGBA", (n, n), (0, 0, 0, 0))
ImageDraw.Draw(bg).rounded_rectangle([0, 0, n - 1, n - 1], radius=int(n * 0.22), fill=NAVY)
bg = bg.resize((S, S), Image.LANCZOS)
bg.alpha_composite(fg)
bg.save("assets/icon/icon.png")
