## 局外（M6，架构文档 8 节的 MetaProgress，15 节第 4 项）：仓库、钱、战绩、最近几局。
## 现在只是看：仓库里的东西怎么用（带进下一局、卖掉、局外成长）等作者定。
extends GameScreen


func open(payload: Dictionary) -> void:
	var m := flow.meta
	_backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var row := _hbox(32)
	margin.add_child(row)

	var left := _vbox(10)
	left.custom_minimum_size.x = 420
	row.add_child(left)
	left.add_child(_label("仓库与战绩", 26, UiPalette.FG))
	var just: RunResult = payload.get("result", null)
	if just != null:
		left.add_child(_wrapped("刚才这一局：%s，%s" % ["撤离，%d 件进了仓库，值 %d 币，带出 %d 币" % [just.carried.size(), just.value, just.balance]
			if just.is_extracted() else "战败，什么都没带出来", "已记账"], 13, UiPalette.HEAL if just.is_extracted() else UiPalette.HP, 400))
	left.add_child(_label("%d 局　撤离 %d　战败 %d　累计价值 %d　单局最高 %d　钱 %d" % [
		m.runs, m.extractions, m.deaths, m.score, m.best_value, m.funds], 14, UiPalette.FG))
	left.add_child(_label("仓库 %d 件" % m.warehouse.item_count(), 15, UiPalette.DIM))
	var view := StashView.new()
	view.label_font = font
	view.stash = m.warehouse
	view.custom_minimum_size.x = 380
	view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(view)
	var buttons := _hbox(8)
	buttons.add_child(_button("再来一局", flow.new_run, 16))
	buttons.add_child(_button("回主菜单", flow.to_main_menu, 16))
	left.add_child(buttons)

	var right := _vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
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
