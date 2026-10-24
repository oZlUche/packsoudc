## 251：基地集市（作者 2026-10-24：「出售直接用钱购买的道具和低稀有度素材（白到蓝）」）—— 科技「集市」点出来、按级长大（[TechFacility]）。
##
## 卖消耗品与素材（[MarketRules]）；**一局一换货**：每次从一局回到基地重新上货，升级集市那一刻也重新上货，基地里不能花钱刷新。
## 货存在 [member MetaState.market_stock]（每格 {"id", "sold"}）与 [member MetaState.market_seed]，级数是派生值（120）。
## 买：钱走 [method MetaState.spend_funds]，东西进仓库按页序第一处空位（包进包架）；仓库满了不卖。纯逻辑，存盘由 [GameFlow] 做
class_name Market
extends RefCounted

const ID := &"market"

static var _rules: MarketRules = null


## 资产里的集市规矩（没导入时用默认）
static func load_rules() -> MarketRules:
	if _rules == null:
		_rules = ContentPaths.load_asset("base_rules", String(ID)) as MarketRules
		if _rules == null:
			_rules = MarketRules.new()
	return _rules


static func level(meta: MetaState) -> int:
	return meta.facility_level(ID) if meta != null else 0


## 能上架的：{"material": 素材 id, "other": 消耗品 id}，各自按 id 升序（抽出来才可复现）。到 [param lv] 级的稀有度上限为止
static func candidates(rules: MarketRules, items: ItemDatabase, lv: int) -> Dictionary:
	var out := {"material": [] as Array[StringName], "other": [] as Array[StringName]}
	if rules == null or items == null or lv <= 0:
		return out
	for id in items.ids():
		var d := items.get_def(id)
		if d == null or d.is_bag or d.is_bullion() or d.is_valuable() or d.is_token() or d.is_sealed() or d.has_faith():
			continue
		if d.tags.any(func(t: StringName) -> bool: return rules.excluded_tags.has(t)):
			continue
		if not d.tags.any(func(t: StringName) -> bool: return rules.allowed_tags.has(t)):
			continue
		if d.tags.has(&"material"):
			if d.rarity <= rules.rarity_cap_at(lv):
				(out["material"] as Array).append(id)
		elif d.rarity <= rules.consumable_cap_at(lv):
			(out["other"] as Array).append(id)
	(out["material"] as Array).sort()
	(out["other"] as Array).sort()
	return out


## 重新上货（换种子）：素材先抽满 [member MarketRules.material_share]，剩下抽消耗品（哪边抽完了另一边补），按稀有度权重、不重复；
## 到 [member MarketRules.bag_slot_from_level] 级最后一格换成一只空包。没有集市就清空
static func restock(meta: MetaState, rules: MarketRules, items: ItemDatabase, pool: BagPool = null) -> void:
	if meta == null:
		return
	meta.market_stock = []
	var lv := level(meta)
	if rules == null or items == null or lv <= 0:
		meta.changed.emit()
		return
	meta.market_seed += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("market:%d" % meta.market_seed)
	var cands := candidates(rules, items, lv)
	var mats: Array = cands["material"]
	var others: Array = cands["other"]
	var n := rules.slots_at(lv)
	var want_mats := mini(n, ceili(float(n) * clampf(rules.material_share, 0.0, 1.0)))
	var ids: Array[StringName] = []
	for i in n:
		var from := mats if (i < want_mats and not mats.is_empty()) or others.is_empty() else others
		if from.is_empty():
			break
		ids.append(_draw(from, rules, items, rng))
	var bag := _draw_bag(rules, items, pool, lv, rng)
	if bag != &"" and n > 0:
		if ids.size() >= n:
			ids[ids.size() - 1] = bag
		else:
			ids.append(bag)
	for id in ids:
		meta.market_stock.append({"id": String(id), "sold": false})
	meta.changed.emit()


## 有集市、却一格货都没有（老档、开发区改了级数）：上一次货
static func ensure(meta: MetaState, rules: MarketRules, items: ItemDatabase, pool: BagPool = null) -> bool:
	if meta == null or level(meta) <= 0 or not meta.market_stock.is_empty():
		return false
	restock(meta, rules, items, pool)
	return true


## 按稀有度权重从 [param from] 里抽一个并拿掉
static func _draw(from: Array, rules: MarketRules, items: ItemDatabase, rng: RandomNumberGenerator) -> StringName:
	var total := 0.0
	for id in from:
		total += rules.rarity_weight(items.get_def(id).rarity)
	var k := from.size() - 1
	if total > 0.0:
		var x := rng.randf() * total
		for j in from.size():
			x -= rules.rarity_weight(items.get_def(from[j]).rarity)
			if x <= 0.0:
				k = j
				break
	else:
		k = rng.randi_range(0, from.size() - 1)
	var id: StringName = from[k]
	from.remove_at(k)
	return id


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
	if meta.funds < price_of(rules, def):
		return UiText.t("market.no_funds")
	if not (BagRack.holds(def) or meta.warehouse.can_admit(def)):
		return UiText.t("market.full")
	return ""


## 买第 i 格：东西进仓库（包进包架）、扣钱、格子标卖掉。不能买返回 null，钱与仓库都不动
static func buy(meta: MetaState, rules: MarketRules, items: ItemDatabase, i: int) -> ItemInstance:
	if can_buy(meta, rules, items, i) != "":
		return null
	var def := def_at(meta, items, i)
	var inst := ItemInstance.create(def, 0)
	inst.uid = meta.allocate_uid()
	var placed := meta.rack.insert(inst) if BagRack.holds(def) else meta.warehouse.try_add(inst, true)
	if not placed:
		return null
	meta.spend_funds(price_of(rules, def))
	meta.market_stock[i]["sold"] = true
	meta.changed.emit()
	return inst


## 说明面板：到第 k 级集市是什么样
static func describe_level(rules: MarketRules, lv: int) -> String:
	if rules == null or lv <= 0:
		return ""
	var text := UiText.t("market.level_line") % [rules.slots_at(lv), UiText.t("tip.rarity_%d" % clampi(rules.rarity_cap_at(lv), 0, 4)),
		UiText.t("tip.rarity_%d" % clampi(rules.consumable_cap_at(lv), 0, 4))]
	if rules.bag_slot_from_level > 0 and lv >= rules.bag_slot_from_level:
		text += UiText.t("market.level_bag")
	return text
