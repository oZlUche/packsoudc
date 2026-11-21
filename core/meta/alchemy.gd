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


## 补料：材料格补一件要几点尘 = 门槛稀有度、占一格的默认单价
static func slot_dust(slot: Dictionary) -> int:
	return ItemValue.BASE_PER_CELL[clampi(int(slot.get("min", 0)), 0, ItemValue.BASE_PER_CELL.size() - 1)]


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
