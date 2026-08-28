extends Node
# 全局事件总线(autoload)。清九只发、陈洒只听,零直接调用。信号名一字不改(任务0.2)。
# H0~2 硬约束:只声明信号,不含任何逻辑。

signal player_died
signal level_completed(level_id: String)
signal beat(beat_number: int)
signal dash_unlocked
signal diary_finished
signal door_opened