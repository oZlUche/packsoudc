## 336 W1（阵营与委托，报告 335 第三、四节）：一局里带着的委托 —— 出征时把接着的至多两份拍个快照带进局（[member tracked]），
## 撤离确认框上的「查验」「交信」记进度（[member rows]），一局结束和其他结果同一次并进局外（[method Commissions.merge_run]）。
##
## 只认真实发生的事：查验 = 人站在撤离点上按了【查验】；交信 = 人站在开着的免费撤离点上、任务信还在身上。
## 同一处只记一次（行的去重键 = 节点 id / 实例 uid），读档重进、反复进同一个点都不重复。
## 进度跟这一局的存档走（`modules.commission`）；没带委托的局什么也不做。取它用 [method of]
class_name CommissionModule
extends RunModule

const ID := &"commission"
## 撤离点上的两种动作（事件选项 [CommissionReady] / [CommissionAct] 写它）
const INSPECT := &"inspect"
const DELIVER := &"deliver"

## 记了一条进度（委托 id、第几步、这一步做完没有）
signal progressed(id: StringName, stage: int, step_done: bool)

## 带进来的委托：[{"id", "stage", "pick"}]（出征那一刻的局外进度）
var tracked: Array[Dictionary] = []
## 这一局记下的进度：[{"id", "stage", "key", "via"}]（[method Commissions.merge_run] 读）
var rows: Array[Dictionary] = []


static func of(run: RunState) -> CommissionModule:
	return run.module(ID) as CommissionModule if run != null else null


func id() -> StringName:
	return ID


func install(run: RunState) -> void:
	if run == null:
		return
	_run = run
	run.hooks.register(&"commission_can", func(action: StringName, node: MapNode) -> bool:
		return can_inspect(node) if action == INSPECT else (can_deliver(node) if action == DELIVER else false))
	run.hooks.register(&"commission_act", func(action: StringName, node: MapNode) -> Array:
		return inspect(node) if action == INSPECT else (deliver(node) if action == DELIVER else []))
	if tracked.is_empty():
		for raw in run.module_input(ID).get("tracked", []):
			if raw is Dictionary:
				tracked.append({"id": String(raw.get("id", "")), "stage": int(raw.get("stage", 0)), "pick": String(raw.get("pick", ""))})


func is_active() -> bool:
	return not tracked.is_empty()


## 这份委托在这一局里现在停在第几步（出征时的那一步 + 这一局里做完的步数）；不在这一局 = -1
func stage_of(cid: StringName) -> int:
	for t in tracked:
		if StringName(String(t["id"])) == cid:
			var s := int(t["stage"])
			var d := Commissions.def(cid)
			while d != null and s < d.stages.size() and progress(cid, s) >= maxi(1, d.stages[s].count):
				s += 1
			return s
	return -1


## 这一步在这一局里记了几处
func progress(cid: StringName, stage: int) -> int:
	var n := 0
	for r in rows:
		if StringName(String(r["id"])) == cid and int(r["stage"]) == stage:
			n += 1
	return n


func _has_row(cid: StringName, stage: int, key: String) -> bool:
	for r in rows:
		if StringName(String(r["id"])) == cid and int(r["stage"]) == stage and String(r["key"]) == key:
			return true
	return false


## 带着的委托里，现在这一步是 [param goal] 的那几份（[委托定义, 第几步]）
func waiting(goal: StringName) -> Array:
	var out: Array = []
	for t in tracked:
		var cid := StringName(String(t["id"]))
		var d := Commissions.def(cid)
		var s := stage_of(cid)
		if d != null and s >= 0 and s < d.stages.size() and d.stages[s].goal == goal:
			out.append([d, s])
	return out


static func _is_free(node: MapNode) -> bool:
	return PaidExtracts.fee_of(node) <= 0


## 这个撤离点能不能「查验」：带着查验的委托、这个点这一步还没查过（付费点也能查，不收钱）
func can_inspect(node: MapNode) -> bool:
	return not _inspect_targets(node).is_empty()


func _inspect_targets(node: MapNode) -> Array:
	var out: Array = []
	if node == null or _run == null or NodeEvents.effective_type(node) != &"extract":
		return out
	for pair in waiting(&"inspect_extracts"):
		var d := pair[0] as CommissionDef
		var s := int(pair[1])
		if not _has_row(d.id, s, "%s/node:%d" % [_run.run_id, node.id]) and _kind_ok(d.stages[s], node):
			out.append(pair)
	return out


static func _kind_ok(stage: CommissionStage, node: MapNode) -> bool:
	match String(stage.params.get("kind", "")):
		"free":
			return _is_free(node)
		"paid":
			return not _is_free(node)
	return true


## 查验这个撤离点：带着的每份查验委托各记一处。返回记上的那几份 [{"id", "goal", "finished": 这一局里整份做完了}]
func inspect(node: MapNode) -> Array:
	var out: Array = []
	for pair in _inspect_targets(node):
		out.append(_add(pair[0] as CommissionDef, int(pair[1]), "node:%d" % node.id, "self"))
	return out


## 这个撤离点能不能「交信」：免费撤离点、出口开着、身上有这份委托的任务信
func can_deliver(node: MapNode) -> bool:
	return not _deliver_targets(node).is_empty()


func _deliver_targets(node: MapNode) -> Array:
	var out: Array = []
	if node == null or _run == null or NodeEvents.effective_type(node) != &"extract":
		return out
	var cd := CountdownModule.of(_run)
	if cd != null and cd.extract_closed(node):
		return out
	for pair in waiting(&"deliver_letter"):
		var d := pair[0] as CommissionDef
		var s := int(pair[1])
		if _kind_ok(d.stages[s], node) and letter_of(d.stages[s]) != null:
			out.append(pair)
	return out


## 身上（棋盘 / 地上）这一步的任务信；没有 null。托付出去的不算（已经交给接应的人了）
func letter_of(stage: CommissionStage) -> ItemInstance:
	if _run == null or stage == null or stage.item == &"":
		return null
	for c in [_run.board, _run.storage]:
		if c == null:
			continue
		for inst in c.items():
			var it := inst as ItemInstance
			if it.def != null and it.def.id == stage.item:
				return it
	return null


## 交信：信从身上拿走，这一步当场成立（之后败退也算）。返回交了的那几份（同 [method inspect]）
func deliver(node: MapNode) -> Array:
	var out: Array = []
	for pair in _deliver_targets(node):
		var d := pair[0] as CommissionDef
		var s := int(pair[1])
		var letter := letter_of(d.stages[s])
		if letter == null:
			continue
		for c in [_run.board, _run.storage]:
			if c != null and c.get_item(letter.uid) != null:
				c.remove(letter.uid)
				break
		out.append(_add(d, s, "uid:%d" % letter.uid, "self"))
	return out


## 去重键带上这一局的 id：uid 每局从 1 重来，别的局的同号不是同一件
func _add(d: CommissionDef, stage: int, key: String, via: String) -> Dictionary:
	rows.append({"id": String(d.id), "stage": stage, "key": "%s/%s" % [_run.run_id, key], "via": via})
	var step_done := progress(d.id, stage) >= maxi(1, d.stages[stage].count)
	progressed.emit(d.id, stage, step_done)
	return {"id": String(d.id), "goal": String(d.stages[stage].goal), "finished": stage_of(d.id) >= d.stages.size()}


## 局内小牌的几行：[{"id", "name", "text": 这一步做什么, "done": 这一局里做到了几, "need": 要几, "finished": 这一局里全做完了}]
func lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in tracked:
		var cid := StringName(String(t["id"]))
		var d := Commissions.def(cid)
		if d == null:
			continue
		var s := stage_of(cid)
		var finished := s >= d.stages.size()
		var shown := mini(s, d.stages.size() - 1)
		var need := maxi(1, d.stages[shown].count)
		out.append({"id": String(cid), "name": Names.of(d), "text": Names.pick(d.stages[shown].texts, d.stages[shown].text),
			"done": need if finished else progress(cid, s), "need": need, "finished": finished})
	return out


func to_dict() -> Dictionary:
	return {"tracked": tracked.duplicate(true), "rows": rows.duplicate(true)}


func restore(d: Dictionary) -> void:
	tracked.clear()
	rows.clear()
	for raw in d.get("tracked", []):
		if raw is Dictionary:
			tracked.append({"id": String(raw.get("id", "")), "stage": int(raw.get("stage", 0)), "pick": String(raw.get("pick", ""))})
	for raw in d.get("rows", []):
		if raw is Dictionary:
			rows.append({"id": String(raw.get("id", "")), "stage": int(raw.get("stage", 0)), "key": String(raw.get("key", "")), "via": String(raw.get("via", "self"))})
