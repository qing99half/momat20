# 中景派生(美术正式中景交付前的过渡):从远景真图生成压暗+柔化的中景层,
# 写回 placeholder mid 路径(JSON 引用不变,正式中景交付后直接覆盖同路径即替换)。
# lv3/lv4 双段:b 段比 a 段更暗,让 D-531 接缝切换有可见变化。
from PIL import Image, ImageFilter, ImageEnhance

JOBS = [
    # (远景源, 中景目标, 亮度系数)
    ("assets/placeholder/placeholder_bg_ch1_lv1_far.png", "assets/placeholder/placeholder_bg_ch1_lv1_mid.png", 0.38),
    ("assets/placeholder/placeholder_bg_ch1_lv2_far.png", "assets/placeholder/placeholder_bg_ch1_lv2_mid.png", 0.38),
    ("assets/placeholder/placeholder_bg_ch1_lv3_far.png", "assets/placeholder/placeholder_bg_ch1_lv3_mid_a.png", 0.38),
    ("assets/placeholder/placeholder_bg_ch1_lv3_far.png", "assets/placeholder/placeholder_bg_ch1_lv3_mid_b.png", 0.26),
    ("assets/placeholder/placeholder_bg_ch1_lv4_far.png", "assets/placeholder/placeholder_bg_ch1_lv4_mid_a.png", 0.38),
    ("assets/placeholder/placeholder_bg_ch1_lv4_far.png", "assets/placeholder/placeholder_bg_ch1_lv4_mid_b.png", 0.26),
]

for src, dst, brightness in JOBS:
    im = Image.open(src).convert("RGB")
    im = im.filter(ImageFilter.GaussianBlur(1.5))          # 柔化:比远景清晰、比前景糊
    im = ImageEnhance.Contrast(im).enhance(0.85)           # 压对比,往剪影靠
    im = ImageEnhance.Brightness(im).enhance(brightness)   # 压暗=更近的暗色层
    im.save(dst)
    print("mid <-", src, "->", dst, im.size)
