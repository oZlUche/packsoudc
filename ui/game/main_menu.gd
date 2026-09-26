## 主菜单（M6）：新的游戏、继续（有存档或教程打到中途才显示）、仓库、开发工具、退出。局外的一行数字挂在标题下面。
## 085：多了一个「语言」按钮 —— 切 [GameSettings.language] 并存盘，[UiText.lang] 跟着改，菜单原地重建。
extends GameScreen

signal dev_tools_requested

var _continue_btn: Button = null


func open(_payload: Dictionary) -> void:
	UiText.apply(flow.settings)
	_backdrop()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := _vbox(14)
	col.custom_minimum_size.x = 420
	center.add_child(col)

	col.add_child(_label("背包搜打撤", 34, UiPalette.FG))
	var m := flow.meta
	col.add_child(_label(UiText.t("menu.stats") % [
		m.runs + 1, m.extractions, m.deaths, m.warehouse.item_count(), m.score, m.funds], 13, UiPalette.DIM))
	col.add_child(HSeparator.new())

	# 085（作者定）：「新的游戏」= 从头开始；「继续」和它并列 —— 有局内存档就读档，教程打到中途就开下一张；
	# 两样都没有就不显示。只写这两个词，不写章名
	col.add_child(_button(UiText.t("menu.new_run"), flow.new_run, 18))
	_continue_btn = null
	if flow.has_save() or flow.continue_target() != null:
		_continue_btn = _button(UiText.t("menu.continue"), func(): flow.continue_run(), 18)
		col.add_child(_continue_btn)
	col.add_child(_button(UiText.t("menu.meta"), flow.show_meta, 18))
	col.add_child(_button(UiText.t("menu.settings"), flow.show_settings, 14))
	col.add_child(_button(UiText.t("menu.language"), toggle_language, 14))
	col.add_child(HSeparator.new())
	col.add_child(_button(UiText.t("menu.dev_tools"), func(): dev_tools_requested.emit(), 13))
	col.add_child(_button(UiText.t("menu.quit"), func(): get_tree().quit(), 13))


## 切到下一种界面语言：写进设置并存盘，然后把菜单原地重建（按钮文字立刻换）
func toggle_language() -> void:
	if flow.settings == null:
		flow.settings = GameSettings.new()
	flow.settings.language = UiText.next_lang(flow.settings.language)
	flow.save_settings()
	UiText.apply(flow.settings)
	for c in get_children():
		c.queue_free()
		remove_child(c)
	open({})
