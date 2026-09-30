## 触发某类道具的效果（093 表：自然「触发自然道具效果 +3」、大地「触发中体积及以上道具效果 +8」）：
## 一场里带 [member tag] 标签（空 = 不限）且格子数 ≥ [member min_cells] 的道具每成功出手一次给 amount 点；[member cap] 一场上限
class_name ItemTriggeredDeed
extends FaithDeed

@export var tag: StringName = &""
@export var min_cells: int = 0
@export var cap: int = 0


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"battle":
		return 0
	var got := 0
	for entry in payload.get("fired_items", []):
		var e := entry as Dictionary
		if tag != &"" and not (e.get("tags", []) as Array).has(String(tag)):
			continue
		if int(e.get("cells", 0)) < min_cells:
			continue
		got += amount * int(e.get("count", 0))
	return mini(got, cap) if cap > 0 else got


func describe() -> String:
	var what := ("带「%s」的" % tag) if tag != &"" else ""
	if min_cells > 0:
		what += "%s体积及以上的" % ItemVolume.grade_name(ItemVolume.grade_of_cells(min_cells))
	return "%s道具每出手一次 +%d%s" % [what if what != "" else "", amount, ("（每场最多 %d）" % cap) if cap > 0 else ""]
