## 设置（058 第 3 条）：现在只有一项 —— 离开点时暂存区的提醒档位与阈值。改了就存。
extends GameScreen

var _auto_close_btn: Button = null
var _tooltip_btn: Button = null
var _unlock_all_btn: Button = null
## 091：背景底色的按钮（主题 id → 按钮）
var _bg_btns: Dictionary = {}
var _mode_btns: Dictionary = {}
var _rarity_spin: SpinBox
var _value_spin: SpinBox
## 090：从地图的暂停菜单嵌进来时的「返回」（回暂停菜单，一局还在）；空 = 独立的一屏，回主菜单
var back: Callable = Callable()


func open(_payload: Dictionary) -> void:
	_backdrop()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := _vbox(10)
	col.custom_minimum_size.x = 520
	center.add_child(col)
	col.add_child(_label("设置", 26, UiPalette.FG))
	col.add_child(_label("离开一个点时，暂存区里还有东西要不要提醒", 15, UiPalette.DIM))
	col.add_child(_wrapped("暂存区是在一个点上腾挪用的空间：在这个点上打过、搜过、买过之后一走，里面的东西就留在那里了（3.4）。", 12, UiPalette.DIM, 500))
	var s := flow.settings
	for mode in GameSettings.WARN_MODES:
		var m: StringName = mode
		var b := _button(String(GameSettings.WARN_MODE_LABELS.get(m, String(m))), func(): set_mode(m), 14, UiPalette.Tier.MINOR)
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_mode_btns[m] = b
		col.add_child(b)
	var row := _hbox(12)
	row.add_child(_label("稀有度阈值（0 普通 … 4 传说）", 13, UiPalette.DIM))
	_rarity_spin = SpinBox.new()
	_rarity_spin.min_value = 0
	_rarity_spin.max_value = 4
	_rarity_spin.value = s.storage_warn_rarity
	_rarity_spin.value_changed.connect(func(v: float): set_rarity(int(v)))
	row.add_child(_rarity_spin)
	col.add_child(row)
	var row2 := _hbox(12)
	row2.add_child(_label("价值阈值（币）", 13, UiPalette.DIM))
	_value_spin = SpinBox.new()
	_value_spin.min_value = 0
	_value_spin.max_value = 100000
	_value_spin.step = 10
	_value_spin.value = s.storage_warn_value
	_value_spin.value_changed.connect(func(v: float): set_value_threshold(int(v)))
	row2.add_child(_value_spin)
	col.add_child(row2)
	col.add_child(HSeparator.new())
	col.add_child(_label("战利品 / 容器屏", 15, UiPalette.DIM))
	_auto_close_btn = _button("拿走最后一件后自动关闭", toggle_loot_auto_close, 14, UiPalette.Tier.MINOR)
	_auto_close_btn.toggle_mode = true
	_auto_close_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_auto_close_btn)
	col.add_child(HSeparator.new())
	col.add_child(_label("地图", 15, UiPalette.DIM))
	col.add_child(_wrapped("节点浮窗（鼠标停在点上显示敌人数据与背包 / 用过了 / 可能发生什么……）按章节开放，第二章才开。这里能强制打开先看效果。", 12, UiPalette.DIM, 500))
	_tooltip_btn = _button("节点浮窗预览", toggle_node_tooltips_preview, 14, UiPalette.Tier.MINOR)
	_tooltip_btn.toggle_mode = true
	_tooltip_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
			b.add_theme_stylebox_override("normal", swatch)
		_bg_btns[tid] = b
		bg_row.add_child(b)
	col.add_child(bg_row)
	col.add_child(HSeparator.new())
	col.add_child(_label("老手", 15, UiPalette.DIM))
	col.add_child(_wrapped("全部解锁：章节、难度、道具不看解锁，直接全开；代价是成就不计（091）。", 12, UiPalette.DIM, 500))
	_unlock_all_btn = _button("全部解锁", toggle_unlock_all, 14, UiPalette.Tier.MINOR)
	_unlock_all_btn.toggle_mode = true
	_unlock_all_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_unlock_all_btn)
	col.add_child(HSeparator.new())
	col.add_child(_button("返回" if back.is_valid() else "回主菜单", go_back, 14))
	_refresh()


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


func set_mode(mode: StringName) -> void:
	if GameSettings.WARN_MODES.has(mode):
		flow.settings.storage_warn_mode = mode
		flow.save_settings()
	_refresh()


func set_rarity(v: int) -> void:
	flow.settings.storage_warn_rarity = clampi(v, 0, 4)
	flow.save_settings()


func set_value_threshold(v: int) -> void:
	flow.settings.storage_warn_value = maxi(0, v)
	flow.save_settings()


func _refresh() -> void:
	if _tooltip_btn != null:
		_tooltip_btn.set_pressed_no_signal(flow.settings.node_tooltips_preview)
		_tooltip_btn.text = "节点浮窗预览：%s" % ("开（不管章节）" if flow.settings.node_tooltips_preview else "关（按章节：第二章开）")
	if _auto_close_btn != null:
		_auto_close_btn.set_pressed_no_signal(flow.settings.loot_auto_close)
		_auto_close_btn.text = "拿走最后一件后自动关闭：%s" % ("开" if flow.settings.loot_auto_close else "关（手动关）")
	for m in _mode_btns:
		(_mode_btns[m] as Button).set_pressed_no_signal(flow.settings.storage_warn_mode == m)
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
