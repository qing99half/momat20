extends SceneTree
# 步骤8.3 关1(家暴关)无头构建脚本:重铺地面 tilemap + 摆放台灯/陷阱/日记桌/背景,
# 结果保存回 src/levels/level_ch1_lv1.tscn(编辑器里打开即可见)。
#
# 用法:
#   godot --headless --path <项目根> --script tools/build_level_ch1_lv1.gd
#
# 坐标约定:1格=8px,X=格数×8;设计 Y=0 地面 = 第18行顶面(像素 y=144)。
# 布局表(格):教学段 X0~40 连续平台+2格缺口;核心段 X40~80 起伏(高低差≤2格);
#             组合段 X80~120 摆锤+尖刺带;关底 X120~130 平坦,日记桌 X=125。

const GROUND_BOTTOM_ROW := 22  # 地面实心填到第22行(底边 y=184,相机下界180裁掉)

const PLAYER_SCENE := "res://src/player/Player.tscn"
const CHECKPOINT_SCENE := "res://src/player/Checkpoint.tscn"
const DESK_SCENE := "res://src/props/DiaryDesk.tscn"
const TRAP_WASHBOARD := "res://src/traps/scenes/trap_washboard.tscn"
const TRAP_PENDULUM := "res://src/traps/scenes/trap_pendulum.tscn"
const TRAP_BOTTLE := "res://src/traps/scenes/trap_bottle.tscn"

const BG_FAR := "res://assets/placeholder/placeholder_bg_ch1_lv1_far.png"
const BG_MID := "res://assets/placeholder/placeholder_bg_ch1_lv1_mid.png"


func _initialize() -> void:
	var packed: PackedScene = load("res://src/levels/level_ch1_lv1.tscn")
	var root := packed.instantiate()
	_paint_ground(root.get_node("TileMapLayer") as TileMapLayer)
	_add_backgrounds(root.get_node("ParallaxBackground") as ParallaxBackground, root)
	_add_actors(root)
	var out := PackedScene.new()
	out.pack(root)
	var err := ResourceSaver.save(out, "res://src/levels/level_ch1_lv1.tscn")
	print("[build] level_ch1_lv1.tscn 保存", "成功" if err == OK else "失败: %s" % err)
	quit(0 if err == OK else 1)


# ---- 地面布局表 ----
# 返回该列地面顶行(行号越小越高);-1 = 缺口(无地面)。
func _ground_top_row(x: int) -> int:
	if (x >= 20 and x <= 21) or (x >= 32 and x <= 33):
		return -1   # 教学段缺口×2(各2格,跳跃距离实测≈4格,稳过)
	if x <= 47:
		return 18   # 教学段 X0~40(+核心入口缓冲):连续平台
	if x <= 55:
		return 17   # 核心段:抬高1格
	if x <= 63:
		return 19   # 核心段:下沉1格(相对前段降2格,酒瓶落点在这段)
	if x <= 71:
		return 18   # 核心段:回升1格
	return 17       # X72~130:组合段+平坦走廊+关底,统一抬1格平台


func _paint_ground(tm: TileMapLayer) -> void:
	tm.clear()
	for x in range(0, 131):
		var top := _ground_top_row(x)
		if top < 0:
			continue
		for y in range(top, GROUND_BOTTOM_ROW + 1):
			tm.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))


func _add_backgrounds(bg: ParallaxBackground, root: Node) -> void:
	# 640×210 贴图:中心放(320,105)铺满 320×180 视野,配合层上已有的 motion_mirroring=640 横向循环
	for conf in [["Far", "FarSprite", BG_FAR], ["Mid", "MidSprite", BG_MID]]:
		var layer := bg.get_node(conf[0]) as ParallaxLayer
		# 幂等:重复构建先清掉旧 sprite
		var old := layer.get_node_or_null(conf[1])
		if old:
			old.queue_free()
		var sprite := Sprite2D.new()
		sprite.name = conf[1]
		sprite.texture = load(conf[2])
		sprite.position = Vector2(320.0, 105.0)
		layer.add_child(sprite)
		sprite.owner = root


# ---- 摆放(像素坐标) ----
func _add_actors(root: Node) -> void:
	# 玩家出生点:X=0 落地
	_place(root, PLAYER_SCENE, ".", Vector2(8, 144), "Player")
	# 台灯检查点:X=2(教学段,Y=0落地)、X=80(组合段入口,平台抬1格→y=136)
	_place(root, CHECKPOINT_SCENE, "SpawnPoints", Vector2(16, 144), "LampStart")
	_place(root, CHECKPOINT_SCENE, "SpawnPoints", Vector2(640, 136), "LampExam")
	# 教学段:搓衣板尖刺带 X=14~16(宽3格×高1格,中心x=124,贴地中心y=140)
	_place(root, TRAP_WASHBOARD, "Traps", Vector2(124, 140), "TrapWashboardTeach")
	# 核心段:鸡毛掸子摆锤 X=48(锚点Y=8天花板=y80,摆臂48px,±60°,周期2.0s,配置自带)
	_place(root, TRAP_PENDULUM, "Traps", Vector2(384, 80), "TrapPendulumCore")
	# 核心段:酒瓶坠落区 X=60(起点y=112,坠落40px落到下沉段地面y=152;阴影预警配置自带)
	_place(root, TRAP_BOTTLE, "Traps", Vector2(480, 112), "TrapBottleCore")
	# 组合考试段:摆锤+尖刺带两组,间距5格(摆锤锚点统一Y=8;尖刺贴地中心y=132)
	_place(root, TRAP_PENDULUM, "Traps", Vector2(704, 80), "TrapPendulumExam1")
	_place(root, TRAP_WASHBOARD, "Traps", Vector2(752, 132), "TrapWashboardExam1")  # X=93~95
	_place(root, TRAP_PENDULUM, "Traps", Vector2(800, 80), "TrapPendulumExam2")
	_place(root, TRAP_WASHBOARD, "Traps", Vector2(848, 132), "TrapWashboardExam2")  # X=105~107
	# X108~120:平坦走廊(无陷阱)
	# 关底段:日记桌 X=125(落地线y=136)
	_place(root, DESK_SCENE, ".", Vector2(1000, 136), "DiaryDesk")


func _place(root: Node, scene_path: String, parent_path: String, pos: Vector2, node_name: String) -> void:
	var parent := root if parent_path == "." else root.get_node(parent_path)
	# 幂等:重复构建先清掉同名旧节点
	var old := parent.get_node_or_null(node_name)
	if old:
		old.queue_free()
	var inst := (load(scene_path) as PackedScene).instantiate()
	inst.name = node_name
	parent.add_child(inst)
	inst.owner = root
	(inst as Node2D).position = pos
	print("[build] %s @ %s" % [node_name, pos])
