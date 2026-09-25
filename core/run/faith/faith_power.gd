## 信力（作者定，报告 082）：获得信仰道具（= 激活了一个信仰）之后，完成那个信仰指定的行为攒点数；点数过了几道阈值，
## 信仰道具就多出额外的功能（道具上的 [ItemDef.faith_bonuses]，按阶解锁，编译器读 [method tiers]）。
##
## 每个信仰一个池子，只有**此刻激活的信仰**收点；行为与阈值都是信仰文件里的数据（[FaithDef.deeds] / [FaithDef.thresholds]）。
## 一局里的事由 [RunState] 接线喂进来（[method credit]），本类不碰任何系统、不认具体的神。跟着存档走。
## 切换信仰不清别的池子（作者：切换没有代价，甚至可以继承 —— 继承还没做，先各池各记）。
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


## 一局里发生了一件事：激活信仰的每个行为各自说给几点，加起来记到它的池子里。没激活信仰 = 不记。返回加了几点
func credit(event: StringName, payload: Dictionary = {}) -> int:
	if run == null:
		return 0
	var def := run.active_faith()
	if def == null:
		return 0
	var gained := 0
	for d in def.deeds:
		var deed := d as FaithDeed
		if deed != null:
			gained += maxi(0, deed.gain(event, payload))
	if gained <= 0:
		return 0
	var key := String(def.id)
	points[key] = points_of(def.id) + gained
	changed.emit(def.id, points_of(def.id), tier_of(def.id))
	return gained


## 给界面的一句：「信力 12 / 30（第 1 阶）」；没激活信仰返回空
func line() -> String:
	var def := run.active_faith() if run != null else null
	if def == null:
		return ""
	var p := points_of(def.id)
	var tier := def.tier_of(p)
	var next := def.next_threshold(p)
	return "信力 %d%s（第 %d 阶）" % [p, (" / %d" % next) if next >= 0 else "", tier]


func to_dict() -> Dictionary:
	return points.duplicate()


func restore(d: Dictionary) -> void:
	points.clear()
	for key in d:
		points[String(key)] = int(d[key])
