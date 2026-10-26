## 赐福（095，作者定）：普通道具「变成」信仰道具的那一套 —— 派生赐福版、战利品 / 搜索替代、包内转化、挑一件赐福。
## 全是静态函数，不持状态；概率与模板都在数据里（[FaithDef.blessings / convert_chance]、[DropRule.bless_chance]、[SearchRules.bless_chance]）
class_name Blessings
extends RefCounted


static func variant_id(base_id: StringName, faith_id: StringName) -> StringName:
	return StringName("%s_%s" % [base_id, faith_id])


## 这件能不能被赐福：不是包、本来不是信仰道具、不是封存 / 特殊、不是已经赐福的
static func eligible(def: ItemDef) -> bool:
	return def != null and not def.is_bag and not def.has_faith() and not def.is_sealed() and not def.is_keepsake() and not def.is_blessed() and not def.is_signature()     # 256：随身之物不赐福


## 这位神对这件用哪条模板（写了 items 的优先）；没有 null
static func rule_for(faith: FaithDef, def: ItemDef) -> Blessing:
	if faith == null or not eligible(def):
		return null
	var fallback: Blessing = null
	for b in faith.blessings:
		var rule := b as Blessing
		if rule == null or not rule.matches(def):
			continue
		if not rule.items.is_empty():
			return rule
		if fallback == null:
			fallback = rule
	return fallback


## 派生赐福版
static func derive(faith: FaithDef, def: ItemDef, rule: Blessing) -> ItemDef:
	var out := def.duplicate(true) as ItemDef
	out.id = variant_id(def.id, faith.id)
	out.display_name = rule.name_prefix + def.display_name
	var names := def.display_names.duplicate()
	if names.has("en"):
		names["en"] = rule.name_prefix_en + String(names["en"])
	out.display_names = names
	var tags: Array[StringName] = def.tags.duplicate()
	if not tags.has(faith.tag()):     # 250：只挂神的标签（faith / blessed 删了；赐福与否看 blessed_of）
		tags.append(faith.tag())
	for t in rule.add_tags:
		if not tags.has(t):
			tags.append(t)
	out.tags = tags
	out.faith_bonuses = rule.faith_bonuses.duplicate()
	out.rarity = clampi(def.rarity + rule.rarity_up, 0, 5)
	if def.value > 0:
		out.value = roundi(float(def.value) * rule.value_mult)
	out.blessed_of = def.id
	return out


## 给道具库里每一件能赐福的、每位有模板的神派生一份。返回派生了几件
static func derive_all(db: ItemDatabase, faiths: Dictionary) -> int:
	if db == null or faiths.is_empty():
		return 0
	var n := 0
	var bases: Array = db.all_ids().duplicate()
	var fids: Array = faiths.keys()
	fids.sort()
	for id in bases:
		var def := db.get_def(id)
		for fid in fids:
			var faith := faiths[fid] as FaithDef
			var rule := rule_for(faith, def)
			if rule == null or db.get_def(variant_id(def.id, faith.id)) != null:
				continue
			if db.register(derive(faith, def, rule)):
				n += 1
	return n


## 这件的某位神的赐福版；没有 null
static func variant_of(db: ItemDatabase, base_id: StringName, faith_id: StringName) -> ItemDef:
	return db.get_def(variant_id(base_id, faith_id)) if db != null and faith_id != &"" else null


## 哪些神有这件的赐福版
static func faiths_with_variant(db: ItemDatabase, base_id: StringName, faith_ids: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for fid in faith_ids:
		if variant_of(db, base_id, StringName(String(fid))) != null:
			out.append(StringName(String(fid)))
	out.sort()
	return out


## 战利品 / 搜索替代：每件按概率换成赐福版 —— 激活了信仰只换成那位神的（chance_active），没激活随机一位（chance_idle）
static func substitute(ids: Array[StringName], db: ItemDatabase, active_faith: StringName, faith_ids: Array,
		chance_idle: float, chance_active: float, rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in ids:
		var def := db.get_def(id) if db != null else null
		var replaced := id
		if def != null and eligible(def) and rng != null:
			if active_faith != &"":
				if variant_of(db, id, active_faith) != null and rng.randf() < chance_active:
					replaced = variant_id(id, active_faith)
			else:
				var cands := faiths_with_variant(db, id, faith_ids)
				if not cands.is_empty() and rng.randf() < chance_idle:
					replaced = variant_id(id, cands[rng.randi_range(0, cands.size() - 1)])
		out.append(replaced)
	return out


## 就地把一件实例换成赐福版（形状一样，位置 / 朝向 / uid 不动）。返回换成的定义；换不了 null
static func bless_instance(inst: ItemInstance, db: ItemDatabase, faith_id: StringName) -> ItemDef:
	if inst == null or inst.def == null:
		return null
	var v := variant_of(db, inst.def.id, faith_id)
	if v == null:
		return null
	inst.def = v
	return v


## 容器里能被这位神赐福的、最值钱的一件；没有 null
static func best_candidate(container: ItemContainer, db: ItemDatabase, faith_id: StringName) -> ItemInstance:
	var best: ItemInstance = null
	if container == null:
		return null
	for raw in container.items():
		var inst := raw as ItemInstance
		if inst == null or variant_of(db, inst.def.id, faith_id) == null:
			continue
		if best == null or ItemValue.of(inst.def) > ItemValue.of(best.def) or (ItemValue.of(inst.def) == ItemValue.of(best.def) and inst.uid < best.uid):
			best = inst
	return best
