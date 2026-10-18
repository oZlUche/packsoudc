## 神坛特殊操作（095，各神都有）：花 [member cost] 信力，赐福包里能被赐福的最值钱的一件（棋盘优先，其次地上）
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
	var altar := AltarModule.of(run)
	if altar != null:
		altar.item_blessed.emit(inst, def.id)
	return "花 %d 信力：「%s」成了「%s」" % [cost, was, Names.of(v)]


## 188 补充一（作者原话「可以在祭坛赐福武器」）：花多少信力只在神坛按钮上写
func _summary() -> String:
	return "可以在祭坛赐福道具"


## 能赐福什么 = 这位神赐福模板圈的标签（中文名）
func summary_for(def: FaithDef, _points: int) -> String:
	var names: Array[String] = []
	if def != null:
		for b in def.blessings:
			if b == null:
				continue
			for t in (b as Blessing).tags:
				var n := Glossary.tag_name(t)
				if not names.has(n):
					names.append(n)
	return "可以在祭坛赐福%s" % ("、".join(names) if not names.is_empty() else "道具")
