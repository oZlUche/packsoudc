## 145：一条规则的浮窗（作者：规则看不清是谁的，效仿 Windows —— 列表一行一条，双击弹窗，触发 / 消耗 / 效果分页签）。
##
## 继承 [FloatingWindow]：同一张画布里能拖的面板，位置按 [constant KEY] 记住。挂在编辑器给的弹窗层上
## （[member PropertyForm.popup_layer]），弹窗开着时那一层接住鼠标，点外面就关；Esc 也关。
##
## 三个页签各是一份 [PropertyForm]，对象就是这条规则本身、只显示自己那几个字段 ——
## **改动直接写进规则**（和整个编辑器一样所见即所得，反悔 = 不存盘），每次改动刷新顶上的预览句、页签条数，并回调列表。
class_name RuleWindow
extends FloatingWindow

const KEY := "rule_window"
## 页签：标题、显示的字段
const TABS := [["触发", ["trigger", "cadence"]], ["消耗", ["costs"]], ["效果", ["effects"]]]

var rule: AbilityRule = null
var _preview: Label
var _tabs: TabContainer
var _implied: Label
var _on_change: Callable


## 弹窗层里已有一块就复用（换内容、位置不动），没有就新建一块
static func open_in(layer: Control) -> RuleWindow:
	for c in layer.get_children():
		if c is RuleWindow and not c.is_queued_for_deletion():
			return c
	var w := RuleWindow.new()
	w.setup(KEY, "规则", w.close, "关闭")
	w.custom_minimum_size = Vector2(580, 460)
	layer.add_child(w)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.gui_input.connect(w._on_layer_input)
	layer.move_to_front()
	return w


func show_rule(p_rule: AbilityRule, title: String, font: Font, on_change: Callable = Callable()) -> void:
	rule = p_rule
	_on_change = on_change
	_title.text = title
	var held := _tabs.current_tab if _tabs != null else 0
	UiTheme.clear_children(body())
	_preview = UiTheme.make_wrapped("", 13, UiPalette.FG, 540)
	body().add_child(_preview)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.custom_minimum_size.y = 360
	body().add_child(_tabs)
	for spec in TABS:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(col)
		var form := PropertyForm.create(rule, font)
		form.only = spec[1]
		form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		form.changed.connect(_changed)
		col.add_child(form)
		if spec[0] == "消耗":
			_implied = UiTheme.make_label("", 12, UiPalette.DIM)
			col.add_child(_implied)
		_tabs.add_child(scroll)
	_tabs.current_tab = clampi(held, 0, TABS.size() - 1)
	_refresh()


## 第几页的表单（测试用）
func tab_form(i: int) -> PropertyForm:
	return (_tabs.get_child(i) as ScrollContainer).get_child(0).get_child(0) as PropertyForm


func tab_title(i: int) -> String:
	return _tabs.get_tab_title(i)


func preview_text() -> String:
	return _preview.text


func implied_text() -> String:
	return _implied.text if _implied.visible else ""


func _changed() -> void:
	_refresh()
	if _on_change.is_valid():
		_on_change.call()


func _refresh() -> void:
	_preview.text = Glossary.rule_text(rule)
	_tabs.set_tab_title(0, TABS[0][0])
	_tabs.set_tab_title(1, "%s（%d）" % [TABS[1][0], rule.costs.size()])
	_tabs.set_tab_title(2, "%s（%d）" % [TABS[2][0], rule.effects.size()])
	# 扳机隐含的消耗（层数够时消耗那几层）只读，写在消耗页底下
	var bits: Array[String] = []
	if rule.trigger != null:
		for c in rule.trigger.implied_costs():
			var d := c.describe()
			if d != "":
				bits.append(d)
	_implied.text = "扳机隐含：" + "，".join(bits) if not bits.is_empty() else ""
	_implied.visible = not bits.is_empty()


func close() -> void:
	var layer := get_parent() as Control
	if layer != null:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if layer.gui_input.is_connected(_on_layer_input):
			layer.gui_input.disconnect(_on_layer_input)
	queue_free()


## 点到浮窗外面（弹窗层上）就关
func _on_layer_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		close()


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE and not is_queued_for_deletion():
		close()
		get_viewport().set_input_as_handled()
