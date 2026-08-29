# -*- coding: utf-8 -*-
"""日记定妆照派生 UI 素材后处理（2026-08-30）
依据:策划案-美术音乐.md 六、UI素材需求(1920×1080 高清) + 附录E 替换约定(同名覆盖占位路径,程序零改动)。
输入:assets/art/_raw_ui_*.png(image_generation 原图,挂 ui_notebook_reference 生成)
输出:覆盖 assets/placeholder/ 同名占位(旧文件备份 .orig.png):
  - placeholder_ui_menu_bg.png        1920×1080 主菜单主视觉
  - placeholder_ui_notebook_close.png 1920×1080 开锁演出笔记本特写
  - placeholder_ui_diary_open.png     1920×1080 日记摊开底图(左页空白=正文区,右页顶部=日期区)
  - placeholder_ui_memory_fragment_1~4.png 64×64 记忆光片(透明底,呼应封面发光菱形)
"""
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "assets" / "art"
PH = ROOT / "assets" / "placeholder"


def backup(p: Path) -> None:
    bak = p.with_name(p.name + ".orig.png")
    if p.exists() and not bak.exists():
        shutil.copy2(p, bak)
        print(f"  备份: {bak.name}")


def deliver_full(raw: str, target: Path) -> None:
    """2K 16:9 原图 -> 裁掉底部 72px(去 AI生成 水印)-> 1920×1080。"""
    im = Image.open(ART / raw).convert("RGB")
    im = im.crop((0, 0, im.width, im.height - 72))
    im = im.resize((1920, 1080), Image.LANCZOS)
    im.save(target)
    print(f"  交付: {target.relative_to(ROOT)}  {im.size}")


def deliver_fragments(raw: str) -> None:
    """按 alpha 列投影切 4 枚光片,各自取包围盒 ->  padding 成正方 -> 64×64。"""
    im = Image.open(ART / raw).convert("RGBA")
    a = np.asarray(im)
    mask = a[:, :, 3] > 30
    col_has = mask.any(axis=0)
    # 找 4 段连续有内容的列区间
    segments, start = [], None
    for x, has in enumerate(col_has):
        if has and start is None:
            start = x
        elif not has and start is not None:
            segments.append((start, x))
            start = None
    if start is not None:
        segments.append((start, len(col_has)))
    # 合并间距过小的碎段(光晕断档),按x排序取最大的4段
    merged = []
    for seg in segments:
        if merged and seg[0] - merged[-1][1] < 20:
            merged[-1] = (merged[-1][0], seg[1])
        else:
            merged.append(list(seg))
    merged = sorted(merged, key=lambda s: s[1] - s[0], reverse=True)[:4]
    merged = sorted(merged, key=lambda s: s[0])
    assert len(merged) == 4, f"光片切分失败,只找到 {len(merged)} 段"

    for i, (x0, x1) in enumerate(merged, 1):
        rows = mask[:, x0:x1].any(axis=1)
        y0, y1 = int(np.argmax(rows)), len(rows) - int(np.argmax(rows[::-1]))
        # 包围盒 padding 12px 后裁成正方形
        pad = 12
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        half = max(x1 - x0, y1 - y0) // 2 + pad
        box = (max(cx - half, 0), max(cy - half, 0),
               min(cx + half, im.width), min(cy + half, im.height))
        shard = im.crop(box).resize((64, 64), Image.LANCZOS)
        out = PH / f"placeholder_ui_memory_fragment_{i}.png"
        shard.save(out)
        print(f"  交付: {out.relative_to(ROOT)}  {shard.size}  bbox=({x0},{y0})-({x1},{y1})")


def main() -> None:
    print("[备份]")
    for name in [
        "placeholder_ui_menu_bg.png",
        "placeholder_ui_notebook_close.png",
        "placeholder_ui_diary_open.png",
        "placeholder_ui_memory_fragment_1.png",
        "placeholder_ui_memory_fragment_2.png",
        "placeholder_ui_memory_fragment_3.png",
        "placeholder_ui_memory_fragment_4.png",
    ]:
        backup(PH / name)

    print("[1] 主菜单主视觉")
    deliver_full("_raw_ui_menu_bg.png", PH / "placeholder_ui_menu_bg.png")
    print("[2] 开锁演出笔记本特写")
    deliver_full("_raw_ui_notebook_close.png", PH / "placeholder_ui_notebook_close.png")
    print("[3] 日记摊开底图")
    deliver_full("_raw_ui_diary_open.png", PH / "placeholder_ui_diary_open.png")
    print("[4] 记忆光片 ×4")
    deliver_fragments("_raw_ui_fragments.png")

    print("\n[验收]")
    for name in [
        "placeholder_ui_menu_bg.png", "placeholder_ui_notebook_close.png",
        "placeholder_ui_diary_open.png",
    ] + [f"placeholder_ui_memory_fragment_{i}.png" for i in range(1, 5)]:
        im = Image.open(PH / name)
        print(f"  {name}: {im.size} {im.mode}")


if __name__ == "__main__":
    main()
