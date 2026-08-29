extends Node
# 流程状态机(任务5.1)+ 关卡链与章节状态(任务10.5)。autoload 单例必须继承 Node,否则引擎无法实例化。
enum State { Gameplay, Cutscene, Transition, Menu }

var current: State = State.Gameplay

# 地图编辑器试玩链路:非空时 MainGame 装载该 JSON 关卡而非默认场景,Esc 返回编辑器
var editor_level_path := ""

# ---- 关卡链(任务10.5):关级转场=翻页(PageTurn),章级转场=眼睑过场(EyelidTransition) ----
# 索引 0~3=一章,4~7=二章,8=三章。autoload 切场景不销毁,章节/光片计数都放这里,
# 不能放 DiaryUI/HUD(方案A 每关重建场景,放 UI 里会被清零)。
const LEVEL_CHAIN: Array[String] = [
	"ch1_lv1", "ch1_lv2", "ch1_lv3", "ch1_lv4",
	"ch2_lv1", "ch2_lv2", "ch2_lv3", "ch2_lv4",
	"ch3",
]

var current_level_index := 0
var current_chapter := 1
var collected_fragments := 0       # 记忆光片计数(二章专属收集物,任务10/11.1)
var unlock_pending := false        # 集齐4片且位于 ch2_lv4:关底不翻页,改播开锁演出(任务11.2+ 接管)
var chapter_intro_pending := false # 章级过场后,新场景第一眼保持闭眼再睁开(MainGame._ready 消费)


func current_level_id() -> String:
	return LEVEL_CHAIN[current_level_index]


## 推进到下一关;返回 "level"(关内翻页)/ "chapter"(章级过场)/ "end"(全链走完)。
func advance_level() -> String:
	if current_level_index >= LEVEL_CHAIN.size() - 1:
		return "end"
	var prev_chapter := current_chapter
	current_level_index += 1
	current_chapter = _chapter_of(current_level_index)
	print("[GameState] 关卡推进 -> %s (index=%d, chapter=%d)" % [current_level_id(), current_level_index, current_chapter])
	return "chapter" if current_chapter != prev_chapter else "level"


func _chapter_of(index: int) -> int:
	if index < 4:
		return 1
	if index < 8:
		return 2
	return 3


## 编辑器试玩等旁路进关时按关卡 id 同步章节(HUD 门控/冲刺解锁据此判定),不动链进度。
func sync_chapter_from_level_id(level_id: String) -> void:
	if level_id.begins_with("ch3"):
		current_chapter = 3
	elif level_id.begins_with("ch2"):
		current_chapter = 2
	else:
		current_chapter = 1


## 任务11.1(修正版):光片飞入 HUD 时由 HUD 调用;计数放这里,切场景不丢。
## 集齐 4 片且当前关是 ch2_lv4 → 置 unlock_pending 并返回 true(调用方不翻页,改播开锁演出)。
func add_fragment() -> bool:
	collected_fragments += 1
	print("[GameState] 记忆光片 %d/4" % collected_fragments)
	if collected_fragments >= 4 and current_level_id() == "ch2_lv4":
		unlock_pending = true
		print("[GameState] 集齐四片,应播开锁演出 trigger_unlock_cutscene()(任务11.2+ 待做)")
		return true
	return false
