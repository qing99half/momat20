# 资源替换台账（附录 E 专项一）

> 记录每个资源当前是占位还是真素材、替换时间。换绑只改路径常量/场景引用，不改代码逻辑。

| 资源 | 状态 | 引用位置 | 替换时间 | 备注 |
|---|---|---|---|---|
| char_young_spritesheet.png（年轻通用体 24 帧 480×20） | ✅ 真素材 | `src/player/Player.tscn` ext_resource | 2026-08-29 | 来自 `assets/art/char-young/`（assemble_spritesheet_v2 管线）；逐帧 QA 通过；**素材基准帧原朝左，管线已加逐帧水平翻转为朝右**（代码约定 flip_h=dir<0，改图不改码），左右移动冒烟验证通过 |
| ground_ch1_lv1_1w~5w / platform_ch1_lv1_* | ⬜ 未绑 | — | — | PlatformModule 无贴图通道，且横/竖平台图与 10px 薄板厚度不匹配，待决策 |
| bg_ch1_lv1_far/mid | 占位 | `levels/ch1_lv1.json` | — | |
| 其余陷阱/道具/UI/音频 | 占位 | 各 .tres/.tscn | — | |
