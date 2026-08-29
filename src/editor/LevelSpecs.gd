class_name LevelSpecs
extends RefCounted
# 关卡范围规格(照抄策划案任务8.3 + 附录C,不许自改):
#   每关约130格(2600px,相机Limit Right=2600),四段式,地面行Y=8(y=160px,Y=0为地面,视野9格高)。
# 各关差异仅在核心段/考试段分界:关1=80,关2/3=85,关4=70。

const LENGTH_CELLS := 130
const GROUND_Y_PX := 160.0
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
		"desk_cell": DESK_CELL,
		"sections": [
			{"name": "教学段", "from": 0, "to": 40},
			{"name": "核心段", "from": 40, "to": core_end},
			{"name": "组合考试段", "from": core_end, "to": 120},
			{"name": "关底段", "from": 120, "to": LENGTH_CELLS},
		],
	}
