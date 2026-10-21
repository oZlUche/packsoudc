## 设置：改了就存。109：离开点时地上的提醒档位那一块随提示一起删了
extends GameScreen

var _auto_close_btn: Button = null
var _tooltip_btn: Button = null
var _unlock_all_btn: Button = null
## 117：开发区的「战斗日志」开关（导出包里整块不画）
var _trace_btn: Button = null
## 150 补 2：调试模式开关
var _debug_btn: Button = null
## 157：换屏淡入开关
var _fades_btn: Button = null
## 157 补：光标材质的按钮（材质 id → 按钮）
var _cursor_btns: Dictionary = {}
## 091：背景底色的按钮（主题 id → 按钮）
var _bg_btns: Dictionary = {}
## 172：窗口模式的按钮（模式 → 按钮）、分辨率的按钮（档位 → 按钮）、全屏时那行注
var _mode_btns: Dictionary = {}
var _res_btns: Dictionary = {}
var _res_note: Label = null
## 204：「声音」一节的音效音量读数
var _sfx_label: Label = null
## 090：从地图的暂停菜单嵌进来时的「返回」（回暂停菜单，一局还在）；空 = 独立的一屏，回主菜单
var back: Callable = Callable()


func open(_payload: Dictionary) -> void:
	_backdrop()
	# 172：加了「显示」一节后，1000 高的视口放不下整列（开发区在时更长）—— 包一层只竖着滚的滚动框，放得下照样居中
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_slab_screen().add_child(scroll)     # 157 补充三：内容在一整块石板上
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := _vbox(10)
	col.custom_minimum_size.x = 520
	center.add_child(col)
	var plate := TitlePlate.new(UiText.t("menu.settings"))     # 226 批二：标题刻在标题牌上
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(plate)
	_build_display(col)
	_build_sound(col)
	col.add_child(HSeparator.new())
	col.add_child(HeaderTag.new(UiText.t("settings.loot_section")))     # 226 批二：分区名上段头签
	_auto_close_btn = _toggle(UiText.t("settings.loot_auto_close"), toggle_loot_auto_close)
	col.add_child(_auto_close_btn)
	col.add_child(HSeparator.new())
	col.add_child(HeaderTag.new(UiText.t("settings.bg_section")))
	var bg_row := _hbox(8)
	for t in UiPalette.BG_THEMES:
		var tid := String(t["id"])
		var b := _button(UiText.pick(t["name"]), func(): set_bg_theme(tid), 13, UiPalette.Tier.MINOR)
		b.toggle_mode = true
		if t.has("note"):
			b.tooltip_text = UiText.pick(t["note"])     # 226 批二：「默认」「最浅」进悬浮窗
		var box := b.get_theme_stylebox("normal") as StyleBoxFlat
		if box != null:
			var swatch := box.duplicate() as StyleBoxFlat
			swatch.bg_color = t["color"]
			b.ready.connect(func():     # 226 批二：按下态边距更宽，按它撑宽（不然选中那键字被裁成「石」「Graphi」）；进了树才取得到主题里的按下态
				var pressed_box := b.get_theme_stylebox("pressed")
				for side in [SIDE_LEFT, SIDE_RIGHT]:
					swatch.set_content_margin(side, maxf(swatch.get_content_margin(side), pressed_box.get_content_margin(side)))
				b.update_minimum_size())
			b.add_theme_stylebox_override("normal", swatch)     # 121 特例：底色色板，按钮底就是那档底色（画布色）
		_bg_btns[tid] = b
		bg_row.add_child(b)
	col.add_child(bg_row)
	_fades_btn = _toggle(UiText.t("settings.fades"), toggle_ui_fades)     # 157
	col.add_child(_fades_btn)
	var cursor_row := _hbox(8)
	cursor_row.add_child(_label(UiText.t("settings.cursor"), 14, UiPalette.FG))
	for skin in UiCursor.SKINS:
		var sid := String(skin)
		var cb := _button(UiText.pick(UiCursor.SKINS[skin]), func(): set_cursor_skin(sid), 13, UiPalette.Tier.MINOR)
		cb.toggle_mode = true
		_cursor_btns[sid] = cb
		cursor_row.add_child(cb)
	col.add_child(cursor_row)
	col.add_child(HSeparator.new())
	col.add_child(HeaderTag.new(UiText.t("settings.veteran")))
	_unlock_all_btn = _toggle(UiText.t("settings.unlock_all"), toggle_unlock_all)
	_unlock_all_btn.tooltip_text = UiText.t("settings.unlock_all_desc")     # 226 批二：说明进开关的悬浮窗
	col.add_child(_unlock_all_btn)
	col.add_child(HSeparator.new())
	if DevGate.on():     # 117：开发区只在非导出包里有 —— 日志是给作者看的，玩家看不到。186：调试模式、节点浮窗预览也挪进来
		col.add_child(_label("开发", 15, UiPalette.DIM))
		col.add_child(_wrapped("调试模式：地图上摆出只给开发看的东西（事件日志）。关掉就藏起来，日志照样在记。", 12, UiPalette.DIM, 500))
		_debug_btn = _toggle("调试模式", toggle_debug_mode)
		col.add_child(_debug_btn)
		col.add_child(_wrapped("节点浮窗按章节开放（第二章才开），这里能强制打开先看效果。", 12, UiPalette.DIM, 500))
		_tooltip_btn = _toggle("节点浮窗预览", toggle_node_tooltips_preview)
		col.add_child(_tooltip_btn)
		col.add_child(_wrapped("战斗日志：每场战斗的内部日志（逐条、带时间）与回放存档写进 user://battle_logs，只留最近 %d 场。回放在开发工具的「战斗回放」里翻。" % BattleArchive.KEEP, 12, UiPalette.DIM, 500))
		var row := _hbox(8)
		_trace_btn = _toggle("战斗日志", toggle_battle_trace)
		row.add_child(_trace_btn)
		row.add_child(_button("打开日志文件夹", open_log_folder, 13, UiPalette.Tier.MINOR))
		col.add_child(row)
		col.add_child(HSeparator.new())
	col.add_child(_button(UiText.t("setup.back") if back.is_valid() else UiText.t("setup.main_menu"), go_back, 14))
	_refresh()


## 172：「显示」一节（放最上面）—— 窗口 / 全屏两个按钮；分辨率按宽高比分行，只列放得进这块屏幕的档；全屏时整块灰掉、注一句。
## 主菜单的设置和 Esc 暂停菜单里嵌的是同一屏，两个入口都有它
func _build_display(col: VBoxContainer) -> void:
	add_to_group(GameDirector.DISPLAY_GROUP)     # F11 切了模式，这一节跟着刷新
	col.add_child(HeaderTag.new(UiText.t("settings.display")))
	var mode_row := _hbox(8)
	for m in [[WindowSetup.WINDOWED, "settings.windowed"], [WindowSetup.FULLSCREEN, "settings.fullscreen"]]:
		var mode: String = m[0]
		var b := _button(UiText.t(String(m[1])), func(): set_window_mode(mode), 13, UiPalette.Tier.MINOR)
		b.toggle_mode = true
		_mode_btns[mode] = b
		mode_row.add_child(b)
	col.add_child(mode_row)
	var rows := {}     # 宽高比 → 那一行
	var shown := WindowSetup.available(WindowSetup.screen_size(get_window() if is_inside_tree() else null))
	for p in shown:
		var aspect := WindowSetup.aspect_name(p)
		if not rows.has(aspect):
			var row := _hbox(8)
			row.add_child(_label(aspect, 12, UiPalette.DIM))
			rows[aspect] = row
			col.add_child(row)
		var size: Vector2i = p
		var rb := _button(WindowSetup.label(p), func(): set_resolution(size), 13, UiPalette.Tier.MINOR)
		rb.toggle_mode = true
		_res_btns[p] = rb
		rows[aspect].add_child(rb)
	if shown.is_empty():     # 屏幕比最小一档还小：窗口就是屏幕那么大
		col.add_child(_label(UiText.t("settings.res_follow_screen"), 13, UiPalette.DIM))
	_res_note = _label(UiText.t("settings.fullscreen_note"), 12, UiPalette.DIM)
	col.add_child(_res_note)


## 204：「声音」一节 —— 音效音量一行（− / + 一步 10%，按钮本身响 `ui.press`，当场听到新音量）。音乐那行等第一首曲子再露出来（待定 4.2）
func _build_sound(col: VBoxContainer) -> void:
	col.add_child(HSeparator.new())
	col.add_child(HeaderTag.new(UiText.t("settings.sound")))
	var row := _hbox(8)
	_sfx_label = _label("", 14, UiPalette.FG)
	_sfx_label.custom_minimum_size.x = 120
	row.add_child(_sfx_label)
	row.add_child(_button("−", func(): step_sfx_volume(-1), 13, UiPalette.Tier.MINOR))
	row.add_child(_button("+", func(): step_sfx_volume(1), 13, UiPalette.Tier.MINOR))
	col.add_child(row)


## 204：音效音量调一步（[param dir] = ±1，一步 10%，夹在 0～100%）；当场套用、存盘
func step_sfx_volume(dir: int) -> void:
	var steps := clampi(roundi(flow.settings.sfx_volume * 10.0) + dir, 0, 10)
	flow.settings.sfx_volume = steps / 10.0
	AudioHub.apply(flow.settings)
	flow.save_settings()
	_refresh()


## 172：窗口 / 全屏（当场套用、存盘）
func set_window_mode(mode: String) -> void:
	if not WindowSetup.MODES.has(mode):
		return
	flow.settings.window_mode = mode
	_apply_display()


## 172：换一档分辨率（当场套用、存盘）；全屏时不接
func set_resolution(size: Vector2i) -> void:
	if not WindowSetup.PRESETS.has(size) or flow.settings.window_mode == WindowSetup.FULLSCREEN:
		return
	flow.settings.resolution = size
	_apply_display()


func _apply_display() -> void:
	if is_inside_tree():
		WindowSetup.apply(flow.settings, get_window())
	flow.save_settings()
	refresh_display()


## 172：按设置刷新「显示」一节（F11 切了模式时导演也调）
func refresh_display() -> void:
	var full := flow.settings.window_mode == WindowSetup.FULLSCREEN
	for m in _mode_btns:
		(_mode_btns[m] as Button).set_pressed_no_signal(String(m) == flow.settings.window_mode)
	for p in _res_btns:
		var b := _res_btns[p] as Button
		b.disabled = full
		b.set_pressed_no_signal(not full and p == flow.settings.resolution)
	if _res_note != null:
		_res_note.visible = full


## 一个开关按钮：辅助档、按下保持、左对齐（这一屏的几个布尔项）
func _toggle(text: String, handler: Callable) -> Button:
	var b := _button(text, handler, 14, UiPalette.Tier.MINOR)
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


## 090：返回上一级 —— 嵌在暂停菜单里就回暂停菜单，独立的一屏就回主菜单
func go_back() -> void:
	if back.is_valid():
		back.call()
	else:
		flow.to_main_menu()


## 084：节点浮窗预览：不管章节开没开都显示
func toggle_node_tooltips_preview() -> void:
	flow.settings.node_tooltips_preview = not flow.settings.node_tooltips_preview
	flow.save_settings()
	_refresh()


## 084：拿走最后一件后自动关闭战利品 / 容器屏（默认关：手动关）
func toggle_loot_auto_close() -> void:
	flow.settings.loot_auto_close = not flow.settings.loot_auto_close
	flow.save_settings()
	_refresh()


## 117：战斗日志开关（这一局当场生效）
func toggle_battle_trace() -> void:
	flow.settings.battle_trace = not flow.settings.battle_trace
	flow.save_settings()
	flow.apply_battle_trace()
	_refresh()


## 150 补 2：调试模式开关（存盘；地图屏从暂停菜单的设置回来时照新值重摆）
func toggle_debug_mode() -> void:
	flow.settings.debug_mode = not flow.settings.debug_mode
	flow.save_settings()
	_refresh()


## 157 补：换光标材质（当场换上、存盘）
func set_cursor_skin(skin: String) -> void:
	if not UiCursor.SKINS.has(skin):
		return
	flow.settings.cursor_skin = skin
	flow.save_settings()
	UiCursor.apply(skin)
	_refresh()


## 157：换屏淡入开关（下一次换屏生效）
func toggle_ui_fades() -> void:
	flow.settings.ui_fades = not flow.settings.ui_fades
	flow.save_settings()
	_refresh()


## 117：在系统的文件管理器里打开 user://battle_logs
func open_log_folder() -> void:
	DirAccess.make_dir_recursive_absolute(BattleArchive.DIR)
	OS.shell_open(ProjectSettings.globalize_path(BattleArchive.DIR))


## 091（作者定）：挑背景底色，立刻生效并存盘
func set_bg_theme(id: String) -> void:
	if not UiPalette.has_bg_theme(id):
		return
	flow.settings.bg_theme = id
	UiPalette.apply(flow.settings)
	flow.save_settings()
	refresh_backdrop()
	_refresh()


## 091：老手的「全部解锁」开关（成就不计）
func toggle_unlock_all() -> void:
	flow.toggle_unlock_all()
	_refresh()


func _refresh() -> void:
	refresh_display()
	if _sfx_label != null:
		_sfx_label.text = UiText.t("settings.sfx_volume") % roundi(flow.settings.sfx_volume * 100.0)
	if _tooltip_btn != null:
		_tooltip_btn.set_pressed_no_signal(flow.settings.node_tooltips_preview)
		_tooltip_btn.text = "节点浮窗预览：%s" % ("开（不管章节）" if flow.settings.node_tooltips_preview else "关（按章节：第二章开）")
	if _auto_close_btn != null:
		_auto_close_btn.set_pressed_no_signal(flow.settings.loot_auto_close)
		_auto_close_btn.text = UiText.t("settings.loot_auto_close_state") % (UiText.t("settings.on") if flow.settings.loot_auto_close else UiText.t("settings.off_manual"))
	if _trace_btn != null:
		_trace_btn.set_pressed_no_signal(flow.settings.battle_trace)
		_trace_btn.text = "战斗日志：%s" % ("开" if flow.settings.battle_trace else "关")
	if _debug_btn != null:
		_debug_btn.set_pressed_no_signal(flow.settings.debug_mode)
		_debug_btn.text = "调试模式：%s" % ("开" if flow.settings.debug_mode else "关")
	if _fades_btn != null:
		_fades_btn.set_pressed_no_signal(flow.settings.ui_fades)
		_fades_btn.text = UiText.t("settings.fades_state") % (UiText.t("settings.on") if flow.settings.ui_fades else UiText.t("settings.off"))
	for sid in _cursor_btns:
		(_cursor_btns[sid] as Button).set_pressed_no_signal(String(sid) == (flow.settings.cursor_skin if UiCursor.SKINS.has(flow.settings.cursor_skin) else UiCursor.DEFAULT_SKIN))
	for tid in _bg_btns:
		# 101 第 5 刀：设置里存的可能是空串或认不出来的 id，按生效的那一档打勾
		(_bg_btns[tid] as Button).set_pressed_no_signal(String(tid) == UiPalette.bg_theme)
	if _unlock_all_btn != null:
		_unlock_all_btn.set_pressed_no_signal(flow.settings.unlock_all)
		_unlock_all_btn.text = UiText.t("settings.unlock_all_state") % (UiText.t("settings.unlock_all_on") if flow.settings.unlock_all else UiText.t("settings.off"))


## 090：Esc = 返回上一级（同「返回 / 回主菜单」按钮）
func escape() -> bool:
	go_back()
	return true
