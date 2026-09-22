## JSON → 引擎资源（架构文档 10.2）。
##
## [b]本类不认识任何一种具体效果。[/b] 它只做三件事：
##
## 1. 问 Godot 目标类有哪些属性、各是什么类型（[ContentSchema]）；
## 2. 碰到抽象基类就按 JSON 里的 `type` 去 [EffectRegistry] 查；
## 3. 严格校验，有错就一个资产都不产出。
##
## 因此新增一种时机／频率／消耗／效果，这个文件一行都不用改。
##
## 只有三处例外，都是「JSON 里的写法和资源结构本来就不同构」，各自注明了理由：
## 形状（0/1 数字串）、增益引用（按 id）、以及 combat.rules 的糖。
class_name ContentImporter
extends RefCounted


## 导入过程中的共享上下文：先导入的东西，后面的可以按 id 引用。
class Context:
	extends RefCounted
	## id -> BuffDef
	var buffs: Dictionary = {}

	func register_buff(def: BuffDef) -> void:
		if def != null and def.id != &"":
			buffs[def.id] = def


#region 顶层入口
static func import_buff(data: Dictionary, ctx: Context, report: ImportReport) -> BuffDef:
	var def := BuffDef.new()
	_fill(def, data, "", ctx, report)
	if def.id == &"":
		report.error("id", "增益必须有 id")
	ctx.register_buff(def)
	return def


static func import_set(data: Dictionary, ctx: Context, report: ImportReport) -> ItemSetDef:
	var def := ItemSetDef.new()
	_fill(def, data, "", ctx, report)
	if def.id == &"":
		report.error("id", "套装必须有 id")
	if def.tiers.is_empty():
		report.warn("tiers", "套装没有任何档位，永远不会生效")
	return def


static func import_item(data: Dictionary, ctx: Context, report: ImportReport) -> ItemDef:
	var def := ItemDef.new()
	_fill(def, data, "", ctx, report)
	_validate_item(def, report)
	return def


## 章节（M3-5）。结构和道具完全不同，走的却是同一条 _fill ——
## 这是「导入器不认识具体类型」的第一次真实检验。
static func import_chapter(data: Dictionary, ctx: Context, report: ImportReport) -> ChapterDef:
	var def := ChapterDef.new()
	_fill(def, data, "", ctx, report)
	_validate_chapter(def, report)
	return def


## 比引擎严格：地图来源得真的能拿出图来。生成器没登记、预设文件不在，都是内容错误。
static func _validate_chapter(def: ChapterDef, report: ImportReport) -> void:
	if def.id == &"":
		report.error("id", "章节必须有 id")
	if def.map_source == null:
		report.error("map_source", "章节必须有地图来源（随机生成或载入预设）")
		return
	var src := def.map_source
	match src.mode:
		MapSource.Mode.PRESET:
			if src.preset_path == "" or not FileAccess.file_exists(src.preset_path):
				report.error("map_source.preset_path", "找不到预设地图 '%s'" % src.preset_path)
		_:
			if not MapGeneratorRegistry.has(src.generator_id):
				report.error("map_source.generator_id", "没有登记过的生成器 '%s'（已登记：%s）"
					% [src.generator_id, ", ".join(MapGeneratorRegistry.ids())])
			elif src.generator_config == null:
				report.error("map_source.generator_config", "随机生成得有一份生成器配置")
			else:
				# 造一个生成器看它认不认这份配置 —— 装错类的配置到开局才炸，那时离文件已经很远了
				var gen := MapGeneratorRegistry.create(src.generator_id)
				var probe := gen.default_config() if gen != null else null
				if probe != null and ContentSchema.class_name_of(probe) != ContentSchema.class_name_of(src.generator_config):
					report.error("map_source.generator_config", "生成器 '%s' 要的是 %s，给的是 %s"
						% [src.generator_id, ContentSchema.class_name_of(probe),
							ContentSchema.class_name_of(src.generator_config)])


## 比引擎严格（10.3）：引擎能接受的半成品，这里一律拒绝。
static func _validate_item(def: ItemDef, report: ImportReport) -> void:
	if def.id == &"":
		report.error("id", "物品必须有 id")
	if def.shape == null:
		report.error("shape", "物品必须有形状")
	elif not def.shape.is_valid():
		report.error("shape", "形状非法：为空或有重复格")
	if def.rarity < 0:
		report.error("rarity", "稀有度不能为负")

	if not def.is_bag:
		if not def.bag_accept_tags.is_empty():
			report.warn("bag_accept_tags", "不是包，准入标签不会生效")
		if not def.bag_mods.is_empty():
			report.warn("bag_mods", "不是包，包体效果不会生效")

	if def.combat != null:
		for i in def.combat.rules.size():
			var r := def.combat.rules[i] as AbilityRule
			var at := "combat.rules[%d]" % i
			if r == null:
				report.error(at, "规则为空")
				continue
			if r.trigger == null:
				report.error(at + ".trigger", "规则必须有时机")
			if r.cadence == null:
				report.error(at + ".cadence", "规则必须有频率")
			if r.effects.is_empty():
				report.warn(at + ".effects", "规则没有任何效果，触发了也什么都不做")

	if def.adjacency != null:
		var ap := def.adjacency
		if not ap.grant_cells.is_empty() and ap.grant_mods.is_empty():
			report.warn("adjacency.grant", "标了增益格却没有加成，不会点亮任何东西")
		if not ap.receive_cells.is_empty() and ap.receive_mods.is_empty():
			report.warn("adjacency.receive", "标了受益格却没有加成")
		_warn_overlapping_markers(def, report)


## 标记格压在自己轮廓上时提醒。
##
## [b]不是错误，但一定是死数据。[/b] 编译器点亮邻居时会跳过 holder 自己
## （见 BattleCompiler._lit_neighbors 里的 `other == holder.uid`），
## 所以这种格子永远点不亮 —— 既不报错也不生效，是最难自查的一类配置。
##
## 画板已经不让点在自己身上了，但手写的 JSON 和早先存下来的数据还会有。
static func _warn_overlapping_markers(def: ItemDef, report: ImportReport) -> void:
	if def.shape == null or not def.shape.is_valid():
		return
	var own := {}
	for c in def.shape.cells_rotated(0):
		own[c] = true
	for pair in [["grant", def.adjacency.grant_cells], ["receive", def.adjacency.receive_cells]]:
		for c in pair[1]:
			if own.has(c):
				report.warn(
					"adjacency.%s_cells" % pair[0],
					"标记格 (%d, %d) 压在物品自己的格子上，永远点不亮 —— 标记格要在轮廓之外"
						% [(c as Vector2i).x, (c as Vector2i).y]
				)
#endregion


#region 通用填充
## 按反射把 [param data] 的每个键写进 [param obj]。
##
## 未知键**报错而不是忽略** —— 打错一个字段名却静默生效为默认值，
## 是内容作者最难自查的一类问题，报出来才有得改。
static func _fill(
	obj: Object, data: Dictionary, path: String, ctx: Context, report: ImportReport
) -> void:
	var props := {}
	for p in ContentSchema.properties_of(obj):
		props[String(p["name"])] = p

	for key in data:
		var at := _join(path, String(key))
		if key == "type":
			continue  # 由调用方消费，用来决定造哪个类
		if not props.has(String(key)):
			report.error(at, "未知字段（可用：%s）" % ", ".join(props.keys()))
			continue
		var prop: Dictionary = props[String(key)]
		var coerced = _coerce(obj, prop, obj.get(prop["name"]), data[key], at, ctx, report)
		if coerced != null:
			obj.set(prop["name"], coerced)


static func _join(path: String, key: String) -> String:
	return key if path == "" else path + "." + key


static func _coerce(
	owner: Object, prop: Dictionary, current: Variant, value: Variant,
	path: String, ctx: Context, report: ImportReport
) -> Variant:
	var type := int(prop["type"])
	match type:
		TYPE_BOOL:
			if value is bool:
				return value
			report.error(path, "应为布尔值")
		TYPE_INT:
			if value is String:
				var resolved = ContentSchema.enum_value(owner, prop, value)
				if resolved == null:
					var opts := ContentSchema.enum_options(owner, prop)
					report.error(path, "认不得的取值 '%s'%s" % [
						value, ("（可用：%s）" % ", ".join(opts)) if not opts.is_empty() else ""
					])
					return null
				return resolved
			if value is float or value is int:
				return int(value)
			report.error(path, "应为整数")
		TYPE_FLOAT:
			if value is float or value is int:
				return float(value)
			report.error(path, "应为数字")
		TYPE_STRING:
			return str(value)
		TYPE_STRING_NAME:
			return StringName(str(value))
		TYPE_VECTOR2I:
			return _to_vec2i(value, path, report)
		TYPE_VECTOR2:
			return _to_vec2(value, path, report)
		TYPE_DICTIONARY:
			if value is Dictionary:
				# JSON 没有整数：{"shop": [0, 1]} 读回来是 [0.0, 1.0]。还原成整数，
				# 不然导出再导入的文本就变了（约定见 MapGraph.normalize）
				return MapGraph.normalize((value as Dictionary).duplicate(true))
			report.error(path, "应为对象")
		TYPE_ARRAY:
			return _coerce_array(current as Array, value, path, ctx, report)
		TYPE_OBJECT:
			return _make_object(StringName(prop["hint_string"]), value, path, ctx, report)
		_:
			report.error(path, "暂不支持的字段类型 %d" % type)
	return null


static func _to_vec2i(value: Variant, path: String, report: ImportReport) -> Variant:
	if value is Array and (value as Array).size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	report.error(path, "应为 [x, y]")
	return null


static func _to_vec2(value: Variant, path: String, report: ImportReport) -> Variant:
	if value is Array and (value as Array).size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	report.error(path, "应为 [x, y]")
	return null


static func _coerce_array(
	current: Array, value: Variant, path: String, ctx: Context, report: ImportReport
) -> Variant:
	if not (value is Array):
		report.error(path, "应为数组")
		return null
	var out := ContentSchema.empty_like(current)
	var element_class := ContentSchema.array_element_class(current)
	var i := -1
	for raw in value:
		i += 1
		var at := "%s[%d]" % [path, i]
		var item: Variant = null
		match current.get_typed_builtin():
			TYPE_OBJECT:
				item = _make_object(element_class, raw, at, ctx, report)
			TYPE_STRING_NAME:
				item = StringName(str(raw))
			TYPE_STRING:
				item = str(raw)
			TYPE_VECTOR2I:
				item = _to_vec2i(raw, at, report)
			TYPE_VECTOR2:
				item = _to_vec2(raw, at, report)
			TYPE_INT:
				item = int(raw)
			TYPE_FLOAT:
				item = float(raw)
			_:
				item = raw
		if item != null:
			out.append(item)
	return out
#endregion


#region 造对象
## 造一个 [param class_id] 类型（或其子类）的实例。
static func _make_object(
	class_id: StringName, value: Variant, path: String, ctx: Context, report: ImportReport
) -> Object:
	if value == null:
		return null

	# --- 例外一：形状。JSON 里是 0/1 数字串，和 ItemShape 的字段不同构，
	#     硬要作者写 {"cells": [[0,0],[1,0]]} 是在为难人。
	if class_id == &"ItemShape":
		return _make_shape(value, path, report)

	# --- 例外二：增益可以按 id 引用先前导入的那一份。
	#     内联也允许 —— 只被一件道具用到的 buff 没必要单开一个文件。
	if class_id == &"BuffDef" and value is String:
		var found: BuffDef = ctx.buffs.get(StringName(value), null)
		if found == null:
			report.error(path, "找不到增益 '%s'（已知：%s）" % [
				value, ", ".join(ctx.buffs.keys())
			])
		return found

	if not (value is Dictionary):
		report.error(path, "应为对象")
		return null
	var data := value as Dictionary

	var inst: Object = null
	if ContentSchema.ABSTRACT_ROOTS.has(class_id):
		inst = _from_registry(class_id, data, path, report)
	else:
		var script := ContentSchema.script_of(class_id)
		# 字段声明成引擎基类（`generator_config: Resource`）时，JSON 里的 type 说造哪个脚本类。
		# 只认 class_name 过的类，而且造出来得真是那个基类的东西
		if script == null and data.has("type"):
			var wanted := StringName(str(data["type"]))
			script = ContentSchema.script_of(wanted)
			if script == null:
				report.error(path, "认不得的 type '%s'" % wanted)
				return null
		if script == null:
			report.error(path, "认不得的类型 %s" % class_id)
			return null
		inst = script.new()
		if data.has("type") and String(class_id) != "" and not ContentSchema.instance_is(inst, class_id) \
				and not ClassDB.is_parent_class(inst.get_class(), String(class_id)):
			report.error(path, "'%s' 不是 %s" % [data["type"], class_id])
			return null

	if inst == null:
		return null
	_fill(inst, data, path, ctx, report)
	return inst


## 抽象基类按 `type` 去注册表查。**这是导入器唯一认识「效果」的地方**，
## 而它认识的也只是一张名字到脚本路径的表。
static func _from_registry(
	class_id: StringName, data: Dictionary, path: String, report: ImportReport
) -> Object:
	if not data.has("type"):
		report.error(path, "%s 必须写明 type" % class_id)
		return null
	var type_name := StringName(str(data["type"]))
	var tables: Array = ContentSchema.ABSTRACT_ROOTS[class_id]

	for table in tables:
		if EffectRegistry.has_type(table, type_name):
			var inst := EffectRegistry.instantiate(table, type_name)
			# 同名可能落在别的作用域里，确认它真的是要的那一支
			if not ContentSchema.instance_is(inst, class_id):
				report.error(path, "'%s' 不是 %s" % [type_name, class_id])
				return null
			return inst

	var known: Array[String] = []
	for table in tables:
		for n in EffectRegistry.type_names(table):
			known.append(String(n))
	known.sort()
	report.error(path, "认不得的 type '%s'（可用：%s）" % [type_name, ", ".join(known)])
	return null


## 形状：接受 "11\n10" 或 ["11", "10"]，1 为占格、0 为空。
static func _make_shape(value: Variant, path: String, report: ImportReport) -> ItemShape:
	var text := ""
	if value is String:
		text = value
	elif value is Array or value is PackedStringArray:
		var rows: Array[String] = []
		for r in value:
			rows.append(str(r))
		text = "\n".join(rows)
	else:
		report.error(path, "形状应为 0/1 数字串，或每行一个的字符串数组")
		return null

	var shape := ItemShape.from_bits(text)
	if not shape.is_valid():
		report.error(path, "形状为空 —— 至少要有一个 1")
		return null
	return shape
#endregion
