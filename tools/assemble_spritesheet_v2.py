"""组装 v2 最终精灵表 char_young_spritesheet.png (480×20, 24帧)。
帧序: 待机0~3 / 跑4~9 / 慢走10~15 / 跳升16~17 / 下落18~19 / 落地20 / 冲刺21 / 推门22 / 回头看23
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

A = Path("assets/art/char-young/strips")
OUT = Path("assets/art/char-young")

def strip_frames(name, n):
    s = np.asarray(Image.open(A / name).convert("RGBA"))
    # 条带素材原始朝向=左;游戏约定基准帧朝右(代码 flip_h = dir<0 时镜像为左),逐帧水平翻转
    return [s[:, i*20:(i+1)*20][:, ::-1].copy() for i in range(n)]

idle = strip_frames("char_young_idle_v2_strip.png", 3)
run = strip_frames("char_young_run_v2_strip.png", 6)
walk = strip_frames("char_young_walk_v2_strip.png", 6)
jump = strip_frames("char_young_jump_up_v2_strip.png", 2)
fall = strip_frames("char_young_fall_v2_strip.png", 2)
land = strip_frames("char_young_land_v2_strip.png", 1)
dash = strip_frames("char_young_dash_v2_strip.png", 1)
push = strip_frames("char_young_push_v2_strip.png", 1)
look = strip_frames("char_young_lookback_v2_strip.png", 1)

frames = [idle[0], idle[1], idle[2], idle[1]] + run + walk + jump + fall + land + dash + push + look
assert len(frames) == 24, len(frames)

sheet = np.zeros((20, 480, 4), dtype=np.uint8)
for i, f in enumerate(frames):
    sheet[:, i*20:(i+1)*20] = f
Image.fromarray(sheet, "RGBA").save(OUT / "char_young_spritesheet.png")

# 标签预览条
sc = 8
prev = Image.fromarray(sheet, "RGBA").resize((480*sc, 20*sc), Image.NEAREST)
bgp = Image.new("RGB", prev.size, (64, 64, 64))
bgp.paste(prev, (0, 0), prev)
d = ImageDraw.Draw(bgp)
labels = ["id0","id1","id2","id3","r0","r1","r2","r3","r4","r5","w0","w1","w2","w3","w4","w5","j0","j1","f0","f1","ld","ds","ps","lb"]
for i, lb in enumerate(labels):
    d.line([(i*20*sc, 0), (i*20*sc, 20*sc)], fill=(30, 30, 30))
    d.text((i*20*sc+2, 2), lb, fill=(255, 255, 0))
bgp.save(OUT / "previews" / "char_young_spritesheet_preview.png")

# 全帧 QA
spec = json.load(open(OUT / "style_spec.json", encoding="utf-8"))
PAL = np.array([p["rgb"] for p in spec["palette"]], dtype=float)
print("final QA:")
all_ok = True
for i in range(24):
    f = sheet[:, i*20:(i+1)*20]
    op = f[..., 3] > 0
    n = int(op.sum())
    cols = np.unique(f[op][:, :3], axis=0)
    in_pal = all(any((c == p).all() for p in PAL) for c in cols)
    ys = np.where(op)[0]
    feet = ys.max() in (18, 19) if len(ys) else False
    ok = 100 <= n <= 260 and in_pal and feet
    all_ok &= ok
    print(f"  f{i:02d} {labels[i]:>3}: opaque={n:3d} palette={'OK' if in_pal else 'NG'} feet={'OK' if feet else 'NG'} -> {'PASS' if ok else 'CHECK'}")
print("ALL PASS" if all_ok else "some frames need review")
print("-> assets/art/char_young_spritesheet.png (480x20)")
