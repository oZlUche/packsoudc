## 主菜单（M6）：新的一局、继续上次、仓库、开发工具、退出。局外的一行数字挂在标题下面。
extends GameScreen

signal dev_tools_requested

var _continue_btn: Button = null


func open(_payload: Dictionary) -> void:
	_backdrop()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := _vbox(14)
	col.custom_minimum_size.x = 420
	center.add_child(col)

	col.add_child(_label("背包搜打撤", 34, UiPalette.FG))
	var m := flow.meta
	col.add_child(_label("第 %d 局　撤离 %d 次　战败 %d 次　仓库 %d 件　累计价值 %d　钱 %d" % [
		m.runs + 1, m.extractions, m.deaths, m.warehouse.item_count(), m.score, m.funds], 13, UiPalette.DIM))
	col.add_child(HSeparator.new())

	col.add_child(_button("新的一局", flow.new_run, 18))
	_continue_btn = _button("继续上次", func(): flow.continue_run(), 18)
	_continue_btn.disabled = not flow.has_save()
	col.add_child(_continue_btn)
	col.add_child(_button("仓库与战绩", flow.show_meta, 18))
	col.add_child(HSeparator.new())
	col.add_child(_button("开发工具（沙盒与编辑器）", func(): dev_tools_requested.emit(), 13))
	col.add_child(_button("退出", func(): get_tree().quit(), 13))
