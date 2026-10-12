## 139（作者定）：基地屏右侧的「调试台」抽屉 —— 开发开关、局外解锁、科技等级、最近几局都收在这里，默认收起。
## 头部那一行最右边一个箭头按钮：「◂」= 收着，点一下开；「▸」= 开着，再点一下关。
## 开着时从右边**盖在页面上**（不把下面的格子挤变形），自己竖向滚。屏幕级的：五个页签都能开；开关只记在本屏，不进设置。
## 里面的东西由基地屏往 [member content] 里放（它们用的是屏幕的按钮 / 标签写法）
class_name DevDrawer
extends PanelContainer

const WIDTH := 420.0

## 开 / 关了（地图屏让右边那一列按钮让开它）
signal toggled(open: bool)

## 抽屉里的内容（竖排）
var content: VBoxContainer
## 头部的箭头按钮（由基地屏放进头部那一行）
var arrow: Button


func _init() -> void:
	visible = false
	name = "DevDrawer"
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.panel(self, 14)     # 121：主题的 PanelDark 变体
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	arrow = Button.new()
	arrow.tooltip_text = "调试台"
	UiPalette.style_button(arrow, UiPalette.Tier.MINOR, UiPalette.button_font_size(16, UiPalette.Tier.MINOR))
	arrow.pressed.connect(toggle)
	_sync_arrow()


## 贴着右缘、从 [param top] 往下到离底 [param margin]，宽 [constant WIDTH]
func dock(top: float, margin: float) -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -WIDTH - margin
	offset_right = -margin
	offset_top = top
	offset_bottom = -margin


## 抽屉只有 [constant WIDTH] 宽：里面的长标签、长按钮折行，不把抽屉撑宽
func wrap_contents(node: Node = null) -> void:
	for c in (node if node != null else content).get_children():
		if c is Label:
			(c as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(c as Label).custom_minimum_size.x = 0.0
			(c as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif c is Button:
			(c as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(c as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not (c is GridContainer):     # 科技等级那张表：名字短，按格子排，不折
			wrap_contents(c)


func toggle() -> bool:
	set_open(not visible)
	return visible


func set_open(on: bool) -> void:
	var was := visible
	visible = on
	_sync_arrow()
	if was != on:
		toggled.emit(on)


func is_open() -> bool:
	return visible


func _sync_arrow() -> void:
	if arrow != null:
		arrow.text = "▸" if visible else "◂"
