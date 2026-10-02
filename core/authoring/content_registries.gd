## 三张注册表合起来（101 第 5 刀）：内容管线要的是**全部**构件。
##
## 表按层拆开住在自己那层（[EffectRegistry] 战斗、[LootRegistry] 战利品、[RunRegistry] 一局），
## 这样战斗层不必认识一局的构件；而导入器、校验、导出、编辑器要的是一张全表，所以合并在
## 这一层做 —— `core/authoring` 本来就在三者之上（架构文档 1 节的依赖方向）。
##
## 种类名（`trigger` / `run_module` / `faith_perk`……）全局唯一，三张表不许撞键：[method tables] 合并时会查。
class_name ContentRegistries
extends RefCounted


## 全部种类 → 该种类的「类型名 → 脚本路径」表
static func tables() -> Dictionary:
	var out: Dictionary = {}
	for part in [EffectRegistry.TABLES, LootRegistry.TABLES, RunRegistry.TABLES]:
		for kind in part:
			if out.has(kind):
				push_error("注册表：种类名 %s 在两张表里都有（种类名要全局唯一）" % kind)
			out[kind] = part[kind]
	return out


## 按种类与类型名构造一个实例；未登记返回 null 并告警
static func instantiate(kind: StringName, type_name: StringName) -> Resource:
	return RegistryLookup.instantiate(tables(), kind, type_name)


static func has_type(kind: StringName, type_name: StringName) -> bool:
	return RegistryLookup.has_type(tables(), kind, type_name)


## 这一种的全部类型名，升序
static func type_names(kind: StringName) -> Array:
	return RegistryLookup.type_names(tables(), kind)
