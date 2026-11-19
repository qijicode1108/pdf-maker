#!/usr/bin/env python3
"""生成「秒转 PDF」应用图标。

深色底 + 白色剪影：一页纸，纸后面探出两只兔耳朵。
风格参考 DeepSeek Harness 的鲸鱼图标——少细节、强轮廓，16px 下也能看清。

    python3 src/icon/make-icon.py             # 输出 build/AppIcon.icns 和 build/AppIcon-1024.png
    python3 src/icon/make-icon.py --png-only  # 只出 1024 预览图

依赖 Pillow（macOS 上 `pip install pillow`）。
"""

import os
import subprocess
import sys

from PIL import Image, ImageDraw

SS = 4              # 超采样倍数
CANVAS = 1024
PIX = CANVAS * SS

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUILD = os.path.join(ROOT, "build")

BG_TOP = (28, 29, 33, 255)
BG_BOTTOM = (11, 12, 14, 255)
INK = (58, 61, 69, 255)
PAPER = (247, 247, 245, 255)
WHITE = (255, 255, 255, 255)
FOLD = (232, 232, 236, 255)
TITLE = (120, 122, 132, 255)
LINE = (203, 203, 208, 255)
BLOCK = (228, 228, 232, 255)


def new_canvas():
    return Image.new("RGBA", (PIX, PIX), (0, 0, 0, 0))


def vertical_gradient(size, top, bottom):
    gradient = Image.new("RGBA", (1, size[1]))
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        gradient.putpixel((0, y), tuple(
            int(top[i] + (bottom[i] - top[i]) * t) for i in range(4)))
    return gradient.resize(size, Image.BILINEAR)


def draw_background(canvas):
    layer = vertical_gradient((824 * SS, 824 * SS), BG_TOP, BG_BOTTOM)
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, layer.size[0] - 1, layer.size[1] - 1], radius=186 * SS, fill=255)
    layer.putalpha(mask)
    canvas.alpha_composite(layer, (100 * SS, 100 * SS))


def ellipse(canvas, cx, cy, rx, ry, angle=0, fill=WHITE):
    pad = 12
    side = int((2 * max(rx, ry) + pad) * SS)
    layer = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    center = side / 2
    ImageDraw.Draw(layer).ellipse(
        [center - rx * SS, center - ry * SS, center + rx * SS, center + ry * SS], fill=fill)
    if angle:
        layer = layer.rotate(-angle, resample=Image.BICUBIC)
    canvas.alpha_composite(layer, (int(cx * SS - layer.width / 2), int(cy * SS - layer.height / 2)))


def draw_page(canvas):
    pad = 60
    width, height = 396 * SS, 452 * SS
    layer = Image.new("RGBA", (width + pad, height + pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ox, oy = pad / 2, pad / 2

    d.rounded_rectangle([ox, oy, ox + width, oy + height], radius=32 * SS, fill=PAPER)
    # 右上折角
    fold = 52 * SS
    d.polygon([(ox + width - fold, oy), (ox + width, oy + fold), (ox + width - fold, oy + fold)],
              fill=FOLD)
    # 标题线
    d.rounded_rectangle([ox + 40 * SS, oy + 58 * SS, ox + 40 * SS + width * 0.46, oy + 96 * SS],
                        radius=19 * SS, fill=TITLE)
    # 正文线
    y = oy + 150 * SS
    for ratio in (0.72, 0.6, 0.72, 0.48, 0.66):
        d.rounded_rectangle([ox + 40 * SS, y, ox + 40 * SS + width * ratio, y + 15 * SS],
                            radius=8 * SS, fill=LINE)
        y += 46 * SS
    # 图块
    d.rounded_rectangle([ox + 40 * SS, oy + height - 96 * SS,
                         ox + 40 * SS + width * 0.32, oy + height - 32 * SS],
                        radius=14 * SS, fill=BLOCK)

    layer = layer.rotate(2, resample=Image.BICUBIC)   # 纸张略微倾斜（顺时针）
    canvas.alpha_composite(layer, (int(500 * SS - layer.width / 2),
                                   int(614 * SS - layer.height / 2)))


def build_icon():
    canvas = new_canvas()
    draw_background(canvas)

    # 速度线
    d = ImageDraw.Draw(canvas)
    for x1, x2, y, w in ((146, 258, 316, 16), (124, 232, 388, 14)):
        d.rounded_rectangle([x1 * SS, (y - w / 2) * SS, x2 * SS, (y + w / 2) * SS],
                            radius=w / 2 * SS, fill=INK)

    # 耳朵（在纸张后面）
    ellipse(canvas, 442, 286, 48, 126, angle=-15)
    ellipse(canvas, 556, 274, 48, 128, angle=9)

    # 纸张
    draw_page(canvas)

    return canvas.resize((CANVAS, CANVAS), Image.LANCZOS)


def write_iconset(image):
    iconset = os.path.join(BUILD, "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    for size in (16, 32, 64, 128, 256, 512, 1024):
        image.resize((size, size), Image.LANCZOS).save(
            os.path.join(iconset, f"icon_{size}x{size}.png"))
        if size <= 512:
            image.resize((size * 2, size * 2), Image.LANCZOS).save(
                os.path.join(iconset, f"icon_{size}x{size}@2x.png"))
    subprocess.run(["iconutil", "-c", "icns", iconset,
                    "-o", os.path.join(BUILD, "AppIcon.icns")], check=True)


def main():
    os.makedirs(BUILD, exist_ok=True)
    icon = build_icon()
    icon.save(os.path.join(BUILD, "AppIcon-1024.png"))
    if "--png-only" not in sys.argv:
        write_iconset(icon)
        print("build/AppIcon.icns")
    print("build/AppIcon-1024.png")


if __name__ == "__main__":
    main()
