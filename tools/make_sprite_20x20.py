"""AI 生图 -> 20×20 像素小人:裁水印/去噪点/取主体/缩放/量化/贴底居中。"""
from pathlib import Path
from PIL import Image
import numpy as np

SRC = Path("assets/art/_ai_char_young_raw2.png")
OUT = Path("assets/art")

img = Image.open(SRC).convert("RGBA")
W, H = img.size
arr = np.asarray(img).copy()
print("source:", img.size, "has alpha:", arr[..., 3].min(), arr[..., 3].max())

# 1. 裁掉左下水印区(底部 8% × 左 25%)直接置透明
arr[int(H*0.92):, : int(W*0.25), 3] = 0

# 2. 主体 mask:alpha>128
mask = arr[..., 3] > 128

# 3. 去零星噪点:保留最大连通域( scipy 不在依赖里,用简单行列投影+bbox 即可,
#    闪光碎点很小,先按 bbox 收,再清掉远离主体的碎点)
ys, xs = np.where(mask)
x0, x1, y0, y1 = xs.min(), xs.max()+1, ys.min(), ys.max()+1
print("bbox:", x0, y0, x1, y1, "size:", x1-x0, y1-y0)

sub = arr[y0:y1, x0:x1].copy()
sub_mask = mask[y0:y1, x0:x1]

# 4. 清碎点:对每个不透明像素,若 5x5 邻域内不透明像素<4 则视为噪点
from collections import deque
m = sub_mask.copy()
h, w = m.shape
visited = np.zeros_like(m, dtype=bool)
best = None
for sy in range(h):
    for sx in range(w):
        if m[sy, sx] and not visited[sy, sx]:
            q = deque([(sy, sx)])
            visited[sy, sx] = True
            comp = []
            while q:
                cy, cx = q.popleft()
                comp.append((cy, cx))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy+dy, cx+dx
                        if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not visited[ny, nx]:
                            visited[ny, nx] = True
                            q.append((ny, nx))
            if best is None or len(comp) > len(best):
                best = comp
keep = np.zeros_like(m)
for (cy, cx) in best:
    keep[cy, cx] = True
removed = int(m.sum() - keep.sum())
print("noise pixels removed:", removed)
sub[~keep] = [0, 0, 0, 0]

# 5. 重新收 bbox(最大连通域)
ys, xs = np.where(keep)
bx0, bx1, by0, by1 = xs.min(), xs.max()+1, ys.min(), ys.max()+1
body = Image.fromarray(sub[by0:by1, bx0:bx1])
bw, bh = body.size
print("body:", body.size)

# 6. 块采样到高 18px:每个目标像素取源图对应块的"中心像素"颜色(保留大像素块的用色意图,
#    不做 LANCZOS 平均,避免糊化);alpha 取块内不透明占比>40%
tw = max(1, round(bw * 18 / bh))
th = 18
sa = np.zeros((th, tw, 4), dtype=np.uint8)
src = np.asarray(body)
for ty in range(th):
    for tx in range(tw):
        ry0, ry1 = int(ty*bh/th), max(int((ty+1)*bh/th), int(ty*bh/th)+1)
        rx0, rx1 = int(tx*bw/tw), max((int((tx+1)*bw/tw)), int(tx*bw/tw)+1)
        block = src[ry0:ry1, rx0:rx1]
        a = block[..., 3]
        opaque = block[a > 128]
        if len(opaque) / block.shape[0] / block.shape[1] > 0.4:
            # 取块内不透明像素的中位色
            med = np.median(opaque[..., :3], axis=0).astype(np.uint8)
            sa[ty, tx] = [med[0], med[1], med[2], 255]
        else:
            sa[ty, tx] = [0, 0, 0, 0]

# 7. 颜色量化(24 色,仅不透明区域参与)
alpha = sa[..., 3]
rgb_img = Image.fromarray(sa[..., :3])
mask_arr = alpha > 0
if mask_arr.sum() > 0:
    q = rgb_img.quantize(colors=24, method=Image.MEDIANCUT).convert("RGB")
    qa = np.asarray(q).copy()
    qa[~mask_arr] = 0
else:
    qa = sa[..., :3]
sprite = Image.fromarray(np.dstack([qa, alpha]), "RGBA")

# 8. 放入 20×20,脚底贴底,水平居中
canvas = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
canvas.paste(sprite, ((20 - tw)//2, 20 - th), sprite)
canvas.save(OUT / "char_young_idle_20x20.png")

# 9. 预览:16x 最近邻 + 深灰底
prev = canvas.resize((320, 320), Image.NEAREST)
bgp = Image.new("RGB", (320, 320), (64, 64, 64))
bgp.paste(prev, (0, 0), prev)
bgp.save(OUT / "char_young_idle_20x20_preview.png")
print("done -> assets/art/char_young_idle_20x20.png", "sprite size:", tw, "x", th)
