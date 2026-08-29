# 占位素材批量放大到 20px 格体系(一次性迁移工具,跑完可删)
# 规则:UI(窗口空间)/LUT/HUD碎片 不动;角色按 20×20 帧重做;背景按新视野规格;其余 ×2.5。
from PIL import Image
import glob, os

D = "assets/placeholder"
special = {
    "placeholder_char_young_spritesheet.png": (480, 20),   # 24帧×20×20(主角新基准)
    "placeholder_char_old_mother.png": (160, 20),          # 8帧×20×20
    "placeholder_bg_ch3_far.png": (2000, 180),
    "placeholder_bg_ch3_mid.png": (1000, 180),
}
skip_kw = ["ui_", "lut_"]  # 窗口空间/格式固定

for f in sorted(glob.glob(f"{D}/*.png")):
    name = os.path.basename(f)
    if any(k in name for k in skip_kw):
        print(f"跳过(窗口空间): {name}")
        continue
    img = Image.open(f)
    if name in special:
        size = special[name]
    elif name.startswith("placeholder_bg_"):
        # 一章背景:lv3/lv4 far 是长图(渐变),其余 800×180
        w = 1280 if ("lv3_far" in name or "lv4_far" in name) else 800
        size = (w, 180)
    else:
        size = (round(img.width * 2.5), round(img.height * 2.5))
    img.resize(size, Image.NEAREST).save(f)
    print(f"{name}: {img.width}×{img.height} -> {size[0]}×{size[1]}")
print("完成")
