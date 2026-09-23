## 结算（M6，架构文档 8 节的 ExtractResult / DeathResult）：撤离了背出去什么、值多少；战败了什么都没有。
## 「继续」把账记进局外（[GameFlow.finish_result]），去看仓库。
extends GameScreen


func open(payload: Dictionary) -> void:
	var r: RunResult = payload.get("result", flow.result)
	_backdrop()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := _panel(24)
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var col := _vbox(10)
	panel.add_child(col)
	if r == null:
		col.add_child(_label("没有可结算的一局", 18, UiPalette.FG))
		col.add_child(_button("回主菜单", flow.to_main_menu, 14))
		return
	var extracted := r.is_extracted()
	col.add_child(_label("撤离成功" if extracted else "战败", 28, UiPalette.HEAL if extracted else UiPalette.HP))
	col.add_child(_label("%s　种子 %d　%s" % [r.chapter_name, r.run_seed, _reason_text(r.reason)], 13, UiPalette.DIM))
	col.add_child(_label("行动点 %d　踩过 %d 个点　打赢 %d 场　打输 %d 场" % [r.steps, r.visited, r.battles_won, r.battles_lost], 14, UiPalette.FG))
	col.add_child(HSeparator.new())
	var list := _log_box(13)
	list.custom_minimum_size.y = 220
	if extracted:
		list.append_text("[b]背出去的[/b]（棋盘上的全部，进仓库）\n")
		for inst in r.carried:
			list.append_text(_item_line(inst.def) + "\n")
		list.append_text("\n一共 %d 件，值 [b]%d[/b] 币；带出 [b]%d[/b] 币\n" % [r.carried.size(), r.value, r.balance])
		if r.left_behind > 0:
			list.append_text("[color=#f0ad4e]暂存区里的 %d 件（值 %d 币）没带出来 —— 暂存区不参战也不出关（3.4）[/color]\n" % [r.left_behind, r.left_value])
	else:
		list.append_text("背包、暂存区、钱，全都留在了里面。\n")
	col.add_child(list)
	col.add_child(_button("继续", proceed, 16))


func proceed() -> void:
	flow.finish_result()


func _reason_text(reason: StringName) -> String:
	match reason:
		&"extract":
			return "从撤离点出来"
		&"vitality_depleted":
			return "体力耗尽"
		&"boss_lost":
			return "核心一战失利"
	return String(reason)
