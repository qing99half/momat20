# 二章四关生成器(2026-08-30 陈洒确认 v2 方案后制作)
# 方法:镜像一章对应关(x' = 2600 - x [- w]) → 撤双台灯换中点单台灯 →
#       按 v2 方案打难度补丁(扩缺口/跳冲点/惯性段/折返) → 包络校验 → 写 levels/ch2_lv*.json
# 运行: python tools/gen_ch2_levels.py          (只打印布局+校验,不写文件)
#       python tools/gen_ch2_levels.py write    (校验通过才落盘)
import json, sys, os, shutil, math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W = 2600.0  # 镜像轴:一章布局 X0~2600(130格)
CELL = 20.0

# 物理包络(Player.gd 常量推导)
JUMP_X = 80.0    # 常规大跳上限(纯跳95留余量)
DASH_X = 140.0   # 跳冲上限(跳冲150留余量)
JUMP_UP = 60.0   # 单跳爬升上限(净高70留余量)

# ch2关 ← 镜像基底ch1关, 日记日期(逆向排序, 陈洒 2026-08-30 确认)
LEVELS = {
    "ch2_lv1": {"base": "ch1_lv4", "diary": "1999"},
    "ch2_lv2": {"base": "ch1_lv3", "diary": "1997"},
    "ch2_lv3": {"base": "ch1_lv2", "diary": "1996"},
    "ch2_lv4": {"base": "ch1_lv1", "diary": "1993"},
}

# 站立面宽度(中心锚点类):传送带200/腐心40;平台地面按 params.w*20 左上锚点
CENTER_STAND_W = {"conveyor": 200.0, "rotten": 40.0}


def load(name):
    with open(os.path.join(ROOT, "levels", name + ".json"), encoding="utf-8") as f:
        return json.load(f)


def mirror_module(m):
    """返回镜像后的模块(dict副本)。平台/地面=左上锚点按宽度镜像;其余=中心锚点直接反射。"""
    m2 = {"id": m["id"], "px": m["px"], "py": m["py"],
          "params": dict(m.get("params", {}))}
    if m["id"].startswith(("ground", "platform")):
        w = float(m["params"].get("w", 1)) * CELL
        m2["px"] = W - m["px"] - w
    else:
        m2["px"] = W - m["px"]
        if m["id"] == "conveyor":
            # 传送带原方向+x(向右运);镜像关前进方向=-x,转180°朝左运
            m2["params"]["rot"] = 180
    return m2


def stand_surfaces(mods):
    """收集站立面: (x0, x1, y_top, is_conveyor)。地面/平台顶面=py(左上锚点);
    传送带顶面=py-6;腐心顶面=py-10(皆中心锚点)。"""
    surfs = []
    for m in mods:
        i, p = m["id"], m.get("params", {})
        if i.startswith(("ground", "platform")):
            w = float(p.get("w", 1)) * CELL
            surfs.append((m["px"], m["px"] + w, m["py"], False))
        elif i in CENTER_STAND_W:
            w = CENTER_STAND_W[i]
            top = m["py"] - (6.0 if i == "conveyor" else 10.0)
            surfs.append((m["px"] - w / 2, m["px"] + w / 2, top, i == "conveyor"))
    surfs.sort(key=lambda s: s[0])
    return surfs


def validate(mods, label, quiet=False):
    """BFS 可达性校验:从出生面到日记桌面。边规则(与包络一致,留余量):
    纯跳 缺口≤80 且爬升≤60;跳冲 缺口≤140 且爬升≤20;传送带起跳惯性 +60。
     mirrored ch1 已验证可通关,同一把尺子量 ch2。"""
    surfs = stand_surfaces(mods)
    spawn = next((m for m in mods if m["id"] == "spawn"), None)
    desk = next((m for m in mods if m["id"] == "diary_desk"), None)
    if spawn is None or desk is None:
        return ["缺 spawn 或 diary_desk"], {}
    def nearest_surf(x):
        return min(range(len(surfs)),
                   key=lambda i: min(abs(surfs[i][0] - x), abs(surfs[i][1] - x),
                                     abs((surfs[i][0] + surfs[i][1]) / 2 - x)))
    start, goal = nearest_surf(spawn["px"]), nearest_surf(desk["px"])
    n = len(surfs)
    adj = [[] for _ in range(n)]  # (邻面, cost): 跳=0, 跳冲=1
    for i in range(n):
        a = surfs[i]
        for j in range(i + 1, n):
            b = surfs[j]
            g = max(0.0, b[0] - a[1])
            if g > DASH_X + 60.0:
                break  # 按 x0 排序,后面只会更远
            for src, dst in ((i, j), (j, i)):
                s, d = surfs[src], surfs[dst]
                climb = d[2] - s[2]  # 负=向上
                bonus = 60.0 if s[3] else 0.0  # 带速惯性
                # 下坠补偿:落点更低时跳跃横距随落差增加(95px纯跳+落差延程),封顶+40
                drop_bonus = min(max(climb, 0.0) * 0.5, 40.0)
                if g <= JUMP_X + drop_bonus + bonus and climb >= -JUMP_UP:
                    adj[src].append((dst, 0))
                elif g <= DASH_X + bonus and climb >= -50.0:
                    # 跳冲:跳起70px后在顶点平冲,落点允许高50px(留20px人性余量)
                    adj[src].append((dst, 1))
    # 0-1 BFS:最少跳冲次数路径(玩家总会找最省力路线,这才是真实难度)
    from collections import deque
    INF = float("inf")
    dist = [INF] * n
    dist[start] = 0
    parent = {start: None}
    dq = deque([start])
    while dq:
        cur = dq.popleft()
        for nb, cost in adj[cur]:
            if dist[cur] + cost < dist[nb]:
                dist[nb] = dist[cur] + cost
                parent[nb] = cur
                (dq.appendleft if cost == 0 else dq.append)(nb)
    seen = {i for i in range(n) if dist[i] < INF}
    problems = []
    if dist[goal] == INF:
        problems.append(f"日记桌面不可达: 面{tuple(int(v) for v in surfs[goal][:3])}")
    if not quiet:
        print(f"== {label}: {len(mods)}模块, {n}面, 可达{len(seen)}" +
              (f", FAIL: {problems}" if problems else ", 全程可达 ✓"))
        if dist[goal] < INF:
            # 最少跳冲路径审计:证明难点在必经之路上,且次数符合设计
            path, cur = [], goal
            while cur is not None:
                path.append(cur)
                cur = parent[cur]
            path.reverse()
            n_dash = 0
            for u, v in zip(path, path[1:]):
                s, d = surfs[u], surfs[v]
                g = max(0.0, max(s[0] - d[1], d[0] - s[1]))
                climb = d[2] - s[2]
                bonus = 60.0 if s[3] else 0.0
                drop_bonus = min(max(climb, 0.0) * 0.5, 40.0)
                if g <= JUMP_X + drop_bonus + bonus and climb >= -JUMP_UP:
                    cls = "惯性跳" if s[3] else "跳"
                else:
                    cls = "惯性跳冲" if s[3] else "跳冲"
                    n_dash += 1
                if cls != "跳":
                    print(f"    {cls}: {int(g)}px  y{int(s[2])}→{int(d[2])}  "
                          f"@x{int(max(s[0],d[0]))}~{int(min(s[1],d[1]))}")
            print(f"    最少跳冲路径: {len(path)} 面 / 必经跳冲 {n_dash} 次")
    return problems, {"surfs": n, "reachable": len(seen), "min_dash": dist[goal]}


def gen(level_id):
    cfg = LEVELS[level_id]
    base = load(cfg["base"])
    mods = [mirror_module(m) for m in base["modules"]]

    # 撤一章双台灯,换中点单台灯(X≈1300,落在就近站立面上)
    mods = [m for m in mods if m["id"] != "lamp"]
    surfs = stand_surfaces(mods)
    best = min(surfs, key=lambda s: abs((s[0] + s[1]) / 2 - 1300))
    lamp_x = max(best[0] + 20, min(1300.0, best[1] - 20))
    mods.append({"id": "lamp", "px": lamp_x, "py": best[2], "params": {}})

    # 日记桌日期(逆向排序)
    for m in mods:
        if m["id"] == "diary_desk":
            m["params"]["diary_date"] = cfg["diary"]

    # ---- 难度补丁(按 v2 方案,逐关定制) ----
    mods = PATCHES.get(level_id, lambda ms: ms)(mods)

    mods.sort(key=lambda m: m["px"])
    return {"level_id": level_id,
            "bg_far": f"res://assets/art/bg_{level_id}_far.png",
            "modules": mods}


# ================= 难度补丁(v2 方案定稿,坐标=镜像后坐标系) =================

def _del(mods, pred):
    return [m for m in mods if not pred(m)]


def _is_plat(m, x, y, ids=("ground", "platform")):
    return m["id"].startswith(ids) and m["px"] == float(x) and m["py"] == float(y)


def _move(mods, x, y, dx, ids=("ground", "platform")):
    for m in mods:
        if _is_plat(m, x, y, ids):
            m["px"] += dx
    return mods


def _add(mods, id_, x, y, **params):
    mods.append({"id": id_, "px": float(x), "py": float(y), "params": dict(params)})
    return mods


def _patch_lv1(mods):
    # 台灯挪到宽平台(1120-1220 y300),自动生成点落在 20px 小平台上太抠
    mods = _del(mods, lambda m: m["id"] == "lamp")
    mods = _add(mods, "lamp", 1170, 300)
    # ① 开场 6 格跳冲(2380→2500):平台 2340-2440 左移 60;下方兜底平台(演出后第一跳不惩罚)
    mods = _move(mods, 2340, 240, -60)
    mods = _add(mods, "platform_h3", 2410, 320, h=1, style="platform", w=3)
    # ② 连续双 6 格跳冲(1860→1980→2080→2200):撤 3 块踏脚小台,平台 2020-2120 左移 40
    mods = _del(mods, lambda m: _is_plat(m, 1880, 180) or _is_plat(m, 1920, 220) or _is_plat(m, 1960, 260))
    mods = _move(mods, 2020, 240, -40)
    # ③ 4 格墙折返(机关②):y240 低路撞墙死路,须退回右侧上 y160 高路,120px 跳冲上墙顶(=孤柱)
    mods = _add(mods, "ground_h1", 1440, 160, h=4, style="ground", w=1)
    # ④ 声波加密 2 处:双跳冲弧线上 + B 段跳跃弧线上
    mods = _add(mods, "soundwave", 2030, 240)
    mods = _add(mods, "soundwave", 1100, 240)
    return mods


def _patch_lv2(mods):
    # ① 下行塔抽 2 级台阶(爬塔变 80px 斜向跳)
    mods = _del(mods, lambda m: _is_plat(m, 2020, 120) or _is_plat(m, 2100, 160))
    # ② 腐心群稀疏化:留 2240-2280 / 2360-2400 / 2440-2480 三块,塌陷计时连跳(80/40 缺口)
    doomed = {(2300, 180), (2340, 180), (2340, 230), (2420, 180), (2280, 230), (2400, 230)}
    mods = _del(mods, lambda m: m["id"] == "rotten" and (int(m["px"]), int(m["py"])) in doomed)
    # ③ B 段 100px 跳冲缺口:撤 1460-1520 平台(落点 y260,心碎滴液区上方)
    mods = _del(mods, lambda m: _is_plat(m, 1460, 280))
    # ④ B 段中段抽 3 块踏脚台:1140-1180 → 960-1000 成 140px 跳冲(荆棘海上方,带下坠)
    mods = _del(mods, lambda m: _is_plat(m, 1060, 260) or _is_plat(m, 1100, 240) or _is_plat(m, 1020, 300))
    return mods


def _patch_lv3(mods):
    # ① 惯性 7 格缺口 + 带速接力:接力带 1200-1400 左移成 1160-1360 并反向(rot=0 向右推=急停回运)
    #    从顺带 A(1500-1700)末端起跳,带惯性飞 140px 落 B,B 向右回运,须立刻左跳上岸
    for m in mods:
        if m["id"] == "conveyor" and int(m["px"]) == 1300:
            m["px"] = 1260.0
            m["params"]["rot"] = 0
    # ② B 段上带跳冲:撤 880-940 平台,登陆台 1000-1040 右移 20 → 140px 跳冲上带(带末端 680 起跳)
    mods = _del(mods, lambda m: _is_plat(m, 880, 280))
    mods = _move(mods, 1000, 280, 20)
    return mods


def _patch_lv4(mods):
    # ① 7 格极限跳冲(B 段,台灯旁):平台 1120-1160 右移 60 → 1180-1220,向左跳 140px 落 940-1040
    mods = _move(mods, 1120, 280, 60)
    # ② 10 格惯性超级缺口(A 段,全游戏唯一):撤 y160/220/260 踏脚链与 2160-2260 平台,
    #    加左向传送带(2060-2260);带上起跳+空中冲刺 200px 飞渡,落台 1740-1840 右移 20 成 1760-1860
    for x, y in [(1860, 260), (1900, 220), (1940, 160), (2040, 220), (2120, 220), (2160, 280)]:
        mods = _del(mods, lambda m, x=x, y=y: _is_plat(m, x, y))
    mods = _add(mods, "conveyor", 2160, 280, rot=180)
    mods = _move(mods, 1740, 280, 20)
    # 超级缺口前后的意外跳冲缺口抹平成 4 格大跳
    mods = _move(mods, 1620, 280, 20)   # 1620-1660 → 1640-1680(与落台 80px 纯跳)
    mods = _move(mods, 1500, 280, 20)   # 1500-1540 → 1520-1560(与前台 80px 纯跳)
    # ③ 摆锤加密 2 个:B 段平台上空 + 超级缺口助跑台上空(可在 2380-2480 等待拍点,公平)
    mods = _add(mods, "pendulum", 1500, 120)
    mods = _add(mods, "pendulum", 2270, 120)
    return mods


PATCHES = {
    "ch2_lv1": _patch_lv1,
    "ch2_lv2": _patch_lv2,
    "ch2_lv3": _patch_lv3,
    "ch2_lv4": _patch_lv4,
}


def main():
    do_write = len(sys.argv) > 1 and sys.argv[1] == "write"
    # 先用同一尺子定标:一章四关必须全程可达(已人工验收可通关)
    print("---- 定标:一章四关(已验证可通关) ----")
    for base in ["ch1_lv1", "ch1_lv2", "ch1_lv3", "ch1_lv4"]:
        probs, _ = validate(load(base)["modules"], base, quiet=True)
        print(f"  {base}: {'FAIL ' + str(probs) if probs else '可达 ✓'}")
    print("---- 二章四关(镜像+补丁) ----")
    all_ok = True
    for lv in LEVELS:
        data = gen(lv)
        probs, _ = validate(data["modules"], lv)
        all_ok = all_ok and not probs
        if do_write and not probs:
            path = os.path.join(ROOT, "levels", lv + ".json")
            if os.path.exists(path):
                bak = os.path.join(ROOT, "backups",
                    f"{lv}_生成前备份.json")
                shutil.copy(path, bak)
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"  → 已写入 levels/{lv}.json")
    print("RESULT:", "PASS" if all_ok else "FAIL")


if __name__ == "__main__":
    main()
