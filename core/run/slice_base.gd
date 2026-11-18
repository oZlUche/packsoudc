## 统一教程 D2（方案 docs/plans/2026-11-18-unified-tutorial-and-base-return.md §10）：切片基地开放哪些 ——
## 集市只卖清单里的货、铁匠铺只列清单里的配方、科技只开清单里的几项（`data/manifests/slice_base.json`）。
## 都走正式版同一套服务，只是可选的少；正式版不受影响。`tutorial_item_ids` = 教程固定奖励带进仓库的东西（教学来源清单）
class_name SliceBase
extends RefCounted

const PATH := "res://data/manifests/slice_base.json"

static var _manifest: Dictionary = {}


static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_manifest = d if d is Dictionary else {}
	return _manifest


static func ids(key: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var raw: Variant = manifest().get(key, [])
	if raw is Array:
		for x in raw:
			out.append(StringName(String(x)))
	return out


## 这一档能用的科技（正式版原样）
static func techs(all: Array[TechDef], p_profile: StringName) -> Array[TechDef]:
	if p_profile != SliceProfile.SLICE:
		return all
	var keep := ids("tech_ids")
	return all.filter(func(t: TechDef) -> bool: return keep.has(t.id))


## 这一档铁匠铺列的配方（正式版原样）
static func recipes(all: Array[SmithRecipeDef], p_profile: StringName) -> Array[SmithRecipeDef]:
	if p_profile != SliceProfile.SLICE:
		return all
	var keep := ids("smith_recipe_ids")
	return all.filter(func(r: SmithRecipeDef) -> bool: return keep.has(r.id))


## 这一档集市的规矩：切片是一份只卖清单里的货的副本（[member MarketRules.allowed_ids]），正式版原样
static func market_rules(rules: MarketRules, p_profile: StringName) -> MarketRules:
	if p_profile != SliceProfile.SLICE or rules == null:
		return rules
	var copy := rules.duplicate() as MarketRules
	copy.allowed_ids = ids("market_item_ids")
	return copy
