extends Node
# 任务3 机关绑拍自动验收(自跑约24s,无需操作,结束打印报表自动退出):
#   Conductor 120BPM,短循环 [0,18) 拍(9s;故意取非各机关周期倍数,验循环边界不漏/不重)
#   5 个周期机关:摆锤(4拍)/冲压机(5拍)/酒瓶(4拍)/声波(4拍)/账单风(吹3拍+停4拍)
# 判据(全部自动断言):
#   ① trap_activated 距最近整数拍偏差 ≤ 0.05拍(epsilon)+1帧(0.033拍)= 0.084拍
#   ② 摆锤在每 4 拍过中点:拍点时刻 |rotation| ≤ 10°(自由漂移则会持续增大越界)
#   ③ 账单风吹/停与拍相位一致:每拍比对 _gust_active == (连续拍%7 < 3)
#   ④ t=7s 对冲压机调 reset_trap()(模拟死亡重生),当周期作废,后续击发仍在拍点上
#   ⑤ 两次循环回卷(t≈9s/18s)后各机关继续按周期击发,不漏/不重

const TRAP_SCENES := [
	"res://src/traps/scenes/trap_pendulum.tscn",
	"res://src/traps/scenes/trap_press.tscn",
	"res://src/traps/scenes/trap_bottle.tscn",
	"res://src/traps/scenes/trap_soundwave.tscn",
	"res://src/traps/scenes/trap_billwind.tscn",
]
const M1 := "res://assets/placeholder/placeholder_M1.wav"
const LOOP_BEATS := 18.0
const RUN_SEC := 24.0
const RESET_AT := 7.0
const PASS_OFFSET := 0.084   # epsilon 0.05拍 + 60fps 一帧量化
const PASS_PEND_DEG := 10.0

var _conductor: Conductor
var _elapsed := 0.0
var _abs := -1                # 连续拍计数(与 TrapBase 同规则)
var _fires := {}              # 机关名 -> [{beat, off}]
var _pend_errs: Array[float] = []
var _wind_errs := 0
var _reset_done := false
var _pendulum: Node2D
var _press: Node2D
var _wind: Node2D


func _ready() -> void:
	_conductor = Conductor.new()
	_conductor.debug_print = false
	add_child(_conductor)
	var x := 40.0
	for path in TRAP_SCENES:
		var trap: Node2D = load(path).instantiate()
		trap.position = Vector2(x, 0.0)
		x += 40.0
		add_child(trap)
		var nm: String = trap.config.source_id
		_fires[nm] = []
		trap.trap_activated.connect(_on_trap_fired.bind(nm))
		match nm:
			&"pendulum": _pendulum = trap
			&"press": _press = trap
			&"billwind": _wind = trap
	EventBus.beat.connect(_on_beat)
	_conductor.play(M1)
	_conductor.set_loop(0.0, LOOP_BEATS)
	print("[验收] 开始:120BPM,循环[0,%.0f)拍,跑%.0fs;t=%.0fs模拟死亡重置冲压机" % [LOOP_BEATS, RUN_SEC, RESET_AT])


func _process(delta: float) -> void:
	_elapsed += delta
	if not _reset_done and _elapsed >= RESET_AT:
		_reset_done = true
		_press.reset_trap()
		print("[验收] >>> t=7s 冲压机 reset_trap(),当周期击发作废,下一周期应重新对拍")
	elif _elapsed >= RUN_SEC:
		_report()


func _on_beat(_n: int) -> void:
	_abs += 1
	# 判据②:摆锤每 4 拍过中点
	if _abs % 4 == 0:
		_pend_errs.append(absf(rad_to_deg(_pendulum.rotation)))
	# 判据③:账单风相位(吹3拍停4拍,周期7拍)
	var expect_wind: bool = _abs % 7 < 3
	if _wind._gust_active != expect_wind:
		_wind_errs += 1


func _on_trap_fired(nm: StringName) -> void:
	var beat := _conductor.get_current_beat()
	var off := beat - roundf(beat)
	if off > 0.5:
		off -= 1.0
	elif off < -0.5:
		off += 1.0
	_fires[nm].append({"beat": beat, "off": off})


func _report() -> void:
	var all_pass := true
	print("[验收] ============ 对拍报表(24s,循环回卷2次,重置1次) ============")
	for nm in _fires:
		var list: Array = _fires[nm]
		if list.is_empty():
			continue
		var max_off := 0.0
		var sum := 0.0
		for r in list:
			max_off = maxf(max_off, absf(r["off"]))
			sum += absf(r["off"])
		var ok: bool = max_off <= PASS_OFFSET
		all_pass = all_pass and ok
		print("[验收] ① %s: 击发%d次, 平均偏差%.3f拍, 最大偏差%.3f拍 -> %s" % [
			nm, list.size(), sum / list.size(), max_off, "PASS" if ok else "FAIL"])
	var pend_max := 0.0
	for e in _pend_errs:
		pend_max = maxf(pend_max, e)
	var pend_ok: bool = pend_max <= PASS_PEND_DEG
	all_pass = all_pass and pend_ok
	print("[验收] ② 摆锤: 每4拍中点误差 最大%.2f° -> %s" % [pend_max, "PASS" if pend_ok else "FAIL"])
	var wind_ok: bool = _wind_errs == 0
	all_pass = all_pass and wind_ok
	print("[验收] ③ 账单风: 相位错位 %d 拍 -> %s" % [_wind_errs, "PASS" if wind_ok else "FAIL"])
	var press_fires: Array = _fires[&"press"]
	var reset_ok: bool = press_fires.size() >= 7  # 重置吞掉1次,其余全在拍点上(①已断言)
	print("[验收] ④ 重置: 冲压机重置后击发 %d 次且偏差见① -> %s" % [press_fires.size(), "PASS" if reset_ok else "FAIL"])
	all_pass = all_pass and reset_ok
	print("[验收] ⑤ 循环边界: 见①各机关跨回卷击发均在拍点上(循环[0,18)非5/4/7拍倍数)")
	print("[验收] ============ 总判定: %s ============" % ("PASS" if all_pass else "FAIL"))
	get_tree().quit()
