# -*- coding: utf-8 -*-
"""把四篇正式日记文案写入已存在的 ch2 关卡 JSON 的 diary_desk params。
依据:《四篇日记文案与 DiaryUI 修改方案》(2026-08-30)——文案优先写进 DiaryDesk 导出变量。
数据源:assets/data/diary_texts.json(倒序:ch2_lv1=1999 … ch2_lv4=1993)。
可重复运行:只对已建且含 diary_desk 模块的 ch2 关卡生效,其余跳过(不创建关卡)。
注意:即使 params 为空,运行时 DiaryDesk 也会回退读 diary_texts.json;本脚本只是让文案在编辑器里可见可改。
"""
import io
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXTS = json.loads((ROOT / "assets" / "data" / "diary_texts.json").read_text(encoding="utf-8"))


def main() -> None:
    for lv in ["ch2_lv1", "ch2_lv2", "ch2_lv3", "ch2_lv4"]:
        path = ROOT / "levels" / f"{lv}.json"
        if not path.exists():
            print(f"  跳过 {lv}: 关卡 JSON 未建")
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        desks = [m for m in data.get("modules", []) if m.get("id") == "diary_desk"]
        if not desks:
            print(f"  跳过 {lv}: 无 diary_desk 模块(关卡可能在重建中)")
            continue
        entry = TEXTS[lv]
        for m in desks:
            m["params"] = {
                "level_id": lv,
                "chapter": 2,
                "diary_date": entry["date"],
                "diary_text": entry["text"],
            }
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"  已写入 {lv}: {entry['date']}({len(entry['text'])} 字)× {len(desks)} 张日记桌")


if __name__ == "__main__":
    main()
