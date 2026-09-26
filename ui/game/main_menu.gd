## 主菜单（M6）：新的一局、继续上次、仓库、开发工具、退出。局外的一行数字挂在标题下面。
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

	# 085：会直接开哪一章就写在按钮上（教程收起后只剩一张时不经开局屏）；收起了的教程可以从第一张重玩
	var target := flow.new_run_target()
	var new_text := UiText.t("menu.new_run") if target == null else UiText.t("menu.new_run_to") % target.display_name
	col.add_child(_button(new_text, flow.new_run, 18))
	var replayable := flow.replayable_chapters()
	if not replayable.is_empty():
		var first := replayable[0]
		col.add_child(_button(UiText.t("menu.replay") % first.display_name, func(): flow.replay_chapter(first), 14))
	_continue_btn = _button(UiText.t("menu.continue"), func(): flow.continue_run(), 18)
	_continue_btn.disabled = not flow.has_save()
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
