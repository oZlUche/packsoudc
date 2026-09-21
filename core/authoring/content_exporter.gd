## 引擎资源 → JSON，[ContentImporter] 的逆运算。
##
## 三个用处：
##
## 1. **把现有 .tres 倒出来**，作为作者数据的起点，不必手抄一遍；
## 2. **编辑器存盘** —— GUI 改的是资源对象，存的是 JSON；
## 3. **往返测试** —— 导出再导入，两边必须一致。这条测试比任何断言都能
##    保住「导入器不认识具体效果」这个性质：新增一种效果如果没走通用路径，
##    往返立刻就崩。
##
## [b]只写与默认值不同的字段。[/b] 全量输出会让每个道具带上二十行
## `"per_stack": false`，git diff 里全是噪音，作者也分不清哪些是他真正设过的。
class_name ContentExporter
extends RefCounted


static func export_item(def: ItemDef) -> Dictionary:
	return _dump(def)


static func export_buff(def: BuffDef) -> Dictionary:
	return _dump(def)


static func export_set(def: ItemSetDef) -> Dictionary:
	return _dump(def)


## 带 type 的导出，用于抽象基类的子对象
static func _dump(obj: Object, with_type: bool = false) -> Dictionary:
	var out := {}
	if obj == null:
		return out
	if with_type:
		out["type"] = String(_registry_name_of(obj))

	var fresh: Object = null
	var script := obj.get_script() as GDScript
	if script != null:
		fresh = script.new()

	for prop in ContentSchema.properties_of(obj):
		var key := String(prop["name"])
		var value = obj.get(key)
		if value == null:
			continue
		# 与默认值相同就不写
		if fresh != null and _same(value, fresh.get(key)):
			continue
		var encoded = _encode(obj, prop, value)
		if encoded != null:
			out[key] = encoded
	return out


static func _same(a: Variant, b: Variant) -> bool:
	if a is Array and b is Array:
		return (a as Array).is_empty() and (b as Array).is_empty()
	if a is Dictionary and b is Dictionary:
		return (a as Dictionary).is_empty() and (b as Dictionary).is_empty()
	if a is Object or b is Object:
		return false
	return a == b


static func _encode(owner: Object, prop: Dictionary, value: Variant) -> Variant:
	match int(prop["type"]):
		TYPE_INT:
			return ContentSchema.enum_name(owner, prop, int(value))
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2I:
			return [(value as Vector2i).x, (value as Vector2i).y]
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate()
		TYPE_ARRAY:
			return _encode_array(value as Array)
		TYPE_OBJECT:
			return _encode_object(StringName(prop["hint_string"]), value as Object)
		_:
			return value


static func _encode_array(arr: Array) -> Array:
	var out: Array = []
	var element_class := ContentSchema.array_element_class(arr)
	for item in arr:
		match arr.get_typed_builtin():
			TYPE_OBJECT:
				out.append(_encode_object(element_class, item as Object))
			TYPE_STRING_NAME:
				out.append(String(item))
			TYPE_VECTOR2I:
				out.append([(item as Vector2i).x, (item as Vector2i).y])
			_:
				out.append(item)
	return out


static func _encode_object(declared: StringName, obj: Object) -> Variant:
	if obj == null:
		return null
	# 形状倒回 0/1 数字串，和作者写进去的是同一种记法。
	#
	# 注意要返回**普通 Array** 而不是 split() 给的 PackedStringArray：
	# 后者过一趟 JSON 会变成 Array，但在内存里直接回灌导入器时不是 ——
	# 于是「导出→导入」在内存里失败、经过 JSON 反而成功，最难查的那种不一致。
	if declared == &"ItemShape" or ContentSchema.instance_is(obj, &"ItemShape"):
		var rows: Array = []
		for line in (obj as ItemShape).to_bits().split("\n"):
			rows.append(String(line))
		return rows
	return _dump(obj, ContentSchema.ABSTRACT_ROOTS.has(declared))


## 实例 → 注册表里的类型名。
##
## 反查而不是在每个效果类上挂一个 `type` 字段：那样同一个事实会存两份，
## 而且新增效果时漏填就悄悄导不出来。
static func _registry_name_of(obj: Object) -> StringName:
	var wanted := ContentSchema.class_name_of(obj)
	for table in EffectRegistry.TABLES:
		var t: Dictionary = EffectRegistry.TABLES[table]
		for type_name in t:
			var path: String = t[type_name]
			var script := load(path) as GDScript
			if script != null and script.get_global_name() == wanted:
				return type_name
	push_warning("ContentExporter: %s 没有在 EffectRegistry 里登记，导出的 type 会是空的" % wanted)
	return &""


#region 文件
static func to_json(data: Dictionary) -> String:
	return JSON.stringify(data, "  ", false) + "\n"


static func save(data: Dictionary, path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_json(data))
	f.close()
	return OK
#endregion
