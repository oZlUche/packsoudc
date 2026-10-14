## 169：配色预览（启动器进）—— 字色模板 `data/authoring/ui/text_colors.json` 里每个颜色名在深底、浅底上各写一行样字，
## 旁边标对比度（不够 [constant UiTheme.MIN_CONTRAST] 标红）。作者改了文件按 F5 重读，不用开游戏翻到那一屏。
## 只读模板、不写任何东西
extends Control

const SAMPLE := "样字 Aa 123"
const COLUMN_WIDTH := 420

var _root: VBoxContainer = null


func _ready() -> void:
	UiTheme.prepare_root(self)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := UiTheme.margins(MarginContainer.new(), 24, 24, 24, 24)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	_root = UiTheme.vbox(12)
	margin.add_child(_root)
	rebuild()


## 按现在的模板重画整页
func rebuild() -> void:
	UiTheme.clear_children(_root)
	_root.add_child(UiTheme.make_label("配色（字色模板）", 22, UiPalette.FG))
	_root.add_child(UiTheme.make_wrapped("文件：%s　　改完按 F5 重读　　F1 回启动器" % UiPalette.text_colors_path, 12, UiPalette.DIM, 900))
	for p in UiPalette.text_color_problems:
		_root.add_child(UiTheme.make_wrapped("✗ %s（现在用的是代码默认）" % p, 13, UiPalette.HP, 900))
	var cols := UiTheme.hbox(16)
	_root.add_child(cols)
	cols.add_child(_column(UiTheme.TONE_DARK))
	cols.add_child(_column(UiTheme.TONE_LIGHT))


## 一列：深底（面板色）或浅底（纸色），挂上对应的深浅（里面的字按 [method UiTheme.tone_at] 取版）
func _column(tone: StringName) -> PanelContainer:
	var light := tone == UiTheme.TONE_LIGHT
	var bg := UiTheme.PAPER if light else UiPalette.PANEL
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", box)
	p.set_meta(&"tone", tone)
	p.theme = UiTheme.text_theme(tone)
	var col := UiTheme.vbox(4)
	col.custom_minimum_size.x = COLUMN_WIDTH
	p.add_child(col)
	col.add_child(UiTheme.make_label("浅底（暗字）" if light else "深底（亮字）", 16))
	var data := UiPalette.text_colors()
	col.add_child(UiTheme.make_label("样式码 {c:名字}", 13))
	for name in data["styles"]:
		col.add_child(_row("[color=@%s]%s %s[/color]" % [name, name, SAMPLE], UiPalette.style_color(name, tone), bg))
	col.add_child(UiTheme.make_label("稀有度（{item:id} 的名字）", 13))
	for r in (data["rarity"] as Array).size():
		col.add_child(_row("[color=@%s%d]%s %s[/color]" % [TextTemplate.RARITY_STYLE, r, ItemTooltip.rarity_name(r), SAMPLE], UiPalette.rarity_color(r, tone), bg))
	col.add_child(UiTheme.make_label("伤害类型", 13))
	for type in data["damage"]:
		var c := UiPalette.damage_color(type, tone)
		col.add_child(_row("[color=#%s]%s %s[/color]" % [c.to_html(false), type, SAMPLE], c, bg))
	return p


func _row(bbcode: String, c: Color, bg: Color) -> Control:
	var h := UiTheme.hbox(8)
	var r := UiTheme.rich_block(300, 15, bbcode)
	h.add_child(r)
	var k := UiTheme.contrast(c, bg)
	# 对比够：暗色字（跟着底换）；不够：标红
	h.add_child(UiTheme.make_label("#%s  %.1f" % [c.to_html(false), k], 12, UiPalette.HP if k < UiTheme.MIN_CONTRAST else UiPalette.DIM))
	return h


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		UiPalette.load_text_colors()
		rebuild()
		get_viewport().set_input_as_handled()
