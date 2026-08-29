"""人工策展最终调色板(11色)并写 style_spec.json + 色卡。
基于 extract_style_spec 的分区统计结果合并近重复色。"""
import json
from pathlib import Path
from PIL import Image, ImageDraw

A = Path("assets/art")

palette = [
    {"name": "hair_dark",     "rgb": [101, 19, 38],   "zone": "head",  "note": "发色最深/轮廓"},
    {"name": "hair_mid",      "rgb": [140, 48, 48],   "zone": "head",  "note": "主发色"},
    {"name": "hair_light",    "rgb": [190, 105, 85],  "zone": "head",  "note": "头发高光"},
    {"name": "eye",           "rgb": [44, 7, 46],     "zone": "head",  "note": "眼睛(近黑紫)"},
    {"name": "skin",          "rgb": [250, 213, 159], "zone": "head",  "note": "面部肤色"},
    {"name": "skin_shadow",   "rgb": [228, 186, 133], "zone": "legs",  "note": "腿部/肤影"},
    {"name": "hoodie",        "rgb": [252, 239, 195], "zone": "torso", "note": "米白帽衫主色"},
    {"name": "hoodie_shadow", "rgb": [202, 157, 118], "zone": "torso", "note": "帽衫阴影"},
    {"name": "shorts",        "rgb": [113, 29, 42],   "zone": "legs",  "note": "棕红短裤"},
    {"name": "shorts_light",  "rgb": [156, 82, 73],   "zone": "legs",  "note": "短裤亮面"},
    {"name": "shoe",          "rgb": [43, 7, 46],     "zone": "shoe",  "note": "黑鞋(与眼同色,允许)"},
]

spec = {
    "version": 1,
    "anchor_frame": "assets/art/char_young_idle_20x20.png",
    "canvas": {"width": 20, "height": 20},
    "baseline": {"feet_y": 19, "rule": "所有帧脚底贴 y=19, 水平居中"},
    "proportions": {
        "bbox": {"w": 18, "h": 18},
        "head_height_px": 9,
        "torso_height_px": 4,
        "leg_height_px": 5,
        "rule": "跨帧按头高 9px 对齐(±1px), 不按整帧 bbox 缩放"
    },
    "palette": palette,
    "palette_rule": "每帧每像素吸附到本 11 色中最近色(RGB 欧氏距离); 不得引入调色板外颜色",
    "qa_gate": {
        "palette_hist_max_dist": 0.15,
        "head_height_tolerance_px": 1,
        "min_opaque_px": 100,
        "max_opaque_px": 260,
        "feet_must_touch_y": 19
    },
    "frame_table": {
        "idle": [0, 3], "run": [4, 9], "walk": [10, 15],
        "jump_up": [16, 17], "fall": [18, 19], "land": [20, 20],
        "dash": [21, 21], "push": [22, 22], "lookback": [23, 23]
    }
}
with open(A / "style_spec.json", "w", encoding="utf-8") as f:
    json.dump(spec, f, ensure_ascii=False, indent=2)

# 色卡: 色块 + 名称 + RGB + 用途
sw, sh = 110, 60
card = Image.new("RGB", (sw * len(palette), sh + 46), (24, 24, 24))
d = ImageDraw.Draw(card)
for i, p in enumerate(palette):
    d.rectangle([i*sw+2, 2, (i+1)*sw-3, sh-2], fill=tuple(p["rgb"]))
    d.text((i*sw+4, sh+2), p["name"], fill=(255, 255, 0))
    d.text((i*sw+4, sh+16), str(tuple(p["rgb"])), fill=(170, 170, 170))
    d.text((i*sw+4, sh+30), p["zone"], fill=(120, 200, 255))
card.save(A / "style_palette_card.png")
print("curated palette:", len(palette), "colors")
print("-> assets/art/style_spec.json + style_palette_card.png")
