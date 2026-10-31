## 251：基地集市（作者 2026-10-24：「出售直接用钱购买的道具和低稀有度素材（白到蓝）」）—— 262 起默认 1 级，科技「高级货物」再升（[TechFacility]）。
## 270（作者 2026-10-31 12:01 / 12:58）分摊位：
## - 五个**固定摊**（[StallDef]）：货单 = 库里带该摊标签、稀有度到本级上限的全部道具（[method catalogue]），买了不减；
## - **散货摊**（原来的木凉棚）：货位按级 4 / 6 / 8，只进战斗道具（[member MarketRules.battle_tags]），绿起按递减权重抽；
##   每局回来免费换一批，在家能花钱【换货】（[method refresh]），锁着的格（[method toggle_lock]）换货不动，买走就解锁。
## 散货摊的货存在 [member MetaState.market_stock]（每格 {"id", "sold", "locked"}）与 [member MetaState.market_seed]，级数是派生值（120）。
## 买：钱走 [method MetaState.spend_funds]，东西进仓库按页序第一处空位（包进包架）；仓库满了不卖。纯逻辑，存盘由 [GameFlow] 做
class_name Market
extends RefCounted

const ID := &"market"
## 散货摊的摊位 id
const LOOSE := &"loose"

static var _rules: MarketRules = null
static var _stalls: Array[StallDef] = []


## 资产里的集市规矩（没导入时用默认）
static func load_rules() -> MarketRules:
	if _rules == null:
		_rules = ContentPaths.load_asset("base_rules", String(ID)) as MarketRules
		if _rules == null:
			_rules = MarketRules.new()
	return _rules


## 270：全部摊位，按 [member StallDef.order]（左列从上到下）；没导入时只有一个散货摊
static func stalls() -> Array[StallDef]:
	if _stalls.is_empty():
		for res in ContentPaths.load_resources(ContentPaths.MARKET_STALLS):
			if res is StallDef:
				_stalls.append(res)
		_stalls.sort_custom(func(a: StallDef, b: StallDef) -> bool: return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
		if not _stalls.any(func(st: StallDef) -> bool: return not st.fixed):
			var loose := StallDef.new()
			loose.id = LOOSE
			loose.display_name = "散货摊"
			loose.fixed = false
			loose.order = 1 << 20
			_stalls.append(loose)
	return _stalls


static func stall(id: StringName) -> StallDef:
	for st in stalls():
		if st.id == id:
			return st
	return null


static func level(meta: MetaState) -> int:
	return meta.facility_level(ID) if meta != null else 0


## 集市卖不卖这一件（包、金银、贵重品、铸牌、封存件、信物、排除表里的都不卖）
static func _sellable(rules: MarketRules, d: ItemDef) -> bool:
	if d == null or d.is_bag or d.is_bullion() or d.is_valuable() or d.is_token() or d.is_sealed() or d.has_faith():
		return false
	return not d.tags.any(func(t: StringName) -> bool: return rules.excluded_tags.has(t)) and not rules.excluded_ids.has(d.id)


## 270：固定摊 [param st] 在 [param lv] 级的货单 —— 带它的标签、稀有度 ≤ 本级上限，按稀有度、价钱、id 排；
## 不到 [member MarketRules.stall_min_listed] 件从更高档按同样的顺序补到那么多件（待定 1 过渡规则）。散货摊 / 没有集市给空
static func catalogue(rules: MarketRules, items: ItemDatabase, st: StallDef, lv: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if rules == null or items == null or st == null or not st.fixed or lv <= 0:
		return out
	var cap := rules.rarity_cap_at(lv)
	var listed: Array[ItemDef] = []
	var above: Array[ItemDef] = []
	for id in items.ids():
		var d := items.get_def(id)
		if not _sellable(rules, d) or st.excluded_ids.has(d.id) or not d.tags.any(func(t: StringName) -> bool: return st.tags.has(t)):
			continue
		(listed if d.rarity <= cap else above).append(d)
	var by := func(a: ItemDef, b: ItemDef) -> bool:
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		var pa := price_of(rules, a)
		var pb := price_of(rules, b)
		return pa < pb if pa != pb else String(a.id) < String(b.id)
	listed.sort_custom(by)
	above.sort_custom(by)
	while listed.size() < rules.stall_min_listed and not above.is_empty():
		listed.append(above.pop_front())
	for d in listed:
		out.append(d.id)
	return out


## 270：散货摊能进的货，按 id 升序（抽出来才可复现）：战斗道具、稀有度有权重（绿起，不受级数上限）
static func loose_candidates(rules: MarketRules, items: ItemDatabase) -> Array[StringName]:
	var out: Array[StringName] = []
	if rules == null or items == null:
		return out
	for id in items.ids():
		var d := items.get_def(id)
		if _sellable(rules, d) and rules.loose_weight(d.rarity) > 0.0 and d.tags.any(func(t: StringName) -> bool: return rules.battle_tags.has(t)):
			out.append(id)
	out.sort()
	return out


## 散货摊重新上货（换种子）：锁着的格原样留在原位，其余按稀有度权重重抽、不重复（也不和锁着的重）；
## 到 [member MarketRules.bag_slot_from_level] 级最后一格换成一只空包（锁着的话照留）。没有集市就清空
static func restock(meta: MetaState, rules: MarketRules, items: ItemDatabase, pool: BagPool = null) -> void:
	if meta == null:
		return
	var old := meta.market_stock
	meta.market_stock = []
	var lv := level(meta)
	if rules == null or items == null or lv <= 0:
		meta.changed.emit()
		return
	var n := rules.slots_at(lv)
	var kept := {}
	for i in mini(old.size(), n):
		if bool(old[i].get("locked", false)) and not bool(old[i].get("sold", false)):
			kept[i] = old[i]
	meta.market_seed += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("market:%d" % meta.market_seed)
	var cands := loose_candidates(rules, items)
	for i in kept:
		cands.erase(StringName(String(kept[i]["id"])))
	var bag := _draw_bag(rules, items, pool, lv, rng) if not kept.has(n - 1) else &""
	for i in n:
		if kept.has(i):
			meta.market_stock.append(kept[i])
			continue
		var id: StringName = bag if i == n - 1 and bag != &"" else _draw(cands, rules, items, rng)
		if id != &"":
			meta.market_stock.append({"id": String(id), "sold": false, "locked": false})
	meta.changed.emit()


## 有集市、却一格货都没有（老档、开发区改了级数）：上一次货
static func ensure(meta: MetaState, rules: MarketRules, items: ItemDatabase, pool: BagPool = null) -> bool:
	if meta == null or level(meta) <= 0 or not meta.market_stock.is_empty():
		return false
	restock(meta, rules, items, pool)
	return true


## 270：先按 [member MarketRules.loose_rarity_weights] 抽一档稀有度（这一档还有货的才算），再在这一档里等概率抽一件并拿掉；抽空了给空
static func _draw(from: Array, rules: MarketRules, items: ItemDatabase, rng: RandomNumberGenerator) -> StringName:
	if from.is_empty():
		return &""
	var tiers := {}
	for j in from.size():
		var r := items.get_def(from[j]).rarity
		if not tiers.has(r):
			tiers[r] = []
		(tiers[r] as Array).append(j)
	var keys := tiers.keys()
	keys.sort()
	var total := 0.0
	for r in keys:
		total += rules.loose_weight(r)
	var tier: Array = tiers[keys[keys.size() - 1]]
	if total > 0.0:
		var x := rng.randf() * total
		for r in keys:
			x -= rules.loose_weight(r)
			if x <= 0.0:
				tier = tiers[r]
				break
	var k: int = tier[rng.randi_range(0, tier.size() - 1)]
	var id: StringName = from[k]
	from.remove_at(k)
	return id


## 270：这次换货要多少钱（40 + 20 × 在家已换的次数）
static func refresh_cost(meta: MetaState, rules: MarketRules) -> int:
	return rules.refresh_cost + rules.refresh_step * (meta.market_refreshes if meta != null else 0)


## 能不能换货：空串 = 行；否则是说给玩家听的那一句
static func can_refresh(meta: MetaState, rules: MarketRules) -> String:
	if meta == null or rules == null or level(meta) <= 0:
		return UiText.t("market.empty")
	if meta.funds < refresh_cost(meta, rules):
		return UiText.t("market.refresh_poor")
	return ""


## 花钱换货：扣钱、次数加一、没锁的格重抽。不能换返回假，钱和货都不动
static func refresh(meta: MetaState, rules: MarketRules, items: ItemDatabase, pool: BagPool = null) -> bool:
	if can_refresh(meta, rules) != "":
		return false
	meta.spend_funds(refresh_cost(meta, rules))
	meta.market_refreshes += 1
	restock(meta, rules, items, pool)
	return true


static func is_locked(meta: MetaState, i: int) -> bool:
	return meta != null and i >= 0 and i < meta.market_stock.size() and bool(meta.market_stock[i].get("locked", false))


## 锁上 / 解开散货摊第 i 格（卖掉了的不能锁）；返回现在锁没锁
static func toggle_lock(meta: MetaState, i: int) -> bool:
	if meta == null or i < 0 or i >= meta.market_stock.size() or is_sold(meta, i):
		return false
	meta.market_stock[i]["locked"] = not is_locked(meta, i)
	meta.changed.emit()
	return is_locked(meta, i)


static func _draw_bag(rules: MarketRules, items: ItemDatabase, pool: BagPool, lv: int, rng: RandomNumberGenerator) -> StringName:
	if pool == null or rules.bag_slot_from_level <= 0 or lv < rules.bag_slot_from_level:
		return &""
	var cands := pool.candidates(items, rules.rarity_cap_at(lv))
	var total := 0.0
	for e in cands:
		total += e.weight
	if total <= 0.0:
		return &""
	var x := rng.randf() * total
	for e in cands:
		x -= e.weight
		if x <= 0.0:
			return e.bag
	return cands[cands.size() - 1].bag


static func price_of(rules: MarketRules, def: ItemDef) -> int:
	if def == null:
		return 0
	return maxi(1, roundi(float(ItemValue.of(def)) * (rules.price_mult if rules != null else 1.0)))


## 第 i 格的定义；没有 / 道具库里没有 null
static func def_at(meta: MetaState, items: ItemDatabase, i: int) -> ItemDef:
	if meta == null or items == null or i < 0 or i >= meta.market_stock.size():
		return null
	return items.get_def(StringName(String(meta.market_stock[i].get("id", ""))))


static func is_sold(meta: MetaState, i: int) -> bool:
	return i >= 0 and i < meta.market_stock.size() and bool(meta.market_stock[i].get("sold", false))


## 第 i 格能不能买：空串 = 行；否则是说给玩家听的那一句（卖掉了 / 钱不够 / 仓库放不下）
static func can_buy(meta: MetaState, rules: MarketRules, items: ItemDatabase, i: int) -> String:
	var def := def_at(meta, items, i)
	if def == null or is_sold(meta, i):
		return UiText.t("market.sold_out")
	return _can_take(meta, rules, def)


## 买散货摊第 i 格：东西进仓库（包进包架）、扣钱、格子标卖掉（270：也解锁）。不能买返回 null，钱与仓库都不动
static func buy(meta: MetaState, rules: MarketRules, items: ItemDatabase, i: int) -> ItemInstance:
	if can_buy(meta, rules, items, i) != "":
		return null
	var inst := _take(meta, rules, def_at(meta, items, i))
	if inst != null:
		meta.market_stock[i]["sold"] = true
		meta.market_stock[i]["locked"] = false
		meta.changed.emit()
	return inst


## 270：固定摊这一件能不能买：空串 = 行；不在本级货单里 / 钱不够 / 仓库放不下说一句
static func can_buy_listed(meta: MetaState, rules: MarketRules, items: ItemDatabase, st: StallDef, id: StringName) -> String:
	var def := items.get_def(id) if items != null else null
	if def == null or not catalogue(rules, items, st, level(meta)).has(id):
		return UiText.t("market.sold_out")
	return _can_take(meta, rules, def)


## 270：买固定摊的一件 —— 货单不减；进仓库（包进包架）、扣钱。不能买返回 null
static func buy_listed(meta: MetaState, rules: MarketRules, items: ItemDatabase, st: StallDef, id: StringName) -> ItemInstance:
	if can_buy_listed(meta, rules, items, st, id) != "":
		return null
	return _take(meta, rules, items.get_def(id))


static func _can_take(meta: MetaState, rules: MarketRules, def: ItemDef) -> String:
	if meta.funds < price_of(rules, def):
		return UiText.t("market.no_funds")
	if not (BagRack.holds(def) or meta.warehouse.can_admit(def)):
		return UiText.t("market.full")
	return ""


## 一件放进仓库（包进包架）、扣钱；放不下返回 null、钱不动
static func _take(meta: MetaState, rules: MarketRules, def: ItemDef) -> ItemInstance:
	var inst := ItemInstance.create(def, 0)
	inst.uid = meta.allocate_uid()
	var placed := meta.rack.insert(inst) if BagRack.holds(def) else meta.warehouse.try_add(inst, true)
	if not placed:
		return null
	meta.spend_funds(price_of(rules, def))
	meta.changed.emit()
	return inst


## 说明面板：到第 k 级集市是什么样（270：固定摊卖到哪一档、散货摊几个货位）
static func describe_level(rules: MarketRules, lv: int) -> String:
	if rules == null or lv <= 0:
		return ""
	var text := UiText.t("market.level_line") % [UiText.t("tip.rarity_%d" % clampi(rules.rarity_cap_at(lv), 0, 4)), rules.slots_at(lv)]
	if rules.bag_slot_from_level > 0 and lv >= rules.bag_slot_from_level:
		text += UiText.t("market.level_bag")
	return text
