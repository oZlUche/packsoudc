## 251：基地铁匠铺（作者 2026-10-24：「有特定配方，可以通过素材和金钱合成武器、防具」）—— 262 起默认 1 级、科技「高级配方」再升，级数 = 能打哪一档配方（[member SmithRecipeDef.level]）。
##
## 只吃**仓库**里的素材（不碰保险箱、包架），锁住的（230）不算有；产物进仓库按页序第一处空位，放不下不打（不扣素材、不扣钱）。
## 扣素材按仓库顺序先扣前面的。产物是局外号段的新实例，图鉴点亮。纯逻辑，存盘由 [GameFlow] 做
class_name Smithy
extends RefCounted

const ID := &"smithy"


static func level(meta: MetaState) -> int:
	return meta.facility_level(ID) if meta != null else 0


## 252：配方要的科技点到了没有（不要科技的总是会）
static func knows(meta: MetaState, recipe: SmithRecipeDef) -> bool:
	return recipe.tech == &"" or TechService.level(meta, recipe.tech) >= recipe.tech_level


## 252：「要先点出「秘银冶炼」」—— 科技一级的不写级数
static func need_tech_text(recipe: SmithRecipeDef) -> String:
	var path := ContentPaths.asset_file("techs", String(recipe.tech))
	var def := ResourceLoader.load(path) as TechDef if ResourceLoader.exists(path) else null
	var name := Names.of(def) if def != null else String(recipe.tech)
	if recipe.tech_level <= 1:
		return UiText.t("smithy.need_tech") % name
	return UiText.t("smithy.need_tech_level") % [name, recipe.tech_level]


## 仓库里每样素材有几件（锁住的不算）：道具 id 字符串 → 件数，只列配方要的；
## 材料格（[method SmithRecipeDef.slots]）记在 `"slot:<序号>"` 下：这一格分得到几件（不超过要的件数）
static func have(meta: MetaState, recipe: SmithRecipeDef) -> Dictionary:
	var out := {}
	if recipe == null:
		return out
	for key in recipe.inputs:
		out[String(key)] = 0
	var picks := slot_picks(meta, recipe)
	for i in picks.size():
		out[SLOT_KEY % i] = (picks[i] as Array).size()
	if meta == null:
		return out
	for inst in meta.warehouse.items():
		var it := inst as ItemInstance
		var key := String(it.def.id)
		if out.has(key) and not it.is_locked_by_player():
			out[key] = int(out[key]) + 1
	return out


const SLOT_KEY := "slot:%d"


## 310（方案 §5.1）：每个材料格会扣仓库里哪几件：序号 → `Array[ItemInstance]`（分不够就少几件）。
## 先把要求高的格排前面，候选按稀有度从低到高（好材料留着）、同档按仓库顺序；一件只顶一格；
## 用增广路找最大分配 —— 不会因为先占了稀缺的那件而「明明够料却打不了」。不拿 [member SmithRecipeDef.inputs] 点名的那几样、不拿锁住的
static func slot_picks(meta: MetaState, recipe: SmithRecipeDef) -> Array:
	var out: Array = []
	if recipe == null:
		return out
	var slots := recipe.slots()
	for i in slots.size():
		out.append([] as Array[ItemInstance])
	if meta == null:
		return out
	var pool: Array[ItemInstance] = []
	for inst in meta.warehouse.items():
		var it := inst as ItemInstance
		if it.is_locked_by_player() or recipe.inputs.has(it.def.id) or recipe.inputs.has(String(it.def.id)):
			continue
		pool.append(it)
	var order := range(pool.size())
	order.sort_custom(func(x: int, y: int) -> bool: return pool[x].def.rarity < pool[y].def.rarity or (pool[x].def.rarity == pool[y].def.rarity and x < y))
	var units: Array[int] = []     # 一件一个位：所属格的序号
	for i in slots.size():
		for _n in maxi(0, int(slots[i]["count"])):
			units.append(i)
	units.sort_custom(func(x: int, y: int) -> bool: return int(slots[x]["min"]) > int(slots[y]["min"]) or (int(slots[x]["min"]) == int(slots[y]["min"]) and x < y))
	var owner := {}     # 候选下标 → 位下标
	for u in units.size():
		_augment(u, units, slots, pool, order, owner, {})
	var taken: Array = owner.keys()
	taken.sort()
	for k in taken:
		(out[units[int(owner[k])]] as Array).append(pool[int(k)])
	return out


static func _augment(u: int, units: Array[int], slots: Array[Dictionary], pool: Array[ItemInstance], order: Array, owner: Dictionary, seen: Dictionary) -> bool:
	for k in order:
		if seen.has(k) or not SmithRecipeDef.slot_fits(slots[units[u]], pool[k].def):
			continue
		seen[k] = true
		if not owner.has(k) or _augment(int(owner[k]), units, slots, pool, order, owner, seen):
			owner[k] = u
			return true
	return false


## 能不能打：空串 = 行；否则是说给玩家听的那一句（科技没点 / 级不够 / 缺素材 / 钱不够 / 仓库放不下）
static func can_forge(meta: MetaState, recipe: SmithRecipeDef, items: ItemDatabase) -> String:
	if meta == null or recipe == null or items == null or items.get_def(recipe.output) == null:
		return UiText.t("smithy.no_recipe")
	if not knows(meta, recipe):
		return need_tech_text(recipe)
	if recipe.level > level(meta):
		return UiText.t("smithy.need_level") % recipe.level
	var got := have(meta, recipe)
	for key in recipe.inputs:
		if int(got.get(String(key), 0)) < int(recipe.inputs[key]):
			return UiText.t("smithy.missing")
	var slots := recipe.slots()
	for i in slots.size():
		if int(got.get(SLOT_KEY % i, 0)) < int(slots[i]["count"]):
			return UiText.t("smithy.missing")
	if meta.funds < recipe.funds:
		return UiText.t("smithy.no_funds")
	if not meta.warehouse.can_admit(items.get_def(recipe.output)):
		return UiText.t("smithy.full")
	return ""


## 打一件：扣素材（仓库顺序在前的先扣）、扣钱、产物进仓库、图鉴点亮。不能打返回 null，什么也不动
static func forge(meta: MetaState, recipe: SmithRecipeDef, items: ItemDatabase) -> ItemInstance:
	if can_forge(meta, recipe, items) != "":
		return null
	var out := ItemInstance.create(items.get_def(recipe.output), 0)
	out.uid = meta.allocate_uid()
	var q := _material_quality(meta, recipe)     # 279 补充二：材料比要求高几档，产物就几档品质；和吃掉的那把取较高，不累加
	meta.warehouse.begin_batch()
	for used in slot_picks(meta, recipe):
		for inst in used:
			meta.warehouse.remove((inst as ItemInstance).uid)
	var left := {}
	for key in recipe.inputs:
		left[String(key)] = int(recipe.inputs[key])
	for inst in meta.warehouse.items():
		var it := inst as ItemInstance
		var key := String(it.def.id)
		if int(left.get(key, 0)) > 0 and not it.is_locked_by_player():
			meta.warehouse.remove(it.uid)
			left[key] = int(left[key]) - 1
			q = maxi(q, it.quality())
	out.set_quality(q)
	var placed := meta.warehouse.try_add(out, true)
	meta.warehouse.end_batch()
	if not placed:
		push_warning("Smithy.forge: %s 放不进仓库（can_forge 查过，不该到这里）" % recipe.output)
		return null
	meta.spend_funds(recipe.funds)
	meta.light_codex(out.def)
	meta.changed.emit()
	return out


## 279 补充二：旧的一类一件格（[member SmithRecipeDef.material_inputs]，排在 [method SmithRecipeDef.slots] 最前）用的那件比要求高几档；
## 310：带件数的新格（[member SmithRecipeDef.material_slots]）不升品质（方案 §5.3）
static func _material_quality(meta: MetaState, recipe: SmithRecipeDef) -> int:
	var q := 0
	var picks := slot_picks(meta, recipe)
	var slots := recipe.slots()
	for i in mini(recipe.material_inputs.size(), picks.size()):
		for inst in picks[i]:
			q = maxi(q, (inst as ItemInstance).def.rarity - int(slots[i]["min"]))
	return q


## 说明面板：到第 k 级会打哪一档
static func describe_level(lv: int) -> String:
	if lv <= 0:
		return ""
	return UiText.t("smithy.level_line") % UiText.t("tip.rarity_%d" % clampi(lv, 0, 4))
