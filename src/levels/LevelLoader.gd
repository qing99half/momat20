class_name LevelLoader
extends RefCounted
# 关卡装载器:从 JSON 数据构建关卡(地图编辑器的存档格式)。
# JSON: { "level_id", "bg_far"?, "bg_mid"?, "modules":[{id, px, py, params?}] }
# spawn 模块不实例化,只决定玩家出生位置;无 spawn 时默认 (60, 320)。

const PLAYER_SCENE := "res://src/player/Player.tscn"
const DEFAULT_SPAWN := Vector2(60.0, 320.0)
# 关卡环境底噪(S9 争吵闷响/S14 机器嗡鸣/S16 婴儿啼哭):按 level_id 的 lv 序号取,同族自动命中
const AMBIENT_SFX := {
	"lv1": "res://assets/audio/sfx_quarrel_muffled.ogg",
	"lv2": "res://assets/audio/sfx_machine_hum.ogg",
	"lv4": "res://assets/audio/sfx_baby_cry.ogg",
}
# 章节 BGM(真素材):ch1→M1 压抑的记忆 / ch2→M2 决意拯救 / ch3→M3_A 相向奔赴;M3_B/V1 留给结局
const BGM_TRACKS := {
	"ch1": "res://assets/audio/bgm_m1.ogg",
	"ch2": "res://assets/audio/bgm_m2.ogg",
	"ch3": "res://assets/audio/bgm_m3_a.ogg",
}


static func build(json_path: String) -> Node2D:
	var text := FileAccess.get_file_as_string(json_path)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_error("LevelLoader: JSON 解析失败 %s" % json_path)
		return null

	var root := Node2D.new()
	root.name = "LevelRoot"

	# 背景(可选):只保留远景视差;中景层已全部删除(2026-08-30 决定,太丑)
	# 真素材优先(2026-08-30):assets/art/bg_<level_id>_far.png 存在就用它,丢图即生效;
	# 否则回退 JSON 里的 bg_far(通常是占位图)。JSON 路径写错/过期也不影响真素材显示。
	var level_id := str(data.get("level_id", ""))
	var bg_far: String = data.get("bg_far", "")
	var art_bg := "res://assets/art/bg_%s_far.png" % level_id
	if level_id != "" and ResourceLoader.exists(art_bg):
		bg_far = art_bg
	if bg_far != "":
		root.add_child(_make_parallax(bg_far))

	var spawn := DEFAULT_SPAWN
	var max_x := 640.0  # 相机右边界=最右模块+余量(半屏320px@视野640宽),随布局扩展不设硬顶

	for m in data.get("modules", []):
		var id: String = m.get("id", "")
		var pos := Vector2(m.get("px", 0.0), m.get("py", 0.0))
		max_x = maxf(max_x, pos.x + 320.0)
		if id == "spawn":
			spawn = pos
			continue
		var node := ModuleRegistry.instantiate(id, m.get("params", {}), str(data.get("level_id", "")))
		if node == null:
			continue
		node.position = pos
		node.name = "%s_%d_%d" % [id, int(pos.x), int(pos.y)]
		root.add_child(node)

	# 玩家;相机右边界跟随布局末端(阻-02:按实际布局+半屏微调,不留地图外空白,也不设上限)
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = spawn
	# 从右向左闯关(二章,2026-08-30):出生点在关卡右半时面朝左,不脸朝墙
	if spawn.x > max_x * 0.5:
		(player.get_node("Sprite2D") as Sprite2D).flip_h = true
	root.add_child(player)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.limit_right = int(max_x)

	# Conductor 节拍器(任务3):挂关卡根,MainGame 进场后播章节 BGM,全关陷阱按 120BPM 对拍
	# 动态加载:静态引用会把 Conductor 拉进启动编译链,看不到 autoload(EventBus)
	var conductor: Node = (load("res://src/flow/Conductor.gd") as GDScript).new()
	conductor.name = "Conductor"
	# 按章配轨;真素材缺失时不挂打点占位(已废弃),节拍随音乐缺失而停——交付即恢复
	var ch_key := str(data.get("level_id", "")).get_slice("_", 0)
	var bgm_path: String = BGM_TRACKS.get(ch_key, "")
	if bgm_path != "" and ResourceLoader.exists(bgm_path):
		conductor.set_meta("autoplay_track", bgm_path)
	root.add_child(conductor)

	# 关卡环境底噪(循环):按 lv 序号取素材,缺文件则静默跳过不挡路
	var lv_key := str(data.get("level_id", "")).get_slice("_", 1)
	var amb_path: String = AMBIENT_SFX.get(lv_key, "")
	if amb_path != "" and ResourceLoader.exists(amb_path):
		var amb := AudioStreamPlayer.new()
		amb.name = "LevelAmbient"
		var amb_stream: AudioStream = load(amb_path)
		if amb_stream is AudioStreamOggVorbis:
			amb_stream.loop = true
		amb.stream = amb_stream
		amb.volume_db = -6.0  # 音效层=BGM 的一半(-6dB)
		amb.autoplay = true
		root.add_child(amb)

	print("[LevelLoader] %s: %d 个模块, 出生点 %s" % [json_path, data.get("modules", []).size(), spawn])
	return root


const BG_SHADER := "res://assets/shaders/bg_dim_blur.gdshader"

static func _make_parallax(far_path: String) -> Node2D:
	# 不用 ParallaxBackground(CanvasLayer layer=-100):游戏画面在 SubViewport 里走
	# BackBufferCopy→LUT 后处理,负层画布内容与后处理采样顺序相冲,背景会被丢掉。
	# 改为普通 Node2D 视差精灵:默认画布、树顺序在关卡内容之前,后处理能采到。
	# 中景层已全部删除(2026-08-30):只留远景,调暗+轻模糊(景深),视差系数 0.15(美术案规格)
	var bg := Node2D.new()
	bg.name = "ParallaxBackground"
	if far_path != "" and ResourceLoader.exists(far_path):
		bg.add_child(_make_layer(far_path, 0.15, "Far", 1.0, false, true))
	return bg


static func _make_layer(tex_path: String, scale: float, layer_name: String, tex_scale: float, bottom_align: bool, dim_blur: bool) -> _ParallaxSprite:
	# 素材未到位(如二章bg_ch2_*)时跳过该层,不报错不挡路
	var layer := _ParallaxSprite.new()
	layer.name = layer_name
	layer.scroll_scale = scale
	layer.tex = load(tex_path)
	layer.tex_scale = tex_scale
	layer.bottom_align = bottom_align
	if dim_blur:
		var mat := ShaderMaterial.new()
		mat.shader = load(BG_SHADER) as Shader
		layer.overlay_material = mat
	return layer


# 手写视差层:两块贴图横向无缝平铺,按相机左上角的 scroll_scale 倍率慢移(与相机只横移的约定配套)。
class _ParallaxSprite:
	extends Node2D
	var scroll_scale := 0.2
	var tex: Texture2D
	var tex_scale := 1.0        # 贴图缩放(中景 0.55)
	var bottom_align := false   # true=底边对齐 360(地平线剪影),false=顶对齐
	var overlay_material: Material  # 远景调暗+模糊
	var gate_x := -1.0          # >=0 时按相机中心 x 门槛显隐(中景 a/b 分段切换)
	var gate_after := true      # true=过门槛才显示;false=过门槛隐藏
	var _sprites: Array[Sprite2D] = []

	func _ready() -> void:
		for i in 2:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.scale = Vector2(tex_scale, tex_scale)
			if overlay_material != null:
				s.material = overlay_material
			add_child(s)
			_sprites.append(s)

	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_2d()
		if cam == null or tex == null:
			return
		var center_x: float = cam.get_screen_center_position().x
		if gate_x >= 0.0:
			visible = (center_x >= gate_x) == gate_after
		var w := float(tex.get_width()) * tex_scale
		var tl: Vector2 = cam.get_screen_center_position() - get_viewport().get_visible_rect().size / 2.0 / cam.zoom.x
		var off := fmod(tl.x * scroll_scale, w)
		if off < 0.0:
			off += w
		# 屏幕 x=-off 与 -off+w 两块盖住视野;y 顶对齐 0 或底对齐 360(相机不纵移)
		var y := 360.0 - float(tex.get_height()) * tex_scale if bottom_align else 0.0
		_sprites[0].global_position = Vector2(tl.x - off, y)
		_sprites[1].global_position = Vector2(tl.x - off + w, y)
