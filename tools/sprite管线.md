# Sprite 工具管线（agent-sprite-forge 已接入，待生成）

> 状态：**工具已补齐，未进行任何生成**。
> 仓库副本：`tools/agent-sprite-forge/`（GitHub zip 快照，2026-08-29；直连 git clone 不通，走 codeload 压缩包）
> 依赖：Pillow 12.2 / numpy 2.4.4（托管 Python 已自带，无需安装）；自带测试 13/13 通过。

## 一、管线分工

```
我（image_generation 插件生图，挂定妆图做参考）
  → tools/agent-sprite-forge 的 Python 脚本后处理（抠底/切帧/对齐/校验）
  → 按《素材体系重设计.md》20px 格规格验收
  → 导出到 assets/art/
```

生图环节不用仓库原设计的 Codex 内置生图，改用本机 image_generation 插件；
后处理脚本是通用的，直接可用。

## 二、关键脚本速查

| 脚本 | 用途 |
|---|---|
| `skills/generate2dsprite/scripts/make_layout_guide.py` | 生成"布局参考图"（格子+安全边距），生图时挂它控制帧排布 |
| `skills/generate2dsprite/scripts/generate2dsprite.py build-prompt` | 按模式拼生图提示词 |
| `skills/generate2dsprite/scripts/generate2dsprite.py process` | 后处理：色度抠底→切帧→对齐→透明 PNG/GIF→QC 元数据 |
| `skills/generate2dmap/scripts/extract_terrain_tiles.py` | 从背景图抽 20×20 地形 tile |
| `skills/generate2dmap/scripts/extract_prop_pack.py` | 道具包切分 |

## 三、本项目规格映射（以《素材体系重设计.md》为准，旧 24px 作废）

| 素材 | 目标画布 | 帧/格 | process 命令要点 |
|---|---|---|---|
| `char_young_spritesheet.png` | 480×20 | 24 帧 20×20（1 行 24 列） | `--target player --mode player_actions --rows 1 --cols 24 --cell-size 20 --align feet --strict-qc` |
| `char_old_mother.png` | 160×20 | 8 帧 20×20 | `--target npc --mode npc_walk --rows 1 --cols 8 --cell-size 20 --align feet` |
| 背景远/中景 ×13 | 800×180 起（关3/4: 1280×180；三章: 2000×180 / mid 1000×180） | 单图 | 不走 sprite 脚本，直接生图+按尺寸验收 |
| 平台/地面 tile ×9 套 | 20×20 tile + 20×20 顶边 | 可平铺 | 生图后用 `extract_terrain_tiles.py` 抽 tile |
| 陷阱/道具（摆锤/搓衣板等 12 种） | 见重设计文档尺寸表 | 1~3 态 | `--target asset --mode sheet --cell-size <对应尺寸>` |

注意：AI 生图无法直接出 480×20 这种细条，实际做法是**生成大尺寸网格图（如 24 列布局参考图）→ process 切帧 → 程序侧缩放到 20×20 逐帧验收**。

## 四、开工时的标准动作（生成前检查单）

1. 定妆图已存在并通过审阅（`char_young_reference.png` 等）
2. `make_layout_guide.py --rows 1 --cols 24 --cell-width <大图格宽> --cell-height <大图格高> --output guide.png` 先出布局参考图
3. 生图提示词：定妆图 + 布局参考图 + 纯品红底 `#FF00FF`（方便色度抠底）
4. `process` 后处理，看 QC 元数据里帧数/对齐是否达标
5. 验收标准见主会话复述的清单（尺寸/帧数/透明通道/不出盒）

## 五、已知限制

- `video2dsprite` 依赖 Grok 的 image_to_video，本机不可用；走位循环用生图+切帧路线
- `build-godot-bundle` 输出 Sprite3D 元数据，本项目 Godot 4 用 Sprite2D/AnimatedSprite2D，元数据仅作参考
