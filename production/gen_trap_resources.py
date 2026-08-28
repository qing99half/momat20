# -*- coding: utf-8 -*-
# 生成 12 个陷阱的 TrapConfig(.tres) 与可拖拽场景(.tscn),输出到 src/traps/。
# 数值来源:策划案-程序任务2 + 策划案-美术音乐陷阱清单(D-509 尺寸)。
import os

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "traps")
CFG_DIR = os.path.join(BASE, "configs")
SCN_DIR = os.path.join(BASE, "scenes")
os.makedirs(CFG_DIR, exist_ok=True)
os.makedirs(SCN_DIR, exist_ok=True)

# name, 行为脚本, 贴图, 尺寸, damage, 额外字段
TRAPS = [
    # SpikeStrip 静态尖刺带(换贴图+判定尺寸)
    ("washboard", "SpikeStrip", "placeholder_trap_washboard", (24, 8), 1, {}),
    ("part", "SpikeStrip", "placeholder_trap_part", (24, 8), 1, {}),
    ("thorns", "SpikeStrip", "placeholder_trap_thorns", (24, 8), 1, {}),
    ("glass", "SpikeStrip", "placeholder_trap_glass", (24, 8), 1, {}),
    # ForceZone 外力区域(damage=0)
    ("conveyor", "ForceZone", "placeholder_trap_conveyor", (64, 8), 0,
     {"push": "Vector2(45, 0)"}),    # 带速=跑速50%(90px/s × 50%)
    ("billwind", "ForceZone", "placeholder_trap_billwind", (8, 12), 0,
     {"push": "Vector2(-45, 0)", "gust_on": 1.5, "gust_off": 2.0}),
    # MovingHazard
    ("pendulum", "MovingHazard", "placeholder_trap_pendulum", (16, 48), 1,
     {"motion": 0, "amplitude": 60.0, "period": 2.0, "anchor_top": "true"}),
    ("bottle", "MovingHazard", "placeholder_trap_bottle", (8, 8), 1,
     {"motion": 1, "fall_distance": 40.0, "period": 2.0, "warn_duration": 0.8}),
    # TimedHazard
    ("press", "TimedHazard", "placeholder_trap_press", (16, 16), 1,
     {"timed_mode": 0, "period": 2.5, "warn_duration": 0.8, "amplitude": 16.0, "active_duration": 0.4}),
    ("rotten", "TimedHazard", "placeholder_platform_rotten", (16, 8), 0,
     {"timed_mode": 1, "crumble_delay": 1.0, "respawn_delay": 3.0}),
    ("heart_big", "TimedHazard", "placeholder_trap_heart_big", (24, 24), 1,
     {"timed_mode": 2, "period": 2.0, "warn_duration": 0.8, "fall_distance": 40.0,
      "_droplet_tex": "placeholder_trap_droplet"}),
    ("soundwave", "TimedHazard", "placeholder_trap_soundwave", (24, 16), 1,
     {"timed_mode": 3, "period": 2.0, "warn_duration": 0.8, "amplitude": 24.0, "active_duration": 0.8}),
]

TRES_TMPL = """[gd_resource type="Resource" script_class="TrapConfig" load_steps={steps} format=3]

[ext_resource type="Script" path="res://src/traps/TrapConfig.gd" id="1_cfg"]
[ext_resource type="Texture2D" path="res://assets/placeholder/{tex}.png" id="2_tex"]
{droplet_ext}
[resource]
script = ExtResource("1_cfg")
source_id = &"{name}"
damage = {damage}
texture = ExtResource("2_tex")
{droplet_ref}hitbox_size = Vector2({w}, {h})
{extra}"""

SCN_TMPL = """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://src/traps/{script}.gd" id="1_gd"]
[ext_resource type="Resource" path="res://src/traps/configs/{name}.tres" id="2_cfg"]

[node name="Trap{NameTitle}" type="Area2D"]
script = ExtResource("1_gd")
config = ExtResource("2_cfg")
"""

for name, script, tex, (w, h), damage, extra in TRAPS:
    droplet_tex = extra.pop("_droplet_tex", None)
    steps = 3 + (1 if droplet_tex else 0)
    droplet_ext = ""
    droplet_ref = ""
    if droplet_tex:
        droplet_ext = '[ext_resource type="Texture2D" path="res://assets/placeholder/%s.png" id="3_drop"]\n' % droplet_tex
        droplet_ref = 'droplet_texture = ExtResource("3_drop")\n'
    extra_lines = "".join("%s = %s\n" % (k, v) for k, v in extra.items())
    tres = TRES_TMPL.format(steps=steps, tex=tex, droplet_ext=droplet_ext, name=name,
                            damage=damage, droplet_ref=droplet_ref, w=w, h=h, extra=extra_lines)
    with open(os.path.join(CFG_DIR, name + ".tres"), "w", encoding="utf-8") as f:
        f.write(tres)
    scn = SCN_TMPL.format(script=script, name=name, NameTitle=name.capitalize())
    with open(os.path.join(SCN_DIR, "trap_%s.tscn" % name), "w", encoding="utf-8") as f:
        f.write(scn)
    print("ok", name, script, "%dx%d" % (w, h))

print("DONE")
