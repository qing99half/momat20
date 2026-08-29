"""全量美术资源审查:尺寸规格核对 + 关卡 JSON 模块覆盖率。
输出:控制台摘要 + production/session-state/art-audit.md
"""
import json
import os
from pathlib import Path
from PIL import Image

ROOT = Path(".")
ART = ROOT / "assets/art"
OUT = ROOT / "production/session-state/art-audit.md"

# ---- 规格表(20px 格体系,素材体系重设计.md + 附录E) ----
TRAP_SPEC = {  # 文件后缀 -> 期望尺寸
    "pendulum": (40, 120), "washboard": (60, 20), "bottle": (20, 20),
    "conveyor": (200, 12), "part": (60, 20), "press": (40, 40),
    "thorns": (60, 20), "heart_platform": (40, 20), "heart_mold": (60, 60),
    "glass": (60, 20), "soundwave": (60, 40), "billwind": None,  # 已删除设计
}
LEVELS = ["ch1_lv1", "ch1_lv2", "ch1_lv3", "ch1_lv4",
          "ch2_lv1", "ch2_lv2", "ch2_lv3", "ch2_lv4", "ch3"]
DUAL = {"ch1_lv3": ["warm", "rot"], "ch2_lv2": ["warm", "rot"], "ch3": ["real", "dream"]}
# 关卡 JSON 里实际用到的陷阱(lv1/lv2 已搭)
TRAP_NAME_MAP = {"heart_big": "heart_mold", "rotten": "heart_platform"}  # 代码id -> 文件后缀

report = []
errors = []
warns = []


def img_size(p: Path):
    try:
        return Image.open(p).size
    except Exception as e:
        errors.append(f"打不开: {p} ({e})")
        return None


def expect(cond, msg):
    (report if cond else errors).append(("PASS " if cond else "FAIL ") + msg)


# ---- 1. 地形条带 ----
for lv in LEVELS:
    d = ART / lv
    if not d.is_dir():
        warns.append(f"缺目录: {d}")
        continue
    variants = DUAL.get(lv, [""])
    for v in variants:
        suf = f"_{v}" if v else ""
        for w in range(1, 6):
            f = d / f"ground_{lv}_{w}w{suf}.png"
            if not f.exists():
                errors.append(f"FAIL 缺 {f}")
                continue
            s = img_size(f)
            if s:
                expect(s == (w * 20, 80), f"{f.name} {s} 期望({w*20},80)")
            f = d / f"platform_{lv}_{w}w{suf}.png"
            if not f.exists():
                errors.append(f"FAIL 缺 {f}")
                continue
            s = img_size(f)
            if s:
                expect(s == (w * 20, 10), f"{f.name} {s} 期望({w*20},10)")
        for h, hh in (("h2a", 40), ("h2b", 40), ("h3a", 60), ("h3b", 60)):
            if lv == "ch3":
                continue  # 三章平坦无平台(任务12),不强制
            f = d / f"platform_{lv}_{h}{suf}.png"
            if not f.exists():
                errors.append(f"FAIL 缺 {f}")
                continue
            s = img_size(f)
            if s:
                expect(s == (20, hh), f"{f.name} {s} 期望(20,{hh})")

# ---- 2. 陷阱图 ----
for lv in LEVELS:
    d = ART / lv
    if not d.is_dir():
        continue
    for f in sorted(d.glob("trap_*.png")):
        suffix = f.stem.replace(f"trap_{lv}_", "")
        spec = TRAP_SPEC.get(suffix, "UNKNOWN")
        s = img_size(f)
        if spec == "UNKNOWN":
            warns.append(f"未知陷阱后缀: {f.name} {s}")
        elif spec is None:
            warns.append(f"{f.name} {s} —— billwind 账单纸风设计已删,不绑")
        elif s != spec:
            errors.append(f"FAIL {f.name} {s} 期望{spec}")
        else:
            report.append(f"PASS {f.name} {s}")

# ---- 3. 道具/角色/背景 ----
for f, want in [
    (ART / "ch3/prop_ch3_door_closed.png", (60, 80)),
    (ART / "ch3/prop_ch3_door_halfopen.png", (60, 80)),
    (ART / "char-old/char_old_mother.png", (160, 20)),
    (ART / "char-young/char_young_spritesheet.png", (480, 20)),
    (ART / "bg_ch2_lv1_far.png", (640, 360)),
]:
    if not f.exists():
        errors.append(f"FAIL 缺 {f}")
    else:
        s = img_size(f)
        if s:
            expect(s == want, f"{f.name} {s} 期望{want}")

# ---- 4. 已有关卡 JSON 的模块覆盖 ----
for jf in sorted((ROOT / "levels").glob("*.json")):
    data = json.load(open(jf, encoding="utf-8"))
    lv = data["level_id"]
    d = ART / lv
    miss_plat, miss_trap = [], []
    for m in data["modules"]:
        mid = m["id"]
        p = m.get("params", {})
        variants = DUAL.get(lv, [""])

        def any_file(stem: str) -> bool:
            return any((d / f"{stem}{('_' + v) if v else ''}.png").exists() for v in variants)

        if mid.startswith("ground_h"):
            w = int(p.get("w", 3))
            if not any_file(f"ground_{lv}_{w}w"):
                miss_plat.append(f"ground {w}w")
        elif mid.startswith("platform_h"):
            w = int(p.get("w", 1))
            if not any_file(f"platform_{lv}_{w}w"):
                miss_plat.append(f"platform {w}w")
        elif mid.startswith("platform_v"):
            h = int(p.get("h", 2))
            if not any_file(f"platform_{lv}_h{h}a"):
                miss_plat.append(f"platform v{h}")
        elif mid in ("lamp", "diary_desk", "spawn"):
            pass
        else:  # 陷阱
            suffix = TRAP_NAME_MAP.get(mid, mid)
            if not (d / f"trap_{lv}_{suffix}.png").exists():
                miss_trap.append(f"{mid}(trap_{lv}_{suffix})")
    line = f"{lv}: 地形缺={sorted(set(miss_plat)) or '无'} 陷阱缺={sorted(set(miss_trap)) or '无'}"
    (warns if (miss_plat or miss_trap) else report).append(("WARN " if (miss_plat or miss_trap) else "PASS ") + line)

# ---- 输出 ----
OUT.parent.mkdir(parents=True, exist_ok=True)
with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("# 美术资源全量审查（audit_art.py）\n\n")
    fh.write(f"## FAIL（{len(errors)}）\n" + "".join(f"- {e}\n" for e in errors))
    fh.write(f"\n## WARN（{len(warns)}）\n" + "".join(f"- {w}\n" for w in warns))
    fh.write(f"\n## PASS（{len(report)}）\n" + "".join(f"- {r}\n" for r in report))
print(f"FAIL={len(errors)} WARN={len(warns)} PASS={len(report)}")
for e in errors:
    print(" ", e)
for w in warns:
    print(" ", w)
print("->", OUT)
