## 251：基地里的一间铺子（集市 `market`、铁匠铺 `smithy`）—— 级数就是铺子的大小。
## 只把级数记进 [member MetaState.facility_levels]（派生值，不存档，120）；铺子自己按级数查规则（[Market] / [Smithy]）
class_name TechFacility
extends TechEffect

## 哪一间铺子
@export var facility: StringName = &""


func derive(meta: MetaState, level: int) -> void:
	if meta == null or facility == &"":
		return
	if level > 0:
		meta.facility_levels[facility] = level
	else:
		meta.facility_levels.erase(facility)


func describe() -> String:
	return describe_level(1)


## 到第 k 级这间铺子是什么样（各铺子自己说）
func describe_level(level: int, _buff_defs: Dictionary = {}) -> String:
	match facility:
		Market.ID:
			return Market.describe_level(Market.load_rules(), level)
		Smithy.ID:
			return Smithy.describe_level(level)
	return ""
