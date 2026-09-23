## 设置（058 第 3 条）：现在只有一项 —— 离开点时暂存区的提醒档位与阈值。改了就存。
extends GameScreen

var _mode_btns: Dictionary = {}
var _rarity_spin: SpinBox
var _value_spin: SpinBox


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
		var b := _button(String(GameSettings.WARN_MODE_LABELS.get(m, String(m))), func(): set_mode(m), 14)
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
	col.add_child(_button("回主菜单", flow.to_main_menu, 14))
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
	for m in _mode_btns:
		(_mode_btns[m] as Button).set_pressed_no_signal(flow.settings.storage_warn_mode == m)
