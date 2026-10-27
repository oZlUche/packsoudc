## 设置：改了就存。109：离开点时地上的提醒档位那一块随提示一起删了
extends GameScreen

var _auto_close_btn: Button = null
var _tooltip_btn: Button = null
var _unlock_all_btn: Button = null
## 标题牌：告示卷排在它下面（[method notice_top]）
var _plate: Control = null
var _scroll: ScrollContainer = null
## 「导出平衡数据」石签：导出的告示卷排在它右边（[method notice_spot]）
var _export_btn: Control = null
## 2026-10-22：名字全显（百科不遮没点亮的道具名）
var _reveal_names_btn: Button = null
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
## 258：字号三档的石签（档名 → 签）
var _text_btns: Dictionary = {}
## 204：「声音」一节的音效音量（读数写在步进件的石牌上）
var _sfx: StoneStepper = null
## 090：从地图的暂停菜单嵌进来时的「返回」（回暂停菜单，一局还在）；空 = 独立的一屏，回主菜单
var back: Callable = Callable()


func open(_payload: Dictionary) -> void:
	_backdrop()
	# 172：加了「显示」一节后，1000 高的视口放不下整列（开发区在时更长）—— 包一层只竖着滚的滚动框，放得下照样居中。
	# UI替换美术 10-22：标题牌固定在板顶刻线上、不跟着滚；滚动框从标题牌下面开始，滚过去的内容不压刻线
	var frame := _vbox(10)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slab_screen().add_child(frame)     # 157 补充三：内容在一整块石板上
	var plate := TitlePlate.new(UiText.t("menu.settings"))     # 226 批二：标题刻在标题牌上
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_child(plate)
	_plate = plate
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := _vbox(10)
	col.custom_minimum_size.x = 520
	center.add_child(col)
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
		var b := StoneChip.make(UiText.pick(t["name"]), func(): set_bg_theme(tid), t["color"])     # 乙 石刻：底色签左边一块色样
		if t.has("note"):
			b.tooltip_text = UiText.pick(t["note"])     # 226 批二：「默认」「最浅」进悬浮窗
		var box := b.get_theme_stylebox("normal") as StyleBoxFlat
		if box != null and not b is StoneChip:     # 缺图的平板按钮：按钮底就是那档底色
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
	cursor_row.add_child(HeaderTag.new(UiText.t("settings.cursor")))     # 226：「光标」上段头签
	for skin in UiCursor.SKINS:
		var sid := String(skin)
		var cb := StoneChip.make(UiText.pick(UiCursor.SKINS[skin]), func(): set_cursor_skin(sid))
		_cursor_btns[sid] = cb
		cursor_row.add_child(cb)
	col.add_child(cursor_row)
	col.add_child(HSeparator.new())
	col.add_child(HeaderTag.new(UiText.t("settings.veteran")))
	_unlock_all_btn = _toggle(UiText.t("settings.unlock_all"), toggle_unlock_all)
	_unlock_all_btn.tooltip_text = UiText.t("settings.unlock_all_desc")     # 226 批二：说明进开关的悬浮窗
	col.add_child(_unlock_all_btn)
	var export_btn := StoneChip.make(UiText.t("settings.export_data"), func(): export_balance_data())     # 242：玩家版也有；和同页选项同一张石签（UI替换美术），只是不切换
	export_btn.toggle_mode = false
	export_btn.tooltip_text = UiText.t("settings.export_data_desc")
	export_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(export_btn)
	_export_btn = export_btn
	# 2026-10-22（作者）：百科遮名的总开关 —— 和老手开关同类，放同一节
	_reveal_names_btn = _toggle(UiText.t("settings.reveal_names"), toggle_reveal_names)
	_reveal_names_btn.tooltip_text = UiText.t("settings.reveal_names_desc")
	col.add_child(_reveal_names_btn)
	col.add_child(HSeparator.new())
	if DevGate.on():     # 117：开发区只在非导出包里有 —— 日志是给作者看的，玩家看不到。186：调试模式、节点浮窗预览也挪进来
		var dev := _vbox(8)     # 226 批四：开发区的说明字不算裸字，守门测试放过（只在开发包里有）
		dev.set_meta(&"exempt_bare_text", "dev")
		col.add_child(dev)
		dev.add_child(_label("开发", 15, UiPalette.DIM))
		dev.add_child(_wrapped("调试模式：地图上摆出只给开发看的东西（事件日志）。关掉就藏起来，日志照样在记。", 12, UiPalette.DIM, 500))
		_debug_btn = _toggle("调试模式", toggle_debug_mode)
		dev.add_child(_debug_btn)
		dev.add_child(_wrapped("节点浮窗按章节开放（第二章才开），这里能强制打开先看效果。", 12, UiPalette.DIM, 500))
		_tooltip_btn = _toggle("节点浮窗预览", toggle_node_tooltips_preview)
		dev.add_child(_tooltip_btn)
		dev.add_child(_wrapped("战斗日志：每场战斗的内部日志（逐条、带时间）与回放存档写进 user://battle_logs，只留最近 %d 场。回放在开发工具的「战斗回放」里翻。" % BattleArchive.KEEP, 12, UiPalette.DIM, 500))
		var row := _hbox(8)
		_trace_btn = _toggle("战斗日志", toggle_battle_trace)
		row.add_child(_trace_btn)
		var open_btn := StoneChip.make("打开日志文件夹", open_log_folder)     # UI替换美术：和整页同一张石签，不切换
		open_btn.toggle_mode = false
		row.add_child(open_btn)
		dev.add_child(row)
		dev.add_child(HSeparator.new())
	var back_key := ScrollKey.make(UiText.t("setup.back") if back.is_valid() else UiText.t("setup.main_menu"), go_back)     # 乙 石刻
	back_key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(back_key)
	_refresh()


## 172：「显示」一节（放最上面）—— 窗口 / 全屏两个按钮；分辨率按宽高比分行，只列放得进这块屏幕的档；全屏时整块灰掉、注一句。
## 主菜单的设置和 Esc 暂停菜单里嵌的是同一屏，两个入口都有它
func _build_display(col: VBoxContainer) -> void:
	add_to_group(GameDirector.DISPLAY_GROUP)     # F11 切了模式，这一节跟着刷新
	col.add_child(HeaderTag.new(UiText.t("settings.display")))
	var mode_row := _hbox(8)
	for m in [[WindowSetup.WINDOWED, "settings.windowed"], [WindowSetup.FULLSCREEN, "settings.fullscreen"]]:
		var mode: String = m[0]
		var b := StoneChip.make(UiText.t(String(m[1])), func(): set_window_mode(mode))
		_mode_btns[mode] = b
		mode_row.add_child(b)
	col.add_child(mode_row)
	var rows := {}     # 宽高比 → 那一行（226 批四：行头的「16:9」小字删了，宽高比进各档的悬浮窗）
	var shown := WindowSetup.available(WindowSetup.screen_size(get_window() if is_inside_tree() else null))
	for p in shown:
		var aspect := WindowSetup.aspect_name(p)
		if not rows.has(aspect):
			var row := _hbox(8)
			rows[aspect] = row
			col.add_child(row)
		var size: Vector2i = p
		var rb := StoneChip.make(WindowSetup.label(p), func(): set_resolution(size))
		_res_btns[p] = rb
		rows[aspect].add_child(rb)
	if shown.is_empty():     # 屏幕比最小一档还小：窗口就是屏幕那么大 —— 一颗灰着的签（226 批四）
		var follow := StoneChip.make(UiText.t("settings.res_follow_screen"), func(): pass)
		follow.disabled = true
		col.add_child(follow)
	# 258（作者 2026-10-27 定）：字号三档 小 / 中 / 大（主菜单不跟）；点了这一屏当场按新字号重建，别的屏下次进来生效
	var size_row := _hbox(8)
	size_row.add_child(HeaderTag.new(UiText.t("settings.text_size")))
	for tier in GameSettings.TEXT_SIZES:
		var id: StringName = tier
		var tb := StoneChip.make(UiText.t("settings.text_" + String(id)), func(): set_text_size(id))
		_text_btns[id] = tb
		size_row.add_child(tb)
	col.add_child(size_row)


## 204：「声音」一节 —— 音效音量一行（− / + 一步 10%，按钮本身响 `ui.press`，当场听到新音量）。音乐那行等第一首曲子再露出来（待定 4.2）
func _build_sound(col: VBoxContainer) -> void:
	col.add_child(HSeparator.new())
	col.add_child(HeaderTag.new(UiText.t("settings.sound")))
	# 226 §1.5 + 乙 石刻：读数并进步进件 [−][音效 80%][+]
	_sfx = StoneStepper.new(func(): step_sfx_volume(-1), func(): step_sfx_volume(1))
	_sfx.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_sfx)


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
		b.tooltip_text = UiText.t("settings.fullscreen_note") if full else WindowSetup.aspect_name(p)     # 226 批四：「全屏按桌面分辨率」进灰着的档的悬浮窗


## 一个开关行（这一屏的几个布尔项）：乙 石刻 —— 石签拉满整行、左头印表示开 / 关（[method StoneChip.toggle]）
func _toggle(text: String, handler: Callable) -> Button:
	return StoneChip.toggle(text, handler)


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


## 242：校准记录 + 战斗日志打成 zip 放桌面；取不到桌面放 user:// 并打开那个文件夹。返回写到的路径（失败空串）
func export_balance_data() -> String:
	var dir := DataExport.target_dir()
	var path := dir.path_join(DataExport.file_name())
	if DataExport.pack(path) < 0:
		_post(UiText.t("settings.export_data_failed") % ProjectSettings.globalize_path(path), true)
		return ""
	if dir.begins_with("user://"):
		OS.shell_open(ProjectSettings.globalize_path(dir))
	_post(export_notice(path))
	return path


## 游戏测试 10-22：告示只写放到哪、文件名 —— 整条路径太长，卷轴拉满整屏
static func export_notice(path: String) -> String:
	var key := "settings.export_data_done_folder" if path.begins_with("user://") else "settings.export_data_done"
	return UiText.t(key) % path.get_file()


## 游戏测试 10-22：告示卷排在标题牌下面，不压住「设置」两个字
func notice_top() -> float:
	if _plate == null or not is_instance_valid(_plate) or not _plate.is_inside_tree():
		return 0.0
	return _plate.get_global_rect().end.y + NoticeLayer.GAP


## 游戏测试 v4.26：标题牌下面紧挨着「显示」段头签，卷压住它的右半边 —— 卷排到刚点的那颗石签右边（那一行只有它，右边空着），
## 竖着对齐石签；石签不在 / 右边放不下（卷伸出板面）才照 [method notice_top] 排在标题牌下面。返回 [卷左沿离屏中线多远（负 = 中线左边）, 卷顶]
## 258：字号放大后导出石签可能在滚动框底边只露一半 —— 先把它连同卷的高度滚进来，卷才不出板面
func _reveal_export(text: String) -> void:
	if _scroll == null or _export_btn == null or not is_instance_valid(_export_btn) or not _export_btn.is_inside_tree():
		return
	var probe := NoticeScroll.make(text)
	var h := probe.custom_minimum_size.y
	probe.free()
	var btn := _export_btn.get_global_rect()
	var over := btn.get_center().y + h / 2.0 - _scroll.get_global_rect().end.y
	if over > 0.0:
		_scroll.scroll_vertical += ceili(over)
		_scroll.notification(Container.NOTIFICATION_SORT_CHILDREN)     # 立刻排到新位置，下面按石签量位置


func notice_spot(text: String) -> Vector2:
	var probe := NoticeScroll.make(text)
	var sz := probe.custom_minimum_size
	probe.free()
	if _export_btn != null and is_instance_valid(_export_btn) and _export_btn.is_inside_tree():
		var btn := _export_btn.get_global_rect()
		var left := btn.end.x + NoticeLayer.GAP
		if left + sz.x <= (_plate.get_parent() as Control).get_global_rect().end.x:     # 板面（标题牌所在的内容区）右沿
			var x := left - notice_layer().get_global_rect().get_center().x
			return Vector2(x if x != 0.0 else 0.5, btn.get_center().y - sz.y / 2.0)
	return Vector2(0.0, notice_top())


func _post(text: String, urgent: bool = false) -> void:
	_reveal_export(text)
	var spot := notice_spot(text)
	notice_layer().push(text, urgent, notice_cap(), spot.x, spot.y)


## 091（作者定）：挑背景底色，立刻生效并存盘
func set_bg_theme(id: String) -> void:
	if not UiPalette.has_bg_theme(id):
		return
	flow.settings.bg_theme = id
	UiPalette.apply(flow.settings)
	flow.save_settings()
	refresh_backdrop()
	_refresh()


## 258：换字号档 —— 存盘、主题按新倍率重填，这一屏整个重建（字号跟着变的是新造的控件）
func set_text_size(id: StringName) -> void:
	if not GameSettings.TEXT_SIZES.has(id) or flow.settings.text_size == id:
		_refresh()
		return
	flow.settings.text_size = id
	UiPalette.apply(flow.settings)
	flow.save_settings()
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for d in [_cursor_btns, _bg_btns, _mode_btns, _res_btns, _text_btns]:
		(d as Dictionary).clear()
	_auto_close_btn = null
	_tooltip_btn = null
	_unlock_all_btn = null
	_reveal_names_btn = null
	_trace_btn = null
	_debug_btn = null
	_fades_btn = null
	_sfx = null
	open({})


## 091：老手的「全部解锁」开关（成就不计）
func toggle_unlock_all() -> void:
	flow.toggle_unlock_all()
	_refresh()


## 2026-10-22（作者）：名字全显 —— 勾上之后百科不再把图鉴没点亮的道具名遮成「？」。
## 百科那三个遮名回调每次渲染现查这个开关，所以不用重建百科，下一次画就变
func toggle_reveal_names() -> void:
	if flow.settings == null:
		return
	flow.settings.reveal_names = not flow.settings.reveal_names
	flow.save_settings()
	_refresh()


func _refresh() -> void:
	refresh_display()
	if _sfx != null:
		_sfx.set_text(UiText.t("settings.sfx_volume") % roundi(flow.settings.sfx_volume * 100.0))
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
	for id in _text_btns:
		(_text_btns[id] as Button).set_pressed_no_signal(id == flow.settings.text_size)
	for tid in _bg_btns:
		# 101 第 5 刀：设置里存的可能是空串或认不出来的 id，按生效的那一档打勾
		(_bg_btns[tid] as Button).set_pressed_no_signal(String(tid) == UiPalette.bg_theme)
	if _unlock_all_btn != null:
		_unlock_all_btn.set_pressed_no_signal(flow.settings.unlock_all)
		_unlock_all_btn.text = UiText.t("settings.unlock_all_state") % (UiText.t("settings.unlock_all_on") if flow.settings.unlock_all else UiText.t("settings.off"))
	if _reveal_names_btn != null:
		_reveal_names_btn.set_pressed_no_signal(flow.settings.reveal_names)
		_reveal_names_btn.text = UiText.t("settings.reveal_names_state") % (UiText.t("settings.on") if flow.settings.reveal_names else UiText.t("settings.off"))


## 090：Esc = 返回上一级（同「返回 / 回主菜单」按钮）
func escape() -> bool:
	go_back()
	return true
