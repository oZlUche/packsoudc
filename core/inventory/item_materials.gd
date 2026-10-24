## 250（作者定）：材质 —— 十选一的道具字段（[member ItemDef.material]），不再是标签：不显示、不进标签表。
## 重量、音效、铸炉的材质行读它；包的准入（「只收草药」）写材质 id 也认（[method ItemDef.has_tag]），这里给那一处的名字
class_name ItemMaterials
extends RefCounted

const IDS: Array[StringName] = [&"metal", &"wood", &"leather", &"cloth", &"bone", &"stone", &"gem", &"clay", &"flesh", &"herb"]
const NAMES := {
	&"metal": {"zh": "金属", "en": "Metal"}, &"wood": {"zh": "木", "en": "Wood"}, &"leather": {"zh": "皮革", "en": "Leather"},
	&"cloth": {"zh": "织物", "en": "Cloth"}, &"bone": {"zh": "骨", "en": "Bone"}, &"stone": {"zh": "石", "en": "Stone"},
	&"gem": {"zh": "晶体", "en": "Crystal"}, &"clay": {"zh": "陶", "en": "Clay"}, &"flesh": {"zh": "血肉", "en": "Flesh"},
	&"herb": {"zh": "草药", "en": "Herb"},
}


static func is_material(id: StringName) -> bool:
	return NAMES.has(id)


## 当前语言（或 [param lang]）的名字；不是材质给空串
static func name_of(id: StringName, lang: String = "") -> String:
	var n: Dictionary = NAMES.get(id, {})
	if n.is_empty():
		return ""
	return String(n.get(lang if lang != "" else UiText.lang, n["zh"]))
