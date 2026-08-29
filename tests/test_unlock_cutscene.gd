extends Node
# 任务11.2~11.6 验收测试:模拟 ch2_lv4 集齐4片的状态,直接触发开锁演出,
# 验证全链路无报错跑完(黑屏→特写→光片飞→锁开→白光→黑屏大字→"妈妈"骤停→切场景进三章)。
# 运行:godot --headless --path <项目根> --quit-after 800 res://tests/test_unlock_cutscene.tscn
# 演出总时长约 10.6s ≈ 640 帧;800 帧足够看到切场景后的 MainGame。

func _ready() -> void:
	# 模拟任务11.1 的产出状态:二章末关 + 4片集齐
	GameState.current_level_index = 7  # ch2_lv4
	GameState.current_chapter = 2
	GameState.collected_fragments = 4
	GameState.unlock_pending = true

	var layer := CanvasLayer.new()
	add_child(layer)

	# 黑屏大字组件(正常由 MainGame 挂载,这里补一个)
	var bs: ColorRect = load("res://src/ui/BlackscreenText.tscn").instantiate()
	bs.visible = false
	bs.add_to_group("blackscreen_text")
	layer.add_child(bs)

	var uc: Control = load("res://src/ui/UnlockCutscene.tscn").instantiate()
	uc.add_to_group("unlock_cutscene")
	layer.add_child(uc)

	uc.trigger_unlock_cutscene()
	print("[测试] 开锁演出已触发,等待全链路跑完并切场景...")
	# 注:本节点随切场景销毁,不写事后校验;演出链路跑通的证据=切场景后新 MainGame 打印
	# "[MainGame] res://levels/ch3.json 不存在,回退默认场景"(ch3 未搭建,任务12 待做)
