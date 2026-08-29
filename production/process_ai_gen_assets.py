# -*- coding: utf-8 -*-
"""AI 生成素材后处理（像素陷阱 ×4 + 渐变远景 ×2）
依据《AI生成提示词.md》：
- 裁剪中央横条/居中裁方 -> 缩放到目标尺寸 -> 文件名不变放入目标路径
- 荆棘/碎玻璃：整图不透明（免抠图）；冲压机：保留深色底
- 传送带：裁中间最均匀横带，自动选平铺接缝最小的纵坐标
- lv3/lv4 远景：裁横向长条 -> 1280×360，覆盖 assets/placeholder/ 同名文件
覆盖前把旧文件备份为 .prev.png（占位背景按既有约定备份为 .orig.png）。
"""
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "assets" / "art"
PLACEHOLDER = ROOT / "assets" / "placeholder"


def backup(path: Path, suffix: str) -> None:
    if path.exists():
        bak = path.with_name(path.name + suffix)
        if not bak.exists():
            shutil.copy2(path, bak)
            print(f"  备份: {bak.name}")


def seam_diff(img: Image.Image, edge: int = 4) -> float:
    """左右边缘各 edge 列的平均 RGB 差，越小平铺接缝越不明显。"""
    import numpy as np

    a = np.asarray(img, dtype=np.float32)
    left = a[:, :edge, :]
    right = a[:, -edge:, :]
    return float(abs(left - np.flip(right, axis=1)).mean())


def crop_resize(src: str, box, size, outs, note=""):
    im = Image.open(ART / src).convert("RGB")
    region = im.crop(box)
    out = region.resize(size, Image.LANCZOS)
    for o in outs:
        out.save(o)
        print(f"  交付: {o.relative_to(ROOT)}  {out.size}  {note}")


def main() -> None:
    # ---- 0. 备份将被覆盖的旧文件 ----
    print("[备份]")
    for p in [
        ART / "ch1_lv3" / "trap_ch1_lv3_thorns.png",
        ART / "ch2_lv2" / "trap_ch2_lv2_thorns.png",
        ART / "ch1_lv2" / "trap_ch1_lv2_press.png",
        ART / "ch2_lv3" / "trap_ch2_lv3_press.png",
        ART / "ch1_lv2" / "trap_ch1_lv2_conveyor.png",
        ART / "ch2_lv3" / "trap_ch2_lv3_conveyor.png",
    ]:
        backup(p, ".prev.png")
    for p in [
        PLACEHOLDER / "placeholder_bg_ch1_lv3_far.png",
        PLACEHOLDER / "placeholder_bg_ch1_lv4_far.png",
    ]:
        backup(p, ".orig.png")

    # ---- 1. 荆棘丛 60×20（同图两副本）----
    print("[1] 荆棘丛 -> 60x20")
    crop_resize(
        "_raw_thorns.png", (0, 234, 2048, 917), (60, 20),
        [ART / "ch1_lv3" / "trap_ch1_lv3_thorns.png",
         ART / "ch2_lv2" / "trap_ch2_lv2_thorns.png"],
    )

    # ---- 2. 冲压机 40×40（同图两副本，保留深色底）----
    print("[2] 冲压机 -> 40x40")
    crop_resize(
        "_raw_press.png", (50, 0, 974, 924), (40, 40),
        [ART / "ch1_lv2" / "trap_ch1_lv2_press.png",
         ART / "ch2_lv3" / "trap_ch2_lv3_press.png"],
    )

    # ---- 3. 传送带 200×12（同图两副本，自动选接缝最小横带）----
    print("[3] 传送带 -> 200x12")
    im = Image.open(ART / "_raw_conveyor.png").convert("RGB")
    band_h = int(round(2048 / (200 / 12)))  # 123px，保持 16.67:1 不拉伸
    best_y, best_d = None, 1e9
    for y in range(380, 701, 4):
        band = im.crop((0, y, 2048, y + band_h)).resize((200, 12), Image.LANCZOS)
        d = seam_diff(band)
        if d < best_d:
            best_y, best_d = y, d
    print(f"  最优横带 y={best_y}（接缝差 {best_d:.1f}）")
    crop_resize(
        "_raw_conveyor.png", (0, best_y, 2048, best_y + band_h), (200, 12),
        [ART / "ch1_lv2" / "trap_ch1_lv2_conveyor.png",
         ART / "ch2_lv3" / "trap_ch2_lv3_conveyor.png"],
    )

    # ---- 4. 碎玻璃渣 60×20（仅 lv2 一张）----
    print("[4] 碎玻璃渣 -> 60x20")
    crop_resize(
        "_raw_glass.png", (0, 234, 2048, 917), (60, 20),
        [ART / "ch1_lv2" / "trap_ch1_lv2_glass.png"],
    )

    # ---- 5. lv3 远景 1280×360（覆盖占位）----
    print("[5] lv3 远景 -> 1280x360")
    crop_resize(
        "_raw_bg_lv3_far.png", (0, 288, 2048, 864), (1280, 360),
        [PLACEHOLDER / "placeholder_bg_ch1_lv3_far.png"],
    )

    # ---- 6. lv4 远景 1280×360（覆盖占位）----
    print("[6] lv4 远景 -> 1280x360")
    crop_resize(
        "_raw_bg_lv4_far.png", (0, 150, 2048, 726), (1280, 360),
        [PLACEHOLDER / "placeholder_bg_ch1_lv4_far.png"],
    )

    # ---- 验收输出：尺寸 / 不透明度 / 平铺接缝差 ----
    print("\n[验收]")
    targets = [
        ART / "ch1_lv3" / "trap_ch1_lv3_thorns.png",
        ART / "ch2_lv2" / "trap_ch2_lv2_thorns.png",
        ART / "ch1_lv2" / "trap_ch1_lv2_press.png",
        ART / "ch2_lv3" / "trap_ch2_lv3_press.png",
        ART / "ch1_lv2" / "trap_ch1_lv2_conveyor.png",
        ART / "ch2_lv3" / "trap_ch2_lv3_conveyor.png",
        ART / "ch1_lv2" / "trap_ch1_lv2_glass.png",
        PLACEHOLDER / "placeholder_bg_ch1_lv3_far.png",
        PLACEHOLDER / "placeholder_bg_ch1_lv4_far.png",
    ]
    for p in targets:
        im = Image.open(p)
        opaque = im.mode == "RGB" or (
            im.mode == "RGBA" and im.getchannel("A").getextrema()[0] == 255
        )
        seam = f"  接缝差={seam_diff(im.convert('RGB')):.1f}" if im.width / im.height >= 3 else ""
        print(f"  {p.relative_to(ROOT)}: {im.size} {im.mode} 不透明={opaque}{seam}")

    # ---- 目检用放大预览（最近邻放大，不交付）----
    prev = ROOT / "production" / "session-state"
    prev.mkdir(parents=True, exist_ok=True)
    for name, scale in [
        ("ch1_lv3/trap_ch1_lv3_thorns.png", 8),
        ("ch1_lv2/trap_ch1_lv2_press.png", 8),
        ("ch1_lv2/trap_ch1_lv2_conveyor.png", 4),
        ("ch1_lv2/trap_ch1_lv2_glass.png", 8),
    ]:
        im = Image.open(ART / name)
        im.resize((im.width * scale, im.height * scale), Image.NEAREST).save(
            prev / ("preview_" + Path(name).name)
        )
    # 传送带平铺接缝目检：左右拼一次
    im = Image.open(ART / "ch1_lv2" / "trap_ch1_lv2_conveyor.png")
    tiled = Image.new("RGB", (im.width * 2, im.height))
    tiled.paste(im, (0, 0))
    tiled.paste(im, (im.width, 0))
    tiled.resize((tiled.width * 4, tiled.height * 4), Image.NEAREST).save(
        prev / "preview_trap_ch1_lv2_conveyor_tiled.png"
    )
    print("  预览图已写入 production/session-state/preview_*.png")


if __name__ == "__main__":
    main()
