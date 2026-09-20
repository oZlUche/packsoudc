## 伤害类型注册表。
##
## 内置四种够跑通管线，内容确定后用 [method register] 追加，不改任何结算代码。
## 未登记的类型名会退回一份「常规」默认值并告警 —— 打错字不该静默变成无敌。
class_name DamageTypes
extends RefCounted

## 常规物理。吃护盾、吃护甲、触发受伤效果。
const PHYSICAL := &"physical"

## 火焰。目前与物理同性质，留作元素线的起点。
const FIRE := &"fire"

## 中毒。**绕过护盾与护甲**，直接见血。
const POISON := &"poison"

## 流失。血量因代价、超频、献祭而减少时用它。
##
## 走完整管线（因此减伤、反转、免疫照样生效），但**不触发默认的受伤效果**。
const DRAIN := &"drain"

static var _defs: Dictionary = {}
static var _fallback: DamageTypeDef = null


static func _ensure_builtins() -> void:
	if not _defs.is_empty():
		return
	_define(PHYSICAL, "物理", true, true, true)
	_define(FIRE, "火焰", true, true, true)
	_define(POISON, "中毒", false, false, true)
	_define(DRAIN, "流失", false, false, false)


static func _define(
	id: StringName, name: String, absorbable: bool, armor: bool, notifies: bool
) -> void:
	var d := DamageTypeDef.new()
	d.id = id
	d.display_name = name
	d.shield_absorbable = absorbable
	d.armor_applies = armor
	d.notifies = notifies
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


## 仅供测试：清掉内容追加的类型，恢复到只有内置四种
static func reset_to_builtins() -> void:
	_defs.clear()
	_ensure_builtins()
