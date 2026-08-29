class_name LevelLoader
extends RefCounted
# 关卡装载器:从 JSON 数据构建关卡(地图编辑器的存档格式)。
# JSON: { "level_id", "bg_far"?, "bg_mid"?, "modules":[{id, px, py, params?}] }
# spawn 模块不实例化,只决定玩家出生位置;无 spawn 时默认 (24, 144)。

const PLAYER_SCENE := "res://src/player/Player.tscn"
const DEFAULT_SPAWN := Vector2(60.0, 160.0)


static func build(json_path: String) -> Node2D:
	var text := FileAccess.get_file_as_string(json_path)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_error("LevelLoader: JSON 解析失败 %s" % json_path)
		return null

	var root := Node2D.new()
	root.name = "LevelRoot"

	# 背景(可选):远/中景视差,与关卡模板同约定
	var bg_far: String = data.get("bg_far", "")
	var bg_mid: String = data.get("bg_mid", "")
	if bg_far != "" or bg_mid != "":
		root.add_child(_make_parallax(bg_far, bg_mid))

	var spawn := DEFAULT_SPAWN

	for m in data.get("modules", []):
		var id: String = m.get("id", "")
		var pos := Vector2(m.get("px", 0.0), m.get("py", 0.0))
		if id == "spawn":
			spawn = pos
			continue
		var node := ModuleRegistry.instantiate(id, m.get("params", {}))
		if node == null:
			continue
		node.position = pos
		node.name = "%s_%d_%d" % [id, int(pos.x), int(pos.y)]
		root.add_child(node)

	# 玩家;相机右边界全局固定=关卡规格130格×20px(阻-02:所有关同一基准,不随内容多少变化)
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = spawn
	root.add_child(player)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.limit_right = 2600

	# Conductor 节拍器(任务3):挂关卡根,MainGame 进场后播 M1,全关陷阱按 120BPM 对拍
	# 动态加载:静态引用会把 Conductor 拉进启动编译链,看不到 autoload(EventBus)
	var conductor: Node = (load("res://src/flow/Conductor.gd") as GDScript).new()
	conductor.name = "Conductor"
	conductor.set_meta("autoplay_track", "res://assets/placeholder/placeholder_M1.wav")
	root.add_child(conductor)

	print("[LevelLoader] %s: %d 个模块, 出生点 %s" % [json_path, data.get("modules", []).size(), spawn])
	return root


static func _make_parallax(far_path: String, mid_path: String) -> ParallaxBackground:
	var bg := ParallaxBackground.new()
	bg.name = "ParallaxBackground"
	if far_path != "":
		bg.add_child(_make_layer(far_path, 0.2, "Far"))
	if mid_path != "":
		bg.add_child(_make_layer(mid_path, 0.5, "Mid"))
	return bg


static func _make_layer(tex_path: String, scale: float, layer_name: String) -> ParallaxLayer:
	var layer := ParallaxLayer.new()
	layer.name = layer_name
	layer.motion_scale = Vector2(scale, scale)
	# 素材未到位(如二章bg_ch2_*)时跳过该层,不报错不挡路
	if not ResourceLoader.exists(tex_path):
		return layer
	var sprite := Sprite2D.new()
	sprite.texture = load(tex_path)
	sprite.centered = false
	layer.add_child(sprite)
	# 镜像宽度跟随贴图实际宽(素材换尺寸不用改代码)
	layer.motion_mirroring = Vector2(float(sprite.texture.get_width()), 0.0)
	return layer
