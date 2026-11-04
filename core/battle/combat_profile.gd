## 物品的战斗定义。没有这个字段的物品不参战（纯素材、纯包体等）。
##
## [b]这里不再有 is_active 与 cooldown_sec。[/b]
## 「是否主动」由 rules 是否为空决定；冷却是 [CooldownCadence] 的参数。
## 把触发时机与频率写死成字段，正是架构文档 4.4 明令禁止的。
class_name CombatProfile
extends Resource

## 基础属性，键见 [BattleStats]。编辑器里写浮点，编译期转定点。
##     {"damage": 10.0, "max_stamina": 100.0}
@export var base_stats: Dictionary = {}

## 时机 → 频率 → 消耗 → 内容。一件物品可以有多条。
@export var rules: Array[AbilityRule] = []

## 273（作者 2026-11-04）：法杖的威力系数 —— 轮读的一下（杖基础 + 这颗晶石的加值）整下乘它，向下取整；没装晶石的木棍一下 = 基础 × 它。
## 白 1.0 / 绿 1.2 / 蓝 1.4 / 紫 1.6；不写 = 1（别的武器不用）
@export var power_mult: float = 1.0


## 把基础值写进一份 StatSet
func seed_stats(into: StatSet) -> void:
	for key in base_stats:
		into.set_base(StringName(key), StatMath.from_float(float(base_stats[key])))
	# 速度倍率总要有个基准，否则冷却累积会乘以 0
	if not base_stats.has(String(BattleStats.HASTE)):
		into.set_base(BattleStats.HASTE, StatMath.ONE)
