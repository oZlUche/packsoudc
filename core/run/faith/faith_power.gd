## 信力（作者定，报告 082）：获得信仰道具（= 激活了一个信仰）之后，完成那个信仰指定的行为攒点数；点数过了几道阈值，
## 信仰道具就多出额外的功能（道具上的 [ItemDef.faith_bonuses]，按阶解锁，编译器读 [method tiers]）。
##
## 每个信仰一个池子，只有**此刻激活的信仰**收点；行为与阈值都是信仰文件里的数据（[FaithDef.deeds] / [FaithDef.thresholds]）。
## 一局里的事由 [RunState] 接线喂进来（[method credit]），本类不碰任何系统、不认具体的神。跟着存档走。
## 切换信仰不清别的池子（作者：切换没有代价，甚至可以继承 —— 继承还没做，先各池各记）。
class_name FaithPower
extends RefCounted

## 某个信仰的点数变了（tier 是现在第几阶）。信仰重构 B：信力或祈愿任一变了都发（points 是信力）
signal changed(faith_id: StringName, points: int, tier: int)

## 信仰重构 B（交接方案 §3）：祈愿上限没配时的默认值（候选，[member FaithDef.prayer_cap] 可按神改）
const PRAYER_CAP_DEFAULT := 100
## 信仰重构 B：一场有效战斗完成给这位神多少祈愿（候选；秒杀不算打了一场，不给）
const PRAYER_PER_BATTLE := 8

var run: RunState = null
## faith id（String）→ **信力**（devotion：累计成长，只增不减，阶只看它；信仰重构 B 起不再用于支付）
var points: Dictionary = {}
## 信仰重构 B：faith id（String）→ **祈愿**（prayer：可花的余额，不超过这位神的上限；花它不降阶）
var prayer: Dictionary = {}
## 104 信力节奏的量尺：每次加点记一条 {step, node_type, faith, event, gained, total, tier}（献祭的 event 是 `offering`）。
## 跟着存档（RunState 的 `faith_history`），结算屏与开发模式的 CSV 读它 —— 作者打几局就能对着表调阈值与给点
var history: Array[Dictionary] = []


func setup(p_run: RunState) -> void:
	run = p_run


## 236：这一局不要了（[method RunState.dispose]）—— 放掉对局的引用（局 ↔ 系统互相抓着，一局放不掉）
func dispose() -> void:
	run = null


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
			out[StringName(FaithTags.PREFIX + String(id))] = tier
	return out


## 一局里发生了一件事：有效信仰的每个行为各自说给几点，加起来记到它的池子里。不奉神 / 联系中断 = 不记。返回加了几点。
## [param faith_id]：事务开始时定下的信仰快照（战斗用开战那一刻编译的信仰）；`?` = 此刻的有效信仰
func credit(event: StringName, payload: Dictionary = {}, faith_id: StringName = &"?") -> int:
	if run == null:
		return 0
	var def: FaithDef = run.active_faith() if faith_id == &"?" else run.faith_defs.get(faith_id, null)
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
	_record(def.id, event, gained)
	changed.emit(def.id, points_of(def.id), tier_of(def.id))
	return gained


## 095：给编译器：信仰对象标签 → 点数
func points_by_tag() -> Dictionary:
	var out := {}
	for key in points:
		out[StringName(FaithTags.PREFIX + String(key))] = int(points[key])
	return out


## 信仰重构 B：这位神现在有多少祈愿
func prayer_of(id: StringName) -> int:
	return int(prayer.get(String(id), 0))


## 这位神的祈愿上限
func prayer_cap(id: StringName) -> int:
	var def: FaithDef = run.faith_defs.get(id, null) if run != null else null
	return def.prayer_cap if def != null and def.prayer_cap > 0 else PRAYER_CAP_DEFAULT


## 祈愿还能进多少
func prayer_room(id: StringName) -> int:
	return maxi(0, prayer_cap(id) - prayer_of(id))


## 信仰重构 B：加祈愿（封顶）。返回实际加了多少
func add_prayer(id: StringName, n: int, event: StringName = &"prayer") -> int:
	if n <= 0 or id == &"":
		return 0
	var got := mini(n, prayer_room(id))
	if got <= 0:
		return 0
	prayer[String(id)] = prayer_of(id) + got
	_record(id, event, 0, got)
	changed.emit(id, points_of(id), tier_of(id))
	return got


## 信仰重构 B：花祈愿（神坛的祈求赐福、蛮神秒杀）。不够 false、一点不扣。**信力不动，阶不变**
func spend_prayer(id: StringName, n: int) -> bool:
	if n <= 0 or id == &"" or prayer_of(id) < n:
		return false
	prayer[String(id)] = prayer_of(id) - n
	_record(id, &"spend", 0, -n)
	changed.emit(id, points_of(id), tier_of(id))
	return true


## 093：直接加点（献祭）。返回加完之后第几阶
func add_points(id: StringName, n: int) -> int:
	if n <= 0 or id == &"":
		return tier_of(id)
	points[String(id)] = points_of(id) + n
	_record(id, &"offering", n)
	changed.emit(id, points_of(id), tier_of(id))
	return tier_of(id)


func _record(id: StringName, event: StringName, gained: int, prayer_delta: int = 0) -> void:
	var step := 0
	var node_type := ""
	if run != null:
		step = run.travel.clock.total if run.travel != null and run.travel.clock != null else 0
		var node := run.current_node() if run.map != null and run.travel != null else null
		node_type = String(node.type) if node != null else ""
	var row := {"step": step, "node_type": node_type, "faith": String(id), "event": String(event),
		"gained": gained, "total": points_of(id), "tier": tier_of(id)}
	if prayer_delta != 0:
		row["prayer"] = prayer_delta     # 信仰重构 B：这一笔祈愿的进出（校准看收入 / 支出）
		row["prayer_total"] = prayer_of(id)
	history.append(row)


## 104：某个信仰每一阶头一回到达是第几步：[第 1 阶的步数, 第 2 阶的步数, …]，没到的不列
static func tier_steps(p_history: Array, id: StringName) -> Array[int]:
	var out: Array[int] = []
	for e in p_history:
		var entry := e as Dictionary
		if entry == null or String(entry.get("faith", "")) != String(id):
			continue
		while out.size() < int(entry.get("tier", 0)):
			out.append(int(entry.get("step", 0)))
	return out


## 104：结算屏的一行「信力节奏：日神 第 3 步到 1 阶、第 9 步到 2 阶」；一条记录都没有返回空
static func pace_line(p_history: Array, defs: Dictionary = {}) -> String:
	var order: Array[String] = []
	for e in p_history:
		var f := String((e as Dictionary).get("faith", ""))
		if f != "" and not order.has(f):
			order.append(f)
	var parts: Array[String] = []
	for f in order:
		var steps := tier_steps(p_history, StringName(f))
		var def: FaithDef = defs.get(StringName(f), null)
		var name := Names.of(def) if def != null else f
		if steps.is_empty():
			parts.append("%s 没到 1 阶" % name)
			continue
		var bits: Array[String] = []
		for i in steps.size():
			bits.append("第 %d 步到 %d 阶" % [steps[i], i + 1])
		parts.append("%s %s" % [name, "、".join(bits)])
	return ("信力节奏：" + "；".join(parts)) if not parts.is_empty() else ""


## 104：开发模式导出的 CSV（一行一次加点）
static func history_csv(p_history: Array) -> String:
	var lines: Array[String] = ["step,node_type,faith,event,gained,total,tier"]
	for e in p_history:
		var d := e as Dictionary
		lines.append("%d,%s,%s,%s,%d,%d,%d" % [int(d.get("step", 0)), String(d.get("node_type", "")), String(d.get("faith", "")),
			String(d.get("event", "")), int(d.get("gained", 0)), int(d.get("total", 0)), int(d.get("tier", 0))])
	return "\n".join(lines) + "\n"


func history_to_array() -> Array:
	return history.duplicate(true)


func restore_history(raw: Variant) -> void:
	history.clear()
	if raw is Array:
		for e in raw:
			if e is Dictionary:
				history.append((e as Dictionary).duplicate())


## 给界面的一句：「蛮神 Lv.1　35 / 100」；没激活信仰返回空
func line() -> String:
	var def := run.active_faith() if run != null else null
	if def == null:
		return ""
	var p := points_of(def.id)
	var tier := def.tier_of(p)
	var next := def.next_threshold(p)
	return UiText.t("faith.line") % [Names.of(def), tier, p, (" / %d" % next) if next >= 0 else UiText.t("faith.max_rank")] \
		+ UiText.t("faith.prayer_line") % prayer_of(def.id)


func to_dict() -> Dictionary:
	return points.duplicate()


## 信仰重构 B：每位神 {devotion, prayer}（存档的 `faith_progress`）
func progress_to_dict() -> Dictionary:
	var out := {}
	for key in points:
		out[String(key)] = {"devotion": int(points[key]), "prayer": int(prayer.get(key, 0))}
	for key in prayer:
		if not out.has(String(key)):
			out[String(key)] = {"devotion": 0, "prayer": int(prayer[key])}
	return out


## 信仰重构 B：读 `faith_progress`（别名规范化、负数清成 0、非法类型跳过）
func restore_progress(d: Dictionary) -> void:
	points.clear()
	prayer.clear()
	for key in d:
		var row: Variant = d[key]
		if not (row is Dictionary):
			continue
		var id := String(IdAliases.faith(StringName(String(key))))
		var dv: Variant = (row as Dictionary).get("devotion", 0)
		var pv: Variant = (row as Dictionary).get("prayer", 0)
		points[id] = int(points.get(id, 0)) + maxi(0, int(dv) if (dv is int or dv is float) else 0)
		prayer[id] = int(prayer.get(id, 0)) + maxi(0, int(pv) if (pv is int or pv is float) else 0)


## 098：读档时旧信仰 id 并进新池子（093 的 violence → brute、sunfire → sun），两边都有就加起来 ——
## 切换信仰不清别的池子，所以合并点数是唯一不丢信力的做法
func restore(d: Dictionary) -> void:
	points.clear()
	for key in d:
		var id := IdAliases.faith(StringName(String(key)))
		points[String(id)] = int(points.get(String(id), 0)) + int(d[key])
