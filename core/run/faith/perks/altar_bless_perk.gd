## 神坛特殊操作（095，各神都有）：赐福包里能被赐福的最值钱的一件（棋盘优先，其次地上）。
## 372：祈愿删了，不再花什么 —— 它占的是这座神坛的那一次机会（献祭和特殊操作二选一），所以就是「每座神坛一次」（报告 377 的初值）。
## 报告 377：以后改成万神院四档解锁的祭坛选项
class_name AltarBlessPerk
extends FaithPerk


func altar_label() -> String:
	return UiText.t("perk.bless_label")


func altar_available(run: RunState, _node: MapNode) -> String:
	var def := run.active_faith() if run != null else null
	if def == null:
		return UiText.t("perk.no_active_faith")
	if Blessings.best_candidate(run.board, run.items, def.id) == null and Blessings.best_candidate(run.storage, run.items, def.id) == null:
		return UiText.t("perk.bless_none")
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
	where.changed.emit()
	var altar := AltarModule.of(run)
	if altar != null:
		altar.item_blessed.emit(inst, def.id)
	return UiText.t("perk.bless_done") % [was, Names.of(v)]


## 188 补充一（作者原话「可以在祭坛赐福武器」）
func _summary() -> String:
	return UiText.t("perk.bless_summary") % UiText.t("perk.items")


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
	return UiText.t("perk.bless_summary") % (UiText.t("hud.buff_sep").join(names) if not names.is_empty() else UiText.t("perk.items"))
