"""老年母亲调色板(12色) -> assets/art/char-old/char_old_style_spec.json + 色卡。
基于 _old_idle_raw.png 高分辨率生图 MEDIANCUT 聚类策展。"""
import json
from pathlib import Path
from PIL import Image, ImageDraw

A = Path("assets/art/char-old")

palette = [
    {"name": "outline",       "rgb": [10, 10, 12],    "zone": "all",   "note": "近黑轮廓"},
    {"name": "hair_dark",     "rgb": [43, 38, 36],    "zone": "head",  "note": "发色最深"},
    {"name": "hair_mid",      "rgb": [63, 52, 46],    "zone": "head",  "note": "主发色"},
    {"name": "hair_light",    "rgb": [97, 83, 68],    "zone": "head",  "note": "发髻高光"},
    {"name": "eye",           "rgb": [10, 10, 12],    "zone": "head",  "note": "眼睛(与轮廓同色,允许)"},
    {"name": "skin",          "rgb": [244, 219, 173], "zone": "head",  "note": "面部肤色"},
    {"name": "skin_shadow",   "rgb": [204, 174, 143], "zone": "head",  "note": "肤影"},
    {"name": "skin_deep",     "rgb": [119, 91, 72],   "zone": "torso", "note": "手部/深肤影"},
    {"name": "shirt",         "rgb": [146, 157, 159], "zone": "torso", "note": "灰蓝工装衬衫主色"},
    {"name": "shirt_shadow",  "rgb": [84, 95, 102],   "zone": "torso", "note": "衬衫阴影"},
    {"name": "pants",         "rgb": [70, 66, 61],    "zone": "legs",  "note": "深灰长裤"},
    {"name": "shoe",          "rgb": [10, 10, 12],    "zone": "shoe",  "note": "黑鞋(与轮廓同色,允许)"},
]

spec = {
    "version": 1,
    "anchor_frame": "assets/art/char-old/char_old_idle_20x20.png",
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
    "palette_rule": "每帧每像素吸附到本 12 色中最近色(RGB 欧氏距离); 不得引入调色板外颜色",
    "qa_gate": {
        "head_height_tolerance_px": 1,
        "min_opaque_px": 80,
        "max_opaque_px": 260,
        "feet_must_touch_y": 19
    },
    "frame_table": {
        "walk": [0, 5], "push": [6, 6], "lookback": [7, 7]
    }
}
with open(A / "char_old_style_spec.json", "w", encoding="utf-8") as f:
    json.dump(spec, f, ensure_ascii=False, indent=2)

sw, sh = 110, 60
card = Image.new("RGB", (sw * len(palette), sh + 46), (24, 24, 24))
d = ImageDraw.Draw(card)
for i, p in enumerate(palette):
    d.rectangle([i*sw+2, 2, (i+1)*sw-3, sh-2], fill=tuple(p["rgb"]))
    d.text((i*sw+4, sh+2), p["name"], fill=(255, 255, 0))
    d.text((i*sw+4, sh+16), str(tuple(p["rgb"])), fill=(170, 170, 170))
    d.text((i*sw+4, sh+30), p["zone"], fill=(120, 200, 255))
card.save(A / "char_old_palette_card.png")
print("curated palette:", len(palette), "colors")
print("-> assets/art/char-old/char_old_style_spec.json + char_old_palette_card.png")
