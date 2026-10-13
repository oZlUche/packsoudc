## 启动选择器 —— 开发期的入口。
##
## 有好几个能单独跑的场景（沙盒、编辑器），命令行还得记住路径。这里列出来，点一下就行。
## M6 之后项目的主场景是正式游戏（`ui/game/game.tscn`），这里退化成调试入口：
## 从主菜单的「开发工具」进来，F1 回去。
##
## [b]它只负责切场景，不碰任何游戏状态。[/b]
extends Control

## 说明文字的折行宽度（[method UiTheme.make_wrapped]：中文没有词边界，不给最小宽度整段会被压成一列）
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
		"desc": "M1 验收：棋盘 + 包体、异形拖拽、地上与战利品",
		"keys": "左键拖动　R 旋转　右键 / Esc 取消",
	},
	{
		"scene": "res://ui/battle/battle_sandbox.tscn",
		"title": "战斗沙盒",
		"desc": "M2 验收：摆背包 → 开打 → 看回放。拖一件装备就重新编译，预估 DPS 实时变",
		"keys": "播放 / 倍速 / 跳过　战斗中只能看",
	},
	{
		"scene": "res://ui/battle/replay_browser.tscn",
		"title": "战斗回放",
		"desc": "117：翻最近打过的战斗（user://battle_logs，设置里「战斗日志」开着时每场都存），照真打时一样重演；旁边能打开这场的逐条内部日志",
		"keys": "左边挑一场　播放 / 倍速 / 拖动　游戏里没有这个入口",
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
		"scene": "res://ui/part_editor/part_editor.tscn",
		"title": "构件编辑器",
		"desc": "146：规则构件库 —— 填好数值、起了名字的扳机 / 节奏 / 消耗与检查 / 效果。别的编辑器「添加」的下拉里「库：」那一组就是这里的；改一份，引用它的规则都跟着变",
		"keys": "保存 = JSON + .tres　右边看谁在用",
	},
	{
		"scene": "res://ui/set_editor/set_editor.tscn",
		"title": "套装编辑器",
		"desc": "给作者做套装：id、名字、计数方式、各档位（集齐几件生效什么：属性修饰 / 规则 / 别的作用域的效果），右边看哪些道具属于这套，实时校验，存盘直接产出资产",
		"keys": "保存 = JSON + .tres　道具的 set_id 写这个 id 就是成员",
	},
	{
		"scene": "res://ui/palette_preview/palette_preview.tscn",
		"title": "配色",
		"desc": "169：字色模板 data/authoring/ui/text_colors.json —— 每个颜色名在深底、浅底上各一行样字，标对比度（不够标红）",
		"keys": "改完文件按 F5 重读",
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
	UiTheme.prepare_root(self)     # 091 / 121：底色跟设置走、装上界面主题

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size.x = CARD_WIDTH + 40
	center.add_child(col)

	col.add_child(UiTheme.make_label("背包搜打撤", 28, UiPalette.FG))
	col.add_child(UiTheme.make_label("第一项是正式游戏，其余是开发期的沙盒与编辑器。", 13, UiPalette.DIM))
	col.add_child(HSeparator.new())

	for entry in ENTRIES:
		col.add_child(_card(entry))

	col.add_child(HSeparator.new())
	col.add_child(UiTheme.make_label("进去之后按 F1 或点右上角回到这里　　Esc 退出", 12, UiPalette.DIM))


func _card(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	UiTheme.panel(panel, 12)     # 121：主题的 PanelDark 变体

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var go := Button.new()
	go.text = entry["title"]
	go.add_theme_font_size_override("font_size", 16)
	var scene: String = entry["scene"]
	go.pressed.connect(func(): _open(scene))
	box.add_child(go)

	# 说明文字单独一行，不要塞进 HBox：
	# autowrap 的 Label 在 HBox 里最小宽度会退化成一个字符宽，
	# 中文没有词边界，于是整段被压成竖排的一列。
	box.add_child(UiTheme.make_wrapped(entry["desc"], 12, UiPalette.DIM, CARD_WIDTH))
	box.add_child(UiTheme.make_wrapped(entry["keys"], 11, UiPalette.DIM.darkened(0.25), CARD_WIDTH))
	return panel


func _open(scene: String) -> void:
	# change_scene_to_file 把本场景整个换掉，回来的路由 DevNav 那个 autoload 提供
	# （右上角按钮 / F1）—— 放在 autoload 里，是因为 F6 直接跑某个场景时
	# 也得能回来，而那时没有人替它装按钮。
	var err := get_tree().change_scene_to_file(scene)
	if err != OK:
		push_error("场景切换失败：" + scene)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
