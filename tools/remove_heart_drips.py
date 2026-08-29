# 腐心(heart_mold)滴血效果程序侧去除:
# 1) 每列只保留最长连续不透明段(分离的滴血段直接删)
# 2) 底缘做滑动中值包络,超过包络+容差的下垂像素裁掉(合并进主体的滴血)
# 原图备份为 *.orig.png(已存在则不覆盖)
from PIL import Image
import numpy as np
import sys

TOL = 0  # 包络容差(px)
WINDOW = 9  # 中值窗口(列)

def clean(path: str) -> None:
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    mask = a[:, :, 3] > 0
    h, w = mask.shape
    keep = np.zeros_like(mask)
    bottoms = np.full(w, -1)
    for x in range(w):
        ys = np.where(mask[:, x])[0]
        if len(ys) == 0:
            continue
        # 分段,保留最长段
        runs = []
        s = p = ys[0]
        for y in ys[1:]:
            if y - p > 1:
                runs.append((s, p))
                s = y
            p = y
        runs.append((s, p))
        top, bot = max(runs, key=lambda r: r[1] - r[0])
        keep[top:bot + 1, x] = True
        bottoms[x] = bot
    # 滑动中值包络裁剪
    for x in range(w):
        if bottoms[x] < 0:
            continue
        lo, hi = max(0, x - WINDOW // 2), min(w, x + WINDOW // 2 + 1)
        nb = bottoms[lo:hi]
        nb = nb[nb >= 0]
        env = int(np.median(nb)) + TOL
        if bottoms[x] > env:
            keep[env + 1:bottoms[x] + 1, x] = False
    a[:, :, 3] = np.where(keep, a[:, :, 3], 0)
    import os
    bak = path.replace(".png", ".orig.png")
    if not os.path.exists(bak):
        Image.open(path).save(bak)
    Image.fromarray(a).save(path)
    print("cleaned:", path)

if __name__ == "__main__":
    for f in sys.argv[1:]:
        clean(f)
