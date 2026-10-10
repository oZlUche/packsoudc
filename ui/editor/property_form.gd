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
## 133：资源声明了 `editor_hint() -> String` 就在字段下面画一行灰字，任何字段改了就重算（[StatModifier]：乘算还是加算、扩大还是缩小）
var _hint: Label = null
## 133：外层表单的对象（子表单才有）。[StatModifier] 挂在 [BuffDef] 下时，提示末尾补「每层一份」
var parent_target: Object = null
## 145：规则表（`Array[AbilityRule]`）的弹窗挂在这一层上（编辑器给，子表单继承）。没有就退回内联卡片
var popup_layer: Control = null
## 145：只显示这几个字段（规则弹窗的三个页签各显示规则的一部分）；空 = 全部。不传给子表单
var only: Array = []
## 145：本表单里的规则列表（字段名 → Tree），弹窗改了东西按这个找回去刷新那几行
var _rule_trees: Dictionary = {}
## 146：「添加」下拉里列不列规则构件库（构件编辑器自己、buff 的规则里不列：构件不套构件，buff 的规则请内联）。子表单继承
var parts_allowed: bool = true
## 146：来自库的构件（带 `part_ref`）只读：控件全部禁用，「断开」之后才能改。子表单继承
var locked: bool = false
## 146：「去库里改」「去 buff 制作器」切过去时要定位到哪一份（目标编辑器开场读一次）
static var library_focus: String = ""

const PART_EDITOR := "res://ui/part_editor/part_editor.tscn"
const BUFF_EDITOR := "res://ui/buff_editor/buff_editor.tscn"
## 「添加」下拉里库项的 id 从这里起（前面是类型）
const LIB_ID0 := 1000

## 用时再 load：弹窗里的页签又是 PropertyForm，两边互相 preload 会成环
const RULE_WINDOW := "res://ui/editor/rule_window.gd"
const RULE_COLUMNS := ["#", "时机", "消耗", "效果"]
## 规则列表一行的高度与最多显示几行（多了在列表里滚）
const RULE_ROW_H := 26
const RULE_ROWS_MAX := 8


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
	UiTheme.clear_children(self)
	_rows.clear()
	_rule_trees.clear()
	if _target == null:
		return
	var hidden: Array = skip.get(String(ContentSchema.class_name_of(_target)), [])
	for prop in ContentSchema.properties_of(_target):
		if hidden.has(String(prop["name"])):
			continue
		if not only.is_empty() and not only.has(String(prop["name"])):
			continue
		var row := _row_for(_target, prop)
		if row != null:
			add_child(row)
			_rows[String(prop["name"])] = row
	_apply_visibility(false)
	_hint = null
	if _target.has_method("editor_hint"):
		_hint = _muted("")
		_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_hint)
		_refresh_hint()
	if locked:
		_lock_controls()


## 146：来自库的构件只读 —— 输入框不能改、按钮与下拉点不了，整块灰一点
func _lock_controls() -> void:
	modulate.a = 0.6
	for n in find_children("*", "", true, false):
		if n is LineEdit or n is SpinBox or n is TextEdit:
			n.editable = false
		elif n is BaseButton:
			n.disabled = true


## 133：灰字提示的当前文字（没有 = 空；测试用）
func hint_text() -> String:
	return _hint.text if _hint != null else ""


func _refresh_hint() -> void:
	if _hint == null or _target == null or not _target.has_method("editor_hint"):
		return
	var text := String(_target.call("editor_hint"))
	if text != "" and parent_target is BuffDef:
		text += "；在 buff 里是每层一份"
	_hint.text = text
	_hint.visible = text != ""


func _emit() -> void:
	_refresh_hint()
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
			_compact(cb)
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
			if key == "amount" and _percent_mod(owner):
				# 作者反馈：暴击率 / 暴击伤害按百分数填（20 = 20%），存成小数
				var pct := _number(BattleStats.to_percent(value), 1.0, func(v: float): owner.set(key, BattleStats.from_percent(v)), prop)
				pct.suffix = "%"
				return _labeled(owner, key, pct)
			return _labeled(owner, key, _number(value, 0.1, func(v: float): owner.set(key, v), prop))

		TYPE_STRING, TYPE_STRING_NAME:
			if int(prop["hint"]) == PROPERTY_HINT_ENUM:
				# 111：字符串枚举（`@export_enum`）→ 下拉；值仍是字符串，显示名走 FieldText.enum_label
				return _labeled(owner, key, _string_picker(owner, prop, ContentSchema.enum_options(owner, prop), String(value)))
			if type == TYPE_STRING_NAME and _is_stat_field(key):
				# 091（作者定）：指向属性键的字段（修饰的 stat、效果的 damage_stat）下拉浏览已有属性，也能自定义
				# 可以为空的（默认值是空串，如 amount_stat）第一项是「不用」，空值就停在它上，不再被显示成第一个属性
				var allow_empty := _stat_field_nullable(owner, key)
				var picker := _stat_picker(String(value), func(k: String):
					var was_pct := _percent_mod(owner)
					owner.set(key, StringName(k))
					if owner is StatModifier and was_pct != _percent_mod(owner):
						# 换到 / 换出百分比属性：填的数不变（20 还是 20），存的值跟着换算，数字框按新单位重画
						var m := owner as StatModifier
						m.amount = BattleStats.from_percent(m.amount) if not was_pct else BattleStats.to_percent(m.amount)
						rebuild.call_deferred()
					_emit(), [], allow_empty)
				if allow_empty:
					picker.tooltip_text = STAT_EMPTY_TIP
				return _labeled(owner, key, picker)
			if type == TYPE_STRING_NAME and _is_damage_type_field(key):
				# 096：伤害类型是数据（DamageTypes）：下拉列出登记过的，也能自定义
				return _labeled(owner, key, _key_picker(_damage_type_keys(), Callable(PropertyForm, "damage_type_label"), String(value), func(k: String):
					owner.set(key, StringName(k))
					_emit()))
			if type == TYPE_STRING_NAME and _is_axis_field(key):
				# 152：指向一条标准轴的字段（buff 带的轴、改轴、扣轴、轴条件）：下拉列出轴表，显示正名 / 反名
				return _labeled(owner, key, _key_picker(_axis_keys(), Callable(PropertyForm, "axis_label"), String(value), func(k: String):
					owner.set(key, StringName(k))
					_emit()))
			if type == TYPE_STRING_NAME and _is_buff_id_field(owner, key):
				# 146：指向一个 buff 的 id（移除 / 条件 / 扳机里的状态）：下拉列出库里的 buff，也能手填
				return _labeled(owner, key, _key_picker(known_buff_ids(), Callable(PropertyForm, "buff_id_label"), String(value), func(k: String):
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
			_compact(le)
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
	_compact(ob)
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
	_compact(ob)
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


## 加算、指向百分比属性的修饰：amount 按百分数显示
static func _percent_mod(owner: Object) -> bool:
	return owner is StatModifier and not (owner as StatModifier).is_mult() and BattleStats.is_percent((owner as StatModifier).stat)


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


## 152：指向标准轴的字段
static func _is_axis_field(key: String) -> bool:
	return key == "axis"


static func _axis_keys() -> Array[String]:
	var out: Array[String] = []
	for a in StatAxes.ORDER:
		out.append(String(a))
	return out


## 「强攻 / 虚弱 (damage_dealt)」
static func axis_label(key: String) -> String:
	var i := StatAxes.info(StringName(key))
	return "%s / %s (%s)" % [i["pos"], i["neg"], key] if not i.is_empty() else key


## 146：指向 buff id 的字段：`buff_id`（移除 / 条件 / 状态扳机 / 扣层），转化状态的 `from`
static func _is_buff_id_field(owner: Object, key: String) -> bool:
	return key == "buff_id" or (owner is ConvertStatus and key == "from")


## 库里全部 buff 的 id
static func known_buff_ids() -> Array[String]:
	var out: Array[String] = []
	for id in ContentLibrary.buffs():
		out.append(String(id))
	out.sort()
	return out


## buff id 给人看：「流血 (bleed)」
static func buff_id_label(id: String) -> String:
	var def: BuffDef = ContentLibrary.buffs().get(StringName(id), null)
	var n := Names.of(def) if def != null else DamageTypes.name_of(StringName(id))
	return "%s (%s)" % [n, id] if n != "" and n != id else id


## 这个 buff 对象是不是库里的那一份（同一个对象，或同 id 且内容一样）；是就返回 id
static func library_buff_id(value: Object) -> String:
	if not (value is BuffDef):
		return ""
	var lib: BuffDef = ContentLibrary.buffs().get((value as BuffDef).id, null)
	if lib == null:
		return ""
	if lib == value or ContentExporter.dump(lib) == ContentExporter.dump(value):
		return String(lib.id)
	return ""


## 带 `part_ref` 的对象来自库里哪一件；不是返回空
static func part_ref_of(obj: Object) -> String:
	if obj is Resource and obj.has_meta(RulePartDef.REF_META):
		return String(obj.get_meta(RulePartDef.REF_META))
	return ""


static func part_label(def: RulePartDef) -> String:
	var n := Names.of(def)
	return n if n != "" else String(def.id)


## 「来自库：名字」
static func part_ref_label(ref: String) -> String:
	var def := ContentLibrary.part(StringName(ref))
	return ("来自库：" + part_label(def)) if def != null else "来自库：@%s（库里已没有）" % ref


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
							if s != "" and not s.begins_with(FaithTags.PREFIX) and not _extra_tags.has(s):
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


const STAT_EMPTY_TIP := "填了就按这件道具属性表里的那一项取数量，走加成公式；例如武器写 stamina_cost，耐力消耗就能被加成和灵巧轴改"
const STAT_NONE_LABEL := "不用（用上面的数量）"


## 这个属性键字段能不能为空：脚本里它的默认值就是空串（amount_stat 这种「可选的取数来源」）；
## 必填的（stat、默认 damage 的 damage_stat）不给「不用」这一项
static func _stat_field_nullable(owner: Object, key: String) -> bool:
	var script := owner.get_script() as Script
	if script == null:
		return false
	var def = script.get_property_default_value(key)
	return def != null and String(def) == ""


## 属性键选择器：下拉列出已知属性（中文名 + 原键），最后一项「自定义…」露出输入框。
## [param current] 是当前值（不在列表里就当自定义）；[param on_pick] 每次改动回调（可以是空 Callable，之后用 _picked_stat 读）；
## [param exclude] 不列出的键（属性表里已有的）
func _stat_picker(current: String, on_pick: Callable, exclude: Array = [], allow_empty: bool = false) -> Control:
	var keys: Array[String] = []
	for k in known_stat_keys():
		if not exclude.has(k) or k == current:
			keys.append(k)
	return _key_picker(keys, Callable(PropertyForm, "stat_label"), current, on_pick, "属性键（小写英文）" if FieldText.zh() else "stat key", allow_empty)


## 096：通用的「键」选择器 —— 属性键 / 标签 / 伤害类型都是一张「已知的键 + 自定义…」下拉。
## [param label_of] 把键变成显示文字（中文名 + 原键）；其余同 [method _stat_picker]
## [param allow_empty] 为真：第一项是「不用」（空串），值为空就选中它（可选字段；「加一项」那种选择器不传）
func _key_picker(keys: Array[String], label_of: Callable, current: String, on_pick: Callable, placeholder: String = "", allow_empty: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var ob := OptionButton.new()
	_compact(ob)
	var off := 1 if allow_empty else 0
	if allow_empty:
		ob.add_item(STAT_NONE_LABEL if FieldText.zh() else "None (use the amount above)", 0)
		ob.set_item_tooltip(0, "")
	for i in keys.size():
		ob.add_item(String(label_of.call(keys[i])), i + off)
		ob.set_item_tooltip(i + off, keys[i])
	ob.add_item("自定义…" if FieldText.zh() else "Custom…", keys.size() + off)
	ob.set_item_metadata(keys.size() + off, CUSTOM_STAT)
	var custom := LineEdit.new()
	custom.custom_minimum_size.x = 140
	custom.placeholder_text = placeholder if placeholder != "" else ("键（小写英文）" if FieldText.zh() else "key")
	_compact(custom)
	var at := keys.find(current)
	if at >= 0:
		at += off
	elif current == "" and allow_empty:
		at = 0     # 可选字段：空值停在「不用」
	elif current == "" and not keys.is_empty():
		at = 0     # 加一项的选择器：没有当前值就停在第一项，不露输入框
	if at >= 0:
		ob.select(at)
		custom.visible = false
	else:
		ob.select(keys.size() + off)
		custom.text = current
		custom.visible = true
	ob.item_selected.connect(func(idx: int):
		custom.visible = idx >= keys.size() + off
		if allow_empty and idx == 0:
			if on_pick.is_valid():
				on_pick.call("")
		elif idx < keys.size() + off:
			if on_pick.is_valid():
				on_pick.call(keys[idx - off])
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
		_compact(name_edit)
		var old_key := String(k)
		var raw = dict[k]
		if raw is String:
			# 文字：直接改，不走 JSON
			var se := LineEdit.new()
			se.text = String(raw)
			se.custom_minimum_size.x = 200
			se.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_compact(se)
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
			_compact(te)
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
		var pct_key := key == "base_stats" and BattleStats.is_percent(StringName(old_key))
		val.value = BattleStats.to_percent(float(raw)) if pct_key else float(raw)
		if pct_key:
			val.suffix = "%"
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
			dict[old_key] = BattleStats.from_percent(v) if pct_key else v
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
		_compact(le)
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
			_compact(ob)
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
		_compact(le2)
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
		_compact(le3)
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
	# 145：规则表一条一行，双击弹窗改（四层嵌套的卡片看不清哪个效果是谁的）
	if element_class == &"AbilityRule" and popup_layer != null:
		return _rule_list(owner, key, arr)
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
		var ref := part_ref_of(item)
		var item_head := _muted("[%d] %s" % [idx, part_ref_label(ref) if ref != "" else FieldText.type_label(ContentSchema.registry_name_of(item))])
		item_head.tooltip_text = FieldText.type_help(item)
		item_head.mouse_filter = Control.MOUSE_FILTER_STOP
		head.add_child(item_head)
		if ref != "":
			_library_buttons(head, item, ref)
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


#region 146：库
## 来自库的构件卡片头上的两个按钮：「断开」（去掉 part_ref，字段能改，存盘后内联）、「去库里改」（切到构件编辑器定位到它）
func _library_buttons(head: HBoxContainer, obj: Object, ref: String) -> void:
	head.add_child(_small_button("断开", func():
		obj.remove_meta(RulePartDef.REF_META)
		_emit()
		rebuild()))
	head.add_child(_small_button("去库里改", func(): _goto_library(PART_EDITOR, ref)))


## buff 字段：下拉「内联」+ 库里全部 buff。选库里的 = 引用（只读，旁边「去 buff 制作器」）；内联 = 照旧的子表单
func _buff_section(owner: Object, key: String, value: Object) -> Control:
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	var title := _heading(FieldText.label(owner, key))
	title.tooltip_text = FieldText.tip(owner, key)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_child(title)
	var lib := ContentLibrary.buffs()
	var ids: Array = lib.keys()
	ids.sort()
	var linked := library_buff_id(value)
	var ob := OptionButton.new()
	_compact(ob)
	ob.add_item("内联（这一件自己的）", 0)
	for i in ids.size():
		ob.add_item(buff_id_label(String(ids[i])), i + 1)
	ob.select(ids.find(StringName(linked)) + 1 if linked != "" else 0)
	ob.item_selected.connect(func(idx: int):
		if idx == 0:
			# 改成内联：拿库里那份拷一份当起点（之后改了就是这一件自己的版本）
			if value != null:
				owner.set(key, (value as Resource).duplicate_deep(Resource.DEEP_DUPLICATE_ALL))
		else:
			owner.set(key, lib[ids[idx - 1]])
		_emit()
		rebuild())
	head.add_child(ob)
	box.set_meta("buff_picker", ob)
	if linked != "":
		head.add_child(_small_button("去 buff 制作器", func(): _goto_library(BUFF_EDITOR, linked)))
		box.add_child(head)
		var note := _muted("库里的 buff，这里只读；要改去 buff 制作器，或在下拉里选「内联」")
		box.add_child(note)
		return box
	if value == null:
		head.add_child(_adder(&"BuffDef", func(made: Object):
			owner.set(key, made)
			_emit()
			rebuild()))
		box.add_child(head)
		return box
	head.add_child(_small_button("清除", func():
		owner.set(key, null)
		_emit()
		rebuild()))
	box.add_child(head)
	var card := _card()
	_body(card).add_child(_sub_form(value))
	box.add_child(card)
	return box


## 切到库的编辑器并定位。当前编辑器有没存的改动就不切（切场景草稿就没了），在状态栏说一声
func _goto_library(scene: String, id: String) -> void:
	var host: Node = self
	while host != null and not host.has_method("has_unsaved_changes"):
		host = host.get_parent()
	if host != null and host.has_unsaved_changes():
		var status = host.get("_status")
		if status is RichTextLabel:
			(status as RichTextLabel).text = "[color=#f0ad4e]先存盘再去库里改 —— 切过去没存的改动会丢[/color]"
		return
	PropertyForm.library_focus = id
	if is_inside_tree():
		get_tree().change_scene_to_file(scene)
#endregion


#region 145：规则列表
## 规则表 = 一张四列的列表（#、时机、消耗、效果，文案走 [Glossary]）+ 一排按钮。双击 / 回车 / 「编辑」弹 [RuleWindow]
func _rule_list(owner: Object, key: String, arr: Array) -> Control:
	var box := VBoxContainer.new()
	var heading := _heading("%s（%d）" % [FieldText.label(owner, key), arr.size()])
	heading.tooltip_text = FieldText.tip(owner, key)
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(heading)

	var tree := Tree.new()
	tree.set_meta("rule_key", key)
	tree.hide_root = true
	tree.columns = RULE_COLUMNS.size()
	tree.column_titles_visible = true
	tree.select_mode = Tree.SELECT_ROW
	for c in RULE_COLUMNS.size():
		tree.set_column_title(c, RULE_COLUMNS[c])
		tree.set_column_expand(c, c > 0)
	tree.set_column_custom_minimum_width(0, 44)
	tree.set_column_expand_ratio(3, 2)
	tree.custom_minimum_size.y = RULE_ROW_H * (clampi(arr.size(), 1, RULE_ROWS_MAX) + 1) + 8
	tree.create_item()
	for i in arr.size():
		tree.create_item()
	_fill_rule_rows(tree, arr)
	_rule_trees[key] = tree
	box.add_child(tree)

	var row := HBoxContainer.new()
	var needs_pick: Array[Button] = []
	row.add_child(_small_button("新建", func():
		arr.append(ContentSchema.make(&"AbilityRule", &"AbilityRule"))
		_rules_changed(owner, key, arr, arr.size() - 1)
		_open_rule(owner, key, arr, arr.size() - 1)))
	needs_pick.append(_small_button("复制", func():
		var i := _picked_rule(tree)
		arr.insert(i + 1, (arr[i] as Resource).duplicate_deep(Resource.DEEP_DUPLICATE_ALL))
		_rules_changed(owner, key, arr, i + 1)))
	needs_pick.append(_small_button("删除", func():
		var i := _picked_rule(tree)
		arr.remove_at(i)
		_rules_changed(owner, key, arr, mini(i, arr.size() - 1))))
	needs_pick.append(_small_button("上移", func():
		var i := _picked_rule(tree)
		if i > 0:
			var tmp = arr[i - 1]
			arr[i - 1] = arr[i]
			arr[i] = tmp
			_rules_changed(owner, key, arr, i - 1)))
	needs_pick.append(_small_button("下移", func():
		var i := _picked_rule(tree)
		if i < arr.size() - 1:
			var tmp = arr[i + 1]
			arr[i + 1] = arr[i]
			arr[i] = tmp
			_rules_changed(owner, key, arr, i + 1)))
	needs_pick.append(_small_button("编辑", func():
		_open_rule(owner, key, arr, _picked_rule(tree))))
	for b in needs_pick:
		b.disabled = true
		row.add_child(b)
	box.add_child(row)

	var set_picked := func(on: bool) -> void:
		for b in needs_pick:
			b.disabled = not on
	tree.item_selected.connect(func(): set_picked.call(true))
	tree.nothing_selected.connect(func():
		tree.deselect_all()
		set_picked.call(false))
	tree.item_activated.connect(func(): _open_rule(owner, key, arr, _picked_rule(tree)))
	return box


## 列表里选中的是第几条；没选中为 -1
static func _picked_rule(tree: Tree) -> int:
	var it := tree.get_selected()
	return it.get_index() if it != null else -1


## 每行的文字。不合法的（缺扳机 / 节奏 / 效果）序号前加「！」、整行暗色；悬浮看完整的一句
static func _fill_rule_rows(tree: Tree, arr: Array) -> void:
	var items := tree.get_root().get_children()
	for i in mini(items.size(), arr.size()):
		var item := items[i] as TreeItem
		var rule := arr[i] as AbilityRule
		var bad := rule == null or not rule.is_valid()
		item.set_text(0, ("！" if bad else "") + str(i + 1))
		var tip := ""
		if rule != null:
			item.set_text(1, Glossary.timing_text(rule))
			item.set_text(2, Glossary.costs_text(rule))
			item.set_text(3, Glossary.effects_text(rule.effects))
			tip = Glossary.rule_text(rule)
		for c in RULE_COLUMNS.size():
			item.set_tooltip_text(c, tip)
			if bad:
				item.set_custom_color(c, UiPalette.DIM)
			else:
				item.clear_custom_color(c)


## 增删、换顺序之后：写回、通知、重画，选中 [param pick] 那一行
func _rules_changed(owner: Object, key: String, arr: Array, pick: int) -> void:
	owner.set(key, arr)
	_emit()
	rebuild()
	var tree := _rule_trees.get(key) as Tree
	if tree != null and pick >= 0 and pick < arr.size():
		tree.get_root().get_child(pick).select(0)


func _open_rule(owner: Object, key: String, arr: Array, idx: int) -> void:
	if idx < 0 or idx >= arr.size() or popup_layer == null:
		return
	var win = load(RULE_WINDOW).open_in(popup_layer)
	win.show_rule(arr[idx], "规则 %d · %s" % [idx + 1, FieldText.label(owner, key)], label_font, parts_allowed, func():
		_emit()
		var tree := _rule_trees.get(key) as Tree
		if tree != null and is_instance_valid(tree):
			_fill_rule_rows(tree, arr))


## 测试用：本表单里某个规则表字段的列表（没有为 null）
func rule_list(key: String) -> Tree:
	return _rule_trees.get(key) as Tree
#endregion


func _object_section(owner: Object, prop: Dictionary, value: Object) -> Control:
	var key := String(prop["name"])
	var declared := StringName(prop["hint_string"])
	# 贴图之类的引擎类型交给别处，表单不碰
	if not ContentSchema.ABSTRACT_ROOTS.has(declared) \
			and ContentSchema.script_of(declared) == null:
		return null

	# 146：buff 字段是「库里的 buff / 内联」二选一
	if declared == &"BuffDef":
		return _buff_section(owner, key, value)

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
		var ref := part_ref_of(value)
		var kind := _muted(part_ref_label(ref) if ref != "" else FieldText.type_label(ContentSchema.registry_name_of(value)))
		kind.tooltip_text = FieldText.type_help(value)
		kind.mouse_filter = Control.MOUSE_FILTER_STOP
		head.add_child(kind)
		if ref != "":
			_library_buttons(head, value, ref)
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
	# 146：扳机 / 节奏 / 消耗 / 效果的下拉分两组：「新建：」各类型，再是「库：」里现成的构件（选了 = 复制一份、来自库）
	var lib: Array[RulePartDef] = []
	if parts_allowed and RulePartDef.SLOTS.values().has(declared):
		lib = ContentLibrary.parts_for(declared)
	if not lib.is_empty():
		var lob := OptionButton.new()
		_compact(lob)
		for i in types.size():
			lob.add_item("新建：" + FieldText.type_label(types[i]), i)
			lob.set_item_tooltip(i, String(types[i]))
		lob.add_separator("库")
		for j in lib.size():
			lob.add_item("库：" + part_label(lib[j]), LIB_ID0 + j)
			lob.set_item_tooltip(lob.item_count - 1, "@%s　%s" % [lib[j].id, lib[j].preview()])
		row.add_child(lob)
		row.add_child(_small_button("+ 添加", func():
			var sel := lob.get_selected_id()
			var made: Object = ContentLibrary.instance_of(lib[sel - LIB_ID0]) if sel >= LIB_ID0 \
				else ContentSchema.make(declared, types[sel])
			if made != null:
				on_made.call(made)))
		row.set_meta("library", lob)
		return row
	if types.size() <= 1:
		var only := types[0] if types.size() == 1 else declared
		row.add_child(_small_button("+ 添加", func():
			var made := ContentSchema.make(declared, only)
			if made != null:
				on_made.call(made)))
		return row

	var ob := OptionButton.new()
	_compact(ob)
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
	sub.parent_target = _target
	sub.popup_layer = popup_layer
	sub.parts_allowed = parts_allowed and not (obj is BuffDef)
	sub.locked = locked or part_ref_of(obj) != ""
	sub.changed.connect(_emit)
	return sub
#endregion


#region 小控件
## 表单里的输入框 / 下拉 / 按钮用 13 号（比正文紧一号；字体在主题里）。标签的字号与颜色在 [method _labeled] / [method _heading] / [method _muted] 里各自给
func _compact(c: Control) -> void:
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
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", UiPalette.DIM)
	row.add_child(l)
	row.add_child(control)
	return row


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", UiPalette.FG)
	return l


func _muted(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UiPalette.DIM)
	return l


func _small_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	_compact(b)
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
