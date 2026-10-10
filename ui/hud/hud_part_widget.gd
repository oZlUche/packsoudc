## 150 补 1（作者定）：屏幕自己的一块控件（背包 / 撤离按钮、技能、路线、日志……）装进组件里，和读数一样按布局摆。
##
## 控件归屏幕：屏幕的 `hud_part(id)` 给出它（没有 = 这件空着），组件只是把它挂在自己身上；宿主换掉组件之前
## （[method release]）还给屏幕的 `hud_shelve(part)`，所以日志藏起来时照样在写，再摆出来能看到之前的。
## 「有没有内容」：列表（容器）没有子节点、提示行没字 = 空着，平时藏起来；摆读数时空着的露个名字好拖。
## 摆读数时上面盖一层「把手」接鼠标（按钮自己不再吃点击），拖动 / 右键 / 滚轮转给组件
class_name HudPartWidget
extends HudWidget

var part: Control = null
var _grip: Control


func _init() -> void:
	super()
	_grip = Control.new()
	_grip.name = "Grip"
	_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_grip.visible = false
	_grip.gui_input.connect(_gui_input)
	add_child(_grip)


func setup(p_run: RunState, p_screen: Control) -> void:
	screen = p_screen
	if part == null and screen != null and screen.has_method("hud_part"):
		part = screen.call("hud_part", id)
	if part != null:
		if part.get_parent() != null:
			part.reparent(self, false)
		else:
			add_child(part)
		move_child(_grip, -1)
		part.child_order_changed.connect(_poke)     # 列表重建了（路线、技能）：跟着显隐。提示行改字由屏幕叫 refresh
	super.setup(p_run, p_screen)


func release() -> void:
	if part == null:
		return
	if part.child_order_changed.is_connected(_poke):
		part.child_order_changed.disconnect(_poke)
	if screen != null and screen.has_method("hud_shelve"):
		screen.call("hud_shelve", part)
	elif part.get_parent() == self:
		remove_child(part)
	part = null


func title() -> String:
	return String(HudWidgets.PART_TITLES.get(id, id))


func has_content() -> bool:
	if part == null:
		return false
	if part is Label:
		return (part as Label).text != ""
	if part is Container:
		return part.get_child_count() > 0
	return true


func text_of() -> String:
	return ""


func refresh() -> void:
	var has := has_content()
	_text.visible = not has
	_text.text = "（%s）" % title() if editing and not has else ""
	if part != null:
		part.visible = has
	_grip.visible = editing
	visible = editing or (shown and has)
	queue_redraw()

