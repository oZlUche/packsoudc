## 开局（M6，架构文档 8 节的 RunSetup）：挑一章、挑一套开局装备、定个种子，出发。
##
## 装备是内容管线里的 [LoadoutDef]（`data/loadouts/`），这里只列出来给人挑；摆法出发之后在地图上按「背包」调整。
## 所有动作都是公开方法（[method choose_chapter]、[method choose_loadout]、[method depart]），按钮只是调它们；测试直接调。
extends GameScreen

var chapter_index: int = 0
var loadout_index: int = 0
var run_seed: int = 1

var _chapter_btns: Array[Button] = []
var _loadout_btns: Array[Button] = []
var _preview: RichTextLabel
var _status: Label
var _seed_spin: SpinBox


func open(_payload: Dictionary) -> void:
	_backdrop()
	run_seed = randi() % 1000000
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var row := _hbox(32)
	margin.add_child(row)

	# 左：章节、装备、种子
	var left := _vbox(10)
	left.custom_minimum_size.x = 380
	row.add_child(left)
	left.add_child(_label("开局", 26, UiPalette.FG))
	left.add_child(_label("章节", 15, UiPalette.DIM))
	for i in flow.chapters.size():
		var c := flow.chapters[i]
		var idx := i
		var b := _button("%s（难度 %d）" % [c.display_name if c.display_name != "" else String(c.id), c.difficulty],
			func(): choose_chapter(idx))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_chapter_btns.append(b)
		left.add_child(b)
	if flow.chapters.is_empty():
		left.add_child(_label("没有章节：先跑 tools/import_content.gd", 13, UiPalette.HP))
	left.add_child(_label("开局装备", 15, UiPalette.DIM))
	for i in flow.loadouts.size():
		var l := flow.loadouts[i]
		var idx := i
		var b := _button(l.display_name if l.display_name != "" else String(l.id), func(): choose_loadout(idx))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_loadout_btns.append(b)
		left.add_child(b)
	if flow.loadouts.is_empty():
		left.add_child(_label("没有开局装备：data/authoring/loadouts/ 里一份都没有", 13, UiPalette.HP))
	var seed_row := _hbox(8)
	seed_row.add_child(_label("种子", 13, UiPalette.DIM))
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0
	_seed_spin.max_value = 999999
	_seed_spin.value = run_seed
	_seed_spin.value_changed.connect(func(v: float): run_seed = int(v))
	seed_row.add_child(_seed_spin)
	seed_row.add_child(_button("随机", func(): set_run_seed(randi() % 1000000), 12))
	left.add_child(seed_row)
	left.add_child(HSeparator.new())
	left.add_child(_button("出发", func(): depart(), 18))
	left.add_child(_button("回主菜单", flow.to_main_menu, 12))
	_status = _wrapped("", 12, UiPalette.DIM, 360)
	left.add_child(_status)

	# 右：预览
	var right := _vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_label("这一套带什么", 15, UiPalette.DIM))
	_preview = _log_box(14)
	right.add_child(_preview)

	choose_chapter(0)
	choose_loadout(0)


#region 公开动作
func choose_chapter(i: int) -> void:
	if flow.chapters.is_empty():
		return
	chapter_index = clampi(i, 0, flow.chapters.size() - 1)
	for k in _chapter_btns.size():
		_chapter_btns[k].add_theme_color_override("font_color", UiPalette.FG if k == chapter_index else UiPalette.DIM)
	_refresh_preview()


func choose_loadout(i: int) -> void:
	if flow.loadouts.is_empty():
		return
	loadout_index = clampi(i, 0, flow.loadouts.size() - 1)
	for k in _loadout_btns.size():
		_loadout_btns[k].add_theme_color_override("font_color", UiPalette.FG if k == loadout_index else UiPalette.DIM)
	_refresh_preview()


func set_run_seed(v: int) -> void:
	run_seed = v
	if _seed_spin != null:
		_seed_spin.set_value_no_signal(v)


func chapter() -> ChapterDef:
	return flow.chapters[chapter_index] if chapter_index < flow.chapters.size() else null


func loadout() -> LoadoutDef:
	return flow.loadouts[loadout_index] if loadout_index < flow.loadouts.size() else null


## 出发。生成不出图返回 false，留在这一屏说明原因
func depart() -> bool:
	var c := chapter()
	if c == null:
		_status.text = "没有章节可开"
		return false
	if flow.begin(c, loadout(), run_seed) == null:
		_status.text = "这一章生成不出图：%s" % (c.map_source.last_error if c.map_source != null else "没有地图来源")
		return false
	return true
#endregion


func _refresh_preview() -> void:
	if _preview == null:
		return
	_preview.clear()
	var c := chapter()
	if c != null:
		_preview.append_text("[b]%s[/b]　难度 %d　敌人池 %s\n\n" % [c.display_name, c.difficulty, String(c.enemy_pool) if c.enemy_pool != &"" else "无"])
	var l := loadout()
	if l == null:
		return
	_preview.append_text("[b]%s[/b]\n%s\n\n" % [l.display_name, l.description])
	var bag_cells := 0
	var item_cells := 0
	var value := 0
	for id in l.items:
		var def := flow.items.get_def(id)
		if def == null:
			_preview.append_text("[color=#d9534f]找不到道具 %s[/color]\n" % id)
			continue
		var cells := def.shape.cell_count() if def.shape != null else 0
		if def.is_bag:
			bag_cells += cells
			_preview.append_text("包　%s  %d 格\n" % [def.display_name, cells])
		else:
			item_cells += cells
			value += ItemValue.of(def)
			_preview.append_text("　　%s\n" % _item_line(def))
	_preview.append_text("\n包一共 %d 格，东西一共 %d 格%s；本身值 %d 币" % [
		bag_cells, item_cells, "（放不下的进暂存区，出发后按「背包」整理）" if item_cells > bag_cells else "", value])
