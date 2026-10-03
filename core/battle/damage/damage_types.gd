## 伤害类型注册表。
##
## 内置四种够跑通管线，内容确定后用 [method register] 追加，不改任何结算代码。
## 未登记的类型名会退回一份「常规」默认值并告警 —— 打错字不该静默变成无敌。
##
## 096（作者定）：类型也是**内容** —— `data/authoring/damage_types/*.json` → `data/damage_types/*.tres`，装回时覆盖同 id 的内置定义
## （名字、别的语言的名字、说明、三个性质都以数据为准）；内置的只是没有数据时的兜底。[method name_of] 按当前语言给名字
class_name DamageTypes
extends RefCounted

## 常规物理。吃护盾、触发受伤效果。
const PHYSICAL := &"physical"

## 火焰。目前与物理同性质，留作元素线的起点。
const FIRE := &"fire"

## 中毒。**绕过护盾**，直接见血。持续伤害，不招致反应（防护也挡不住它 —— 它来自 buff，不是直接伤害，106 第八节）。
const POISON := &"poison"

## 流血。持续伤害，绕过护盾（伤在内里），不招致反应。
const BLEED := &"bleed"

## 反伤。**反弹伤害专用** —— 它不招致反应，所以两件反伤道具不会互相引燃。
const REFLECT := &"reflect"

## 流失。血量因代价、超频、献祭而减少时用它。
##
## 走完整管线（因此减伤、反转、免疫照样生效），但**不触发默认的受伤效果**。
const DRAIN := &"drain"

static var _defs: Dictionary = {}
static var _fallback: DamageTypeDef = null
static var _content_loaded: bool = false


static func _ensure_builtins() -> void:
	if not _defs.is_empty():
		return
	_define_builtins()
	if not _content_loaded:
		_content_loaded = true
		load_dir(ContentPaths.DAMAGE_TYPES)


## 096：从目录装定义，同 id 覆盖（内置的让位给数据）。返回装了几份
static func load_dir(dir_path: String) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var names: Array[String] = []
	for f in dir.get_files():
		var n := f.trim_suffix(".remap")
		if n.ends_with(".tres") or n.ends_with(".res"):
			names.append(n)
	names.sort()
	var count := 0
	for n in names:
		var res := load(dir_path + "/" + n)
		if res is DamageTypeDef and (res as DamageTypeDef).id != &"":
			_defs[(res as DamageTypeDef).id] = res
			count += 1
	return count


## 096：类型给人看（当前语言）；没登记的原词
static func name_of(id: StringName, lang: String = "") -> String:
	_ensure_builtins()
	var d: DamageTypeDef = _defs.get(id, null)
	if d == null:
		return String(id)
	var n := Names.of(d, lang)
	return n if n != "" else String(id)


## 096：类型的一句说明（当前语言）；没写返回空
static func describe(id: StringName, lang: String = "") -> String:
	_ensure_builtins()
	var d: DamageTypeDef = _defs.get(id, null)
	return Names.description_of(d, lang) if d != null else ""


static func _define_builtins() -> void:
	#            id        名称     护盾   招致反应
	_define(PHYSICAL, "物理", true, true)
	_define(FIRE, "火焰", true, true)
	_define(POISON, "中毒", false, false)
	_define(BLEED, "流血", false, false)
	_define(REFLECT, "反伤", true, false)
	_define(DRAIN, "流失", false, false)


static func _define(
	id: StringName, name: String, absorbable: bool, provokes: bool
) -> void:
	var d := DamageTypeDef.new()
	d.id = id
	d.display_name = name
	d.shield_absorbable = absorbable
	d.provokes = provokes
	_defs[id] = d


## 取一种伤害类型的性质。未登记时返回一份常规默认值并告警。
static func get_def(id: StringName) -> DamageTypeDef:
	_ensure_builtins()
	var d: DamageTypeDef = _defs.get(id, null)
	if d != null:
		return d
	push_warning("DamageTypes: 未登记的伤害类型 '%s'，按常规结算" % id)
	if _fallback == null:
		_fallback = DamageTypeDef.new()
		_fallback.id = &"?"
		_fallback.display_name = "未知"
	return _fallback


## 登记一种新类型。id 重复时返回 false，不覆盖 —— 与 [SetDatabase] 一致。
static func register(def: DamageTypeDef) -> bool:
	_ensure_builtins()
	if def == null or def.id == &"" or _defs.has(def.id):
		return false
	_defs[def.id] = def
	return true


static func has(id: StringName) -> bool:
	_ensure_builtins()
	return _defs.has(id)


## 已登记的类型名，按字典序 —— 顺序稳定，便于测试与编辑器下拉框
static func ids() -> Array:
	_ensure_builtins()
	var k := _defs.keys()
	k.sort()
	return k


## 仅供测试：清掉运行时追加的类型，恢复到内置 + 数据里的
static func reset_to_builtins() -> void:
	_defs.clear()
	_content_loaded = false
	_ensure_builtins()
