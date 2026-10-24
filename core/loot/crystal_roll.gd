## 246 补充二：掉落里的魔晶石「滚品」—— 搜索、敌人身上滚到一件魔晶石，先在同一元素家族（[member ItemDef.crystal_family]）的三品里
## 等概率换一件，再把剩余次数在 1～满之间等概率抽（不出碎裂，满的也算）。没有家族的（清明、琥珀）不换品、照样抽次数；
## 赐福版不换品（换了就丢了赐福）。商店卖的是新货（满的），不走这里。
## 随机数都由调用方给：要可复现的地方各自另起一条（由主随机数派生、不消耗它），加这一步不改原来抽到什么
class_name CrystalRoll
extends RefCounted

const TAG := &"crystal"
## 敌人内容条目里记剩余次数的键（[method EnemyPlacer.roll_crystals]）
const CHARGES := "charges"


## 这件掉下来要不要滚：带 `crystal` 标签又有耐久的（果果之心没有耐久，永不消耗，不滚）
static func is_rolled(def: ItemDef) -> bool:
	return def != null and def.wear != null and def.tags.has(TAG)


## 同家族的几件（不含封存、赐福版），按 id 排好 —— 等概率抽，结果才可复现
static func family(items: ItemDatabase, fam: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if items == null or fam == &"":
		return out
	for id in items.ids_where(func(d: ItemDef) -> bool: return d.crystal_family == fam and not d.is_blessed() and not d.is_sealed()):
		out.append(StringName(String(id)))
	Ids.sort(out)
	return out


## 换品：[param def] 有家族就在家族里等概率换一件（可能换回自己），没有家族或是赐福版原样返回。
## [param rarity_cap] ≥ 0 时只在不超过它的几品里换（敌人身上照档位的稀有度上限）；一件都没有就不换
static func reroll_id(def: ItemDef, items: ItemDatabase, rng: RandomNumberGenerator, rarity_cap: int = -1) -> StringName:
	if not is_rolled(def) or def.crystal_family == &"" or def.is_blessed():
		return def.id if def != null else &""
	var fam: Array[StringName] = []
	for id in family(items, def.crystal_family):
		if rarity_cap < 0 or items.get_def(id).rarity <= rarity_cap:
			fam.append(id)
	if fam.is_empty():
		return def.id
	return fam[rng.randi_range(0, fam.size() - 1)]


## 一批 id 逐个换品（不是魔晶石的原样），返回新数组
static func reroll_ids(ids: Array[StringName], items: ItemDatabase, rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in ids:
		var d := items.get_def(id) if items != null else null
		out.append(reroll_id(d, items, rng) if is_rolled(d) else id)
	return out


## 剩余次数：1～满等概率
static func roll_charges(def: ItemDef, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, maxi(1, def.wear.max_charges))


## 一批实例里的魔晶石逐个抽剩余次数（记在 [member ItemInstance.state]）
static func roll_charges_of(insts: Array, rng: RandomNumberGenerator) -> void:
	for raw in insts:
		var inst := raw as ItemInstance
		if inst != null and is_rolled(inst.def):
			inst.state[WearProfile.CHARGES_KEY] = roll_charges(inst.def, rng)


## 照内容条目 [param entry] 恢复剩余次数（[constant CHARGES]）；没记的不动（满的）
static func restore(inst: ItemInstance, entry: Dictionary) -> void:
	if inst != null and inst.def != null and inst.def.wear != null and entry.has(CHARGES):
		inst.state[WearProfile.CHARGES_KEY] = clampi(int(entry[CHARGES]), 0, inst.def.wear.max_charges)
