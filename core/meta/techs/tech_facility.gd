## 251：基地里的一间铺子（集市 `market`、铁匠铺 `smithy`）—— 级数就是铺子的大小。
## 262：铺子默认就有（[constant MetaState.BASE_FACILITY_LEVEL] 级），科技第 k 级 = 铺子第 1 + k 级（「高级货物」「高级配方」）。
## 只把铺子级数记进 [member MetaState.facility_levels]（派生值，不存档，120）；铺子自己按级数查规则（[Market] / [Smithy]）
class_name TechFacility
extends TechEffect

## 哪一间铺子
@export var facility: StringName = &""


func derive(meta: MetaState, level: int) -> void:
	if meta == null or facility == &"":
		return
	if level > 0:
		meta.facility_levels[facility] = MetaState.BASE_FACILITY_LEVEL + level
	else:
		meta.facility_levels.erase(facility)


func describe() -> String:
	return describe_level(1)


## 科技到第 k 级这间铺子是什么样（铺子第 1 + k 级，各铺子自己说）
func describe_level(level: int, _buff_defs: Dictionary = {}) -> String:
	level += MetaState.BASE_FACILITY_LEVEL
	match facility:
		Market.ID:
			return Market.describe_level(Market.load_rules(), level)
		Smithy.ID:
			return Smithy.describe_level(level)
	return ""
