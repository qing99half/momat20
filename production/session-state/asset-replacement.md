# 资源替换台账（附录 E 专项一）

> 记录每个资源当前是占位还是真素材、替换时间。换绑只改路径常量/场景引用，不改代码逻辑。
> 全量审查详见 `production/session-state/art-audit.md`（`python tools/audit_art.py` 可重跑）。

## 绑定通道（2026-08-29 建成）

| 通道 | 机制 | 入口 |
|---|---|---|
| 地形（ground/platform） | `PlatformModule.tex_path`：有贴图用贴图、无贴图回退色块；**碰撞不变** | `ModuleRegistry._platform_tex()` 按 level_id 自动寻址，支持 `variant`（warm/rot/real/dream）与竖板 a/b |
| 陷阱按关换皮 | `TrapBase` 读 `meta.skin_texture`，缺图回退 TrapConfig 占位 | `ModuleRegistry._trap_skin()`；代码 id→文件后缀映射 heart_big→heart_mold、rotten→heart_platform |
| 角色 | `Player.tscn` ext_resource 直换 | 已绑 |

## 资源状态

| 资源 | 状态 | 引用位置 | 替换时间 | 备注 |
|---|---|---|---|---|
| char_young_spritesheet.png（年轻通用体 24 帧 480×20） | ✅ 真素材 | `src/player/Player.tscn` ext_resource | 2026-08-29 | 管线已加逐帧水平翻转（素材基准原朝左→朝右），左右移动冒烟验证通过 |
| 地形 ground/platform（ch1_lv1~4 / ch2_lv1~4 / ch3 地面） | ✅ 已绑 | 自动寻址 `assets/art/<level_id>/` | 2026-08-29 | 横板条带 w×10、竖板 20×h 居中于 10 厚碰撞；双态关默认 warm/real，可用 params.variant 覆盖 |
| 陷阱贴图（摆锤/搓衣板/酒瓶/零件/荆棘/巨心/腐板/玻璃/声波） | ✅ 已绑 | 按关换皮 | 2026-08-29 | 判定只看 TrapConfig，未动 |
| trap_*_thorns.png | ⚠️ 待重做 | 按关换皮 | — | 抠图毛边差；提示词已出（`AI生成提示词.md` #1，改整图不透明免抠图），生成后覆盖 ch1_lv3/ch2_lv2 同名文件即绑 |
| trap_*_press.png / trap_*_conveyor.png | ⚠️ 待重做 | 按关换皮 | — | 画风非工业真实风；conveyor 尺寸应 **200×12**（清单 L43 过期）。提示词已出（`AI生成提示词.md` #2/#3） |
| trap_*_heart_mold.png（ch1_lv3 / ch2_lv2） | ✅ 已绑+程序修图 | 按关换皮 | 2026-08-30 | 滴血效果已程序侧去除（`tools/remove_heart_drips.py`：列向最长段+底缘中值包络裁剪），原图备份 `.orig.png` |
| trap_ch1_lv2_glass.png | ⬜ 待生成 | — | — | lv2 回退占位中；提示词已出（`AI生成提示词.md` #4，60×20 整图不透明） |
| trap_*_billwind.png | 🚫 不绑 | — | — | 账单纸风设计已删，素材闲置即可 |
| bg_ch1_lv1/lv2/lv3/lv4_far | ✅ 实质已换 | `levels/*.json`（仍指 placeholder 路径，文件内容已是真图） | 用户侧操作 | **lv1 far 已程序裁回 640×360**（备份 `.orig.png`）；lv3/lv4 far 待生成 1280×360 渐变长图（提示词 `AI生成提示词.md` #5/#6）。远景调暗(0.5)+模糊(3.2px) `bg_dim_blur.gdshader`，视差 0.15 |
| bg 中景 | ✅ 过渡版转正 / 🚫 正式版删除 | `levels/*.json` + LevelLoader 中景层 | 2026-08-30 | 大面积像素内容按指示删除；`tools/gen_mid_from_far.py` 远景派生压暗层**转正式**（b 段更暗，lv3/lv4 双段切换 mid_switch_x=1400 已接通）；ch2 mid×6 已交付待 ch2 关卡 |
| trap bottle（酒瓶坠落弹体） | ✅ **已修** | MovingHazard.gd BottleProjectile | 2026-08-30 | 弹体 `setup()` 继承发射器换皮 meta，掉落酒瓶显示真贴图 |
| bg_ch2_lv1~4 far / mid(a/b) | ⬜ 已交付待挂载 | `assets/art/bg_ch2_*` | — | far×4 + mid×6 已交付；ch2 关卡 JSON 未建，建了即可绑 |
| bg_ch3 far | ✅ **已绑** | `assets/placeholder/placeholder_bg_ch3_far.png`（沿用占位路径约定） | 2026-08-30 | 用户提供 4096×768 像素老街长卷，已缩至规格 2000×360（美术案 L411）；三章场景（任务12）建好即生效。源图留存 `assets/art/_inbox_ch3_bg.png`；ch3 mid 删除（届时脚本派生） |
| 道具：台灯 prop_lamp_off/on / 日记桌 prop_diarydesk | ✅ **已绑** | Checkpoint.gd（双态换图，灭→亮）/ DiaryDesk.gd | 2026-08-30 | 交付图即终尺寸（灯 10×20、桌 21×14），缩放改 1.0，去掉占位期明暗调制 |
| 道具：摇篮 | 🚫 **已砍** | — | 2026-08-30 | 用户决定不做 |
| 道具：ch3 门 2 态 | ⬜ 已交付待场景 | — | — | `assets/art/ch3/`，三章场景（任务12）未建暂不绑 |
| char_old 全套（idle/walk/lookback/push strip + 8帧母图） | ⬜ 已交付待绑 | 三章 NPC（任务12 未开发） | — | 绑定目标不存在，先不绑 |
| ch3 地形 ground×5 双态（dream/real） | ⬜ 已交付待场景 | `assets/art/ch3/` | — | ch3 关卡未建 |
| UI 全套 | ⬜ 未交付 | 各 UI 场景 | — | 排期 H36~44（程序案 L1323）；卡笔记本定妆图（ui_notebook_reference.png，美术 H0~4 应交） |
| LUT×5 | 🚫 **已砍** | LutPostProcess | 2026-08-30 | 用户决定不做 |
| BGM M1/M2/M3_A/M3_B/V1 | ✅ 章级 BGM 已接 / ⬜ M3_B、V1 待结局场景 | `assets/audio/bgm_*.ogg`（已归位） | 2026-08-30 | LevelLoader 按章配轨：ch1→M1、ch2→M2、ch3→M3_A；**打点占位 placeholder_M1 已去除**；M3_B ending 与 V1 人声留给 ED/结局（任务12） |
| 音量分级 | ✅ 已统一 | 全部 AudioStreamPlayer | 2026-08-30 | BGM=0dB（正常），全部音效/氛围/菜单底噪=-6dB（BGM 的一半） |
| 音效 S01~S19 | ✅ 已接 17 / ⬜ 待挂载点 2 | `assets/audio/sfx_*.ogg` | 2026-08-29 | 已接：S01~S11、S13~S17、S19（Player/Checkpoint/HUD/PageTurn/UnlockCutscene/DiaryUI/MainMenu/LevelLoader 氛围）。**未接**：S12 door_push、S18 footsteps（三章场景任务12 未开发，无挂载点） |

## 2026-08-30 AI生成提示词.md 六项执行结果

| 素材 | 状态 | 绑定方式 | 日期 | 备注 |
|---|---|---|---|---|
| trap_ch1_lv3/ch2_lv2_thorns.png | ✅ 已重做交付 | 同名覆盖（旧版备份 `.prev.png`） | 2026-08-30 | 60×20 整图不透明免抠图；原图 `assets/art/_raw_thorns.png` |
| trap_ch1_lv2/ch2_lv3_press.png | ✅ 已重做交付 | 同名覆盖（备份 `.prev.png`） | 2026-08-30 | 40×40 保留深色底；原图 `_raw_press.png`（挂工厂参考图生成） |
| trap_ch1_lv2/ch2_lv3_conveyor.png | ✅ 已重做交付 | 同名覆盖（备份 `.prev.png`） | 2026-08-30 | **200×12** 正确尺寸；自动选接缝最小横带（y=468，接缝差3.6）；原图 `_raw_conveyor.png` |
| trap_ch1_lv2_glass.png | ✅ 补交付 | 新增文件 | 2026-08-30 | 60×20 整图不透明；原图 `_raw_glass.png`（挂 lv4 同款参照） |
| placeholder_bg_ch1_lv3_far.png | ✅ 1280×360 渐变长图已覆盖 | 沿用占位路径约定（备份 `.orig.png`） | 2026-08-30 | 玫瑰→荆棘粉→暗红→腐败黑红渐变；原图 `_raw_bg_lv3_far.png` |
| placeholder_bg_ch1_lv4_far.png | ✅ 1280×360 渐变长图已覆盖 | 沿用占位路径约定（备份 `.orig.png`） | 2026-08-30 | 暖室灯光→冷蓝夜街渐变；原图 `_raw_bg_lv4_far.png` |

后处理脚本：`production/process_ai_gen_assets.py`（裁剪/缩放/备份/验收一体，可重跑）。全部 RGB 不透明、尺寸验收通过；传送带平铺接缝目检图见 `production/session-state/preview_trap_ch1_lv2_conveyor_tiled.png`。
