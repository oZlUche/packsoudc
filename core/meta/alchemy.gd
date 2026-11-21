## 354：炼金术 —— 魔法师协会信赖档加剧情《万物可分》开放（后勤「炼金」页）。纯逻辑，存盘由 [GameFlow] 做。
##
## - 分解：仓库里的素材（[member AlchemyRules.accept_tag]，不带 [member AlchemyRules.excluded_tags]、没锁）丢进去换万物之尘（[member MetaState.dust]）。
##   每件的尘值 = 它的基础价（[method ItemValue.of]，作者 2026-11-21「让尘的出率和价值挂钩」）；
##   一次丢的几件合起来 × (1 − 折损) 向下取整，每件至少 1。折损按协会声望档（[method AlchemyRules.loss_at]）。
## - 补料（第二批）：会打、且用真材料打造过的铁匠配方，缺的料按全额尘值补
class_name Alchemy
extends RefCounted

const ID := &"alchemy"
## 不能丢的原因（字表键 `alchemy.why_<原因>`）
const WHY_LOCKED := "locked"
const WHY_KIND := "kind"

static var _rules: AlchemyRules = null


static func load_rules() -> AlchemyRules:
	if _rules == null:
		_rules = ContentPaths.load_asset("base_rules", String(AlchemyRules.ID)) as AlchemyRules
		if _rules == null:
			_rules = AlchemyRules.new()
	return _rules


## 一件的尘值（= 基础价）
static func dust_value(def: ItemDef) -> int:
	return ItemValue.of(def)


## 这件能不能丢进去：空串 = 能
static func why_not(inst: ItemInstance, rules: AlchemyRules = null) -> String:
	var r := rules if rules != null else load_rules()
	if inst == null or inst.def == null or not inst.def.tags.has(r.accept_tag) or r.excluded_ids.has(inst.def.id) \
			or inst.def.tags.any(func(t: StringName) -> bool: return r.excluded_tags.has(t)):
		return WHY_KIND
	if inst.is_locked_by_player():
		return WHY_LOCKED
	return ""


static func can_dissolve(inst: ItemInstance, rules: AlchemyRules = null) -> bool:
	return why_not(inst, rules) == ""


## 协会现在几档（决定折损）
static func tier(meta: MetaState, rules: AlchemyRules = null) -> int:
	var r := rules if rules != null else load_rules()
	return Commissions.tier_of(meta.commissions if meta != null else null, Commissions.faction(r.faction))


## 现在的折损（0.4 = 四成）
static func loss(meta: MetaState, rules: AlchemyRules = null) -> float:
	var r := rules if rules != null else load_rules()
	return r.loss_at(tier(meta, r))


## 尘值合计 [param value]、[param count] 件，在折损 [param p_loss] 下得几点尘
static func yield_of(value: int, count: int, p_loss: float) -> int:
	if count <= 0:
		return 0
	return maxi(count, floori(float(value) * (1.0 - p_loss) + 0.0001))


## 仓库里这几件（uid）丢进去：{"count": 能丢的件数, "value": 尘值合计, "dust": 得几点尘, "funds": 卖掉能得多少金币}。不能丢的不算
static func preview(meta: MetaState, uids: Array, sell_ratio: float = 0.5, rules: AlchemyRules = null) -> Dictionary:
	var r := rules if rules != null else load_rules()
	var out := {"count": 0, "value": 0, "dust": 0, "funds": 0}
	if meta == null:
		return out
	for inst in _picks(meta, uids, r):
		out["count"] = int(out["count"]) + 1
		out["value"] = int(out["value"]) + dust_value(inst.def)
		out["funds"] = int(out["funds"]) + MetaState.sell_price_of(inst, sell_ratio)
	out["dust"] = yield_of(int(out["value"]), int(out["count"]), loss(meta, r))
	return out


## 分解：扣这几件、加尘（和 [method preview] 同一个数）。返回 {"count", "dust"}（一件都不能丢 = 0、什么也不动）
static func dissolve(meta: MetaState, uids: Array, rules: AlchemyRules = null) -> Dictionary:
	var r := rules if rules != null else load_rules()
	var got := preview(meta, uids, 0.5, r)
	if int(got["count"]) <= 0:
		return {"count": 0, "dust": 0}
	meta.warehouse.begin_batch()
	for inst in _picks(meta, uids, r):
		meta.warehouse.remove(inst.uid)
	meta.warehouse.end_batch()
	meta.dust += int(got["dust"])
	meta.changed.emit()
	return {"count": int(got["count"]), "dust": int(got["dust"])}


## 补料：点名的这样素材能不能用尘补（魔晶石、传说及以上不能）
static func input_dustable(def: ItemDef, rules: AlchemyRules = null) -> bool:
	var r := rules if rules != null else load_rules()
	return def != null and def.rarity < r.no_dust_rarity and not def.tags.any(func(t: StringName) -> bool: return r.no_dust_tags.has(t))


## 补料：这个材料格（[method SmithRecipeDef.slots] 的一项）能不能用尘补（魔晶石格、门槛传说及以上的不能）
static func slot_dustable(slot: Dictionary, rules: AlchemyRules = null) -> bool:
	var r := rules if rules != null else load_rules()
	var kind := String(slot.get("material", "")).get_slice(":", 0)
	return int(slot.get("min", 0)) < r.no_dust_rarity and not r.no_dust_tags.has(StringName(kind))


## 补料：材料格补一件要几点尘 = 这一格最便宜的合格品的基础价（报告 356 核对表：按「门槛一格的默认单价」收，
## 最便宜的合格品占两格时买来炼再补比直接买便宜，第二批改成这样）；道具库里一件合格的都没有就按门槛一格的默认单价
static func slot_dust(slot: Dictionary, items: ItemDatabase = null) -> int:
	var fallback: int = ItemValue.BASE_PER_CELL[clampi(int(slot.get("min", 0)), 0, ItemValue.BASE_PER_CELL.size() - 1)]
	if items == null:
		return fallback
	var key := "%s|%d" % [String(slot.get("material", "")), int(slot.get("min", 0))]
	if _slot_cache.has(key) and _slot_cache_db == items:
		return int(_slot_cache[key])
	if _slot_cache_db != items:
		_slot_cache.clear()
		_slot_cache_db = items
	var best := -1
	for id in items.ids(true):
		var d := items.get_def(id)
		if SmithRecipeDef.slot_fits(slot, d) and (best < 0 or ItemValue.of(d) < best):
			best = ItemValue.of(d)
	_slot_cache[key] = best if best > 0 else fallback
	return int(_slot_cache[key])


static var _slot_cache: Dictionary = {}
static var _slot_cache_db: ItemDatabase = null


## 补料：这张配方能不能用尘补 —— 会打（科技、铁匠铺级数）且用真材料打造过
static func dust_open(meta: MetaState, recipe: SmithRecipeDef) -> bool:
	return meta != null and recipe != null and meta.has_forged(recipe.id) and Smithy.knows(meta, recipe) and recipe.level <= Smithy.level(meta)


## 补料：这一项（键同 [method Smithy.have]：道具 id / `slot:<序号>`）补一件要几点尘；不能补 = -1
static func line_cost(recipe: SmithRecipeDef, key: String, items: ItemDatabase, rules: AlchemyRules = null) -> int:
	var r := rules if rules != null else load_rules()
	if key.begins_with("slot:"):
		var slots := recipe.slots()
		var i := int(key.substr(5))
		if i < 0 or i >= slots.size() or not slot_dustable(slots[i], r):
			return -1
		return slot_dust(slots[i], items)
	var d := items.get_def(StringName(key)) if items != null else null
	if d == null or not recipe.inputs.has(key) and not recipe.inputs.has(StringName(key)):
		return -1
	return dust_value(d) if input_dustable(d, r) else -1


## 补料：[param dust]（键 → 件数）一共要几点尘（不能补的项不算）
static func dust_cost(recipe: SmithRecipeDef, items: ItemDatabase, dust: Dictionary) -> int:
	var n := 0
	for key in dust:
		var c := line_cost(recipe, String(key), items)
		if c > 0:
			n += c * maxi(0, int(dust[key]))
	return n


## 补料能不能这样补：空串 = 能；否则是说给玩家听的那一句。[param got] = [method Smithy.have]。
## 只补缺的（每项最多补到够），没打造过、这项不能补、尘不够都不行
static func why_not_dust(meta: MetaState, recipe: SmithRecipeDef, items: ItemDatabase, dust: Dictionary, got: Dictionary) -> String:
	if dust.is_empty():
		return ""
	if not dust_open(meta, recipe):
		return UiText.t("smithy.dust_not_forged")
	var slots := recipe.slots()
	for key in dust:
		var k := String(key)
		var n := int(dust[key])
		if n <= 0:
			continue
		if line_cost(recipe, k, items) < 0:
			return UiText.t("smithy.dust_no")
		var need := int(slots[int(k.substr(5))]["count"]) if k.begins_with("slot:") else int(recipe.inputs.get(k, recipe.inputs.get(StringName(k), 0)))
		if n > need - int(got.get(k, 0)):
			return UiText.t("smithy.dust_no")
	if dust_cost(recipe, items, dust) > meta.dust:
		return UiText.t("smithy.no_dust")
	return ""


static func _picks(meta: MetaState, uids: Array, r: AlchemyRules) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	var seen := {}
	for raw in uids:
		var uid := int(raw)
		if seen.has(uid):
			continue
		seen[uid] = true
		var inst := meta.warehouse.get_item(uid)
		if inst != null and can_dissolve(inst, r):
			out.append(inst)
	return out
