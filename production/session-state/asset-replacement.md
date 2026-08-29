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
| 陷阱贴图（摆锤/搓衣板/酒瓶/零件/冲压/荆棘/巨心/腐板/玻璃/声波） | ✅ 已绑 | 按关换皮 | 2026-08-29 | lv1/lv2/lv3 冒烟通过；判定只看 TrapConfig，未动 |
| trap_*_conveyor.png（ch1_lv2 / ch2_lv3） | ⚠️ 已绑但尺寸错 | 按关换皮 | 2026-08-29 | 实收 160×20，应为 **200×12**，视觉比判定小，**待美术重出** |
| trap_ch1_lv2_glass.png | ⬜ 未交付 | — | — | lv2 用了玻璃渣但 lv2 文件夹无此图，当前回退占位（红色块）；lv4 文件夹里有 lv4 版 |
| trap_*_billwind.png | 🚫 不绑 | — | — | 账单纸风设计已删，素材闲置即可 |
| bg_ch1_lv1/lv2/lv3_far | ✅ 实质已换 | `levels/*.json`（仍指 placeholder 路径，文件内容已是真图） | 用户侧操作 | lv1 far 宽 **641**（应 640，视差接缝会漂 1px，建议修）；**lv3 far 现为 640 宽，规格要求 1280 渐变长图** |
| bg 中景全部 / lv4 远景 / 三章背景 | ⬜ 占位 | `levels/*.json` | — | 待交付 |
| 道具：台灯/日记桌/摇篮 | ⬜ 占位 | Checkpoint.tscn / DiaryDesk.gd | — | 待交付；ch3 门 2 态已交付但三章场景（任务12）未建，暂不绑 |
| char_old_mother.png（160×20 8帧） | ⬜ 待绑 | 三章 NPC（任务12 未开发） | — | 绑定目标不存在，先不绑 |
| UI 全套 / LUT×5 | ⬜ 占位 | 各 UI 场景 / LutPostProcess | — | 待交付 |
| BGM M1/M2/M3/V1 | ⬜ 未交付 | Conductor / LevelLoader autoplay | — | 只有占位 wav；按章配轨无任务认领（建议并入任务10.5） |
| 音效 S01~S19 | ✅ 已接 17 / ⬜ 待挂载点 2 | `assets/audio/sfx_*.ogg`（已归位改名） | 2026-08-29 | 真素材已接：S01 跳/S02 落/S03 冲刺/S04 死亡/S13 重生（Player）、S05 台灯（Checkpoint）、S09 光屑（HUD）、S08 翻页（PageTurn）、S10 锁嗡/S11 开锁/S17 呼吸心跳（UnlockCutscene）、S07 钢笔/S06 日记开合（DiaryUI）、S19 菜单底噪（MainMenu）、S14 争吵闷响/S15 机器嗡鸣/S16 婴儿啼哭（LevelLoader 按 lv 序号循环氛围，ch2 同族命中）。**未接**：S12 door_push、S18 footsteps（三章场景任务12 未开发，无挂载点）；BGM M1/M2/M3/V1 仍未交付。循环类已设 ogg loop；三章冒烟通过无回归 |
