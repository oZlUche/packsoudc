## 标签注册表（096）：id → [TagDef]。第一次用到时从 [constant ContentPaths.TAGS] 装回全部定义；
## 之后 [method name_of] / [method describe] 按当前语言给名字与说明。和 [DamageTypes] 一样是静态表，不是 autoload。
##
## 没登记的标签不是错：[method name_of] 原样返回 id，[method describe] 返回空。
class_name TagRegistry
extends RefCounted

static var _defs: Dictionary = {}
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	load_dir(ContentPaths.TAGS)


## 从一个目录装定义（同 id 后来的覆盖前面的）。返回装了几份
static func load_dir(dir_path: String) -> int:
	var count := 0
	for res in ContentPaths.load_resources(dir_path):
		if res is TagDef and (res as TagDef).id != &"":
			_defs[(res as TagDef).id] = res
			count += 1
	return count


## 登记一份（测试 / 运行时追加）。覆盖同 id 的
static func register(def: TagDef) -> void:
	_ensure()
	if def != null and def.id != &"":
		_defs[def.id] = def


## 098：找不到就问一次改名表（[IdAliases]）—— 标签改了名，老存档与老内容里的旧名字还查得到说明
static func get_def(id: StringName) -> TagDef:
	_ensure()
	var d: TagDef = _defs.get(id, null)
	if d != null:
		return d
	var alias := IdAliases.tag(id)
	return _defs.get(alias, null) if alias != id else null


## 107 后续：内部标签（玩家看不到）。没登记的标签不算内部 —— 界面照原词显示
static func is_internal(id: StringName) -> bool:
	var def := get_def(id)
	return def != null and def.internal


## 107 后续：去掉内部标签，剩下给玩家看的
static func shown(tags: Array) -> Array:
	var out: Array = []
	for t in tags:
		if not is_internal(StringName(String(t))):
			out.append(t)
	return out


## 登记过的标签，按字典序（编辑器下拉框、测试）
static func ids() -> Array:
	_ensure()
	var k := _defs.keys()
	k.sort()
	return k


## 标签给人看：当前语言的名字；没登记的原词。`faith:<id>` 显示成「信仰：<神名>」交给调用方（见 [method Glossary.tag_name]）
static func name_of(id: StringName, lang: String = "") -> String:
	var def := get_def(id)
	if def == null:
		return String(id)
	var n := Names.of(def, lang)
	return n if n != "" else String(id)


## 标签的一句说明（当前语言）；没登记 / 没写返回空
static func describe(id: StringName, lang: String = "") -> String:
	var def := get_def(id)
	return Names.description_of(def, lang) if def != null else ""


## 107：这个标签要不要弹词条（没登记的标签没有词条，返回 false）
static func tip_of(id: StringName) -> bool:
	var def := get_def(id)
	return def != null and def.tip


## 仅供测试：清掉，下次用到重新装
static func reset() -> void:
	_defs.clear()
	_loaded = false
