class_name TrapConfig
extends Resource
# 陷阱配置资源(任务2):一切参数走配置,行为类脚本不硬编码。
# 单位:像素/秒,1格=8px。周期必须 ∈ {1.0,1.5,2.0,2.5,3.0} 秒(=120BPM半拍整数倍)。

@export var source_id: StringName = &"trap"
@export var damage: int = 1                 # 0=不致死(外力区域/腐心平台)
@export var knockback := Vector2.ZERO       # 传给 player.receive_hazard 的击退
@export var texture: Texture2D              # 贴图(占位期=placeholder_trap_*)
@export var droplet_texture: Texture2D      # 滴液模式的液滴贴图
@export var hitbox_size := Vector2(8.0, 8.0)  # 贴图尺寸(px);致死判定体由基类四边各内缩2px
@export var anchor_top := false             # true=锚点在顶部中点(摆锤悬挂)

@export_group("预警(两层)")
@export var warn_duration := 0.8            # 持续态预警≥0.5s(摇晃/收缩/阴影动效)
@export var flash_frames := 2               # 击发前白闪帧数(强调,非预警本体)

@export_group("周期")
@export var period := 2.0                   # 周期(秒)
@export var amplitude := 60.0               # 摆锤=摆角(度);冲压=下砸行程(px);声波=扩散半径(px)
@export var active_duration := 0.4          # 激活(有伤害)窗口时长

@export_group("行为模式")
@export var motion := 0                     # MovingHazard: 0=摆锤(正弦旋转) 1=坠落
@export var timed_mode := 0                 # TimedHazard: 0=冲压 1=腐心平台 2=滴液 3=声波
@export var fall_distance := 40.0           # 坠落/滴液距离(px,5格=40)
@export var droplet_size := 8.0             # 滴液模式的液滴尺寸(px),判定体按它缩放
@export var push := Vector2.ZERO            # ForceZone 推动速度(px/s,直接位移推动)
@export var gust_on := 0.0                  # 阵风:吹风时长(0=恒力)
@export var gust_off := 0.0                 # 阵风:停风时长

@export_group("腐心平台")
@export var crumble_delay := 1.0            # 踩上到碎裂的延迟
@export var respawn_delay := 3.0            # 碎裂后重生延迟
