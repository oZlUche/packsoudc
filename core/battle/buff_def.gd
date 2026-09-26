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
## 088：别的语言的名字，`{"en": "Knife"}`；界面用 [method Names.of] 取（当前语言没有就用 display_name）
@export var display_names: Dictionary = {}
## 仅影响 UI 配色与「净化」类效果的筛选，不影响结算
@export var is_debuff: bool = false

@export_group("叠层与时长")
## 0 = 不限层数
@export var max_stacks: int = 0
## 时长，秒。作者定的规矩（085）：**可叠层的 buff 永续**（`max_stacks != 1`：中毒、流血、结界……叠上就一直在，直到被清除或战斗结束），
## 这个字段对它们不生效、导入器也不许填；**不可叠层的**（`max_stacks == 1`，往往是「满足 X 条件时获得 ABC」那种复杂的）才可以过期，
## 0 = 也永续。可以是任意小数（模拟按时刻跳跃，不受「帧」粒度限制）
@export var duration_sec: float = 0.0
## 叠层时是否把时长刷新回满（只对会过期的有意义）
@export var refresh_on_restack: bool = true


## 可叠层：层数上限不是 1（0 = 不限也算可叠）
func is_stackable() -> bool:
	return max_stacks != 1


## 永续：不过期，到战斗结束 —— 可叠层的一律永续；不可叠层的没填时长也永续
func is_permanent() -> bool:
	return is_stackable() or duration_sec <= 0.0


## 给界面看的时长一句：「永续」/「持续 N 秒」
func duration_text() -> String:
	return "永续" if is_permanent() else "持续 %.1f 秒" % duration_sec

@export_group("效果")
## **每层一份**，走 4.3 公式
@export var mods: Array[StatModifier] = []
## buff 自己也能带触发规则 —— 这是「复合效果」成立的关键。
## 「灼烧：每层每秒掉 2 点血」= 挂在这里的一条 OnTick + Cooldown(1s) + DealDamage，
## BattleSim 里不需要为灼烧写任何特例。
@export var rules: Array[AbilityRule] = []
@export var on_apply: Array[CombatEffect] = []
@export var on_expire: Array[CombatEffect] = []


func is_valid() -> bool:
	return id != &""
