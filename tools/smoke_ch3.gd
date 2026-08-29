extends SceneTree
# ch3 演出关全流程冒烟:模拟按住←,每2秒 dump 玩家/母亲/滚屏/相机/音频状态。
# 用法: godot --headless --path . --script tools/smoke_ch3.gd
# 注意:--script 模式下 autoload 不可编译期直引,一律 root.get_node 动态获取。

var _t := 0.0
var _next_dump := 1.0
var _level: Node2D
var _started := false


func _initialize() -> void:
	pass


func _boot() -> void:
	var gs := root.get_node_or_null("/root/GameState")
	if gs:
		gs.set("current_level_index", 8)  # 链索引 8=ch3
		gs.set("current_chapter", 3)
		gs.set("current", 0)  # State.Gameplay
	else:
		print("[smoke_ch3] FAIL: 拿不到 GameState autoload")
	var mg := (load("res://src/MainGame.tscn") as PackedScene).instantiate()
	root.add_child(mg)
	current_scene = mg
	Input.action_press("ui_left")  # 全程按住←
	print("[smoke_ch3] 进场完成,开始模拟")


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		_boot()
		return false
	_t += delta
	if _level == null:
		_level = current_scene.get_node_or_null("GameLayer/SubViewport/LevelCh3")
		if _level:
			var ui := current_scene.get_node_or_null("UILayer")
			var names: Array[String] = []
			for c in ui.get_children():
				names.append(c.name)
			print("[smoke_ch3] UILayer 子节点顺序(后者画在上层): %s" % [names])
	if _level and _t >= _next_dump:
		_next_dump += 2.0
		var p = _level.get_node_or_null("Player")
		var m = _level.get_node_or_null("Mother")
		var cam := _level.get_node_or_null("Camera2D") as Camera2D
		var far := _level.get_node_or_null("Background/Far") as Sprite2D
		var mid0 := _level.get_node_or_null("Background/Mid") as Sprite2D
		print("[smoke_ch3] t=%.1fs 阶段%d 滚屏%.0f | 玩家(%.0f,%.0f)帧%d flip=%s | 母亲(%.0f,%.0f)帧%d walk=%s | 相机启用=%s@(%.0f,%.0f) | Far.x=%.0f Mid0.x=%.0f" % [
			_t, _level.get("_phase"), _level.get("_scroll"),
			p.global_position.x, p.global_position.y, (p.get_node("Sprite2D") as Sprite2D).frame, (p.get_node("Sprite2D") as Sprite2D).flip_h,
			m.global_position.x, m.global_position.y, (m.get_node("Sprite2D") as Sprite2D).frame, m.get("walking"),
			cam.enabled, cam.global_position.x, cam.global_position.y,
			far.position.x, mid0.position.x])
		for c in _level.get_children():
			if c is AudioStreamPlayer:
				print("    音频: playing=%s stream=%s vol=%.1f loop=%s" % [c.playing, c.stream.resource_path.get_file() if c.stream else "无", c.volume_db, c.stream.loop if c.stream is AudioStreamOggVorbis else "?"])
	if _t > 45.0:
		print("[smoke_ch3] 超时结束(45s 未完成推门=卡死)")
		return true
	return false
