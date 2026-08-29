class_name ModuleRegistry
extends RefCounted
# 模块注册表(地图编辑器):所有可摆放模块的单一目录。
# 每个条目: { id, name, category, scene, params, fp_offset, fp_size }
#   scene     — .tscn 路径(实例化)或 .gd 路径(直接 new,如 PlatformModule)
#   params    — 默认参数(平台=w/h格数)
#   fp_offset/fp_size — 脚印矩形(相对节点原点的px),编辑器画幽灵/拾取/对齐用
# 脚印约定:平台=左上角原点;陷阱=贴图中心(摆锤=顶部悬挂点);台灯/日记桌/出生点=底部落地线。

const CELL := 20.0


static func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	# ---- 平台:横向1~5格 × 高1格;纵向1格宽 × 2~3格 ----
	for w in range(1, 6):
		entries.append({
			"id": "platform_h%d" % w, "name": "横平台 %d格" % w, "category": "平台",
			"scene": "res://src/modules/PlatformModule.gd",
			"params": {"w": w, "h": 1},
			"fp_offset": Vector2.ZERO, "fp_size": Vector2(w * CELL, CELL),
		})
	for h in range(2, 4):
		entries.append({
			"id": "platform_v%d" % h, "name": "竖平台 %d格" % h, "category": "平台",
			"scene": "res://src/modules/PlatformModule.gd",
			"params": {"w": 1, "h": h, "style": "platform"},
			"fp_offset": Vector2.ZERO, "fp_size": Vector2(CELL, h * CELL),
		})
	# ---- 地面:实心方块,横向1~5格 × 4格高(顶面对齐落脚线,向下填实) ----
	for w in range(1, 6):
		entries.append({
			"id": "ground_h%d" % w, "name": "地面 %d格" % w, "category": "地面",
			"scene": "res://src/modules/PlatformModule.gd",
			"params": {"w": w, "h": 4, "style": "ground"},
			"fp_offset": Vector2.ZERO, "fp_size": Vector2(w * CELL, 4 * CELL),
		})
	# ---- 陷阱:12种,脚印从各自 TrapConfig 读取(单一事实源) ----
	var trap_names := {
		"pendulum": "摆锤(鸡毛掸子)", "washboard": "尖刺带(搓衣板)", "bottle": "酒瓶坠落",
		"glass": "碎玻璃", "thorns": "荆棘", "heart_big": "心脏(大)",
		"part": "零件飞溅", "press": "冲压机", "soundwave": "声波",
		"billwind": "阵风(无伤)", "conveyor": "传送带(无伤)", "rotten": "腐板(无伤)",
	}
	for id in trap_names:
		var cfg: TrapConfig = load("res://src/traps/configs/%s.tres" % id)
		var size: Vector2 = cfg.hitbox_size
		var off := Vector2(-size.x / 2.0, -size.y / 2.0)  # 默认中心原点
		if cfg.anchor_top:
			off = Vector2(-size.x / 2.0, 0.0)  # 悬挂类:原点=顶部中点
		entries.append({
			"id": id, "name": trap_names[id], "category": "陷阱",
			"scene": "res://src/traps/scenes/trap_%s.tscn" % id,
			"params": {}, "fp_offset": off, "fp_size": size,
		})
	# ---- 道具与标记 ----
	entries.append({
		"id": "lamp", "name": "台灯(检查点)", "category": "道具",
		"scene": "res://src/player/Checkpoint.tscn", "params": {},
		"fp_offset": Vector2(-10.0, -40.0), "fp_size": Vector2(20.0, 40.0),
	})
	entries.append({
		"id": "diary_desk", "name": "日记桌(关底)", "category": "道具",
		"scene": "res://src/props/DiaryDesk.tscn", "params": {},
		"fp_offset": Vector2(-60.0, -80.0), "fp_size": Vector2(120.0, 80.0),
	})
	entries.append({
		"id": "spawn", "name": "出生点", "category": "道具",
		"scene": "", "params": {},  # 编辑器内画标记,游戏内由 LevelLoader 放置玩家
		"fp_offset": Vector2(-10.0, -20.0), "fp_size": Vector2(20.0, 20.0),
	})
	return entries


static func get_entry(id: String) -> Dictionary:
	for e in get_entries():
		if e.id == id:
			return e
	push_error("ModuleRegistry: 未知模块 id=%s" % id)
	return {}


## 实例化模块(spawn 无实体,返回 null);平台按 params.w/h 设格数
static func instantiate(id: String, params: Dictionary = {}) -> Node2D:
	var entry := get_entry(id)
	if entry.is_empty() or (entry.scene as String).is_empty():
		return null
	var node: Node2D
	if (entry.scene as String).ends_with(".gd"):
		node = (load(entry.scene) as GDScript).new()
	else:
		node = (load(entry.scene) as PackedScene).instantiate()
	if node is PlatformModule:
		node.configure(int(params.get("w", 3)), int(params.get("h", 1)), str(params.get("style", "platform")))
	return node
