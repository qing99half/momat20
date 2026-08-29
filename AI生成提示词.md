# AI 生成提示词（像素陷阱 + 渐变远景）

> 用法：用本机 image_generation skill 逐条生成，按"后处理"列处理后，**文件名不变**放入"目标路径"即自动绑定（程序零改动）。
> 生成尺寸受 skill 限制（1K: 1:1/3:2/2:3；2K: 1:1/16:9），小尺寸像素件一律先生成大图再缩放到目标尺寸。
> 统一风格关键词（每条都带）：`pixel art, 20px grid retro game style, dark muted palette, limited color palette (16-24 colors), clean pixels, no anti-aliasing`

---

## 1. 荆棘丛（重做：抠图不过关 → 改整图不透明，免抠图）

- **目标路径**：`assets/art/ch1_lv3/trap_ch1_lv3_thorns.png`、`assets/art/ch2_lv2/trap_ch2_lv2_thorns.png`（同图两副本）
- **目标尺寸**：60×20px（3×1 格，可旋转；锚点左上）
- **生成规格**：2K 16:9

```
Pixel art texture strip, dense withered thorn bush growing on a dark cracked soil base, sharp thick thorns (each thorn at least 2px wide), dark red and black palette, gothic decay mood, fully opaque rectangular composition filling the entire frame edge to edge, horizontally seamless tileable, ground-level side view, pixel art, 20px grid retro game style, dark muted palette, limited color palette, clean pixels, no anti-aliasing, no transparency
```

- **后处理**：裁剪中央横条 → 缩放 60×20 → 确认四边不透明（这次就是抠图翻车，整图绘制绕开）
- **策划依据**：美术案 L590-597（枯萎荆棘/尖刺密集/可平铺/暗红+黑）

## 2. 冲压机（重做：画风不对 → 工业真实风）

- **目标路径**：`assets/art/ch1_lv2/trap_ch1_lv2_press.png`、`assets/art/ch2_lv3/trap_ch2_lv3_press.png`（同图两副本）
- **目标尺寸**：40×40px（2×2 格）
- **生成规格**：1K 1:1

```
Pixel art industrial hydraulic press machine head, heavy rusted metal piston with hydraulic rods, 1990s Chinese factory realism, worn steel texture, oil stains, rivets, dark gray and rust orange palette, viewed from front, centered composition on dark background, pixel art, 20px grid retro game style, dark muted palette, limited color palette, clean pixels, no anti-aliasing
```

- **后处理**：居中裁方 → 缩放 40×40 → 背景抠透明（主体方正好抠）或保留深色底
- **参考图**：`assets/art/_bg_reference_lv2_factory.jpg`
- **策划依据**：美术案 L677（工业冲压机头，金属+液压杆）

## 3. 传送带（重做：画风不对 + 尺寸错 160×20 → 200×12）

- **目标路径**：`assets/art/ch1_lv2/trap_ch1_lv2_conveyor.png`、`assets/art/ch2_lv3/trap_ch2_lv3_conveyor.png`（同图两副本）
- **目标尺寸**：**200×12px**（10 格长薄带，可平铺；⚠ 关卡素材清单 L43 的 160×20 是过期文档，勿用）
- **生成规格**：2K 16:9

```
Pixel art seamless tileable industrial conveyor belt surface texture, very thin horizontal strip, worn metal belt with roller edges, rust and scratches, 1990s Chinese factory realism, dark gray metal with orange rust accents, strictly horizontal band composition filling frame width, left-right edges must match for seamless tiling, pixel art, 20px grid retro game style, dark muted palette, limited color palette, clean pixels, no anti-aliasing
```

- **后处理**：裁出中间最均匀的一条横带 → 缩放 200×12 → 平铺接缝目检（左右拼一次看断不断）
- **策划依据**：素材体系重设计 L46 / 美术案 L570-572（金属质感可平铺薄带）

## 4. 碎玻璃渣（补交付：lv2 缺失）

- **目标路径**：`assets/art/ch1_lv2/trap_ch1_lv2_glass.png`
- **目标尺寸**：60×20px（3×1 格，可旋转）
- **生成规格**：2K 16:9

```
Pixel art strip of shattered glass shards scattered on dark ground, sharp broken bottle glass fragments, dark green glass with pale highlight edges, dangerous spike strip, fully opaque rectangular composition filling the frame, horizontally seamless tileable, pixel art, 20px grid retro game style, dark muted palette, limited color palette, clean pixels, no anti-aliasing, no transparency
```

- **后处理**：同荆棘（裁横条 → 60×20 → 整图不透明）
- **同款参照**：`assets/art/ch1_lv4/trap_ch1_lv4_glass.png`（lv4 已交付版）

## 5. lv3 远景长图（补规格：640 → 1280×360 渐变）

- **目标路径**：`assets/placeholder/placeholder_bg_ch1_lv3_far.png`（覆盖，沿用现约定）
- **目标尺寸**：1280×360px
- **生成规格**：2K 16:9

```
Side-scrolling game background, wide panoramic gradient from left to right: blooming rose garden in soft pink romantic light on the left third, roses wilting and darkening with more thorns in the middle third, dense corrupted thorn thicket with rotten black-red flowers on the right third, smooth continuous color transition pink -> dark red -> corrupted black-red, no abrupt color blocks, 1990s realistic painterly style, muted film grain, no characters, no text
```

- **后处理**：裁横向长条 → 缩放 1280×360
- **策划依据**：美术案 L460-467（玫瑰→荆棘渐变，30 秒滚过）

## 6. lv4 远景长图（补规格：640 → 1280×360 渐变）

- **目标路径**：`assets/placeholder/placeholder_bg_ch1_lv4_far.png`（覆盖）
- **目标尺寸**：1280×360px
- **生成规格**：2K 16:9

```
Side-scrolling game background, wide panoramic gradient from left to right: warm dim interior of a poor 1990s Chinese home with a single lamp and baby bottle silhouettes on the left, gradually transitioning to a cold blue-gray empty night street on the right, smooth continuous warm-to-cold transition, realistic painterly style, muted film grain, lonely mood, no characters, no text
```

- **后处理**：同上 → 1280×360
- **策划依据**：美术案 L410/L417（暖色灯光→冷色街道）

---

## 已删除（大面积像素内容，按指示不要了）

| 项 | 处理 |
|---|---|
| ch1 正式中景 ×6（800×360 透明剪影） | **删除**。过渡版（远景派生压暗层）转正式使用，画面已验证 |
| ch3 中景（1000×360） | **删除**。三章场景（任务12）建时用同脚本从远景派生即可 |

## 不需要生成的（已解决）

酒瓶弹体贴图（程序已修 skin 继承）、腐心滴血（程序已去除）、lv1 far 641px（程序已裁）、台灯/日记桌（已绑）、LUT/摇篮（已砍）。
