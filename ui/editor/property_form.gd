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
##
## 091（作者定）：字段名、类型名、枚举值**只在显示时**换成中文（[FieldText]），每一行都带悬浮说明（读脚本里 `@export` 上面的注释）；
## 字段本身、JSON、存档一个字不改。英文模式显示原名
class_name PropertyForm
extends VBoxContainer

signal changed

const INDENT := 14
## 091：直接 preload 而不靠全局类名 —— 作者拉了新脚本没重新 --import 时，全局类缓存里没有 FieldText，靠名字引用会让整份表单解析失败、编辑器一片空白
const FieldText := preload("res://core/authoring/field_text.gd")

var label_font: Font

## 由别处专门编辑、表单里要跳过的字段：`类名 -> [属性名]`。
##
## 按**类名**而不是一张平的名字表，因为子表单也要用同一份规则 ——
## 邻接的格子列表在画板上画，但它嵌在 adjacency 子表单里，
## 平的名字表管不到那一层。两处能改同一个值迟早对不上。
var skip: Dictionary = {}

var _target: Object = null
## 111：本表单每个字段的那一行（字段名 → 行控件），按 `FIELD_WHEN` 显隐用
var _rows: Dictionary = {}


static func create(target: Object, font: Font, skip_map: Dictionary = {}) -> PropertyForm:
	var f := PropertyForm.new()
	f.label_font = font
	f.skip = skip_map
	f._target = target
	f.add_theme_constant_override("separation", 4)
	return f


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_rows.clear()
	if _target == null:
		return
	var hidden: Array = skip.get(String(ContentSchema.class_name_of(_target)), [])
	for prop in ContentSchema.properties_of(_target):
		if hidden.has(String(prop["name"])):
			continue
		var row := _row_for(_target, prop)
		if row != null:
			add_child(row)
			_rows[String(prop["name"])] = row
	_apply_visibility(false)


func _emit() -> void:
	if _apply_visibility(true):
		rebuild.call_deferred()     # 有字段被归了默认：重画，让再显示出来时框里是新值
	changed.emit()


## 111：按资源的 `FIELD_WHEN` 显隐各行。[param reset] = 用户刚改过东西：变成隐藏的字段归默认值，
## JSON 里不留看不见的旧值（打开表单时不动数据，只藏）。返回有没有字段被归了默认
func _apply_visibility(reset: bool) -> bool:
	var changed_any := false
	for key in _rows:
		var vis := ContentSchema.field_visible(_target, key)
		(_rows[key] as Control).visible = vis
		if not vis and reset:
			var d = ContentSchema.default_of(_target, key)
			if d != null and _target.get(key) != d:
				_target.set(key, d)
				changed_any = true
	return changed_any


## 111：这一行现在是否显示（测试用）
func row_visible(key: String) -> bool:
	return _rows.has(key) and (_rows[key] as Control).visible


#region 每种类型一个控件
func _row_for(owner: Object, prop: Dictionary) -> Control:
	var key := String(prop["name"])
	var value = owner.get(key)
	var type := int(prop["type"])

	match type:
		TYPE_BOOL:
			var cb := CheckBox.new()
			cb.text = FieldText.label(owner, key)
			cb.tooltip_text = FieldText.tip(owner, key)
			cb.button_pressed = value
			_font(cb)
			cb.toggled.connect(func(on: bool):
				owner.set(key, on)
				_emit())
			return cb

		TYPE_INT:
			var options := ContentSchema.enum_options(owner, prop)
			if not options.is_empty():
				return _labeled(owner, key, _enum_picker(owner, prop, options, int(value)))
			return _labeled(owner, key, _number(value, 1.0, func(v: float): owner.set(key, int(v)), prop))

		TYPE_FLOAT:
			return _labeled(owner, key, _number(value, 0.1, func(v: float): owner.set(key, v), prop))

		TYPE_STRING, TYPE_STRING_NAME:
			if int(prop["hint"]) == PROPERTY_HINT_ENUM:
				# 111：字符串枚举（`@export_enum`）→ 下拉；值仍是字符串，显示名走 FieldText.enum_label
				return _labeled(owner, key, _string_picker(owner, prop, ContentSchema.enum_options(owner, prop), String(value)))
			if type == TYPE_STRING_NAME and _is_stat_field(key):
				# 091（作者定）：指向属性键的字段（修饰的 stat、效果的 damage_stat）下拉浏览已有属性，也能自定义
				return _labeled(owner, key, _stat_picker(String(value), func(k: String):
					owner.set(key, StringName(k))
					_emit()))
			if type == TYPE_STRING_NAME and _is_damage_type_field(key):
				# 096：伤害类型是数据（DamageTypes）：下拉列出登记过的，也能自定义
				return _labeled(owner, key, _key_picker(_damage_type_keys(), Callable(PropertyForm, "damage_type_label"), String(value), func(k: String):
					owner.set(key, StringName(k))
					_emit()))
			if type == TYPE_STRING_NAME and _is_tag_field(key):
				# 096：指向一个标签的字段（信仰的 item_tag、规则的 weapon_tag）：下拉列出登记过 / 用过的标签，也能自定义
				return _labeled(owner, key, _key_picker(known_tags(), Callable(PropertyForm, "tag_label"), String(value), func(k: String):
					owner.set(key, StringName(k))
					_emit()))
			var le := LineEdit.new()
			le.text = String(value)
			le.custom_minimum_size.x = 180
			_font(le)
			le.text_changed.connect(func(t: String):
				owner.set(key, StringName(t) if type == TYPE_STRING_NAME else t)
				_emit())
			return _labeled(owner, key, le)

		TYPE_VECTOR2I, TYPE_VECTOR2:
			# 范围 [min, max] 这类成对的数。两个数字框并排
			var whole := type == TYPE_VECTOR2I
			var pair := HBoxContainer.new()
			for axis in 2:
				var ax := axis
				pair.add_child(_number(float(value[ax]), 1.0 if whole else 0.1, func(v: float):
					var cur = owner.get(key)
					cur[ax] = int(v) if whole else v
					owner.set(key, cur)))
			return _labeled(owner, key, pair)

		TYPE_DICTIONARY:
			return _labeled(owner, key, _dict_editor(owner, key, value as Dictionary))

		TYPE_ARRAY:
			return _array_section(owner, key, value as Array)

		TYPE_OBJECT:
			return _object_section(owner, prop, value as Object)

	return null


func _string_picker(owner: Object, prop: Dictionary, options: Array[String], current: String) -> OptionButton:
	var ob := OptionButton.new()
	_font(ob)
	var string_name := int(prop["type"]) == TYPE_STRING_NAME
	for i in options.size():
		ob.add_item(FieldText.enum_label(options[i]), i)
		ob.set_item_tooltip(i, options[i])
		if options[i] == current:
			ob.select(i)
	ob.item_selected.connect(func(idx: int):
		owner.set(prop["name"], StringName(options[idx]) if string_name else options[idx])
		_emit())
	return ob


func _enum_picker(
	owner: Object, prop: Dictionary, options: Array[String], current: int
) -> OptionButton:
	var ob := OptionButton.new()
	_font(ob)
	var values: Array[int] = []
	for i in options.size():
		ob.add_item(FieldText.enum_label(options[i]), i)
		ob.set_item_tooltip(i, options[i])
		var v = ContentSchema.enum_value(owner, prop, options[i])
		values.append(int(v) if v != null else i)
		if values[i] == current:
			ob.select(i)
	ob.item_selected.connect(func(idx: int):
		owner.set(prop["name"], values[idx])
		_emit())
	return ob


func _number(value: float, step: float, apply: Callable, prop: Dictionary = {}) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = -99999
	sb.max_value = 99999
	sb.step = step
	sb.allow_greater = true
	sb.allow_lesser = true
	# 111：带 `@export_range(min, max[, step])` 的按它来，越界关掉
	if not prop.is_empty() and int(prop.get("hint", 0)) == PROPERTY_HINT_RANGE:
		var bits := String(prop["hint_string"]).split(",")
		if bits.size() >= 2 and bits[0].strip_edges().is_valid_float() and bits[1].strip_edges().is_valid_float():
			sb.min_value = float(bits[0])
			sb.max_value = float(bits[1])
			sb.allow_greater = false
			sb.allow_lesser = false
			if bits.size() >= 3 and bits[2].strip_edges().is_valid_float():
				sb.step = float(bits[2])
	sb.value = value
	_font(sb)
	sb.value_changed.connect(func(v: float):
		apply.call(v)
		_emit())
	return sb


## 「语言 → 文字」的字典（display_names / titles / texts / labels / descriptions）：加一项默认是空字符串、键是还没写的语言，不是数字
const TEXT_DICTS := ["display_names", "titles", "texts", "labels", "descriptions", "tooltip_texts"]


## 这张字典是不是文字表：按字段名认，或者已有的值全是字符串
static func _is_text_dict(key: String, dict: Dictionary) -> bool:
	if TEXT_DICTS.has(key):
		return true
	if dict.is_empty():
		return false
	for v in dict.values():
		if not (v is String):
			return false
	return true


## 「属性键 → 数值」的字典：按字段名认，或者已有的键全是认得的属性键
const STAT_DICTS := ["base_stats", "stat_scale"]
const CUSTOM_STAT := "__custom__"
## 内容里用过的属性键（编辑器打开时扫一遍作者目录；`register_stat_keys` 也能再登记）
static var _extra_stat_keys: Array[String] = []
static var _scanned_stats: bool = false


static func _is_stat_dict(key: String, dict: Dictionary) -> bool:
	if STAT_DICTS.has(key):
		return true
	if dict.is_empty():
		return false
	var known := known_stat_keys()
	for k in dict.keys():
		if not known.has(String(k)):
			return false
	return true


## 指向属性键的字段：修饰的 stat、效果的 damage_stat / heal_stat……
static func _is_stat_field(key: String) -> bool:
	return key == "stat" or key.ends_with("_stat")


## 096：指向标签的字段：`tags` / `*_tags` / `*_filter`（邻接的只给 / 只收）/ `tag` / `*_tag`（信仰的 item_tag、规则的 weapon_tag）
static func _is_tag_field(key: String) -> bool:
	return key == "tags" or key.ends_with("_tags") or key.ends_with("_filter") or key == "tag" or key.ends_with("_tag")


## 096：伤害类型字段
static func _is_damage_type_field(key: String) -> bool:
	return key == "damage_type"


## 标签给人看：中文模式「武器 (weapon)」，英文模式「Weapon (weapon)」；没登记的原词
static func tag_label(key: String) -> String:
	var n := TagRegistry.name_of(StringName(key))
	return "%s (%s)" % [n, key] if n != key else key


static func damage_type_label(key: String) -> String:
	var n := DamageTypes.name_of(StringName(key))
	return "%s (%s)" % [n, key] if n != key else key


static func _damage_type_keys() -> Array[String]:
	var out: Array[String] = []
	for k in DamageTypes.ids():
		out.append(String(k))
	return out


static func _strings(arr: Array) -> Array[String]:
	var out: Array[String] = []
	for v in arr:
		out.append(String(v))
	return out


## 096：已知的标签：登记过的（TagRegistry）+ 道具 / 敌人内容里用过的。升序去重；`faith:<id>` 不列（信仰对象标签由 faith 字段推）
static var _extra_tags: Array[String] = []
static var _scanned_tags: bool = false


static func known_tags() -> Array[String]:
	var seen := {}
	for k in TagRegistry.ids():
		seen[String(k)] = true
	if not _scanned_tags:
		_scanned_tags = true
		for kind in ["items", "enemies"]:
			if not ContentPaths.KINDS.has(kind):
				continue
			var dir := String(ContentPaths.KINDS[kind][0])
			var d := DirAccess.open(dir)
			if d == null:
				continue
			for f in d.get_files():
				if f.ends_with(".json"):
					var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + f))
					if parsed is Dictionary and (parsed as Dictionary).get("tags") is Array:
						for tg in (parsed as Dictionary)["tags"]:
							var s := String(tg)
							if s != "" and not s.begins_with(FaithDef.TAG_PREFIX) and not _extra_tags.has(s):
								_extra_tags.append(s)
	for k in _extra_tags:
		seen[String(k)] = true
	var out: Array[String] = []
	for k in seen:
		out.append(k)
	out.sort()
	return out


## 属性键给人看：中文模式「伤害 (damage)」，英文原名
static func stat_label(key: String) -> String:
	var zh := Glossary.stat_name(StringName(key))
	return "%s (%s)" % [zh, key] if FieldText.zh() and zh != key else key


## 已知的属性键：[BattleStats] 的常量 + 词典里有名字的 + 内容里用过的（道具 / 敌人 / 角色 / buff / 套装的 base_stats 与修饰）。升序去重
static func known_stat_keys() -> Array[String]:
	var seen := {}
	var consts: Dictionary = (BattleStats as Script).get_script_constant_map()
	for name in consts:
		var v = consts[name]
		if v is StringName and String(v) != "":
			seen[String(v)] = true
	for k in Glossary.STAT_NAMES:
		seen[String(k)] = true
	if not _scanned_stats:
		_scanned_stats = true
		for kind in ["items", "enemies", "characters", "buffs", "sets", "run_buffs", "faiths"]:
			if not ContentPaths.KINDS.has(kind):
				continue
			var dir := String(ContentPaths.KINDS[kind][0])
			var d := DirAccess.open(dir)
			if d == null:
				continue
			for f in d.get_files():
				if f.ends_with(".json"):
					var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + f))
					_collect_stat_keys(parsed, _extra_stat_keys)
	for k in _extra_stat_keys:
		seen[k] = true
	var out: Array[String] = []
	for k in seen:
		out.append(k)
	out.sort()
	return out


## 编辑器可以把自己认得的属性键登记进来（比如刚在别的表单里自定义的）
static func register_stat_keys(keys: Array) -> void:
	for k in keys:
		var s := String(k)
		if s != "" and not _extra_stat_keys.has(s):
			_extra_stat_keys.append(s)


static func _collect_stat_keys(node, into: Array[String]) -> void:
	if node is Dictionary:
		for k in node:
			var ks := String(k)
			if ks == "base_stats" and node[k] is Dictionary:
				for sk in node[k]:
					if not into.has(String(sk)):
						into.append(String(sk))
			elif (ks == "stat" or ks.ends_with("_stat")) and node[k] is String and String(node[k]) != "":
				if not into.has(String(node[k])):
					into.append(String(node[k]))
			else:
				_collect_stat_keys(node[k], into)
	elif node is Array:
		for v in node:
			_collect_stat_keys(v, into)


## 属性键选择器：下拉列出已知属性（中文名 + 原键），最后一项「自定义…」露出输入框。
## [param current] 是当前值（不在列表里就当自定义）；[param on_pick] 每次改动回调（可以是空 Callable，之后用 _picked_stat 读）；
## [param exclude] 不列出的键（属性表里已有的）
func _stat_picker(current: String, on_pick: Callable, exclude: Array = []) -> Control:
	var keys: Array[String] = []
	for k in known_stat_keys():
		if not exclude.has(k) or k == current:
			keys.append(k)
	return _key_picker(keys, Callable(PropertyForm, "stat_label"), current, on_pick, "属性键（小写英文）" if FieldText.zh() else "stat key")


## 096：通用的「键」选择器 —— 属性键 / 标签 / 伤害类型都是一张「已知的键 + 自定义…」下拉。
## [param label_of] 把键变成显示文字（中文名 + 原键）；其余同 [method _stat_picker]
func _key_picker(keys: Array[String], label_of: Callable, current: String, on_pick: Callable, placeholder: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var ob := OptionButton.new()
	_font(ob)
	for i in keys.size():
		ob.add_item(String(label_of.call(keys[i])), i)
		ob.set_item_tooltip(i, keys[i])
	ob.add_item("自定义…" if FieldText.zh() else "Custom…", keys.size())
	ob.set_item_metadata(keys.size(), CUSTOM_STAT)
	var custom := LineEdit.new()
	custom.custom_minimum_size.x = 140
	custom.placeholder_text = placeholder if placeholder != "" else ("键（小写英文）" if FieldText.zh() else "key")
	_font(custom)
	var at := keys.find(current)
	if at < 0 and current == "" and not keys.is_empty():
		at = 0     # 加一项的选择器：没有当前值就停在第一项，不露输入框
	if at >= 0:
		ob.select(at)
		custom.visible = false
	else:
		ob.select(keys.size())
		custom.text = current
		custom.visible = true
	ob.item_selected.connect(func(idx: int):
		custom.visible = idx >= keys.size()
		if idx < keys.size():
			if on_pick.is_valid():
				on_pick.call(keys[idx])
		elif on_pick.is_valid():
			on_pick.call(custom.text.strip_edges()))
	custom.text_changed.connect(func(t: String):
		if on_pick.is_valid():
			on_pick.call(t.strip_edges()))
	row.add_child(ob)
	row.add_child(custom)
	row.set_meta("stat_options", ob)
	row.set_meta("stat_custom", custom)
	return row


## 选择器当前选中的属性键（自定义就是输入框里的字）
static func _picked_stat(picker: Control) -> String:
	var ob: OptionButton = picker.get_meta("stat_options")
	var custom: LineEdit = picker.get_meta("stat_custom")
	var idx := ob.get_selected()
	if idx < 0:
		return ""
	if ob.get_item_metadata(idx) is String and String(ob.get_item_metadata(idx)) == CUSTOM_STAT:
		return custom.text.strip_edges()
	return String(ob.get_item_tooltip(idx))


## 字典（base_stats 这种「属性键 → 数值」）用一行一对的写法。
## 键是自由文本而不是下拉框 —— 属性键本来就是可扩展的，锁死列表反而挡住新资源。
## 091（作者反馈）：文字表的值直接编辑（不带 JSON 引号），加一项给空字符串与下一个语言码
func _dict_editor(owner: Object, key: String, dict: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var text_dict := _is_text_dict(key, dict)
	var stat_dict := not text_dict and _is_stat_dict(key, dict)
	for k in dict.keys():
		var row := HBoxContainer.new()
		var name_edit := LineEdit.new()
		name_edit.text = String(k)
		name_edit.custom_minimum_size.x = 130
		_font(name_edit)
		var old_key := String(k)
		var raw = dict[k]
		if raw is String:
			# 文字：直接改，不走 JSON
			var se := LineEdit.new()
			se.text = String(raw)
			se.custom_minimum_size.x = 200
			se.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_font(se)
			se.text_changed.connect(func(t: String):
				dict[old_key] = t
				owner.set(key, dict)
				_emit())
			name_edit.text_submitted.connect(func(t: String):
				var v = dict[old_key]
				dict.erase(old_key)
				dict[t] = v
				owner.set(key, dict)
				_emit()
				rebuild())
			row.add_child(name_edit)
			row.add_child(se)
			row.add_child(_small_button("删", func():
				dict.erase(old_key)
				owner.set(key, dict)
				_emit()
				rebuild()))
			box.add_child(row)
			continue
		if not (raw is float or raw is int):
			# 值不是数（配额的 [min, max]、禁止相邻的类型对……）：按 JSON 文本编辑
			var te := LineEdit.new()
			te.text = JSON.stringify(raw)
			te.custom_minimum_size.x = 160
			_font(te)
			te.text_submitted.connect(func(s: String):
				var parsed = JSON.parse_string(s)
				if parsed != null:
					dict[old_key] = parsed
					owner.set(key, dict)
					_emit())
			row.add_child(name_edit)
			row.add_child(te)
			row.add_child(_small_button("删", func():
				dict.erase(old_key)
				owner.set(key, dict)
				_emit()
				rebuild()))
			box.add_child(row)
			continue
		var val := SpinBox.new()
		val.min_value = -99999
		val.max_value = 99999
		val.step = 0.1
		val.allow_greater = true
		val.allow_lesser = true
		val.value = float(raw)
		_font(val)
		if stat_dict:
			name_edit.tooltip_text = "%s\n（改名直接敲，回车生效）" % stat_label(old_key)
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
	if stat_dict:
		# 091（作者定）：属性表加一项 —— 下拉里是还没写的已有属性（战斗属性常量 + 内容里用过的），最后一项「自定义…」自己敲
		var picker := _stat_picker("", Callable(), dict.keys())
		var row := HBoxContainer.new()
		row.add_child(picker)
		row.add_child(_small_button("+ 加一项", func():
			var k := _picked_stat(picker)
			if k == "":
				k = "new_stat"
			var i := 1
			var base := k
			while dict.has(k):
				k = "%s_%d" % [base, i]
				i += 1
			dict[k] = 0.0
			owner.set(key, dict)
			_emit()
			rebuild()))
		box.add_child(row)
		return box
	box.add_child(_small_button("+ 加一项", func():
		if text_dict:
			# 下一个还没写的语言码；都写了就 lang_1、lang_2…
			var lang := ""
			for l in UiText.LANGS:
				if l != "zh" and not dict.has(l):
					lang = l
					break
			var j := 1
			while lang == "" or dict.has(lang):
				lang = "lang_%d" % j
				j += 1
			dict[lang] = ""
		else:
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
		if builtin == TYPE_STRING_NAME and _is_tag_field(key):
			# 096（作者定）：标签数组旁边一个「加标签…」下拉：列出登记过（TagRegistry，带中文名）与内容里用过的标签，选一个就追加到这一行
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.add_child(le)
			var ob := OptionButton.new()
			_font(ob)
			ob.add_item("加标签…" if FieldText.zh() else "Add tag…", 0)
			var keys := known_tags()
			for i in keys.size():
				ob.add_item(tag_label(keys[i]), i + 1)
				ob.set_item_tooltip(i + 1, keys[i])
			ob.item_selected.connect(func(idx: int):
				ob.select(0)
				if idx <= 0:
					return
				var picked := keys[idx - 1]
				var cur: Array = owner.get(key)
				if cur.has(StringName(picked)):
					return
				var out := ContentSchema.empty_like(arr)
				for v in cur:
					out.append(v)
				out.append(StringName(picked))
				owner.set(key, out)
				le.text = ", ".join(_strings(out))
				_emit())
			row.add_child(ob)
			row.set_meta("tag_options", ob)
			row.set_meta("tag_edit", le)
			return _labeled(owner, key, row)
		return _labeled(owner, key, le)

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
		return _labeled(owner, key, le2)

	# 整数数组（哪几层放撤离点、每层的危险等级……）也用一行文本
	if builtin == TYPE_INT:
		var le3 := LineEdit.new()
		var parts3: Array[String] = []
		for v in arr:
			parts3.append(str(int(v)))
		le3.text = ", ".join(parts3)
		le3.custom_minimum_size.x = 220
		le3.placeholder_text = "1, 2, 3"
		_font(le3)
		le3.text_changed.connect(func(t: String):
			var out := ContentSchema.empty_like(arr)
			for piece in t.split(",", false):
				var s := (piece as String).strip_edges()
				if s.is_valid_int():
					out.append(int(s))
			owner.set(key, out)
			_emit())
		return _labeled(owner, key, le3)

	if builtin != TYPE_OBJECT:
		return _labeled(owner, key, _muted("（暂不支持在界面里编辑）"))

	# --- 对象数组：每项一个可折叠的子表单，带类型下拉 ---
	var element_class := ContentSchema.array_element_class(arr)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var heading := _heading("%s（%d）" % [FieldText.label(owner, key), arr.size()])
	heading.tooltip_text = FieldText.tip(owner, key)
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(heading)

	for i in arr.size():
		var idx := i
		var item := arr[i] as Object
		var card := _card()
		var body := _body(card)
		var head := HBoxContainer.new()
		var item_head := _muted("[%d] %s" % [idx, FieldText.type_label(ContentSchema.registry_name_of(item))])
		item_head.tooltip_text = FieldText.type_help(item)
		item_head.mouse_filter = Control.MOUSE_FILTER_STOP
		head.add_child(item_head)
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
	var title := _heading(FieldText.label(owner, key))
	title.tooltip_text = FieldText.tip(owner, key)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_child(title)
	if value == null:
		head.add_child(_adder(declared, func(made: Object):
			owner.set(key, made)
			_emit()
			rebuild()))
	else:
		var kind := _muted(FieldText.type_label(ContentSchema.registry_name_of(value)))
		kind.tooltip_text = FieldText.type_help(value)
		kind.mouse_filter = Control.MOUSE_FILTER_STOP
		head.add_child(kind)
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
		ob.add_item(FieldText.type_label(types[i]), i)
		ob.set_item_tooltip(i, String(types[i]))
	row.add_child(ob)
	row.add_child(_small_button("+ 添加", func():
		var made := ContentSchema.make(declared, types[ob.get_selected_id()])
		if made != null:
			on_made.call(made)))
	return row


func _sub_form(obj: Object) -> PropertyForm:
	var sub := PropertyForm.create(obj, label_font, skip)
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


## 一行：左边标签（中文模式下是 [FieldText] 的中文，鼠标停上去看说明与字段名），右边控件（同一份说明）
func _labeled(owner: Object, key: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = FieldText.label(owner, key)
	l.custom_minimum_size.x = 130
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	var tip := FieldText.tip(owner, key)
	l.tooltip_text = tip
	if control.tooltip_text == "":
		control.tooltip_text = tip
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
