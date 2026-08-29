class_name LevelLoader
extends RefCounted
# 关卡装载器:从 JSON 数据构建关卡(地图编辑器的存档格式)。
# JSON: { "level_id", "bg_far"?, "bg_mid"?, "modules":[{id, px, py, params?}] }
# spawn 模块不实例化,只决定玩家出生位置;无 spawn 时默认 (60, 320)。

const PLAYER_SCENE := "res://src/player/Player.tscn"
const DEFAULT_SPAWN := Vector2(60.0, 320.0)


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
	var max_x := 640.0  # 相机右边界=最右模块+余量(半屏320px@视野640宽),随布局扩展不设硬顶

	for m in data.get("modules", []):
		var id: String = m.get("id", "")
		var pos := Vector2(m.get("px", 0.0), m.get("py", 0.0))
		max_x = maxf(max_x, pos.x + 320.0)
		if id == "spawn":
			spawn = pos
			continue
		var node := ModuleRegistry.instantiate(id, m.get("params", {}))
		if node == null:
			continue
		node.position = pos
		node.name = "%s_%d_%d" % [id, int(pos.x), int(pos.y)]
		root.add_child(node)

	# 玩家;相机右边界跟随布局末端(阻-02:按实际布局+半屏微调,不留地图外空白,也不设上限)
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = spawn
	root.add_child(player)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.limit_right = int(max_x)

	# Conductor 节拍器(任务3):挂关卡根,MainGame 进场后播 M1,全关陷阱按 120BPM 对拍
	# 动态加载:静态引用会把 Conductor 拉进启动编译链,看不到 autoload(EventBus)
	var conductor: Node = (load("res://src/flow/Conductor.gd") as GDScript).new()
	conductor.name = "Conductor"
	conductor.set_meta("autoplay_track", "res://assets/placeholder/placeholder_M1.wav")
	root.add_child(conductor)

	print("[LevelLoader] %s: %d 个模块, 出生点 %s" % [json_path, data.get("modules", []).size(), spawn])
	return root


static func _make_parallax(far_path: String, mid_path: String) -> Node2D:
	# 不用 ParallaxBackground(CanvasLayer layer=-100):游戏画面在 SubViewport 里走
	# BackBufferCopy→LUT 后处理,负层画布内容与后处理采样顺序相冲,背景会被丢掉。
	# 改为普通 Node2D 视差精灵:默认画布、树顺序在关卡内容之前,后处理能采到。
	var bg := Node2D.new()
	bg.name = "ParallaxBackground"
	if far_path != "" and ResourceLoader.exists(far_path):
		bg.add_child(_make_layer(far_path, 0.2, "Far"))
	if mid_path != "" and ResourceLoader.exists(mid_path):
		bg.add_child(_make_layer(mid_path, 0.5, "Mid"))
	return bg


static func _make_layer(tex_path: String, scale: float, layer_name: String) -> Node2D:
	# 素材未到位(如二章bg_ch2_*)时跳过该层,不报错不挡路
	var layer := _ParallaxSprite.new()
	layer.name = layer_name
	layer.scroll_scale = scale
	layer.tex = load(tex_path)
	return layer


# 手写视差层:两块贴图横向无缝平铺,按相机左上角的 scroll_scale 倍率慢移(与相机只横移的约定配套)。
class _ParallaxSprite:
	extends Node2D
	var scroll_scale := 0.2
	var tex: Texture2D
	var _sprites: Array[Sprite2D] = []

	func _ready() -> void:
		for i in 2:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			add_child(s)
			_sprites.append(s)

	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_2d()
		if cam == null or tex == null:
			return
		var w := float(tex.get_width())
		var tl: Vector2 = cam.get_screen_center_position() - get_viewport().get_visible_rect().size / 2.0 / cam.zoom.x
		var off := fmod(tl.x * scroll_scale, w)
		if off < 0.0:
			off += w
		# 屏幕 x=-off 与 -off+w 两块即可盖住 640 宽视野(w=640);y 固定 0(相机不纵移)
		_sprites[0].global_position = Vector2(tl.x - off, 0.0)
		_sprites[1].global_position = Vector2(tl.x - off + w, 0.0)
