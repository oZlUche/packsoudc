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
	return dump(def)


static func export_buff(def: BuffDef) -> Dictionary:
	return dump(def)


static func export_set(def: ItemSetDef) -> Dictionary:
	return dump(def)


static func export_chapter(def: ChapterDef) -> Dictionary:
	return dump(def)


static func export_enemy(def: EnemyDef) -> Dictionary:
	return dump(def)


static func export_enemy_pool(pool: EnemyPool) -> Dictionary:
	return dump(pool)


static func export_drop_rule(rule: DropRule) -> Dictionary:
	return dump(rule)


static func export_carry_rule(rule: CarryRule) -> Dictionary:
	return dump(rule)


static func export_encumbrance_rules(rules: EncumbranceRules) -> Dictionary:
	return dump(rules)


static func export_node_rules(rules: NodeRules) -> Dictionary:
	return dump(rules)


static func export_economy_rules(rules: EconomyRules) -> Dictionary:
	return dump(rules)


static func export_loadout(def: LoadoutDef) -> Dictionary:
	return dump(def)


static func export_character(def: CharacterDef) -> Dictionary:
	return dump(def)


static func export_difficulty(def: DifficultyDef) -> Dictionary:
	return dump(def)


static func export_hunter(def: HunterDef) -> Dictionary:
	return dump(def)


static func export_meta_rules(rules: MetaRules) -> Dictionary:
	return dump(rules)


static func export_faith(def: FaithDef) -> Dictionary:
	return dump(def)


static func export_tag(def: TagDef) -> Dictionary:
	return dump(def)


static func export_damage_type(def: DamageTypeDef) -> Dictionary:
	return dump(def)


static func export_achievement(def: AchievementDef) -> Dictionary:
	return dump(def)


static func export_tech(def: TechDef) -> Dictionary:
	return dump(def)


static func export_help_page(def: HelpPageDef) -> Dictionary:
	return dump(def)


static func export_recipe(def: RecipeDef) -> Dictionary:
	return dump(def)


static func export_run_buff(def: RunBuffDef) -> Dictionary:
	return dump(def)


static func export_event(def: EventDef) -> Dictionary:
	return dump(def)


## 资源 → 字典。按反射工作、不认识具体类型，所以按种类分派的地方（[ContentCheck]、`tools/normalize_content.gd`）
## 直接用它，上面那排 `export_xxx` 只是带类型的入口。`with_type` 给抽象基类的子对象带上 `type`
static func dump(obj: Object, with_type: bool = false) -> Dictionary:
	var out := {}
	if obj == null:
		return out
	if with_type:
		out["type"] = String(ContentSchema.registry_name_of(obj))

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
	_percent_out(obj, out)
	if obj is ReactionDef:
		_reaction_out(obj as ReactionDef, out)
	return out


## 175 补充二：随 N 变的数字写回效果里的内联写法（导入的反方向，见 [method ContentImporter._pull_reaction_scaling]）
static func _reaction_out(def: ReactionDef, out: Dictionary) -> void:
	out.erase("scaling")
	var effects: Variant = out.get("effects", [])
	if not (effects is Array):
		return
	for raw in def.scaling:
		var row := raw as Dictionary
		var i := int(row.get("effect", -1))
		if i < 0 or i >= (effects as Array).size() or not (effects[i] is Dictionary):
			continue
		var spec := {}
		match String(row.get("kind", "")):
			ReactionDef.KIND_PER_STACK:
				spec["per_stack"] = float(row.get("x", 0.0))
			ReactionDef.KIND_N:
				spec["stacks"] = "n"
			ReactionDef.KIND_SECONDS:
				spec["seconds"] = "n"
		if row.has("max"):
			spec["max"] = float(row["max"])
		var field := String(row.get("field", ""))
		effects[i]["duration_sec" if field == ReactionDef.BUFF_DURATION else field] = spec


## 百分比属性写回百分数（导入时 ÷100 的反方向，见 [method ContentImporter._percent_in]）
static func _percent_out(obj: Object, out: Dictionary) -> void:
	if obj is StatModifier:
		var m := obj as StatModifier
		if out.has("amount") and not m.is_mult() and BattleStats.is_percent(m.stat):
			out["amount"] = BattleStats.to_percent(m.amount)
		return
	if not (out.get("base_stats") is Dictionary):
		return
	var stats: Dictionary = out["base_stats"]
	for key in stats.keys():
		var v = stats[key]
		if (v is float or v is int) and BattleStats.is_percent(StringName(String(key))):
			stats[key] = BattleStats.to_percent(float(v))
	out["base_stats"] = MapGraph.normalize(stats)


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
		TYPE_VECTOR2:
			return _vec2(value)
		TYPE_DICTIONARY:
			# 字典里整数值的浮点写成整数（1.0 → 1），和导入器读回来的一样 ——
			# JSON 没有整数，不这么写「导出→导入→再导出」的文本就变了
			return MapGraph.normalize((value as Dictionary).duplicate(true))
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
			TYPE_VECTOR2:
				out.append(_vec2(item))
			_:
				out.append(item)
	return out


## Vector2 是单精度：1.2 存进去是 1.2000000476837，原样写出去 JSON 读回来的 double 就不等于它了。
## 按六位小数写 —— 作者写的本来就是六位以内的数
static func _vec2(v: Vector2) -> Array:
	return [snappedf(v.x, 0.000001), snappedf(v.y, 0.000001)]


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
	# 146：库里的东西写引用。buff：库里有同 id 且内容一样的就写 id（不一样 = 这件自己的版本，整份内联）；
	# 规则构件：带 `part_ref`（编辑器里没「断开」过）且库里还有它就写 `"@id"`，内容以库为准
	if obj is BuffDef:
		var lib: BuffDef = ContentLibrary.buffs().get((obj as BuffDef).id, null)
		if lib != null and (lib == obj or dump(lib) == dump(obj)):
			return String((obj as BuffDef).id)
	if obj is Resource and obj.has_meta(RulePartDef.REF_META):
		var ref := StringName(obj.get_meta(RulePartDef.REF_META))
		if ContentLibrary.part(ref) != null:
			return "@" + String(ref)
	# 带 type 的两种情况：声明的是抽象基类（按注册表名）；声明的是引擎基类如 Resource
	# 或子类装进了父类字段（按 class_name）—— 不写的话导入器不知道该造哪个类
	var with_type := ContentSchema.ABSTRACT_ROOTS.has(declared) \
		or ContentSchema.script_of(declared) == null \
		or ContentSchema.class_name_of(obj) != declared
	return dump(obj, with_type)


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
