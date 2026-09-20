## 物品的战斗定义。没有这个字段的物品不参战（纯素材、纯包体等）。
class_name CombatProfile
extends Resource

## 是否是会自行触发的主动物品。false 表示它只提供属性或插槽加成，自己不出手。
@export var is_active: bool = true

## 基础冷却，秒。仅 is_active 时有意义。
@export var cooldown_sec: float = 2.0

## 基础属性，键见 [BattleStats]。编辑器里写浮点，编译期转定点。
##     {"damage": 10.0, "max_hp": 25.0}
@export var base_stats: Dictionary = {}


## 把基础值写进一份 StatSet。
func seed_stats(into: StatSet) -> void:
	for key in base_stats:
		into.set_base(StringName(key), StatMath.from_float(float(base_stats[key])))
	# 冷却与速度总是存在，缺省也要给出，否则 BattleSim 拿不到可用值
	if not base_stats.has(String(BattleStats.COOLDOWN)):
		into.set_base(BattleStats.COOLDOWN, StatMath.from_float(cooldown_sec))
	if not base_stats.has(String(BattleStats.HASTE)):
		into.set_base(BattleStats.HASTE, StatMath.ONE)
