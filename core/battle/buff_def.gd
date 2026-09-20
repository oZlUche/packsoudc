## 一种增益／减益的定义（架构文档 4.5）。
##
## 战斗中一切属性变化都由 buff 承载，**包括资源上限** ——
## 「强壮」提供额外生命上限就是一条作用于 max_hp 的 mod，不为上限另开机制。
##
## buff 仅在本场战斗内存在，结束全部清空。
class_name BuffDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 仅影响 UI 配色与「净化」类效果的筛选，不影响结算
@export var is_debuff: bool = false

@export_group("叠层与时长")
## 0 = 不限层数
@export var max_stacks: int = 0
## 持续时长，秒。0 = 持续到本场战斗结束。
## 可以是任意小数 —— 模拟按时刻跳跃，不受任何「帧」粒度限制。
@export var duration_sec: float = 0.0
## 叠层时是否把时长刷新回满
@export var refresh_on_restack: bool = true

@export_group("效果")
## **每层一份**，走 4.3 公式
@export var mods: Array[StatModifier] = []
## buff 自己也能带触发规则 —— 这是「复合效果」成立的关键。
## 「灼烧：每层每秒掉 2 点血」= 挂在这里的一条 OnTick + Cooldown(1s) + DealDamage，
## BattleSim 里不需要为灼烧写任何特例。
@export var rules: Array[AbilityRule] = []
@export var on_apply: Array[Effect] = []
@export var on_expire: Array[Effect] = []


func is_valid() -> bool:
	return id != &""
