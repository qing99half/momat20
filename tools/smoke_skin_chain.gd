extends SceneTree
# 换皮回退链冒烟:ch2 四关 × 全部陷阱/平台,验证跨关复用都能命中真美术(不掉色块)
# 用法: godot --headless --script tools/smoke_skin_chain.gd

func _init() -> void:
	var MR: GDScript = load("res://src/editor/ModuleRegistry.gd")
	var traps := ["washboard", "pendulum", "bottle", "glass", "soundwave", "billwind",
			"thorns", "conveyor", "press", "part", "heart_big", "rotten", "lamp"]
	var levels := ["ch2_lv1", "ch2_lv2", "ch2_lv3", "ch2_lv4"]
	var fails := 0
	for lv in levels:
		print("== %s ==" % lv)
		for t in traps:
			var skin: String = MR._trap_skin(lv, t)
			var any := false
			for any_lv in ["ch1_lv1", "ch1_lv2", "ch1_lv3", "ch1_lv4",
					"ch2_lv1", "ch2_lv2", "ch2_lv3", "ch2_lv4"]:
				if ResourceLoader.exists("res://assets/art/%s/trap_%s_%s.png" % [any_lv, any_lv, t]):
					any = true
					break
			if any and skin == "":
				print("  [FAIL] %s 全库有美术却解析为空" % t)
				fails += 1
			elif skin != "":
				print("  %s -> %s" % [t, skin.get_file()])
		for w in [1, 2, 3, 4, 5]:
			var g: String = MR._platform_tex(lv, "ground", w, 1, "", "a")
			var p: String = MR._platform_tex(lv, "platform", w, 1, "", "a")
			if g == "" or p == "":
				print("  [FAIL] ground/platform %dw 解析为空 (g=%s p=%s)" % [w, g, p])
				fails += 1
	print("RESULT: %s" % ("PASS" if fails == 0 else "FAIL(%d)" % fails))
	quit()
