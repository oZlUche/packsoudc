## 一张「类型名 → 脚本路径」表怎么查（101 第 5 刀）。
##
## 注册表按层分成了三张（[EffectRegistry] 战斗、[LootRegistry] 战利品、[RunRegistry] 一局），
## 查法三家一样，所以查法在这里，表各自留在自己那层。内容管线要的是**全部**三张，由
## [ContentRegistries]（`core/authoring`）合起来 —— 这样战斗层不必认识一局的那些构件（架构文档 1 节）。
class_name RegistryLookup
extends RefCounted


## 按种类与类型名构造一个实例。未登记的类型名返回 null 并告警 —— 导入器据此拒绝生成资产，不产出半成品
static func instantiate(tables: Dictionary, kind: StringName, type_name: StringName) -> Resource:
	var table: Dictionary = tables.get(kind, {})
	var path: String = table.get(type_name, "")
	if path.is_empty():
		push_warning("注册表：未登记的 %s 类型 '%s'" % [kind, type_name])
		return null
	var script: GDScript = load(path)
	if script == null:
		push_error("注册表：脚本加载失败 %s" % path)
		return null
	return script.new()


static func has_type(tables: Dictionary, kind: StringName, type_name: StringName) -> bool:
	return (tables.get(kind, {}) as Dictionary).has(type_name)


## 一个实例的全局类名（没有脚本、或脚本没有 class_name 时是引擎类名）。内部日志写构件类名都走它
static func class_of(o: Object) -> String:
	if o == null:
		return ""
	var script := o.get_script() as Script
	var n := String(script.get_global_name()) if script != null else ""
	return n if n != "" else o.get_class()


## 这一种的全部类型名，升序
static func type_names(tables: Dictionary, kind: StringName) -> Array:
	var k := (tables.get(kind, {}) as Dictionary).keys()
	k.sort()
	return k
