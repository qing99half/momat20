class_name LevelSpecs
extends RefCounted
# 关卡范围规格(照抄策划案任务8.3 + 附录C,不许自改):
#   每关约130格(2600px,相机Limit Right随布局末端+半屏微调),四段式。
#   单屏=整关高:视野640×360=32×18格(16:9),地面行Y=16(y=320px,Y=0为地面),关卡顶Y=0(地面上方16格=320px≈4.6跳)。
#   相机只横移(垂直锁定:整关高度开局即全见,无垂直滚动)。
# 各关差异仅在核心段/考试段分界:关1=80,关2/3=85,关4=70。

const LENGTH_CELLS := 130
const GROUND_Y_PX := 320.0
const CEILING_Y_PX := 0.0  # 关卡顶=视野顶(地面上方16格)
const DESK_CELL := 125  # 日记桌推荐位 X=125


static func get_spec(level_id: String) -> Dictionary:
	var core_end := 80  # 关1:核心段 X40~80
	if level_id in ["ch1_lv2", "ch1_lv3", "ch2_lv2", "ch2_lv3"]:
		core_end = 85
	elif level_id in ["ch1_lv4", "ch2_lv4"]:
		core_end = 70
	return {
		"length_cells": LENGTH_CELLS,
		"ground_y": GROUND_Y_PX,
		"ceiling_y": CEILING_Y_PX,
		"desk_cell": DESK_CELL,
		"sections": [
			{"name": "教学段", "from": 0, "to": 40},
			{"name": "核心段", "from": 40, "to": core_end},
			{"name": "组合考试段", "from": core_end, "to": 120},
			{"name": "关底段", "from": 120, "to": LENGTH_CELLS},
		],
	}
