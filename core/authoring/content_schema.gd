## 内容管线的反射工具（架构文档 10.2）。
##
## [b]导入器与导出器都不认识任何具体效果。[/b] 它们只会做两件事：
##
## 1. 问 Godot「这个类有哪些导出属性、各是什么类型」——靠 [method get_property_list]
##    与类型化数组的 `get_typed_script()`；
## 2. 遇到抽象基类（Trigger / Cadence / Cost / Effect）时，按 JSON 里的 `type`
##    去 [EffectRegistry] 查。
##
## 于是「新增一种效果」＝ 加一个脚本 + 在注册表登记一行。
## 导入器、导出器、编辑器三方都不需要改 —— 这一条是整条管线的地基。
class_name ContentSchema
extends RefCounted

## 抽象基类 → 它在 [EffectRegistry] 里对应哪些表。
##
## 值是**表名数组**：`Effect` 横跨三个作用域，所以要挨个找。
const ABSTRACT_ROOTS := {
	&"Trigger": [&"trigger"],
	&"Cadence": [&"cadence"],
	&"Cost": [&"cost"],
	&"CombatEffect": [&"effect"],
	&"LootEffect": [&"loot_effect"],
	&"MapEffect": [&"map_effect"],
	&"RunEffect": [&"run_effect"],
	&"Effect": [&"effect", &"loot_effect", &"map_effect", &"run_effect"],
}

## 声明成裸 int、但语义上是枚举的属性，键为 `类名.属性名`。
##
## 带类型的枚举（`@export var target: Target`）Godot 会自带 ENUM 提示，
## 不需要登记；这张表只收那些**故意声明成 int** 的 ——
## 比如乘区要能用 -1 表示「不加乘区」，用枚举类型反而别扭。
const INT_ENUMS := {
	"StatModifier.mult_category": "StatMath.Buff",
}

static var _class_paths: Dictionary = {}
static var _int_enum_values: Dictionary = {}


## 枚举名归一化：`Opponent` / `opponent` / `OPPONENT` 都算同一个。
##
## [b]必须归一化，因为 Godot 给的不是源码里的名字。[/b]
## `@export var target: Target` 的 hint_string 是 `Opponent:0,Self:1,Both:2` ——
## 引擎为了在检视器里好看，把 `OPPONENT` 美化成了 `Opponent`。
## 作者数据该用源码里的写法，所以两边都转成 SCREAMING_SNAKE 再比。
static func normalize_enum(name: String) -> String:
	return name.strip_edges().to_upper().replace(" ", "_")


#region 全局类名 → 脚本
## `class_name` 声明过的类都在这里，用来按名字造对象。
##
## 用 ProjectSettings 的全局类表而不是自己维护一份清单：
## 后者每加一个类就要记得同步，忘一次就是一条查不出的导入失败。
static func _ensure_classes() -> void:
	if not _class_paths.is_empty():
		return
	for entry in ProjectSettings.get_global_class_list():
		_class_paths[StringName(entry["class"])] = String(entry["path"])


static func script_of(class_id: StringName) -> GDScript:
	_ensure_classes()
	var path: String = _class_paths.get(class_id, "")
	if path.is_empty():
		return null
	return load(path) as GDScript


## 某个实例是不是 [param base] 或它的子类。
##
## 不能写 `inst is base`（base 是运行时才知道的名字），所以顺着
## get_base_script() 往上爬，比对每一层的全局类名。
static func instance_is(inst: Object, base: StringName) -> bool:
	if inst == null:
		return false
	var s := inst.get_script() as Script
	while s != null:
		if s.get_global_name() == base:
			return true
		s = s.get_base_script()
	return false


## 一个实例的最具体类名，导出时用它写回 `type`
static func class_name_of(inst: Object) -> StringName:
	if inst == null:
		return &""
	var s := inst.get_script() as Script
	return s.get_global_name() if s != null else &""
#endregion


#region 属性表
## 一个对象的导出属性列表，过滤掉引擎自带的那些。
##
## 顺序就是声明顺序，因此导出的 JSON 字段顺序稳定 —— 稳定才能进 git diff。
static func properties_of(obj: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if obj == null:
		return out
	for p in obj.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(p)
	return out


static func property_names(obj: Object) -> Array[StringName]:
	var out: Array[StringName] = []
	for p in properties_of(obj):
		out.append(StringName(p["name"]))
	return out
#endregion


#region 枚举
## 把枚举名解析成整数。认得两种来源：
## 属性自带的 ENUM 提示，以及 [constant INT_ENUMS] 里登记的裸 int 属性。
static func enum_value(
	owner: Object, prop: Dictionary, text: String
) -> Variant:
	# 1. 带类型的枚举：hint_string 形如 "OPPONENT:0,SELF:1,BOTH:2"
	if int(prop["hint"]) == PROPERTY_HINT_ENUM:
		var wanted := normalize_enum(text)
		for pair in String(prop["hint_string"]).split(","):
			var bits := pair.split(":")
			if bits.size() == 2 and normalize_enum(bits[0]) == wanted:
				return int(bits[1])
		return null

	# 2. 登记过的裸 int 属性
	var key := "%s.%s" % [class_name_of(owner), prop["name"]]
	var domain: String = INT_ENUMS.get(key, "")
	if domain == "":
		return null
	var table := _int_enum_table(domain)
	return table.get(normalize_enum(text), null)


static func _int_enum_table(domain: String) -> Dictionary:
	if _int_enum_values.has(domain):
		return _int_enum_values[domain]
	var table := {}
	match domain:
		"StatMath.Buff":
			for i in StatMath.Buff.keys().size():
				table[normalize_enum(StatMath.Buff.keys()[i])] = StatMath.Buff.values()[i]
	_int_enum_values[domain] = table
	return table


## 反向：整数 → 枚举名，导出时用。认不出来就原样返回数字。
static func enum_name(owner: Object, prop: Dictionary, value: int) -> Variant:
	if int(prop["hint"]) == PROPERTY_HINT_ENUM:
		for pair in String(prop["hint_string"]).split(","):
			var bits := pair.split(":")
			if bits.size() == 2 and int(bits[1]) == value:
				return normalize_enum(bits[0])
		return value
	var key := "%s.%s" % [class_name_of(owner), prop["name"]]
	var domain: String = INT_ENUMS.get(key, "")
	if domain == "":
		return value
	for name in _int_enum_table(domain):
		if int(_int_enum_table(domain)[name]) == value:
			return name
	return value


## 某个属性能接受哪些枚举名，供编辑器做下拉框。不是枚举则返回空。
static func enum_options(owner: Object, prop: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if int(prop["hint"]) == PROPERTY_HINT_ENUM:
		for pair in String(prop["hint_string"]).split(","):
			var bits := pair.split(":")
			if bits.size() == 2:
				out.append(normalize_enum(bits[0]))
		return out
	var key := "%s.%s" % [class_name_of(owner), prop["name"]]
	var domain: String = INT_ENUMS.get(key, "")
	if domain != "":
		for name in _int_enum_table(domain):
			out.append(String(name))
	return out
#endregion


#region 造对象
## 某个声明类型下，作者能选哪些具体类型。
##
## 抽象基类去注册表列举；具体类只有它自己。编辑器的下拉框直接用这个填 ——
## 于是**新增一种效果，下拉框自动多一项**，编辑器一行不用改。
static func available_types(class_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if ABSTRACT_ROOTS.has(class_id):
		for table in ABSTRACT_ROOTS[class_id]:
			for n in EffectRegistry.type_names(table):
				out.append(n)
		out.sort()
		return out
	out.append(class_id)
	return out


## 按声明类型与具体类型名造一个空实例，字段全是默认值。
static func make(class_id: StringName, type_name: StringName) -> Object:
	if ABSTRACT_ROOTS.has(class_id):
		for table in ABSTRACT_ROOTS[class_id]:
			if EffectRegistry.has_type(table, type_name):
				return EffectRegistry.instantiate(table, type_name)
		return null
	var script := script_of(class_id)
	return script.new() if script != null else null


## 一个实例在注册表里叫什么。抽象基类的子对象要靠它显示当前选中项。
static func registry_name_of(inst: Object) -> StringName:
	var wanted := class_name_of(inst)
	for table in EffectRegistry.TABLES:
		var t: Dictionary = EffectRegistry.TABLES[table]
		for type_name in t:
			var script := load(t[type_name]) as GDScript
			if script != null and script.get_global_name() == wanted:
				return type_name
	return wanted
#endregion


#region 类型化数组
## 类型化数组的元素类名；不是对象数组则返回空。
static func array_element_class(arr: Array) -> StringName:
	if arr.get_typed_builtin() != TYPE_OBJECT:
		return &""
	var s := arr.get_typed_script() as Script
	return s.get_global_name() if s != null else &""


## 造一个和 [param like] 同样类型化的空数组。
##
## 必须保住类型：往 `Array[StatModifier]` 里塞一个裸 Array，赋值时会静默失败。
static func empty_like(like: Array) -> Array:
	return Array(
		[], like.get_typed_builtin(), like.get_typed_class_name(), like.get_typed_script()
	)
#endregion
