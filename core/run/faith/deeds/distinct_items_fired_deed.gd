## 不同名字的道具出手（104，技巧之神「每场战斗中每种不同名字的武器首次被触发 +10，每场上限 50」）：
## 一场里带 [member tag]（空 = 不限）的道具按定义 id 去重，每种出手过的给 amount 点；[member cap] 一场上限（0 = 不限）
class_name DistinctItemsFiredDeed
extends FaithDeed

@export var tag: StringName = &""
@export var cap: int = 0


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"battle":
		return 0
	var seen := {}
	for entry in payload.get("fired_items", []):
		var e := entry as Dictionary
		if int(e.get("count", 0)) <= 0 or String(e.get("id", "")) == "":
			continue
		if tag != &"" and not (e.get("tags", []) as Array).has(String(tag)):
			continue
		seen[String(e["id"])] = true
	var got := amount * seen.size()
	return mini(got, cap) if cap > 0 else got


func describe() -> String:
	var what := ("带「%s」的" % Glossary.tag_name(tag)) if tag != &"" else ""
	return "一场里每种%s道具首次出手 +%d%s" % [what, amount, ("（每场最多 %d）" % cap) if cap > 0 else ""]
