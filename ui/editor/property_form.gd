## 按反射生成的属性表单（架构文档 10.4）。
##
## [b]和导入器同一条原则：不认识任何具体效果。[/b] 它问 Godot「这个对象有哪些
## 导出属性、各是什么类型」，然后为每种类型摆一个控件；碰到抽象基类就去
## [ContentSchema] 要可选类型列表填下拉框。
##
## 于是**新增一种效果，编辑器的下拉框自动多一项**，这个文件一行都不用改 ——
## 这正是内容管线对 MOD 作者的承诺：加一个脚本 + 注册表登记一行，工具链全线认得。
##
## 表单直接改传进来的对象（所见即所得），每次改动发 [signal changed]，
## 外壳据此重新校验并刷新 JSON 预览。
class_name PropertyForm
extends VBoxContainer

signal changed

const INDENT := 14

var label_font: Font
## 这些字段由别处专门编辑（形状有画板、id 在顶栏），表单里跳过
var skip: Array[StringName] = []

var _target: Object = null


static func create(target: Object, font: Font, skip_props: Array[StringName] = []) -> PropertyForm:
	var f := PropertyForm.new()
	f.label_font = font
	f.skip = skip_props
	f._target = target
	f.add_theme_constant_override("separation", 4)
	return f


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	if _target == null:
		return
	for prop in ContentSchema.properties_of(_target):
		if skip.has(StringName(prop["name"])):
			continue
		var row := _row_for(_target, prop)
		if row != null:
			add_child(row)


func _emit() -> void:
	changed.emit()


#region 每种类型一个控件
func _row_for(owner: Object, prop: Dictionary) -> Control:
	var key := String(prop["name"])
	var value = owner.get(key)
	var type := int(prop["type"])

	match type:
		TYPE_BOOL:
			var cb := CheckBox.new()
			cb.text = key
			cb.button_pressed = value
			_font(cb)
			cb.toggled.connect(func(on: bool):
				owner.set(key, on)
				_emit())
			return cb

		TYPE_INT:
			var options := ContentSchema.enum_options(owner, prop)
			if not options.is_empty():
				return _labeled(key, _enum_picker(owner, prop, options, int(value)))
			return _labeled(key, _number(value, 1.0, func(v: float): owner.set(key, int(v))))

		TYPE_FLOAT:
			return _labeled(key, _number(value, 0.1, func(v: float): owner.set(key, v)))

		TYPE_STRING, TYPE_STRING_NAME:
			var le := LineEdit.new()
			le.text = String(value)
			le.custom_minimum_size.x = 180
			_font(le)
			le.text_changed.connect(func(t: String):
				owner.set(key, StringName(t) if type == TYPE_STRING_NAME else t)
				_emit())
			return _labeled(key, le)

		TYPE_DICTIONARY:
			return _labeled(key, _dict_editor(owner, key, value as Dictionary))

		TYPE_ARRAY:
			return _array_section(owner, key, value as Array)

		TYPE_OBJECT:
			return _object_section(owner, prop, value as Object)

	return null


func _enum_picker(
	owner: Object, prop: Dictionary, options: Array[String], current: int
) -> OptionButton:
	var ob := OptionButton.new()
	_font(ob)
	var values: Array[int] = []
	for i in options.size():
		ob.add_item(options[i], i)
		var v = ContentSchema.enum_value(owner, prop, options[i])
		values.append(int(v) if v != null else i)
		if values[i] == current:
			ob.select(i)
	ob.item_selected.connect(func(idx: int):
		owner.set(prop["name"], values[idx])
		_emit())
	return ob


func _number(value: float, step: float, apply: Callable) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = -99999
	sb.max_value = 99999
	sb.step = step
	sb.allow_greater = true
	sb.allow_lesser = true
	sb.value = value
	_font(sb)
	sb.value_changed.connect(func(v: float):
		apply.call(v)
		_emit())
	return sb


## 字典（base_stats 这种「属性键 → 数值」）用一行一对的写法。
## 键是自由文本而不是下拉框 —— 属性键本来就是可扩展的，锁死列表反而挡住新资源。
func _dict_editor(owner: Object, key: String, dict: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	for k in dict.keys():
		var row := HBoxContainer.new()
		var name_edit := LineEdit.new()
		name_edit.text = String(k)
		name_edit.custom_minimum_size.x = 130
		_font(name_edit)
		var val := SpinBox.new()
		val.min_value = -99999
		val.max_value = 99999
		val.step = 0.1
		val.allow_greater = true
		val.allow_lesser = true
		val.value = float(dict[k])
		_font(val)
		var old_key := String(k)
		name_edit.text_submitted.connect(func(t: String):
			var v = dict[old_key]
			dict.erase(old_key)
			dict[t] = v
			owner.set(key, dict)
			_emit()
			rebuild())
		val.value_changed.connect(func(v: float):
			dict[old_key] = v
			owner.set(key, dict)
			_emit())
		row.add_child(name_edit)
		row.add_child(val)
		row.add_child(_small_button("删", func():
			dict.erase(old_key)
			owner.set(key, dict)
			_emit()
			rebuild()))
		box.add_child(row)
	box.add_child(_small_button("+ 加一项", func():
		var n := "new_stat"
		var i := 1
		while dict.has(n):
			n = "new_stat_%d" % i
			i += 1
		dict[n] = 0.0
		owner.set(key, dict)
		_emit()
		rebuild()))
	return box


func _array_section(owner: Object, key: String, arr: Array) -> Control:
	var builtin := arr.get_typed_builtin()

	# 标签／格子这类简单数组用一行文本，比每项一个控件好用得多
	if builtin == TYPE_STRING_NAME or builtin == TYPE_STRING:
		var le := LineEdit.new()
		var parts: Array[String] = []
		for v in arr:
			parts.append(String(v))
		le.text = ", ".join(parts)
		le.custom_minimum_size.x = 220
		_font(le)
		le.text_changed.connect(func(t: String):
			var out := ContentSchema.empty_like(arr)
			for piece in t.split(",", false):
				var s := (piece as String).strip_edges()
				if s != "":
					out.append(StringName(s) if builtin == TYPE_STRING_NAME else s)
			owner.set(key, out)
			_emit())
		return _labeled(key, le)

	if builtin == TYPE_VECTOR2I:
		var le2 := LineEdit.new()
		var parts2: Array[String] = []
		for v in arr:
			parts2.append("%d,%d" % [(v as Vector2i).x, (v as Vector2i).y])
		le2.text = "; ".join(parts2)
		le2.custom_minimum_size.x = 220
		le2.placeholder_text = "x,y; x,y"
		_font(le2)
		le2.text_changed.connect(func(t: String):
			var out := ContentSchema.empty_like(arr)
			for piece in t.split(";", false):
				var xy := (piece as String).strip_edges().split(",")
				if xy.size() == 2:
					out.append(Vector2i(int(xy[0]), int(xy[1])))
			owner.set(key, out)
			_emit())
		return _labeled(key, le2)

	if builtin != TYPE_OBJECT:
		return _labeled(key, _muted("（暂不支持在界面里编辑）"))

	# --- 对象数组：每项一个可折叠的子表单，带类型下拉 ---
	var element_class := ContentSchema.array_element_class(arr)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_heading("%s（%d）" % [key, arr.size()]))

	for i in arr.size():
		var idx := i
		var item := arr[i] as Object
		var card := _card()
		var body := _body(card)
		var head := HBoxContainer.new()
		head.add_child(_muted("[%d] %s" % [idx, ContentSchema.registry_name_of(item)]))
		head.add_child(_small_button("↑", func():
			if idx > 0:
				var tmp = arr[idx - 1]
				arr[idx - 1] = arr[idx]
				arr[idx] = tmp
				_emit()
				rebuild()))
		head.add_child(_small_button("↓", func():
			if idx < arr.size() - 1:
				var tmp = arr[idx + 1]
				arr[idx + 1] = arr[idx]
				arr[idx] = tmp
				_emit()
				rebuild()))
		head.add_child(_small_button("删", func():
			arr.remove_at(idx)
			owner.set(key, arr)
			_emit()
			rebuild()))
		body.add_child(head)
		body.add_child(_sub_form(item))
		box.add_child(card)

	box.add_child(_adder(element_class, func(made: Object):
		arr.append(made)
		owner.set(key, arr)
		_emit()
		rebuild()))
	return box


func _object_section(owner: Object, prop: Dictionary, value: Object) -> Control:
	var key := String(prop["name"])
	var declared := StringName(prop["hint_string"])
	# 贴图之类的引擎类型交给别处，表单不碰
	if not ContentSchema.ABSTRACT_ROOTS.has(declared) \
			and ContentSchema.script_of(declared) == null:
		return null

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_child(_heading(key))
	if value == null:
		head.add_child(_adder(declared, func(made: Object):
			owner.set(key, made)
			_emit()
			rebuild()))
	else:
		head.add_child(_muted(String(ContentSchema.registry_name_of(value))))
		head.add_child(_small_button("清除", func():
			owner.set(key, null)
			_emit()
			rebuild()))
	box.add_child(head)
	if value != null:
		var card := _card()
		_body(card).add_child(_sub_form(value))
		box.add_child(card)
	return box


## 「添加」按钮 + 类型下拉。可选类型来自 [ContentSchema]，
## 所以新增一种效果这里自动多一项。
func _adder(declared: StringName, on_made: Callable) -> Control:
	var row := HBoxContainer.new()
	var types := ContentSchema.available_types(declared)
	if types.size() <= 1:
		var only := types[0] if types.size() == 1 else declared
		row.add_child(_small_button("+ 添加", func():
			var made := ContentSchema.make(declared, only)
			if made != null:
				on_made.call(made)))
		return row

	var ob := OptionButton.new()
	_font(ob)
	for i in types.size():
		ob.add_item(String(types[i]), i)
	row.add_child(ob)
	row.add_child(_small_button("+ 添加", func():
		var made := ContentSchema.make(declared, types[ob.get_selected_id()])
		if made != null:
			on_made.call(made)))
	return row


func _sub_form(obj: Object) -> PropertyForm:
	var sub := PropertyForm.create(obj, label_font)
	sub.changed.connect(_emit)
	return sub
#endregion


#region 小控件
func _font(c: Control) -> void:
	if label_font == null:
		return
	c.add_theme_font_override("font", label_font)
	if c is LineEdit or c is OptionButton or c is Button:
		c.add_theme_font_size_override("font_size", 13)


func _labeled(text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 130
	_font(l)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", UiPalette.DIM)
	row.add_child(l)
	row.add_child(control)
	return row


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	_font(l)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", UiPalette.FG)
	return l


func _muted(text: String) -> Label:
	var l := Label.new()
	l.text = text
	_font(l)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UiPalette.DIM)
	return l


func _small_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	_font(b)
	b.pressed.connect(handler)
	return b


## 缩进一格的小卡片：返回外层容器，内容加到 [method _body] 里。
func _card() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", INDENT)
	var inner := VBoxContainer.new()
	inner.name = "Body"
	inner.add_theme_constant_override("separation", 3)
	margin.add_child(inner)
	return margin


func _body(card: MarginContainer) -> VBoxContainer:
	return card.get_node("Body") as VBoxContainer
#endregion
