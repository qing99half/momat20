# 母亲二十岁

Godot 4.7.2(.NET 构建)+ GDScript 横版平台跳跃游戏。

## Autoload 登记

本项目 autoload 集中在 `project.godot` 的 `[autoload]` 段。**新增 autoload 必须在此登记。**

| 名称        | 路径                            | 职责                   |
| --------- | ----------------------------- | -------------------- |
| EventBus  | `res://src/EventBus.gd`       | 全局事件总线(仅六个信号,不新增/改名) |
| GameState | `res://src/flow/GameState.gd` | 全局游戏状态               |
| Conductor | `res://src/flow/Conductor.gd` | 音乐播放 / 「音乐骤停」        |

## Conductor(音乐指挥)

负责 BGM 播放与「音乐骤停」的最小接口:

* `play(path: String)` — 播放指定路径的 BGM。

* `stop_music_immediately()` — 音乐立即静音(骤停)。

* `is_playing() -> bool` — 是否正在播放。

> 完整节拍器(三音轨、`EventBus.beat` 节拍信号、暂停/续播、循环点)属任务 3,由清九后续补齐;此处先提供「音乐骤停」所需的最小接口。

## 音乐骤停设计

「妈妈」黑屏大字展示时音乐骤停:

* `BlackscreenText.show_text(text, big)` 中,当 `big == true`(即「妈妈」单独一屏)时调用 `Conductor.stop_music_immediately()` 立即静音。

* 静默 4 秒后(仅 S17 呼吸+心跳渐起),再由调用方走眼睑过场进入下一章。

## 陷阱碰撞箱约定(防美术绑死)

* 判定体与贴图**解耦**:判定尺寸/位置只看 `TrapConfig` 的 `hitbox_size` + `hitbox_offset`,致死判定再由基类四边各内缩 2px(`HITBOX_INSET`,擦尖不死)。
* **美术换图只换贴图,不改判定**:真素材到位后若视觉与判定错位,只调该陷阱 `.tres` 里的 `hitbox_offset`,不动代码。
* 贴图注册点统一:默认**中心点**;悬挂类(摆锤)`anchor_top=true` = 顶部中点。
* 调试验证:运行游戏按 **F3** 开关碰撞箱可视化,逐陷阱核对红框与贴图边缘。

