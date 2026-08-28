extends Node
# 流程状态机(任务5.1)。autoload 单例必须继承 Node,否则引擎无法实例化。
enum State { Gameplay, Cutscene, Transition, Menu }

var current: State = State.Gameplay