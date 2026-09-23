## 局外（M6，架构文档 8.2；058 第 4 / 7 条）：仓库的格子、带回来还没清空的背包、图鉴、战绩、最近几局。
## 带回来的背包没清空之前「再来一局」是灰的（作者：提示玩家清空背包再配置）。
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")

var _wh = null
var _new_run_btn: Button
var _hint: Label
var _buff_btns: Dictionary = {}
var _unlock_btns: Dictionary = {}


func open(payload: Dictionary) -> void:
	var m := flow.meta
	_backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var row := _hbox(28)
	margin.add_child(row)

	var left := _vbox(8)
	row.add_child(left)
	left.add_child(_label("仓库与战绩", 26, UiPalette.FG))
	var just: RunResult = payload.get("result", null)
	if just != null:
		left.add_child(_wrapped("刚才这一局：%s" % ("撤离，背出来 %d 件、值 %d 币、带出 %d 币" % [just.carried.size(), just.value, just.balance]
			if just.is_extracted() else "战败，什么都没带出来"), 13, UiPalette.HEAL if just.is_extracted() else UiPalette.HP, 500))
	left.add_child(_label("%d 局　撤离 %d　战败 %d　累计价值 %d　单局最高 %d　钱 %d　图鉴 %d / %d" % [
		m.runs, m.extractions, m.deaths, m.score, m.best_value, m.funds, m.codex.size(), flow.items.size()], 14, UiPalette.FG))
	_wh = WarehousePanelScript.new()
	_wh.setup(flow, font)
	_wh.changed.connect(_refresh)
	left.add_child(_wh)
	_hint = _label("", 12, UiPalette.STAMINA)
	left.add_child(_hint)
	var buttons := _hbox(8)
	_new_run_btn = _button("再来一局", flow.new_run, 16)
	buttons.add_child(_new_run_btn)
	buttons.add_child(_button("回主菜单", flow.to_main_menu, 16))
	left.add_child(buttons)

	var right := _vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_label("局外 buff　占位：开关列表，将来由任务、局外科技决定", 15, UiPalette.DIM))
	var ids_b: Array = flow.buff_defs.keys()
	ids_b.sort()
	var any_meta := false
	for id in ids_b:
		var def: RunBuffDef = flow.buff_defs[id]
		if not def.is_meta():
			continue
		any_meta = true
		var bid: StringName = id
		var b := _button("%s　%s" % [def.display_name, def.summary()], func(): toggle_buff(bid), 13)
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_pressed_no_signal(m.active_buffs.has(bid))
		_buff_btns[bid] = b
		right.add_child(b)
	if not any_meta:
		right.add_child(_label("（没有局外 buff 的内容）", 12, UiPalette.DIM))
	# 局外解锁（069，占位开关）：难度定义里要求的解锁 id 各一个开关
	var unlock_ids: Array[StringName] = []
	for d in flow.difficulties:
		if d.requires_unlock != &"" and not unlock_ids.has(d.requires_unlock):
			unlock_ids.append(d.requires_unlock)
	if not unlock_ids.is_empty():
		right.add_child(_label("局外解锁　占位：开关列表，将来由成长系统决定", 15, UiPalette.DIM))
		for uid in unlock_ids:
			var names: Array[String] = []
			for d in flow.difficulties:
				if d.requires_unlock == uid:
					names.append(d.display_name)
			var key: StringName = uid
			var ub := _button("%s　解锁难度：%s" % [uid, "、".join(names)], func(): toggle_unlock(key), 13)
			ub.toggle_mode = true
			ub.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ub.set_pressed_no_signal(m.has_unlock(key))
			_unlock_btns[key] = ub
			right.add_child(ub)
	right.add_child(_label("图鉴　带出过的点亮，记累计件数", 15, UiPalette.DIM))
	var codex := _log_box(13)
	codex.custom_minimum_size.y = 260
	var ids: Array = flow.items.ids()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var da := flow.items.get_def(a)
		var db := flow.items.get_def(b)
		return da.rarity < db.rarity if da.rarity != db.rarity else String(a) < String(b))
	for id in ids:
		var def := flow.items.get_def(id)
		if m.codex_lit(id):
			codex.append_text("[color=#%s]%s[/color]　×%d\n" % [ItemPainter.rarity_color(def).to_html(false), def.display_name, m.codex_count(id)])
		else:
			codex.append_text("[color=#4a515e]%s[/color]\n" % def.display_name)
	right.add_child(codex)
	right.add_child(_label("最近几局", 15, UiPalette.DIM))
	var log := _log_box(13)
	for h in m.history:
		var extracted := String(h.get("outcome", "")) == "extracted"
		log.append_text("[color=#%s]%s[/color]　种子 %d　行动点 %d　打赢 %d　%s\n" % [
			(UiPalette.HEAL if extracted else UiPalette.HP).to_html(false), "撤离" if extracted else "战败",
			int(h.get("seed", 0)), int(h.get("steps", 0)), int(h.get("battles_won", 0)),
			"%d 件、值 %d 币、带出 %d 币" % [(h.get("items", []) as Array).size(), int(h.get("value", 0)), int(h.get("balance", 0))] if extracted else ""])
	if m.history.is_empty():
		log.append_text("[color=#8b93a1]还没有打过[/color]")
	right.add_child(log)
	_refresh()


func store_all() -> Dictionary:
	return _wh.store_all()


func discard_board() -> void:
	_wh.discard_board()


func toggle_buff(id: StringName) -> bool:
	var on := flow.toggle_meta_buff(id)
	if _buff_btns.has(id):
		(_buff_btns[id] as Button).set_pressed_no_signal(on)
	return on


func toggle_unlock(id: StringName) -> bool:
	var on := flow.toggle_unlock(id)
	if _unlock_btns.has(id):
		(_unlock_btns[id] as Button).set_pressed_no_signal(on)
	return on


func _refresh() -> void:
	var why := flow.can_begin()
	_new_run_btn.disabled = why != ""
	_hint.text = why
