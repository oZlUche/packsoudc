## 启动选择器 —— 开发期的入口。
##
## 有好几个能单独跑的场景（沙盒、编辑器），命令行还得记住路径。这里列出来，点一下就行。
## M6 之后项目的主场景是正式游戏（`ui/game/game.tscn`），这里退化成调试入口：
## 从主菜单的「开发工具」进来，F1 回去。
##
## [b]它只负责切场景，不碰任何游戏状态。[/b]
extends Control

## 说明文字的折行宽度。见 _wrapped 里的注释。
const CARD_WIDTH := 500

const ENTRIES := [
	{
		"scene": "res://ui/game/game.tscn",
		"title": "正式游戏",
		"desc": "M6 场景流（也是项目的主场景）：主菜单 → 开局选装备 → 地图 ⇄ 战斗 / 搜刮 / 商店 / 事件 / 休息 → 结算 → 仓库",
		"keys": "地图上 B 开背包　F 缩到放下　F1 回这里",
	},
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
		"keys": "存盘直接产出资产，不必再手动导入",
	},
	{
		"scene": "res://ui/event_editor/event_editor.tscn",
		"title": "事件编辑器",
		"desc": "给作者写事件：标题、正文、导入配图、选项与它们的条件 / 后果（构件下拉来自注册表），实时校验、右边看它在事件屏上的样子，存盘直接产出资产，顺手挂进节点规则",
		"keys": "保存 = JSON + .tres　导入的图复制到 assets/events/<id>",
	},
	{
		"scene": "res://ui/buff_editor/buff_editor.tscn",
		"title": "Buff 制作器",
		"desc": "给作者做 buff：可否叠层 / 叠层上限、永续 / 持续秒数、效果从预设里挑或直接改 JSON，实时校验，存盘直接产出资产。界面语言跟主菜单的设置走（中文 / English）",
		"keys": "保存 = JSON + .tres　可叠层的 buff 一律永续",
	},
	{
		"scene": "res://ui/map_editor/map_editor.tscn",
		"title": "地图编辑器",
		"desc": "按参数随机生成一张地图，再手动改点、改路、改类型，存成预设给对局载入",
		"keys": "左键选中　Shift+左键连 / 断　右键路断开　Delete 删点",
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
	col.add_child(_label("第一项是正式游戏，其余是开发期的沙盒与编辑器。", 13, UiPalette.DIM))
	col.add_child(HSeparator.new())

	for entry in ENTRIES:
		col.add_child(_card(entry))

	col.add_child(HSeparator.new())
	col.add_child(_label("进去之后按 F1 或点右上角回到这里　　Esc 退出", 12, UiPalette.DIM))


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
	# change_scene_to_file 把本场景整个换掉，回来的路由 DevNav 那个 autoload 提供
	# （右上角按钮 / F1）—— 放在 autoload 里，是因为 F6 直接跑某个场景时
	# 也得能回来，而那时没有人替它装按钮。
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
