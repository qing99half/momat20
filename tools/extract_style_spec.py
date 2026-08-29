"""风格规格 v2:按身体分区提取语义调色板(头/躯干/腿/鞋),合并近重复色。"""
import json
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

A = Path("assets/art")
arr = np.asarray(Image.open(A / "char_young_idle_20x20.png").convert("RGBA")).copy()
op = arr[..., 3] > 0
ys_all, xs_all = np.where(op)
y_top, y_bot = int(ys_all.min()), int(ys_all.max())
bbox_h = y_bot - y_top + 1

# 分区(按 bbox 比例):头 0~45% / 躯干 45~72% / 短裤腿 72~90% / 鞋 90~100%
def region(y): 
    t = (y - y_top) / bbox_h
    return "head" if t < 0.45 else "torso" if t < 0.72 else "legs" if t < 0.90 else "shoe"

zones = {"head": [], "torso": [], "legs": [], "shoe": []}
for y in range(y_top, y_bot + 1):
    for x in range(20):
        if op[y, x]:
            zones[region(y)].append((tuple(arr[y, x, :3]), x, y))

# 区内聚类:贪心合并,色距<35 归一簇
def cluster(pixels, thresh=35):
    clusters = []
    for rgb, x, y in pixels:
        c = np.array(rgb, dtype=float)
        placed = False
        for cl in clusters:
            if np.linalg.norm(c - cl["center"]) < thresh:
                cl["pixels"].append((rgb, x, y))
                cl["center"] = np.mean([np.array(p[0], dtype=float) for p in cl["pixels"]], axis=0)
                placed = True
                break
        if not placed:
            clusters.append({"center": c, "pixels": [(rgb, x, y)]})
    clusters.sort(key=lambda cl: -len(cl["pixels"]))
    return clusters

def lum(c): return float(np.mean(c))

palette = []
for zone, pixels in zones.items():
    for cl in cluster(pixels):
        c = cl["center"]
        n = len(cl["pixels"])
        if n < 2:
            continue
        xs = [p[1] for p in cl["pixels"]]; ys = [p[2] for p in cl["pixels"]]
        if zone == "head":
            # 深色小簇且位于面部左侧 -> 眼; 亮色 -> 肤; 红棕 -> 发
            if lum(c) < 90 and n <= 8:
                name = "eye"
            elif lum(c) > 180:
                name = "skin" if lum(c) < 235 else "skin_hi"
            else:
                name = "hair_dark" if lum(c) < 130 else "hair_light"
        elif zone == "torso":
            name = "hoodie" if lum(c) > 190 else "hoodie_shadow"
        elif zone == "legs":
            name = "skin_shadow" if lum(c) > 180 else "shorts"
        else:
            name = "shoe"
        palette.append({
            "name": name, "zone": zone,
            "rgb": [int(round(v)) for v in c],
            "count": n,
            "y_range": [min(ys), max(ys)],
        })

# 同名去重(保留大的,其余加序号)
seen = {}
for p in palette:
    n = p["name"]
    if n in seen:
        seen[n] += 1
        p["name"] = f"{n}_{seen[n]}"
    else:
        seen[n] = 1

# 比例度量:头高=头区高度,头宽=头区最大行宽
head_rows = [y for y in range(y_top, y_bot+1) if region(y) == "head"]
head_h = len(head_rows)
head_w = max(int(op[y].sum()) for y in head_rows)
torso_rows = [y for y in range(y_top, y_bot+1) if region(y) == "torso"]
leg_rows = [y for y in range(y_top, y_bot+1) if region(y) in ("legs", "shoe")]

spec = {
    "anchor_frame": "assets/art/char_young_idle_20x20.png",
    "canvas": {"width": 20, "height": 20},
    "baseline": {"feet_y": 19, "rule": "所有帧脚底贴 y=19,水平居中"},
    "proportions": {
        "bbox": {"w": int(xs_all.max()-xs_all.min()+1), "h": bbox_h},
        "head_height_px": head_h, "head_width_px": head_w,
        "torso_height_px": len(torso_rows), "leg_height_px": len(leg_rows),
        "rule": "跨帧按头高对齐(±1px),不按整帧 bbox 缩放"
    },
    "palette": palette,
    "palette_rule": "每帧每像素吸附到本调色板最近色(RGB 欧氏距离);不得引入调色板外颜色",
    "qa_gate": {
        "palette_hist_max_dist": 0.15,
        "head_height_tolerance_px": 1,
        "min_opaque_px": 100, "max_opaque_px": 260
    },
    "frame_table": {
        "idle": [0, 3], "run": [4, 9], "walk": [10, 15],
        "jump_up": [16, 17], "fall": [18, 19], "land": [20, 20],
        "dash": [21, 21], "push": [22, 22], "lookback": [23, 23]
    }
}
with open(A / "style_spec.json", "w", encoding="utf-8") as f:
    json.dump(spec, f, ensure_ascii=False, indent=2)

# 色卡:按 区分组排列
zone_order = ["head", "torso", "legs", "shoe"]
ordered = [p for z in zone_order for p in palette if p["zone"] == z]
sw, sh = 90, 70
card = Image.new("RGB", (sw * len(ordered), sh + 34), (30, 30, 30))
d = ImageDraw.Draw(card)
for i, p in enumerate(ordered):
    d.rectangle([i*sw, 0, (i+1)*sw-1, sh-1], fill=tuple(p["rgb"]))
    d.text((i*sw+3, sh+2), p["name"][:12], fill=(255, 255, 0))
    d.text((i*sw+3, sh+16), str(tuple(p["rgb"])), fill=(180, 180, 180))
card.save(A / "style_palette_card.png")

for p in ordered:
    print(f"  [{p['zone']:>5}] {p['name']:>14}: rgb{tuple(p['rgb'])} n={p['count']} y{p['y_range']}")
print(f"proportions: head {head_h}h/{head_w}w, torso {len(torso_rows)}px, legs {len(leg_rows)}px, bbox {spec['proportions']['bbox']}")
print("-> assets/art/style_spec.json + style_palette_card.png")
