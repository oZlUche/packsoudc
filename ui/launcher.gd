## 启动选择器 —— 项目的主场景。
##
## 现在有三个能单独跑的场景，把主场景写死成其中一个，另外两个就只能在 Godot 里
## 手动挑（F6），命令行还得记住路径。这里列出来，F5 进去点一下就行。
##
## [b]它只负责切场景，不碰任何游戏状态。[/b] 真正的场景流（进关、战斗、结算）
## 是 M6 的事，那时候这个选择器会退化成一个调试入口，或者直接删掉。
extends Control

## 说明文字的折行宽度。见 _wrapped 里的注释。
const CARD_WIDTH := 500

const ENTRIES := [
	{
		"scene": "res://ui/inventory/inventory_sandbox.tscn",
		"title": "背包整理沙盒",
		"desc": "M1 验收：棋盘 + 包体、异形拖拽、暂存区与战利品",
		"keys": "左键拖动　R 旋转　右键 / Esc 取消",
	},
	{
		"scene": "res://ui/battle/battle_sandbox.tscn",
		"title": "战斗沙盒",
		"desc": "M2 验收：摆背包 → 开打 → 看回放。拖一件装备就重新编译，预估 DPS 实时变",
		"keys": "播放 / 倍速 / 跳过　战斗中只能看",
	},
	{
		"scene": "res://ui/editor/content_editor.tscn",
		"title": "道具编辑器",
		"desc": "给开发者与 MOD 作者：改属性、画形状与邻接标记、实时校验，存成 JSON",
		"keys": "存盘后要跑一次 tools/import_content.gd 才会生效",
	},
]

var _font: Font


func _ready() -> void:
	_font = UiPalette.cjk_font()
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiPalette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size.x = CARD_WIDTH + 40
	center.add_child(col)

	col.add_child(_label("背包搜打撤", 28, UiPalette.FG))
	col.add_child(_label("开发期入口。正式场景流是 M6 的事。", 13, UiPalette.DIM))
	col.add_child(HSeparator.new())

	for entry in ENTRIES:
		col.add_child(_card(entry))

	col.add_child(HSeparator.new())
	col.add_child(_label("Esc 退出", 12, UiPalette.DIM))


func _card(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.PANEL
	style.border_color = UiPalette.LINE
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var go := Button.new()
	go.text = entry["title"]
	go.add_theme_font_override("font", _font)
	go.add_theme_font_size_override("font_size", 16)
	var scene: String = entry["scene"]
	go.pressed.connect(func(): _open(scene))
	box.add_child(go)

	# 说明文字单独一行，不要塞进 HBox：
	# autowrap 的 Label 在 HBox 里最小宽度会退化成一个字符宽，
	# 中文没有词边界，于是整段被压成竖排的一列。
	box.add_child(_wrapped(entry["desc"], 12, UiPalette.DIM))
	box.add_child(_wrapped(entry["keys"], 11, UiPalette.DIM.darkened(0.25)))
	return panel


func _open(scene: String) -> void:
	# change_scene_to_file 会把本场景换掉，所以没有「返回」——
	# 开发期够用，真需要的话重启比加一套导航便宜。
	var err := get_tree().change_scene_to_file(scene)
	if err != OK:
		push_error("场景切换失败：" + scene)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## 会折行的说明文字。**必须给最小宽度** —— 否则容器按「最长不可断片段」
## 算最小宽度，中文没有词边界，那个值就是一个字。
func _wrapped(text: String, font_size: int, color: Color) -> Label:
	var l := _label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = CARD_WIDTH
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
