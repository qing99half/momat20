"""从生图中按连通域提取所有角色,输出带编号的联络表供人工指派动作。"""
import sys
from pathlib import Path
from collections import deque
from PIL import Image, ImageDraw
import numpy as np

SRC = Path(sys.argv[1])
PREFIX = sys.argv[2]  # 如 assets/art/_misc_components

img = Image.open(SRC).convert("RGBA")
W, H = img.size
arr = np.asarray(img).copy()
arr[int(H*0.90):, : int(W*0.22), 3] = 0  # 清左下水印

m = arr[..., 3] > 20
h, w = m.shape
visited = np.zeros_like(m, dtype=bool)
comps = []
for sy in range(h):
    for sx in range(w):
        if m[sy, sx] and not visited[sy, sx]:
            q = deque([(sy, sx)]); visited[sy, sx] = True
            comp = []
            while q:
                cy, cx = q.popleft(); comp.append((cy, cx))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy+dy, cx+dx
                        if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not visited[ny, nx]:
                            visited[ny, nx] = True; q.append((ny, nx))
            comps.append(comp)

# 只保留大块(角色),过滤小碎点
comps = [c for c in comps if len(c) > 2000]
print("components:", len(comps))

# 每个连通域取 bbox,按 行带(y中心粗排) + x 排序
items = []
for c in comps:
    ys = [p[0] for p in c]; xs = [p[1] for p in c]
    y0, y1, x0, x1 = min(ys), max(ys)+1, min(xs), max(xs)+1
    items.append((y0, y1, x0, x1, (y0+y1)/2))
items.sort(key=lambda t: (round(t[4]/300), t[2]))  # 300px 为一个行带

# 导出每个组件 + 联络表
thumbs = []
for i, (y0, y1, x0, x1, _) in enumerate(items):
    sub = arr[y0:y1, x0:x1].copy()
    cm = np.zeros((y1-y0, x1-x0), dtype=bool)
    # 保留该组件像素(重新判定即可,因为已按 bbox 裁出,附近无其他组件)
    cm = sub[..., 3] > 20
    pim = Image.fromarray(sub, "RGBA")
    pim.save(f"{PREFIX}_{i}.png")
    # 缩略图:统一高度 160
    th = 160
    tw = max(1, round((x1-x0) * th / (y1-y0)))
    thumbs.append(pim.resize((tw, th), Image.NEAREST))
    print(f"comp {i}: bbox y[{y0},{y1}] x[{x0},{x1}] size {x1-x0}x{y1-y0}")

# 联络表:横排 + 编号
pad = 20
total_w = sum(t.size[0] for t in thumbs) + pad * (len(thumbs)+1)
sheet = Image.new("RGB", (total_w, 160 + pad*2 + 30), (40, 40, 40))
d = ImageDraw.Draw(sheet)
x = pad
for i, t in enumerate(thumbs):
    bg = Image.new("RGBA", t.size, (40, 40, 40, 255))
    bg.alpha_composite(t)
    sheet.paste(bg.convert("RGB"), (x, pad))
    d.text((x + 4, pad + 160 + 6), f"#{i}", fill=(255, 255, 0))
    x += t.size[0] + pad
sheet.save(f"{PREFIX}_contact.png")
print("contact sheet ->", f"{PREFIX}_contact.png")
