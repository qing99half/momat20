"""锚帧落格:组件PNG -> 20x20(块采样中位色, 不吸附调色板, 脚底贴y=19)。
用法: python tools/make_anchor_20.py <组件png> <输出png>
"""
import sys
import numpy as np
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
arr = np.asarray(Image.open(SRC).convert("RGBA")).copy()
mask = arr[..., 3] > 20
ys, xs = np.where(mask)
arr = arr[ys.min():ys.max()+1, xs.min():xs.max()+1]
fh, fw = arr.shape[:2]
BODY_H = 18
scale = BODY_H / fh
tw = max(1, round(fw * scale))
th = min(20, max(1, round(fh * scale)))
sa = np.zeros((th, tw, 4), dtype=np.uint8)
for ty in range(th):
    for tx in range(tw):
        ry0, ry1 = int(ty*fh/th), max(int((ty+1)*fh/th), int(ty*fh/th)+1)
        rx0, rx1 = int(tx*fw/tw), max(int((tx+1)*fw/tw), int(tx*fw/tw)+1)
        block = arr[ry0:ry1, rx0:rx1]
        a = block[..., 3]
        content = block[a > 20]
        if len(content) > 0 and a.mean() / 255 > 0.35:
            med = np.median(content[..., :3], axis=0).astype(np.uint8)
            sa[ty, tx] = [med[0], med[1], med[2], 255]
canvas = np.zeros((20, 20, 4), dtype=np.uint8)
px = (20 - tw) // 2
sx0 = max(0, -px); dx0 = max(0, px)
cw = min(tw - sx0, 20 - dx0)
canvas[20-th:20, dx0:dx0+cw] = sa[:, sx0:sx0+cw]
ys2 = np.where(canvas[..., 3] > 0)[0]
if len(ys2):
    shift = 19 - ys2.max()
    canvas = np.roll(canvas, shift, axis=0)
    if shift > 0:
        canvas[:shift] = 0
Image.fromarray(canvas, "RGBA").save(OUT)
# 预览
sc = 12
prev = Image.fromarray(canvas, "RGBA").resize((20*sc, 20*sc), Image.NEAREST)
bg = Image.new("RGB", prev.size, (64, 64, 64))
bg.paste(prev, (0, 0), prev)
bg.save(OUT.replace(".png", "_preview.png"))
print("opaque:", int((canvas[..., 3] > 0).sum()), "->", OUT)
