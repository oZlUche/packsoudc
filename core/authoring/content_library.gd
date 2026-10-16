## 146：库 —— 已导入的独立 buff（`data/buffs`）与规则构件（`data/rule_parts`），按 id 查。
##
## 三处要它：编辑器单独导入一件道具时的上下文（176 起在 `authoring_context.gd`，这里不写导入器的名字，免得游戏启动时把它编译进来；道具里写的 `"buff": "bleed"`、`"@id"` 得查得到）、
## 导出器回写引用（[ContentExporter]：和库里那份一样的 buff 写 id，带 `part_ref` 的写 `"@id"`）、编辑器的下拉。
## 读的是 `.tres`（游戏读的也是它）；编辑器存盘之后 [method reset] 一下就重读。
class_name ContentLibrary
extends RefCounted

static var _buffs: Variant = null
static var _parts: Variant = null


## 库变了（存了一份 buff / 构件、重新导入过）：下次用时重读
static func reset() -> void:
	_buffs = null
	_parts = null


## id → BuffDef
static func buffs() -> Dictionary:
	if _buffs == null:
		_buffs = _load("buffs")
	return _buffs


## id → RulePartDef
static func parts() -> Dictionary:
	if _parts == null:
		_parts = _load("rule_parts")
	return _parts


static func part(id: StringName) -> RulePartDef:
	return parts().get(id, null)


## 接在某个基类上的全部构件（`&"Trigger"` …），按 id 排
static func parts_for(root: StringName) -> Array[RulePartDef]:
	var out: Array[RulePartDef] = []
	var ids: Array = parts().keys()
	ids.sort()
	for id in ids:
		var p := parts()[id] as RulePartDef
		if p.root() == root:
			out.append(p)
	return out


## 从库里复制一份构件的内容，打上 `part_ref`（导入器解析 `"@id"`、编辑器下拉选库项都走这里）
static func instance_of(def: RulePartDef) -> Resource:
	var src := def.part()
	if src == null:
		return null
	var copy := src.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	copy.set_meta(RulePartDef.REF_META, def.id)
	return copy


static func _load(kind: String) -> Dictionary:
	var out := {}
	var dir: String = ContentPaths.dirs_of(kind)[1]
	for name in ContentPaths.resource_names(dir):
		var res = load(dir + "/" + name)
		if res != null and res.get("id") != null and res.id != &"":
			out[res.id] = res
	return out
