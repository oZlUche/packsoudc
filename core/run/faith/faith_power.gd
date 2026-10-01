## 信力（作者定，报告 082）：完成各信仰指定的行为攒点数（从开局就攒，不必先激活）；点数过了几道阈值，
## 信仰道具就多出额外的功能（道具上的 [ItemDef.faith_bonuses]，按阶解锁，编译器读 [method tiers]）。
##
## 每个信仰一个池子，所有信仰从开局起同时收点（不看激活与否）；行为与阈值都是信仰文件里的数据（[FaithDef.deeds] / [FaithDef.thresholds]）。
## 一局里的事由 [RunState] 接线喂进来（[method credit]），本类不碰任何系统、不认具体的神。跟着存档走。
## 切换信仰不清任何池子；激活只决定谁的阶数加成生效。
class_name FaithPower
extends RefCounted

## 某个信仰的点数变了（tier 是现在第几阶）
signal changed(faith_id: StringName, points: int, tier: int)

var run: RunState = null
## faith id（String）→ 点数
var points: Dictionary = {}


func setup(p_run: RunState) -> void:
	run = p_run


func points_of(id: StringName) -> int:
	return int(points.get(String(id), 0))


## 第几阶：过了几道阈值（0 = 一道都没过）
func tier_of(id: StringName) -> int:
	var def: FaithDef = run.faith_defs.get(id, null) if run != null else null
	return def.tier_of(points_of(id)) if def != null else 0


## 给编译器：信仰对象标签 → 现在第几阶（只列有点数的）
func tiers() -> Dictionary:
	var out := {}
	for key in points:
		var id := StringName(String(key))
		var tier := tier_of(id)
		if tier > 0:
			out[StringName(FaithDef.TAG_PREFIX + String(id))] = tier
	return out


## 一局里发生了一件事：**每个信仰**的每个行为各自说给几点，加起来记到各自的池子里 —— 与是否激活无关
## （信力从开局就在攒，激活哪个信仰只决定哪个的加成生效）。返回所有池子一共加了几点
func credit(event: StringName, payload: Dictionary = {}) -> int:
	if run == null:
		return 0
	var ids: Array = run.faith_defs.keys()
	ids.sort()
	var total := 0
	for id in ids:
		var def := run.faith_defs.get(id, null) as FaithDef
		if def == null:
			continue
		var gained := 0
		for d in def.deeds:
			var deed := d as FaithDeed
			if deed != null:
				gained += maxi(0, deed.gain(event, payload))
		if gained <= 0:
			continue
		points[String(def.id)] = points_of(def.id) + gained
		total += gained
		changed.emit(def.id, points_of(def.id), tier_of(def.id))
	return total


## 095：给编译器：信仰对象标签 → 点数
func points_by_tag() -> Dictionary:
	var out := {}
	for key in points:
		out[StringName(FaithDef.TAG_PREFIX + String(key))] = int(points[key])
	return out


## 095：花信力（神坛的祈求赐福）。不够 false
func spend_points(id: StringName, n: int) -> bool:
	if n <= 0 or points_of(id) < n:
		return false
	points[String(id)] = points_of(id) - n
	changed.emit(id, points_of(id), tier_of(id))
	return true


## 093：直接加点（献祭）。返回加完之后第几阶
func add_points(id: StringName, n: int) -> int:
	if n <= 0 or id == &"":
		return tier_of(id)
	points[String(id)] = points_of(id) + n
	changed.emit(id, points_of(id), tier_of(id))
	return tier_of(id)


## 给界面的一句：「蛮神 Lv.1　35 / 100」；没激活信仰返回空
func line() -> String:
	var def := run.active_faith() if run != null else null
	if def == null:
		return ""
	var p := points_of(def.id)
	var tier := def.tier_of(p)
	var next := def.next_threshold(p)
	return "%s Lv.%d　%d%s" % [Names.of(def), tier, p, (" / %d" % next) if next >= 0 else "（满级）"]


func to_dict() -> Dictionary:
	return points.duplicate()


func restore(d: Dictionary) -> void:
	points.clear()
	for key in d:
		points[String(key)] = int(d[key])
