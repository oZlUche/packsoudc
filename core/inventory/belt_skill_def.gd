## 160 补一（作者定）：随身技能 —— 「可堆叠的一次性技能」（烟雾弹、急救包……）。**不是道具**：不在道具库里，
## 所以不进仓库、不进图鉴、没有负重、不在敌人包里、不落地，搜索 / 掉落 / 商店货架的道具候选里也自然没有它。
## 只有四条来路：事件（`grant_belt`）、商店的「随身」一排（[member EconomyRules.belt_stock]）、局外科技（`tech_belt_grant`）、
## 角色能力与章节（`starting_belt`）。腰带（[BeltModule]）按 id 记几个，用一次少一个。
##
## 作者数据 `data/authoring/belt_skills/<id>.json` → `data/belt_skills/<id>.tres`。什么时候能用、用了做什么沿用 147 的 [BeltUse]；
## 图标约定在 `assets/belt_skills/<id>.png`（没有图就画名字的头一个字）
class_name BeltSkillDef
extends BeltUse

const ICON_DIR := "res://assets/belt_skills/"

@export var id: StringName = &""
@export var display_name: String = ""
## 别的语言的名字（语言码 → 名字）
@export var display_names: Dictionary = {}
@export var description: String = ""
## 221 F5: description in other languages, {"en": ...}
@export var descriptions: Dictionary = {}
## 商店「随身」那一排的标价（经济规则的价格倍数照乘）
@export var price: int = 20

static var _cache: Dictionary = {}


## 按 id 找定义（`data/belt_skills/<id>.tres`，读过就记住）；没有返回 null
static func find(skill_id: StringName) -> BeltSkillDef:
	if skill_id == &"":
		return null
	if _cache.has(skill_id):
		return _cache[skill_id]
	var path := ContentPaths.asset_file("belt_skills", String(skill_id))
	var def := load(path) as BeltSkillDef if ResourceLoader.exists(path) else null
	_cache[skill_id] = def
	return def


## 库里全部的 id（排好序）
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var dir := DirAccess.open(ContentPaths.dirs_of("belt_skills")[1])
	if dir == null:
		return out
	for f in dir.get_files():
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres"):
			out.append(StringName(name.get_basename()))
	out.sort()
	return out


## 图标（约定路径有图才有）
func icon() -> Texture2D:
	var path := ICON_DIR + String(id) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
