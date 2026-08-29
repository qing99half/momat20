"""第2级批处理:选定连通域 -> 共享缩放块采样 -> 基线对齐 -> 11色吸附 -> QA评分 -> 拼条。
用法: python tools/batch_frames_v2.py <输出前缀> <comp前缀> <comp编号...>
例: python tools/batch_frames_v2.py assets/art/char_young_run_v2 assets/art/_runv2_comp 1 2 3 4 5 9
"""
import sys, json
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

PREFIX = sys.argv[1]
COMP_PREFIX = sys.argv[2]
COMPS = [int(x) for x in sys.argv[3:]]

spec = json.load(open("assets/art/style_spec.json", encoding="utf-8"))
PAL = np.array([p["rgb"] for p in spec["palette"]], dtype=float)
HEAD_H = spec["proportions"]["head_height_px"]  # 9
BODY_H = 18  # 锚帧总高

# 载入组件
frames_src = []
for c in COMPS:
    arr = np.asarray(Image.open(f"{COMP_PREFIX}_{c}.png").convert("RGBA")).copy()
    mask = arr[..., 3] > 20
    ys, xs = np.where(mask)
    arr = arr[ys.min():ys.max()+1, xs.min():xs.max()+1]
    frames_src.append(arr)
    print(f"comp {c}: {arr.shape[1]}x{arr.shape[0]}")

# 共享缩放:以各帧内容高度的中位数 -> 18px(同批次 AI 尺度一致,用中位数抗异常)
heights = [f.shape[0] for f in frames_src]
scale = BODY_H / np.median(heights)
print("shared scale:", round(scale, 4), "median_h:", np.median(heights))

out_frames = []
snap_dists = []
for i, f in enumerate(frames_src):
    fh, fw = f.shape[:2]
    tw = max(1, round(fw * scale))
    th = max(1, round(fh * scale))
    th = min(th, 20)
    sa = np.zeros((th, tw, 4), dtype=np.uint8)
    for ty in range(th):
        for tx in range(tw):
            ry0, ry1 = int(ty*fh/th), max(int((ty+1)*fh/th), int(ty*fh/th)+1)
            rx0, rx1 = int(tx*fw/tw), max(int((tx+1)*fw/tw), int(tx*fw/tw)+1)
            block = f[ry0:ry1, rx0:rx1]
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
    # 阴影残留检测:底行宽度显著超过其上一行 -> 剔除超出的列(地面阴影线规则)
    for _ in range(2):  # 最多清两层
        rowy = 19 if _ == 0 else 18
        above_y = rowy - 1
        cur = np.where(canvas[rowy, :, 3] > 0)[0]
        abv = np.where(canvas[above_y, :, 3] > 0)[0]
        if len(cur) >= 6 and len(abv) and len(cur) > len(abv) + 3:
            lo, hi = abv.min(), abv.max()
            for x in cur:
                if not (lo <= x <= hi):
                    canvas[rowy, x] = [0, 0, 0, 0]
            print(f"  frame {i}: shadow residue cleaned at y={rowy}")
    # 11 色吸附(先记吸附距离: 原色到最近板色的平均距离, 越小=AI用色越贴板)
    op = canvas[..., 3] > 0
    snap_dist = 0.0
    if op.sum():
        pxv = canvas[..., :3].astype(float)
        d = ((pxv[:, :, None, :] - PAL[None, None, :, :]) ** 2).sum(axis=3) ** 0.5
        amin = d.argmin(axis=2)
        snap_dist = float(np.take_along_axis(d, amin[..., None], axis=2)[op].mean())
        canvas[..., :3] = np.where(op[..., None], PAL[amin].astype(np.uint8), 0)
    out_frames.append(canvas)
    snap_dists.append(snap_dist)

# QA:吸附距离(姿态无关的保色度) + 不透明像素数 + 贴底检查
print("\nQA (snap_dist=原色到板色平均距离, <40 为贴板):")
for i, canvas in enumerate(out_frames):
    op = canvas[..., 3] > 0
    n = int(op.sum())
    ok_n = spec["qa_gate"]["min_opaque_px"] <= n <= spec["qa_gate"]["max_opaque_px"]
    sd = snap_dists[i]
    ok_c = sd < 40
    ys3 = np.where(op)[0]
    feet = ys3.max() == 19 if len(ys3) else False
    print(f"  f{i}: opaque={n:3d} {'OK' if ok_n else 'NG'}  snap_dist={sd:5.1f} {'OK' if ok_c else 'NG'}  feet@19 {'OK' if feet else 'NG'}")

# 拼条 + 预览 + GIF
strip = np.zeros((20, 20*len(out_frames), 4), dtype=np.uint8)
for i, c in enumerate(out_frames):
    strip[:, i*20:(i+1)*20] = c
Image.fromarray(strip, "RGBA").save(f"{PREFIX}_strip.png")

sc = 12
prev = Image.fromarray(strip, "RGBA").resize((20*len(out_frames)*sc, 20*sc), Image.NEAREST)
bgp = Image.new("RGB", prev.size, (64, 64, 64))
bgp.paste(prev, (0, 0), prev)
bgp.save(f"{PREFIX}_strip_preview.png")

gifs = []
for c in out_frames:
    big = Image.fromarray(c, "RGBA").resize((240, 240), Image.NEAREST)
    bgf = Image.new("RGB", (240, 240), (64, 64, 64))
    bgf.paste(big, (0, 0), big)
    gifs.append(bgf)
gifs[0].save(f"{PREFIX}_preview.gif", save_all=True, append_images=gifs[1:], duration=120, loop=0)
print("done ->", f"{PREFIX}_strip.png")
