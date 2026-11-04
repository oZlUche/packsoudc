## 279 §二.2 / §四.3：休息点的砧 —— 武器槽放上一把、材料槽放一件某类材料，配得上 [SmithRecipeDef] 里的升级配方（吃这一把 + `material_inputs`）
## 就能锤一下：两件消耗，出一把高一档的；材料比要求高几档，出件就几档品质（补充二，和原件取较高）。每个休息点免费一次（记在节点内容里，跟存档）。
## 基地铁匠铺走 [Smithy]，同一批配方当普通配方打。纯逻辑
class_name Anvil
extends RefCounted

const USED_KEY := "used_anvil"

static var _all: Array[SmithRecipeDef] = []


## 资产里的全部铁匠铺配方（第一次用时读，之后复用；道具说明「可升为」那一行用它）
static func recipes() -> Array[SmithRecipeDef]:
	if _all.is_empty():
		_all = SmithRecipeDef.load_all()
	return _all


## 一把武器在砧上能升成的每一张配方（吃这一件、外加一类材料），按配方 id 排
static func upgrades_for(weapon: ItemDef, pool: Array) -> Array[SmithRecipeDef]:
	var out: Array[SmithRecipeDef] = []
	if weapon == null:
		return out
	for r in pool:
		var def := r as SmithRecipeDef
		if def == null or def.material_inputs.is_empty() or def.inputs.size() != 1:
			continue
		var key: Variant = def.inputs.keys()[0]
		if StringName(String(key)) == weapon.id and int(def.inputs[key]) == 1:
			out.append(def)
	out.sort_custom(func(a: SmithRecipeDef, b: SmithRecipeDef) -> bool: return String(a.id) < String(b.id))
	return out


## 这把 + 这件材料配上的那张（材质对、稀有度够；几张都配得上取第一张）；配不上 = null
static func recipe_for(weapon: ItemDef, material: ItemDef, pool: Array) -> SmithRecipeDef:
	if material == null:
		return null
	for r in upgrades_for(weapon, pool):
		for m in r.material_inputs:
			if r.material_fits(String(m), material):
				return r
	return null


## 补充二：出件的品质 —— 材料比要求高几档，和原件的品质取较高（不累加），上限 [constant ItemInstance.QUALITY_MAX]
static func quality_of(recipe: SmithRecipeDef, material: ItemDef, weapon: ItemInstance) -> int:
	var q := weapon.quality() if weapon != null else 0
	if recipe != null and material != null:
		for m in recipe.material_inputs:
			if recipe.material_fits(String(m), material):
				q = maxi(q, material.rarity - int(recipe.material_inputs[m]))
	return clampi(q, 0, ItemInstance.QUALITY_MAX)


## 锤下去会出的那一件（新建、带品质、不在任何容器里；预览和真锤都用它）；配不上 = null
static func result(weapon: ItemInstance, material: ItemInstance, pool: Array, items: ItemDatabase) -> ItemInstance:
	if weapon == null or material == null or items == null:
		return null
	var r := recipe_for(weapon.def, material.def, pool)
	var out_def := items.get_def(r.output) if r != null else null
	if out_def == null:
		return null
	var out := ItemInstance.create(out_def, 0)
	out.set_quality(quality_of(r, material.def, weapon))
	return out


## 这座休息点的砧锤过了
static func used(node: MapNode) -> bool:
	return node != null and bool(node.content.get(USED_KEY, false))


static func use(node: MapNode) -> void:
	if node != null:
		node.content[USED_KEY] = true
