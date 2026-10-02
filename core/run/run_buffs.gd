## 一组激活的 buff 合起来改了什么（059）：算 [RunContext]、收战斗属性与规则、往掉落上下文里加。
## 纯函数；谁激活了什么由 [MetaState.active_buffs]（局外）与 [BuffModule]（一局）说了算。
class_name RunBuffs
extends RefCounted


static func context(defs: Array) -> RunContext:
	var ctx := RunContext.new()
	for d in defs:
		var def := d as RunBuffDef
		if def == null:
			continue
		for e in def.effects:
			if e is RunEffect:
				(e as RunEffect).modify(ctx)
	return ctx


static func combat_mods(defs: Array) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for d in defs:
		var def := d as RunBuffDef
		if def != null:
			out.append_array(def.mods)
	return out


static func combat_rules(defs: Array) -> Array[AbilityRule]:
	var out: Array[AbilityRule] = []
	for d in defs:
		var def := d as RunBuffDef
		if def != null:
			out.append_array(def.rules)
	return out


## 掉落：把 buff 的 [LootEffect] 施加到上下文上（6.1 里局外 / 地图 buff 的接缝，现在接上了）
static func apply_loot(defs: Array, ctx: LootContext) -> void:
	for d in defs:
		var def := d as RunBuffDef
		if def == null:
			continue
		for e in def.effects:
			if e is LootEffect:
				(e as LootEffect).modify(ctx)


## 带某个标记的有没有
static func has_tag(defs: Array, tag: StringName) -> bool:
	for d in defs:
		var def := d as RunBuffDef
		if def != null and def.tags.has(tag):
			return true
	return false


## 资产目录里的全部 buff：id → 定义
static func load_all(dir_path: String = ContentPaths.RUN_BUFFS) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file_name in dir.get_files():
		var name := file_name.trim_suffix(".remap")
		if not (name.ends_with(".tres") or name.ends_with(".res")):
			continue
		var res := ResourceLoader.load(dir_path.path_join(name))
		if res is RunBuffDef and (res as RunBuffDef).id != &"":
			out[(res as RunBuffDef).id] = res
	return out
