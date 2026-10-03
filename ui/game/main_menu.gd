## 主菜单（M6）：继续（有存档才显示）、读取存档（有任何一位有存档才显示）、新的游戏（= 开一份新存档）、仓库、开发工具、退出（089 作者定的顺序）。
## 局外的一行数字挂在标题下面。
## 085：多了一个「语言」按钮 —— 切 [GameSettings.language] 并存盘，[UiText.lang] 跟着改，菜单原地重建。
extends GameScreen

signal dev_tools_requested

var _continue_btn: Button = null


func open(_payload: Dictionary) -> void:
	UiText.apply(flow.settings)
	UiPalette.apply(flow.settings)
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
	# 098：这个存档位读不回来、已备份的那一句（战绩行下面）
	var notice := flow.backup_notice()
	if notice != "":
		col.add_child(_label(notice, 13, UiPalette.STAMINA))
	col.add_child(HSeparator.new())

	# 089（作者定）：第一项「继续」（当前位有存档才显示：读档 / 下一张教程 / 按这份存档开局）；第二项「读取存档」（换位，有任何一位有存档才显示）；
	# 第三项「新的游戏」= 开一份新存档（挑空位）。只写这几个词，不写章名
	_continue_btn = null
	if flow.profile_exists():
		_continue_btn = _button(UiText.t("menu.continue"), func(): flow.continue_game(), 18, UiPalette.Tier.PRIMARY)
		col.add_child(_continue_btn)
	if flow.slots != null and flow.slots.any():
		col.add_child(_button(UiText.t("menu.load"), flow.show_slots, 18))
	col.add_child(_button(UiText.t("menu.new_run"), func(): flow.start_new_game(), 18, UiPalette.Tier.PRIMARY))
	col.add_child(_button(UiText.t("menu.meta"), flow.show_meta, 18))
	col.add_child(_button(UiText.t("menu.encyclopedia"), func(): flow.show_encyclopedia(), 14, UiPalette.Tier.MINOR))     # 114
	col.add_child(_button(UiText.t("menu.settings"), flow.show_settings, 14, UiPalette.Tier.MINOR))
	col.add_child(_button(UiText.t("menu.language"), toggle_language, 14, UiPalette.Tier.MINOR))
	col.add_child(HSeparator.new())
	col.add_child(_button(UiText.t("menu.dev_tools"), func(): dev_tools_requested.emit(), 13, UiPalette.Tier.MINOR))
	col.add_child(_button(UiText.t("menu.quit"), func(): get_tree().quit(), 13, UiPalette.Tier.MINOR))


## 切到下一种界面语言：写进设置并存盘，然后把菜单原地重建（按钮文字立刻换）
func toggle_language() -> void:
	if flow.settings == null:
		flow.settings = GameSettings.new()
	flow.settings.language = UiText.next_lang(flow.settings.language)
	flow.save_settings()
	UiText.apply(flow.settings)
	UiPalette.apply(flow.settings)
	for c in get_children():
		c.queue_free()
		remove_child(c)
	open({})
