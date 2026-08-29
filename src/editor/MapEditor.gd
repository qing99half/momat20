extends Node2D
# 可视化地图编辑器:左键放置/拖动模块,右键删除,滚轮缩放,中键/方向键平移。
# 模块目录见 ModuleRegistry;存档为 res://levels/<关卡id>.json,游戏经 LevelLoader 读取。
# 启动:运行本场景(地图编辑器.bat)或 godot --path <项目> res://src/editor/MapEditor.tscn

const CELL := 8.0
const LEVEL_DIR := "res://levels/"

var _entries: Array[Dictionary] = []
var _placing: Dictionary = {}      # 正在放置的模块条目(空=未处于放置模式)
var _eraser := false               # 橡皮擦模式:左键点谁删谁
var _dragging: Node2D = null       # 正在拖动的已放置模块
var _panning := false

var _world: Node2D                 # 已放置模块的父节点
var _grid: Node2D
var _ghost: Node2D
var _camera: Camera2D
var _level_edit: LineEdit
var _status: Label
var _palette_buttons := {}         # id -> Button(高亮当前放置项)


func _ready() -> void:
	get_window().title = "momat20 地图编辑器"
	_entries = ModuleRegistry.get_entries()

	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_grid = _GridDraw.new()
	_grid.editor = self
	add_child(_grid)

	_ghost = _GhostDraw.new()
	_ghost.editor = self
	add_child(_ghost)

	_camera = Camera2D.new()
	_camera.position = Vector2(160.0, 90.0)
	_camera.zoom = Vector2(4.0, 4.0)
	add_child(_camera)
	_camera.make_current()

	_build_ui()
	# 从游戏试玩返回时自动重载刚才的关卡
	if GameState.editor_level_path != "" and FileAccess.file_exists(GameState.editor_level_path):
		_level_edit.text = GameState.editor_level_path.get_file().get_basename()
		_load_level()


# ---- UI 构建 ----

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	# 顶栏:关卡id + 操作按钮
	var top := HBoxContainer.new()
	top.position = Vector2(8.0, 6.0)
	top.add_theme_constant_override("separation", 6)
	ui.add_child(top)
	var lbl := Label.new()
	lbl.text = "关卡:"
	top.add_child(lbl)
	_level_edit = LineEdit.new()
	_level_edit.text = "ch1_lv1"
	_level_edit.custom_minimum_size = Vector2(110.0, 0.0)
	top.add_child(_level_edit)
	for spec in [["保存", _save_level], ["读取", _load_level], ["清空", _clear_level], ["试玩", _playtest], ["退出", func(): get_tree().quit()]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		top.add_child(b)

	# 左侧模块面板
	var panel := PanelContainer.new()
	panel.position = Vector2(8.0, 40.0)
	panel.size = Vector2(150.0, 640.0)
	ui.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	# 工具:橡皮擦(点选删除单个模块;任何时候也可直接右键删除)
	var tool_header := Label.new()
	tool_header.text = "【工具】"
	vbox.add_child(tool_header)
	var eraser_btn := Button.new()
	eraser_btn.text = "橡皮擦(点谁删谁)"
	eraser_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	eraser_btn.toggle_mode = true
	eraser_btn.pressed.connect(_on_eraser_pressed)
	vbox.add_child(eraser_btn)
	_palette_buttons["__eraser"] = eraser_btn
	var last_cat := ""
	for e in _entries:
		if e.category != last_cat:
			last_cat = e.category
			var header := Label.new()
			header.text = "【%s】" % last_cat
			vbox.add_child(header)
		var b := Button.new()
		b.text = e.name
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.pressed.connect(_on_palette_pressed.bind(e.id))
		vbox.add_child(b)
		_palette_buttons[e.id] = b

	# 底部状态栏
	_status = Label.new()
	_status.position = Vector2(170.0, 690.0)
	ui.add_child(_status)


func _on_palette_pressed(id: String) -> void:
	_eraser = false
	for e in _entries:
		if e.id == id:
			_placing = e
	for bid in _palette_buttons:
		_palette_buttons[bid].button_pressed = (bid == id and _placing.get("id", "") == id)


func _on_eraser_pressed() -> void:
	_eraser = true
	_placing = {}
	for bid in _palette_buttons:
		_palette_buttons[bid].button_pressed = (bid == "__eraser")


# ---- 输入 ----

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at_mouse(1.25)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at_mouse(0.8)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_left_click()
			else:
				_dragging = null
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# 右键优先删除悬停模块;没点到东西才退出当前模式
			var hovered := _pick(get_global_mouse_position())
			if hovered:
				hovered.free()
			else:
				_cancel_placing()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			_camera.position -= mm.relative / _camera.zoom.x
			_grid.queue_redraw()
		elif _dragging:
			_dragging.position = _snap(get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_DELETE or k.keycode == KEY_BACKSPACE:
			_delete_hovered()
		elif k.keycode == KEY_ESCAPE:
			_cancel_placing()
		elif k.keycode == KEY_S and k.ctrl_pressed:
			_save_level()


func _process(_delta: float) -> void:
	# 方向键平移
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		_camera.position += dir * 240.0 * _delta / _camera.zoom.x
		_grid.queue_redraw()
	# 幽灵跟随
	_ghost.queue_redraw()
	# 状态栏
	var mp := get_global_mouse_position()
	var mode := "放置:%s" % _placing.name if not _placing.is_empty() else ("橡皮擦:点谁删谁" if _eraser else ("拖动中" if _dragging else "选择模块"))
	_status.text = "%s | 格(%d,%d) px(%d,%d) | 模块数 %d | 左键放/拖 右键删 中键平移 滚轮缩放 Ctrl+S保存" % [
		mode, floori(mp.x / CELL), floori(mp.y / CELL), int(mp.x), int(mp.y), _world.get_child_count()]


func _zoom_at_mouse(factor: float) -> void:
	var before := get_global_mouse_position()
	var z := clampf(_camera.zoom.x * factor, 1.0, 8.0)
	_camera.zoom = Vector2(z, z)
	_camera.position += before - get_global_mouse_position()
	_grid.queue_redraw()


func _snap(p: Vector2) -> Vector2:
	return Vector2(snappedf(p.x, CELL), snappedf(p.y, CELL))


func _left_click() -> void:
	if _eraser:
		_delete_hovered()
		return
	if not _placing.is_empty():
		_place_module(_placing, _snap(get_global_mouse_position()))
		return
	_dragging = _pick(get_global_mouse_position())


func _pick(p: Vector2) -> Node2D:
	# 后放的优先(视觉上在最上层)
	var children := _world.get_children()
	for i in range(children.size() - 1, -1, -1):
		var node := children[i] as Node2D
		var e := ModuleRegistry.get_entry(node.get_meta("module_id"))
		if e.is_empty():
			continue
		var rect := Rect2(node.position + e.fp_offset, e.fp_size)
		if rect.has_point(p):
			return node
	return null


func _delete_hovered() -> void:
	var node := _pick(get_global_mouse_position())
	if node:
		node.free()


func _cancel_placing() -> void:
	_placing = {}
	_eraser = false
	for bid in _palette_buttons:
		_palette_buttons[bid].button_pressed = false


# ---- 放置 ----

func _place_module(e: Dictionary, pos: Vector2) -> Node2D:
	var node: Node2D
	if e.id == "spawn":
		# 出生点全关唯一:重复放置=移动旧的
		for c in _world.get_children():
			if c.get_meta("module_id") == "spawn":
				c.free()
		node = _SpawnMarker.new()
	else:
		node = ModuleRegistry.instantiate(e.id, e.params)
	if node == null:
		return null
	node.position = pos
	node.set_meta("module_id", e.id)
	node.set_meta("params", e.params.duplicate())
	_world.add_child(node)
	return node


# ---- 存档 / 读档 ----

func _level_path() -> String:
	return LEVEL_DIR + _level_edit.text.strip_edges() + ".json"


func _save_level() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LEVEL_DIR))
	var modules: Array = []
	for c in _world.get_children():
		modules.append({
			"id": c.get_meta("module_id"),
			"px": c.position.x, "py": c.position.y,
			"params": c.get_meta("params", {}),
		})
	modules.sort_custom(func(a, b): return a.px < b.px)
	var data := {
		"level_id": _level_edit.text.strip_edges(),
		"bg_far": "res://assets/placeholder/placeholder_bg_%s_far.png" % _level_edit.text.strip_edges(),
		"bg_mid": "res://assets/placeholder/placeholder_bg_%s_mid.png" % _level_edit.text.strip_edges(),
		"modules": modules,
	}
	var f := FileAccess.open(_level_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("[编辑器] 已保存 %s (%d 个模块)" % [_level_path(), modules.size()])


func _load_level() -> void:
	_clear_level()
	if not FileAccess.file_exists(_level_path()):
		print("[编辑器] 存档不存在: %s" % _level_path())
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_level_path()))
	if not (data is Dictionary):
		push_error("[编辑器] JSON 解析失败")
		return
	for m in data.get("modules", []):
		var e := ModuleRegistry.get_entry(m.get("id", ""))
		if e.is_empty():
			continue
		var node := _place_module(e, Vector2(m.get("px", 0.0), m.get("py", 0.0)))
		if node and m.get("params", {}) is Dictionary and node is PlatformModule:
			node.set_meta("params", m.params)
			node.configure(int(m.params.get("w", 3)), int(m.params.get("h", 1)), str(m.params.get("style", "platform")))
	print("[编辑器] 已读取 %s" % _level_path())


func _clear_level() -> void:
	for c in _world.get_children():
		c.free()


func _playtest() -> void:
	_save_level()
	GameState.editor_level_path = _level_path()
	get_tree().change_scene_to_file("res://src/MainGame.tscn")


# ---- 编辑器内绘图层 ----

class _GridDraw:
	extends Node2D
	var editor: Node2D

	func _draw() -> void:
		var cam: Camera2D = editor._camera
		var view: Vector2 = editor.get_viewport_rect().size / cam.zoom.x
		var tl: Vector2 = cam.position - view / 2.0
		var br: Vector2 = cam.position + view / 2.0
		var thin := 1.0 / cam.zoom.x
		var c8 := Color(1, 1, 1, 0.06)
		var c40 := Color(1, 1, 1, 0.14)
		var x := floorf(tl.x / 8.0) * 8.0
		while x <= br.x:
			draw_line(Vector2(x, tl.y), Vector2(x, br.y), c40 if int(x) % 40 == 0 else c8, thin)
			x += 8.0
		var y := floorf(tl.y / 8.0) * 8.0
		while y <= br.y:
			draw_line(Vector2(tl.x, y), Vector2(br.x, y), c40 if int(y) % 40 == 0 else c8, thin)
			y += 8.0


class _GhostDraw:
	extends Node2D
	var editor: Node2D

	func _draw() -> void:
		var thin := 2.0 / editor._camera.zoom.x
		# 橡皮擦模式:红框标出"将被删除"的悬停模块
		if editor._eraser:
			var hovered: Node2D = editor._pick(editor.get_global_mouse_position())
			if hovered:
				var he := ModuleRegistry.get_entry(hovered.get_meta("module_id"))
				if not he.is_empty():
					draw_rect(Rect2(hovered.position + he.fp_offset, he.fp_size), Color(1.0, 0.2, 0.2, 0.25), true)
					draw_rect(Rect2(hovered.position + he.fp_offset, he.fp_size), Color(1.0, 0.2, 0.2, 0.9), false, thin)
			return
		if editor._placing.is_empty():
			return
		var e: Dictionary = editor._placing
		var pos: Vector2 = editor._snap(editor.get_global_mouse_position())
		var rect := Rect2(pos + e.fp_offset, e.fp_size)
		var color := Color(0.4, 1.0, 0.6, 0.35) if e.category != "陷阱" else Color(1.0, 0.4, 0.3, 0.35)
		draw_rect(rect, color, true)
		draw_rect(rect, Color(color, 0.9), false, thin)


class _SpawnMarker:
	extends Node2D

	func _draw() -> void:
		# 小旗子:杆+三角旗,底部=出生落地线
		draw_line(Vector2.ZERO, Vector2(0, -16), Color(0.5, 0.9, 1.0), 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(10, -13), Vector2(0, -10)]), Color(0.5, 0.9, 1.0, 0.8))
