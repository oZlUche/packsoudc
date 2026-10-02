## 神坛特殊操作（095，各神都有）：花 [member cost] 信力，赐福包里能被赐福的最值钱的一件（棋盘优先，其次暂存区）
class_name AltarBlessPerk
extends FaithPerk

@export var cost: int = 40


func altar_label() -> String:
	return "祈求赐福（花 %d 信力，赐福最值钱的一件）" % cost


func altar_available(run: RunState, _node: MapNode) -> String:
	var def := run.active_faith() if run != null else null
	if def == null:
		return "没有激活的信仰"
	if run.faith_power.points_of(def.id) < cost:
		return "信力不够（要 %d）" % cost
	if Blessings.best_candidate(run.board, run.items, def.id) == null and Blessings.best_candidate(run.storage, run.items, def.id) == null:
		return "包里没有能被赐福的东西"
	return ""


func altar_apply(run: RunState, _node: MapNode, _option: StringName = &"") -> String:
	var def := run.active_faith()
	if def == null or altar_available(run, _node) != "":
		return ""
	var inst := Blessings.best_candidate(run.board, run.items, def.id)
	var where: ItemContainer = run.board
	if inst == null:
		inst = Blessings.best_candidate(run.storage, run.items, def.id)
		where = run.storage
	var was := Names.of(inst.def)
	var v := Blessings.bless_instance(inst, run.items, def.id)
	if v == null:
		return ""
	run.faith_power.spend_points(def.id, cost)
	where.changed.emit()
	run.item_blessed.emit(inst, def.id)
	return "花 %d 信力：「%s」成了「%s」" % [cost, was, Names.of(v)]


func _summary() -> String:
	return "神坛：花 %d 信力赐福一件" % cost
