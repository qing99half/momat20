# -*- coding: utf-8 -*-
# 生成 assets/placeholder/ 下的全部图片占位资源(任务0.1b, 附录E)
# 尺寸/颜色严格对齐策划案;真素材到位后统一改 AssetPaths.gd 常量替换。
import os
from PIL import Image, ImageDraw, ImageFont

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "placeholder")
os.makedirs(BASE, exist_ok=True)

# 颜色
RED = (0xF4, 0x43, 0x36)      # 危险红 F44336(致死陷阱)
ORANGE = (0xFF, 0x98, 0x00)   # 不致死橙 FF9800
YELLOW = (0xFF, 0xD7, 0x00)   # 亮黄 FFD700(年轻角色)
BROWN = (0x8B, 0x73, 0x55)    # 灰褐 8B7355(年迈母亲)
GREEN = (0x4C, 0xAF, 0x50)    # 亮绿 4CAF50
PINK = (0xE9, 0x1E, 0x63)     # 粉 E91E63
AMBER = (0xFF, 0xC1, 0x07)    # 黄 FFC107(道具交互)
WHITE = (0xFF, 0xFF, 0xFF)
BLACK = (0x00, 0x00, 0x00)

def _font(px):
    try:
        return ImageFont.load_default(px if px >= 11 else 11)
    except Exception:
        return ImageFont.load_default()

def solid(name, w, h, color, label=None):
    img = Image.new("RGBA", (w, h), color + (255,))
    if label and w >= 16 and h >= 12:
        d = ImageDraw.Draw(img)
        try:
            d.text((1, 1), label, fill=BLACK + (255,), font=_font(min(max(h // 2, 8), 16)))
        except Exception:
            pass
    p = os.path.join(BASE, name)
    img.save(p)
    print("ok", name, w, h)

def gradient(name, w, h, c1, c2):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for x in range(w):
        t = x / max(w - 1, 1)
        c = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
        d.line([(x, 0), (x, h)], fill=c)
    img.convert("RGBA").save(os.path.join(BASE, name))
    print("ok", name, w, h, "gradient")

# ---------- 角色(2) ----------
def spritesheet(name, w, h, frames, color, mark):
    img = Image.new("RGBA", (w, h), color + (255,))
    d = ImageDraw.Draw(img)
    fw = w // frames
    for i in range(frames):
        cx = i * fw + fw // 2
        cy = h // 2
        d.line([(cx - 3, cy), (cx + 3, cy)], fill=BLACK + (255,))
        d.line([(cx, cy - 3), (cx, cy + 3)], fill=BLACK + (255,))
    img.save(os.path.join(BASE, name))
    print("ok", name, w, h)

spritesheet("placeholder_char_young_spritesheet.png", 576, 24, 24, YELLOW, "+")
spritesheet("placeholder_char_old_mother.png", 192, 24, 8, BROWN, "+")

# ---------- 平台地形(3) ----------
solid("placeholder_tile_platform.png", 8, 8, GREEN)
img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.line([(2, 8), (14, 8)], fill=(255, 255, 255, 128))
d.line([(8, 2), (8, 14)], fill=(255, 255, 255, 128))
img.save(os.path.join(BASE, "placeholder_tile_crack.png"))
print("ok placeholder_tile_crack.png 16 16")
solid("placeholder_platform_rotten.png", 16, 8, PINK)

# ---------- 陷阱(12) ----------
solid("placeholder_trap_pendulum.png", 16, 48, RED)
solid("placeholder_trap_washboard.png", 24, 8, RED)
solid("placeholder_trap_conveyor.png", 64, 8, ORANGE)
solid("placeholder_trap_part.png", 24, 8, RED)
solid("placeholder_trap_press.png", 16, 16, RED)
solid("placeholder_trap_thorns.png", 24, 8, RED)
solid("placeholder_trap_heart_big.png", 24, 24, RED)
solid("placeholder_trap_droplet.png", 8, 8, RED)
solid("placeholder_trap_bottle.png", 8, 8, RED)
solid("placeholder_trap_soundwave.png", 24, 16, RED)
solid("placeholder_trap_glass.png", 24, 8, RED)
solid("placeholder_trap_billwind.png", 8, 12, ORANGE)

# ---------- 道具(5) ----------
solid("placeholder_prop_lamp.png", 8, 16, AMBER)
solid("placeholder_prop_diary_desk.png", 48, 32, AMBER)
solid("placeholder_prop_cradle.png", 16, 16, AMBER)
solid("placeholder_prop_door_closed.png", 24, 32, AMBER)
solid("placeholder_prop_door_half_open.png", 24, 32, AMBER)

# ---------- 背景(12) 高210 ----------
solid("placeholder_bg_ch1_lv1_far.png", 640, 210, (0x2A, 0x2A, 0x2A))
solid("placeholder_bg_ch1_lv1_mid.png", 640, 210, (0x3A, 0x3A, 0x3A))
solid("placeholder_bg_ch1_lv2_far.png", 640, 210, (0x33, 0x3A, 0x44))
solid("placeholder_bg_ch1_lv2_mid.png", 640, 210, (0x44, 0x4C, 0x57))
gradient("placeholder_bg_ch1_lv3_far.png", 1280, 210, (0xFF, 0x9A, 0x9E), (0x7A, 0x1F, 0x1F))  # 粉->暗红
solid("placeholder_bg_ch1_lv3_mid_a.png", 640, 210, (0x50, 0x30, 0x38))
solid("placeholder_bg_ch1_lv3_mid_b.png", 640, 210, (0x38, 0x26, 0x2C))
gradient("placeholder_bg_ch1_lv4_far.png", 1280, 210, (0xFF, 0xE0, 0x8A), (0x3A, 0x6E, 0xA5))  # 暖黄->冷蓝
solid("placeholder_bg_ch1_lv4_mid_a.png", 640, 210, (0x3C, 0x4A, 0x5A))
solid("placeholder_bg_ch1_lv4_mid_b.png", 640, 210, (0x2E, 0x3A, 0x4C))
gradient("placeholder_bg_ch3_far.png", 1000, 210, (0x66, 0x66, 0x66), (0xE0, 0xB0, 0xF0))  # 灰->虹(占位)
solid("placeholder_bg_ch3_mid.png", 640, 210, (0x1A, 0x1A, 0x1A))

# ---------- UI(13) ----------
UI = (1920, 1080)
for n in ["menu_bg", "diary_open", "notebook_close", "lock_closed", "lock_open", "popup_frame", "eyelid", "page_turn"]:
    solid("placeholder_ui_%s.png" % n, UI[0], UI[1], (0x20, 0x20, 0x28))
for i in range(1, 5):
    solid("placeholder_ui_memory_fragment_%d.png" % i, 64, 64, (0x8A, 0xD4, 0xFF))

# ---------- LUT(2) ----------
# 约定: 256x16 = 16x16x16 展开; red=x//16, blue=x%16, green=y(占位 identity)
img = Image.new("RGB", (256, 16))
d = ImageDraw.Draw(img)
for y in range(16):
    for x in range(256):
        r = (x // 16) * 17
        g = y * 17
        b = (x % 16) * 17
        d.point((x, y), fill=(r, g, b))
img.save(os.path.join(BASE, "placeholder_lut_neutral.png"))
print("ok placeholder_lut_neutral.png 256 16")

img2 = Image.new("RGB", (256, 16))
d2 = ImageDraw.Draw(img2)
for y in range(16):
    for x in range(256):
        r = 255 - (x // 16) * 17
        g = 255 - y * 17
        b = 255 - (x % 16) * 17
        d2.point((x, y), fill=(r, g, b))
img2.save(os.path.join(BASE, "placeholder_lut_test_invert.png"))
print("ok placeholder_lut_test_invert.png 256 16")

print("DONE")