"""组装年轻通用体 24 帧完整精灵表 480×20。
帧序(动作表): 待机0~3 / 跑4~9 / 慢走10~15 / 跳升16~17 / 下落18~19 / 落地20 / 冲刺21 / 推门22 / 回头看23
"""
from pathlib import Path
from PIL import Image
import numpy as np

A = Path("assets/art")
TH = 18  # 内容目标高度

def block_sample(arr, th=TH):
    """RGBA ndarray -> 20×20 画布 ndarray,块采样+底对齐+量化。"""
    h, w = arr.shape[:2]
    mask = arr[..., 3] > 20
    ys, xs = np.where(mask)
    arr = arr[ys.min():ys.max()+1, xs.min():xs.max()+1]
    h, w = arr.shape[:2]
    tw = max(1, round(w * th / h))
    sa = np.zeros((th, tw, 4), dtype=np.uint8)
    for ty in range(th):
        for tx in range(tw):
            ry0, ry1 = int(ty*h/th), max(int((ty+1)*h/th), int(ty*h/th)+1)
            rx0, rx1 = int(tx*w/tw), max(int((tx+1)*w/tw), int(tx*w/tw)+1)
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
        canvas[:shift] = 0 if shift > 0 else canvas[:0]
    alpha = canvas[..., 3]
    q = Image.fromarray(canvas[..., :3]).quantize(colors=20, method=Image.MEDIANCUT).convert("RGB")
    qa = np.asarray(q).copy()
    qa[alpha == 0] = 0
    return np.dstack([qa, alpha])

def load(p):
    return np.asarray(Image.open(p).convert("RGBA")).copy()

frames = {}

# 帧0: 已有的待机(raw2 块采样成品)
frames[0] = np.asarray(Image.open(A / "char_young_idle_20x20.png").convert("RGBA")).copy()

# 帧1~3: 待机呼吸相位 #0 #1 #2
for slot, comp in [(1, 0), (2, 1), (3, 2)]:
    frames[slot] = block_sample(load(A / f"_misc_comp_{comp}.png"))

# 帧4~9: 跑步条
run = np.asarray(Image.open(A / "char_young_run_strip.png").convert("RGBA"))
for i in range(6):
    frames[4+i] = run[:, i*20:(i+1)*20].copy()

# 帧10~15: 慢走条
walk = np.asarray(Image.open(A / "char_young_walk_strip.png").convert("RGBA"))
for i in range(6):
    frames[10+i] = walk[:, i*20:(i+1)*20].copy()

# 帧16~17: 跳升(腾空抱膝) #3 #4
frames[16] = block_sample(load(A / "_misc_comp_3.png"))
frames[17] = block_sample(load(A / "_misc_comp_4.png"))

# 帧18~19: 下落(腿伸直) #5 #8
frames[18] = block_sample(load(A / "_misc_comp_5.png"))
frames[19] = block_sample(load(A / "_misc_comp_9.png"))

# 帧20: 落地微蹲 #10
frames[20] = block_sample(load(A / "_misc_comp_10.png"))

# 帧21: 冲刺前倾 #11
frames[21] = block_sample(load(A / "_misc_comp_11.png"))

# 帧22: 推门双手前伸 #7
frames[22] = block_sample(load(A / "_misc_comp_7.png"))

# 帧23: 回头看 = #12 身体不动 + 头部水平翻转
look = block_sample(load(A / "_misc_comp_12.png"))
HEAD_ROWS = 8  # 头部约占顶部 8 行
head = look[:HEAD_ROWS, :, :]
look[:HEAD_ROWS, :, :] = head[:, ::-1, :]
frames[23] = look

# 拼 480×20
sheet = np.zeros((20, 480, 4), dtype=np.uint8)
for i in range(24):
    sheet[:, i*20:(i+1)*20] = frames[i]
Image.fromarray(sheet, "RGBA").save(A / "char_young_spritesheet.png")

# 预览条 8x + 分隔线
sc = 8
prev = Image.fromarray(sheet, "RGBA").resize((480*sc, 20*sc), Image.NEAREST)
bgp = Image.new("RGB", prev.size, (64, 64, 64))
bgp.paste(prev, (0, 0), prev)
from PIL import ImageDraw
d = ImageDraw.Draw(bgp)
for i in range(25):
    d.line([(i*20*sc, 0), (i*20*sc, 20*sc)], fill=(30, 30, 30))
labels = ["id0","id1","id2","id3","r0","r1","r2","r3","r4","r5","w0","w1","w2","w3","w4","w5","j0","j1","f0","f1","ld","ds","ps","lb"]
for i, lb in enumerate(labels):
    d.text((i*20*sc+2, 2), lb, fill=(255, 255, 0))
bgp.save(A / "char_young_spritesheet_preview.png")

# 验收打印
for i in range(24):
    f = sheet[:, i*20:(i+1)*20]
    op = f[f[..., 3] > 0]
    ys = np.where(f[..., 3] > 0)[0]
    print(f"f{i:02d} {labels[i]:>3}: opaque={len(op):3d} colors={len(np.unique(op[:,:3],axis=0)):2d} y=[{ys.min()},{ys.max()}]")
print("done -> assets/art/char_young_spritesheet.png (480x20)")
