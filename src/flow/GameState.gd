extends Node
# 流程状态机(任务5.1)。autoload 单例必须继承 Node,否则引擎无法实例化。
enum State { Gameplay, Cutscene, Transition, Menu }

var current: State = State.Gameplay

# 地图编辑器试玩链路:非空时 MainGame 装载该 JSON 关卡而非默认场景,Esc 返回编辑器
var editor_level_path := ""