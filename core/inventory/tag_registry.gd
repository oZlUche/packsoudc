## 标签注册表（096）：id → [TagDef]。第一次用到时从 [constant ContentPaths.TAGS] 装回全部定义；
## 之后 [method name_of] / [method describe] 按当前语言给名字与说明。和 [DamageTypes] 一样是静态表，不是 autoload。
##
## 没登记的标签在这里不是错：[method name_of] 原样返回 id，[method describe] 返回空（171：道具上写没登记的标签，导入器报错）。
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


## 107 后续：内部标签（玩家看不到）。没登记的标签不算内部 —— 界面照原词显示；171：内部类也算
static func is_internal(id: StringName) -> bool:
	var def := get_def(id)
	return def != null and (def.internal or def.category == "internal")


## 171：大类的先后（悬浮窗副行、编辑器下拉分组都按这个排）。来源类排在材料后面，副行不列它
const CATEGORY_ORDER: Array[String] = ["purpose", "element", "material", "origin", "source", "internal"]


## 171：这个标签归哪类；没登记 / 没归类返回空串。`faith:<id>` 算归属类
static func category_of(id: StringName) -> String:
	if String(id).begins_with(FaithTags.PREFIX):
		return "origin"
	var def := get_def(id)
	return def.category if def != null else ""


## 171：某一类的标签 id，按字典序
static func by_category(cat: String) -> Array:
	_ensure()
	var out: Array = []
	for id in ids():
		if (_defs[id] as TagDef).category == cat:
			out.append(id)
	return out


## 171：把一串标签按大类排（用途 → 属性 → 材料 → 归属 → 来源 → 内部；没归类的在最后），同类内保持原顺序
static func sorted_by_category(tags: Array) -> Array:
	var rank := func(t) -> int:
		var i := CATEGORY_ORDER.find(category_of(StringName(String(t))))
		return i if i >= 0 else CATEGORY_ORDER.size()
	var indexed: Array = []
	for i in tags.size():
		indexed.append([rank.call(tags[i]), i, tags[i]])
	indexed.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return indexed.map(func(e): return e[2])


## 177：大类的名次（[constant CATEGORY_ORDER] 里的下标；没归类的排最后）
static func category_rank(id: StringName) -> int:
	var i := CATEGORY_ORDER.find(category_of(id))
	return i if i >= 0 else CATEGORY_ORDER.size()


## 177：登记顺序里的位置（装定义时的先后；没登记的排最后）
static func order_of(id: StringName) -> int:
	_ensure()
	var i := _defs.keys().find(id)
	return i if i >= 0 else _defs.size()


## 107 后续：去掉内部标签，剩下给玩家看的
static func shown(tags: Array) -> Array:
	var out: Array = []
	for t in tags:
		if not is_internal(StringName(String(t))):
			out.append(t)
	return out


## 登记过的标签，按字典序（编辑器下拉框、测试）。StringName 直接 sort 是按指针排的，得转成字符串比
static func ids() -> Array:
	_ensure()
	var k := _defs.keys()
	k.sort_custom(func(a, b) -> bool: return String(a) < String(b))
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


## 193：标签图标在的目录（文件名 = [member TagDef.icon]，空 = id）
const ICON_DIR := "res://assets/ui/tags/"


## 193：这个标签的图标路径；没图返回空串。没登记的标签按 id 找（献祭条件里的标签也走这里）
static func icon_path(id: StringName) -> String:
	var def := get_def(id)
	return icon_path_of_file(def.icon if def != null and def.icon != "" else String(id))


## 193：[constant ICON_DIR] 下这个文件名（不含扩展名）的图在不在：在给路径，不在给空串（导入器、标签制作器的预览也用）
static func icon_path_of_file(file: String) -> String:
	var path := ICON_DIR + file + ".png"
	return path if file != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)) else ""


## 107：这个标签要不要弹词条（没登记的标签没有词条，返回 false）
static func tip_of(id: StringName) -> bool:
	var def := get_def(id)
	return def != null and def.tip


## 仅供测试：清掉，下次用到重新装
static func reset() -> void:
	_defs.clear()
	_loaded = false
