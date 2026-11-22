## 经验值（原来的信力，作者 2026-11-21 22:02 改名；报告 372 把信仰和升级合成一个系统）：一局里做了所奉之神指定的事，
## 这位神的行为构件说给几点，记进**这一局唯一的那一池经验值**（[LevelModule]，所有途径都乘难度系数）。
## 神的阶仍然按这一池算（[FaithDef.thresholds]，第一批暂按第 5、10、15 级的累计经验值），第二批改成逢 5 级的质变三选一。
##
## 只有**此刻有效的信仰**收点；行为是信仰文件里的数据（[FaithDef.deeds]）。一局里的事由 [RunState] 接线喂进来（[method credit]），
## 本类不碰任何系统、不认具体的神。祈愿删掉了（作者 18:30）。
## 没装局内成长模块的沙盒（测试的半截局）退回老办法：每位神一池，记在 [member points]
class_name FaithPower
extends RefCounted

## 经验值变了（tier 是这位神现在第几阶）
signal changed(faith_id: StringName, points: int, tier: int)

var run: RunState = null
## 没有 [LevelModule] 时的后备：faith id（String）→ 点数
var points: Dictionary = {}
## 104 节奏的量尺：每次加点记一条 {step, node_type, faith, event, gained, total, tier}（献祭的 event 是 `offering`）。
## 跟着存档（RunState 的 `faith_history`），结算屏与开发模式的 CSV 读它
var history: Array[Dictionary] = []


func setup(p_run: RunState) -> void:
	run = p_run


## 236：这一局不要了（[method RunState.dispose]）—— 放掉对局的引用（局 ↔ 系统互相抓着，一局放不掉）
func dispose() -> void:
	run = null


## 这一局的经验值池（没装 = null，走 [member points]）
func _level() -> LevelModule:
	return LevelModule.of(run) if run != null else null


## 这位神现在按多少点算阶：装了局内成长就是这一局的经验值（只算所奉的那一位），没装按各自的池
func points_of(id: StringName) -> int:
	var lv := _level()
	if lv != null:
		return int(lv.xp + 0.0001) if id != &"" else 0     # 一局一池：哪位神都按这一池算阶（换神不丢）
	return int(points.get(String(id), 0))


## 第几阶：过了几道阈值（0 = 一道都没过）
func tier_of(id: StringName) -> int:
	var def: FaithDef = run.faith_defs.get(id, null) if run != null else null
	return def.tier_of(points_of(id)) if def != null else 0


## 给编译器：信仰对象标签 → 现在第几阶（只列有点数的）
func tiers() -> Dictionary:
	var out := {}
	for id in _ids():
		var tier := tier_of(id)
		if tier > 0:
			out[StringName(FaithTags.PREFIX + String(id))] = tier
	return out


## 有点数的那几位（装了局内成长 = 所奉的那一位）
func _ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if _level() != null:
		if run.selected_faith != &"":
			out.append(run.selected_faith)
		return out
	for key in points:
		out.append(StringName(String(key)))
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
	_add(def.id, gained, event)
	return gained


## 记一笔：装了局内成长进那一池（乘难度系数），没装进这位神自己的池
func _add(id: StringName, n: int, event: StringName) -> void:
	var lv := _level()
	if lv != null:
		lv.gain(n, LevelModule.SRC_FAITH if event != &"offering" else LevelModule.SRC_OFFERING, "%s:%s" % [id, event])
	else:
		points[String(id)] = int(points.get(String(id), 0)) + n
	_record(id, event, n)
	changed.emit(id, points_of(id), tier_of(id))


## 095：给编译器：信仰对象标签 → 点数
func points_by_tag() -> Dictionary:
	var out := {}
	for id in _ids():
		out[StringName(FaithTags.PREFIX + String(id))] = points_of(id)
	return out


## 093：直接加点（献祭、献祭生命上限）。返回加完之后第几阶
func add_points(id: StringName, n: int) -> int:
	if n <= 0 or id == &"":
		return tier_of(id)
	_add(id, n, &"offering")
	return tier_of(id)


## 外面已经把点数记进了经验值池（神坛献祭按每座的上限记，[method LevelModule.offer_at]）：这里只记节奏、发信号
func note(id: StringName, n: int, event: StringName = &"offering") -> void:
	if id == &"" or n <= 0:
		return
	_record(id, event, n)
	changed.emit(id, points_of(id), tier_of(id))


func _record(id: StringName, event: StringName, gained: int) -> void:
	var step := 0
	var node_type := ""
	if run != null:
		step = run.travel.clock.total if run.travel != null and run.travel.clock != null else 0
		var node := run.current_node() if run.map != null and run.travel != null else null
		node_type = String(node.type) if node != null else ""
	var row := {"step": step, "node_type": node_type, "faith": String(id), "event": String(event),
		"gained": gained, "total": points_of(id), "tier": tier_of(id)}
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
	return (UiText.t("faith.pace") + "；".join(parts)) if not parts.is_empty() else ""


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


## 给界面的一句：「蛮神 1 阶」；没激活信仰返回空（经验值看顶端栏下面那根管子）
func line() -> String:
	var def := run.active_faith() if run != null else null
	if def == null:
		return ""
	return UiText.t("faith.line") % [Names.of(def), def.tier_of(points_of(def.id))]


func to_dict() -> Dictionary:
	return points.duplicate()


## 372：读老档的 `faith_progress`（{神: {devotion, prayer}}）—— 只在没装局内成长的沙盒里用（迁移已经把它折成经验值）
func restore_progress(d: Dictionary) -> void:
	points.clear()
	for key in d:
		var row: Variant = d[key]
		if not (row is Dictionary):
			continue
		var id := String(IdAliases.faith(StringName(String(key))))
		var dv: Variant = (row as Dictionary).get("devotion", 0)
		points[id] = int(points.get(id, 0)) + maxi(0, int(dv) if (dv is int or dv is float) else 0)


## 098：读档时旧信仰 id 并进新池子（093 的 violence → brute、sunfire → sun），两边都有就加起来 ——
## 切换信仰不清别的池子，所以合并点数是唯一不丢信力的做法
func restore(d: Dictionary) -> void:
	points.clear()
	for key in d:
		var id := IdAliases.faith(StringName(String(key)))
		points[String(id)] = int(points.get(String(id), 0)) + int(d[key])
