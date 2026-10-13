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
## 090：从地图的暂停菜单嵌进来时的「返回」（回暂停菜单，一局还在）；空 = 独立的一屏，回主菜单
var back: Callable = Callable()


func open(_payload: Dictionary) -> void:
	_backdrop()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slab_screen().add_child(center)     # 157 补充三：内容在一整块石板上
	var col := _vbox(10)
	col.custom_minimum_size.x = 520
	center.add_child(col)
	col.add_child(_label("设置", 26, UiPalette.FG))
	col.add_child(_label("战利品 / 容器屏", 15, UiPalette.DIM))
	_auto_close_btn = _toggle("拿走最后一件后自动关闭", toggle_loot_auto_close)
	col.add_child(_auto_close_btn)
	col.add_child(HSeparator.new())
	col.add_child(_label("地图", 15, UiPalette.DIM))
	col.add_child(_wrapped("节点浮窗（鼠标停在点上显示敌人数据与背包 / 用过了 / 可能发生什么……）按章节开放，第二章才开。这里能强制打开先看效果。", 12, UiPalette.DIM, 500))
	_tooltip_btn = _toggle("节点浮窗预览", toggle_node_tooltips_preview)
	col.add_child(_tooltip_btn)
	col.add_child(HSeparator.new())
	col.add_child(_label("背景底色", 15, UiPalette.DIM))
	var bg_row := _hbox(8)
	for t in UiPalette.BG_THEMES:
		var tid := String(t["id"])
		var b := _button(String(t["name"]), func(): set_bg_theme(tid), 13, UiPalette.Tier.MINOR)
		b.toggle_mode = true
		var box := b.get_theme_stylebox("normal") as StyleBoxFlat
		if box != null:
			var swatch := box.duplicate() as StyleBoxFlat
			swatch.bg_color = t["color"]
			b.add_theme_stylebox_override("normal", swatch)     # 121 特例：底色色板，按钮底就是那档底色（画布色）
		_bg_btns[tid] = b
		bg_row.add_child(b)
	col.add_child(bg_row)
	_fades_btn = _toggle("换屏淡入", toggle_ui_fades)     # 157
	col.add_child(_fades_btn)
	var cursor_row := _hbox(8)
	cursor_row.add_child(_label("光标", 14, UiPalette.FG))
	for skin in UiCursor.SKINS:
		var sid := String(skin)
		var cb := _button(String(UiCursor.SKINS[skin]), func(): set_cursor_skin(sid), 13, UiPalette.Tier.MINOR)
		cb.toggle_mode = true
		_cursor_btns[sid] = cb
		cursor_row.add_child(cb)
	col.add_child(cursor_row)
	col.add_child(HSeparator.new())
	col.add_child(_label("老手", 15, UiPalette.DIM))
	col.add_child(_wrapped("全部解锁：章节、难度、道具不看解锁，直接全开；代价是成就不计（091）。", 12, UiPalette.DIM, 500))
	_unlock_all_btn = _toggle("全部解锁", toggle_unlock_all)
	col.add_child(_unlock_all_btn)
	col.add_child(HSeparator.new())
	col.add_child(_label("调试", 15, UiPalette.DIM))
	col.add_child(_wrapped("调试模式：地图上摆出只给开发看的东西（事件日志）。关掉就藏起来，日志照样在记，再打开能看到之前的（150）。", 12, UiPalette.DIM, 500))
	_debug_btn = _toggle("调试模式", toggle_debug_mode)
	col.add_child(_debug_btn)
	col.add_child(HSeparator.new())
	if BattleArchive.default_on():     # 117：开发区只在非导出包里有 —— 日志是给作者看的，玩家看不到
		col.add_child(_label("开发", 15, UiPalette.DIM))
		col.add_child(_wrapped("战斗日志：每场战斗的内部日志（逐条、带时间）与回放存档写进 user://battle_logs，只留最近 %d 场。回放在开发工具的「战斗回放」里翻。" % BattleArchive.KEEP, 12, UiPalette.DIM, 500))
		var row := _hbox(8)
		_trace_btn = _toggle("战斗日志", toggle_battle_trace)
		row.add_child(_trace_btn)
		row.add_child(_button("打开日志文件夹", open_log_folder, 13, UiPalette.Tier.MINOR))
		col.add_child(row)
		col.add_child(HSeparator.new())
	col.add_child(_button("返回" if back.is_valid() else "回主菜单", go_back, 14))
	_refresh()


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
	if _tooltip_btn != null:
		_tooltip_btn.set_pressed_no_signal(flow.settings.node_tooltips_preview)
		_tooltip_btn.text = "节点浮窗预览：%s" % ("开（不管章节）" if flow.settings.node_tooltips_preview else "关（按章节：第二章开）")
	if _auto_close_btn != null:
		_auto_close_btn.set_pressed_no_signal(flow.settings.loot_auto_close)
		_auto_close_btn.text = "拿走最后一件后自动关闭：%s" % ("开" if flow.settings.loot_auto_close else "关（手动关）")
	if _trace_btn != null:
		_trace_btn.set_pressed_no_signal(flow.settings.battle_trace)
		_trace_btn.text = "战斗日志：%s" % ("开" if flow.settings.battle_trace else "关")
	if _debug_btn != null:
		_debug_btn.set_pressed_no_signal(flow.settings.debug_mode)
		_debug_btn.text = "调试模式：%s" % ("开" if flow.settings.debug_mode else "关")
	if _fades_btn != null:
		_fades_btn.set_pressed_no_signal(flow.settings.ui_fades)
		_fades_btn.text = "换屏淡入：%s" % ("开" if flow.settings.ui_fades else "关")
	for sid in _cursor_btns:
		(_cursor_btns[sid] as Button).set_pressed_no_signal(String(sid) == (flow.settings.cursor_skin if UiCursor.SKINS.has(flow.settings.cursor_skin) else UiCursor.DEFAULT_SKIN))
	for tid in _bg_btns:
		# 101 第 5 刀：设置里存的可能是空串或认不出来的 id，按生效的那一档打勾
		(_bg_btns[tid] as Button).set_pressed_no_signal(String(tid) == UiPalette.bg_theme)
	if _unlock_all_btn != null:
		_unlock_all_btn.set_pressed_no_signal(flow.settings.unlock_all)
		_unlock_all_btn.text = "全部解锁：%s" % ("开（章节 / 难度 / 道具全开，成就不计）" if flow.settings.unlock_all else "关")


## 090：Esc = 返回上一级（同「返回 / 回主菜单」按钮）
func escape() -> bool:
	go_back()
	return true
