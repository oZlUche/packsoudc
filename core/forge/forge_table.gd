## 铸炉的一张映射表（175 第三批 §3.2）：一个槽（时机 / 效果 / 数值）一张，`data/authoring/forge/<slot>.json`。
## 三列：材质类标签、用途类标签、稀有度，各自一组 [ForgeEntry]，`default` 行兜底
class_name ForgeTable
extends Resource

const SLOTS: Array[StringName] = [&"timing", &"effect", &"value"]
const DEFAULT := &"default"

## 槽：timing / effect / value（也是文件名与 id）
@export var id: StringName = &""
@export var display_name: String = ""
@export var display_names: Dictionary = {}
@export_multiline var description: String = ""
## 按材质（250：[member ItemDef.material] 字段；表里的本源三行 crafted / nature / magic 仍认标签）
@export var material: Array[ForgeEntry] = []
## 按用途（类别标签）
@export var purpose: Array[ForgeEntry] = []
## 按稀有度（key 写 "0".."4"）
@export var rarity: Array[ForgeEntry] = []


## 这件道具按材质落到哪一行：道具的标签里第一个在表里的（按表的顺序），都没有落 default
func by_material(def: ItemDef) -> ForgeEntry:
	return _by_tags(material, def)


func by_purpose(def: ItemDef) -> ForgeEntry:
	return _by_tags(purpose, def)


func by_rarity(r: int) -> ForgeEntry:
	var e := find(rarity, StringName(str(r)))
	return e if e != null else find(rarity, DEFAULT)


## 按 key 找一行（存档里记的是 key）
static func find(rows: Array[ForgeEntry], key: StringName) -> ForgeEntry:
	for e in rows:
		if e != null and e.key == key:
			return e
	return null


static func _by_tags(rows: Array[ForgeEntry], def: ItemDef) -> ForgeEntry:
	if def != null:
		for e in rows:
			if e != null and e.key != DEFAULT and def.has_tag(e.key):     # 250：材质行认 [member ItemDef.material]，本源 / 用途行认标签
				return e
	return find(rows, DEFAULT)
