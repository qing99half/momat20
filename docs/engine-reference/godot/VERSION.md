# Godot 版本约定

- 引擎版本: Godot **4.7.2(.NET 构建)**,脚本一律 **GDScript**(不写 C#)。
- 写码前对照《策划案-程序.md》附录 A「过时写法黑名单」。核心禁用项:
  - 节点: `TileMap` → **`TileMapLayer`**
  - 移动: `move_and_slide(velocity)` → 无参 **`move_and_slide()`**(velocity 是属性)
  - 协程: `yield(...)` → **`await`**
  - 信号连接: `xxx.connect("sig", self, "fn")` → **`xxx.sig.connect(fn)`**
  - 物理体: `KinematicBody2D` → **`CharacterBody2D`**
  - 变量注解: `export var` → **`@export var`**;`onready var` → **`@onready var`**
  - 计时: `OS.get_ticks_msec()` → **`Time.get_ticks_msec()`**
  - shader: `hint_albedo`/`SCREEN_TEXTURE` → **`source_color`** / `hint_screen_texture` + sampler
- 单向平台: 4.7 原生支持任意方向单向碰撞,不要手写 raycast 方案。