extends SceneTree
# 判定体自动描边工具:从陷阱贴图的 alpha 通道描出多边形,内缩后写回对应 TrapConfig。
# 美术交付不规则贴图后运行一次即可,判定体永远跟随贴图轮廓(且比视觉小,擦边不死)。
# 用法: godot --headless --path <项目根> --script tools/autotrace_hitbox.gd -- [陷阱id...]
#   不带参数 = 处理 src/traps/configs/ 下全部伤害类陷阱
#   例: ... -- pendulum bottle   只处理摆锤和酒瓶

const CONFIG_DIR := "res://src/traps/configs/"


func _initialize() -> void:
	var ids: Array[String] = []
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		for f in DirAccess.get_files_at(CONFIG_DIR):
			if f.ends_with(".tres"):
				ids.append(f.get_basename())
	else:
		for a in args:
			ids.append(a)

	var ok := 0
	for id in ids:
		if _trace_one(id):
			ok += 1
	print("[描边] 完成 %d/%d" % [ok, ids.size()])
	quit(0 if ok == ids.size() else 1)


func _trace_one(id: String) -> bool:
	var cfg_path := CONFIG_DIR + id + ".tres"
	if not FileAccess.file_exists(cfg_path):
		push_error("[描边] 配置不存在: " + cfg_path)
		return false
	var cfg: TrapConfig = load(cfg_path)
	if cfg.texture == null:
		push_error("[描边] %s 无贴图" % id)
		return false

	var img := cfg.texture.get_image()
	if img == null:
		push_error("[描边] %s 贴图无法读取像素" % id)
		return false
	if not img.detect_alpha():
		print("[描边] %s 贴图无透明通道,保留矩形判定" % id)
		return true

	# alpha → 位图 → 多边形(取面积最大的一块)
	var bmp := BitMap.new()
	bmp.create_from_image_alpha(img, 0.5)
	var polys := bmp.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), 1.0)
	if polys.is_empty():
		push_error("[描边] %s 描边失败(全透明?)" % id)
		return false
	var best: PackedVector2Array = polys[0]
	for p in polys:
		if absf(_poly_area(p)) > absf(_poly_area(best)):
			best = p	# 内缩:致死陷阱判定体 < 视觉(宽容),内缩量来自 config.polygon_inset
	var inset := cfg.polygon_inset if cfg.damage > 0 else 0.0
	if inset > 0.0:
		var shrunk := Geometry2D.offset_polygon(best, -inset, Geometry2D.JOIN_MITER)
		if not shrunk.is_empty():
			best = shrunk[0]
			for p in shrunk:
				if absf(_poly_area(p)) > absf(_poly_area(best)):
					best = p

	# 图像坐标(左上原点) → 贴图注册点坐标(中心;anchor_top=顶部中点)
	var origin := Vector2(img.get_size()) / 2.0
	if cfg.anchor_top:
		origin.y = 0.0
	for i in best.size():
		best[i] = (best[i] - origin).round()

	cfg.hitbox_polygon = best
	var err := ResourceSaver.save(cfg, cfg_path)
	if err != OK:
		push_error("[描边] %s 写回失败: %s" % [id, error_string(err)])
		return false
	print("[描边] %s: %d 顶点, 内缩 %.0fpx, 已写回 %s" % [id, best.size(), inset, cfg_path])
	return true


# 鞋带公式求多边形面积(带符号)
func _poly_area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var j := (i + 1) % p.size()
		a += p[i].x * p[j].y - p[j].x * p[i].y
	return a / 2.0
