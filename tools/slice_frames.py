"""横排生图 -> 逐帧 20×20 -> 拼条 + GIF 预览。
用法: python tools/slice_frames.py <输入.png> <帧数> <输出前缀>
"""
import sys
from pathlib import Path
from PIL import Image
import numpy as np

SRC = Path(sys.argv[1])
N = int(sys.argv[2])
PREFIX = sys.argv[3]  # 如 assets/art/char_young_run

img = Image.open(SRC).convert("RGBA")
W, H = img.size
arr = np.asarray(img).copy()

# 1. 清左下水印区
arr[int(H*0.90):, : int(W*0.22), 3] = 0

# 2. 全局 mask 与总 bbox(alpha>20 即算内容:AI 会把深色眼睛画成半透明,阈值太高会挖洞)
mask = arr[..., 3] > 20
ys, xs = np.where(mask)
gx0, gx1, gy0, gy1 = xs.min(), xs.max()+1, ys.min(), ys.max()+1
print("global bbox:", gx0, gy0, gx1, gy1, "size:", gx1-gx0, gy1-gy0)

# 3. 均分 N 列,逐列取内容
cell_w = (gx1 - gx0) / N
frames = []
for i in range(N):
    cx0, cx1 = int(gx0 + i*cell_w), int(gx0 + (i+1)*cell_w)
    cmask = mask[gy0:gy1, cx0:cx1]
    ys2, xs2 = np.where(cmask)
    if len(ys2) == 0:
        print(f"frame {i}: EMPTY!")
        continue
    fx0, fx1 = xs2.min(), xs2.max()+1
    fy0, fy1 = ys2.min(), ys2.max()+1
    cell_arr = arr[gy0+fy0:gy0+fy1, cx0+fx0:cx0+fx1].copy()
    # 只保留最大连通域,清除闪光碎点
    m = cell_arr[..., 3] > 20
    ch, cw0 = m.shape
    visited = np.zeros_like(m, dtype=bool)
    best = []
    from collections import deque
    for sy in range(ch):
        for sx in range(cw0):
            if m[sy, sx] and not visited[sy, sx]:
                q = deque([(sy, sx)]); visited[sy, sx] = True; comp = []
                while q:
                    cy, cx = q.popleft(); comp.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy+dy, cx+dx
                            if 0 <= ny < ch and 0 <= nx < cw0 and m[ny, nx] and not visited[ny, nx]:
                                visited[ny, nx] = True; q.append((ny, nx))
                if len(comp) > len(best):
                    best = comp
    keep = np.zeros_like(m)
    for (cy, cx) in best:
        keep[cy, cx] = True
    cell_arr[~keep] = [0, 0, 0, 0]
    frames.append(cell_arr)
    print(f"frame {i}: cell x[{cx0},{cx1}] content {fx1-fx0}x{fy1-fy0}")

# 4. 统一缩放:以最"高"的帧定比例,所有帧同比例缩到高<=18,保持跨帧尺度一致
max_h = max(f.shape[0] for f in frames)
scale = 18 / max_h
out_frames = []
for i, f in enumerate(frames):
    fh, fw = f.shape[:2]
    tw = max(1, round(fw * scale))
    th = max(1, round(fh * scale))
    # 块采样
    sa = np.zeros((th, tw, 4), dtype=np.uint8)
    for ty in range(th):
        for tx in range(tw):
            ry0, ry1 = int(ty*fh/th), max(int((ty+1)*fh/th), int(ty*fh/th)+1)
            rx0, rx1 = int(tx*fw/tw), max(int((tx+1)*fw/tw), int(tx*fw/tw)+1)
            block = f[ry0:ry1, rx0:rx1]
            a = block[..., 3]
            content = block[a > 20]
            # 覆盖率按 alpha 总量算,半透明眼睛也能撑起一个像素
            if len(content) > 0 and a.mean() / 255 > 0.35:
                med = np.median(content[..., :3], axis=0).astype(np.uint8)
                sa[ty, tx] = [med[0], med[1], med[2], 255]
    # 放入 20×20,脚底贴底,水平居中
    canvas = np.zeros((20, 20, 4), dtype=np.uint8)
    px = (20 - tw) // 2
    py = 20 - th
    # 防越界裁剪
    sx0 = max(0, -px); dx0 = max(0, px)
    cw = min(tw - sx0, 20 - dx0)
    if py < 0:
        sa = sa[-py:, :, :]
        py = 0
    canvas[py:py+sa.shape[0], dx0:dx0+cw] = sa[:, sx0:sx0+cw]
    # 底基线对齐:内容实际底部贴到 y=19(阴影等低覆盖率块被丢弃后会留下悬空)
    ys3 = np.where(canvas[..., 3] > 0)[0]
    if len(ys3):
        shift = 19 - ys3.max()
        if shift != 0:
            canvas = np.roll(canvas, shift, axis=0)
            if shift > 0:
                canvas[:shift] = 0
            else:
                canvas[shift:] = 0
    # 量化到 20 色,压掉近重复色
    alpha = canvas[..., 3]
    qimg = Image.fromarray(canvas[..., :3]).quantize(colors=20, method=Image.MEDIANCUT).convert("RGB")
    qa = np.asarray(qimg).copy()
    qa[alpha == 0] = 0
    canvas = np.dstack([qa, alpha])
    out_frames.append(Image.fromarray(canvas, "RGBA"))
    out_frames[-1].save(f"{PREFIX}_f{i}.png")

# 5. 拼条 N*20 × 20
strip = Image.new("RGBA", (20*len(out_frames), 20), (0, 0, 0, 0))
for i, fr in enumerate(out_frames):
    strip.paste(fr, (i*20, 0), fr)
strip.save(f"{PREFIX}_strip.png")

# 6. 预览:整条 12x 最近邻 + GIF
scale_p = 12
prev = strip.resize((20*len(out_frames)*scale_p, 20*scale_p), Image.NEAREST)
bgp = Image.new("RGB", prev.size, (64, 64, 64))
bgp.paste(prev, (0, 0), prev)
bgp.save(f"{PREFIX}_strip_preview.png")

gif_frames = []
for fr in out_frames:
    big = fr.resize((240, 240), Image.NEAREST)
    bgf = Image.new("RGB", (240, 240), (64, 64, 64))
    bgf.paste(big, (0, 0), big)
    gif_frames.append(bgf)
gif_frames[0].save(f"{PREFIX}_preview.gif", save_all=True, append_images=gif_frames[1:],
                   duration=120, loop=0)
print("done ->", f"{PREFIX}_strip.png", "+", len(out_frames), "frames + GIF")
