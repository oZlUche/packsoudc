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
## 279：按材质类认的那几格记在 `"material:<材质>"` 下（有没有能顶的一件：1 / 0）
static func have(meta: MetaState, recipe: SmithRecipeDef) -> Dictionary:
	var out := {}
	if recipe == null:
		return out
	for key in recipe.inputs:
		out[String(key)] = 0
	var picks := material_picks(meta, recipe)
	for m in recipe.material_inputs:
		out[MATERIAL_KEY % m] = 1 if picks.get(String(m)) != null else 0
	if meta == null:
		return out
	for inst in meta.warehouse.items():
		var it := inst as ItemInstance
		var key := String(it.def.id)
		if out.has(key) and not it.is_locked_by_player():
			out[key] = int(out[key]) + 1
	return out


const MATERIAL_KEY := "material:%s"


## 279：每个材质类格会扣仓库里哪一件：材质 → ItemInstance（没有能顶的 = null）。
## 稀有度最低的先用（好材料留着），同档按仓库顺序；不拿 [member SmithRecipeDef.inputs] 点名的那几样、不拿锁住的
static func material_picks(meta: MetaState, recipe: SmithRecipeDef) -> Dictionary:
	var out := {}
	if recipe == null:
		return out
	var mats: Array = recipe.material_inputs.keys()
	mats.sort()
	var used := {}
	for m in mats:
		var best: ItemInstance = null
		if meta != null:
			for inst in meta.warehouse.items():
				var it := inst as ItemInstance
				if used.has(it.uid) or it.is_locked_by_player() or recipe.inputs.has(it.def.id) or recipe.inputs.has(String(it.def.id)):
					continue
				if recipe.material_fits(String(m), it.def) and (best == null or it.def.rarity < best.def.rarity):
					best = it
		if best != null:
			used[best.uid] = true
		out[String(m)] = best
	return out


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
	for m in recipe.material_inputs:
		if int(got.get(MATERIAL_KEY % m, 0)) < 1:
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
	var picks := material_picks(meta, recipe)
	var q := 0     # 279 补充二：材料比要求高几档，产物就几档品质；和吃掉的那把取较高，不累加
	meta.warehouse.begin_batch()
	for m in picks:
		var used := picks[m] as ItemInstance
		q = maxi(q, used.def.rarity - int(recipe.material_inputs[m]))
		meta.warehouse.remove(used.uid)
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


## 298：升级类配方（[method Anvil.is_upgrade]）打下去前后的两把：`before` = 仓库里会被吃掉的那把（没有 = null），
## `after` = 出件（品质照 [method forge]：用得上的材料比要求高几档，和那把的品质取较高）。不是升级类 / 查不到出件 = 空字典
static func preview(meta: MetaState, recipe: SmithRecipeDef, items: ItemDatabase) -> Dictionary:
	if not Anvil.is_upgrade(recipe) or items == null or items.get_def(recipe.output) == null:
		return {}
	var key := String(recipe.inputs.keys()[0])
	var before: ItemInstance = null
	if meta != null:
		for inst in meta.warehouse.items():
			var it := inst as ItemInstance
			if String(it.def.id) == key and not it.is_locked_by_player():
				before = it
				break
	var q := before.quality() if before != null else 0
	var picks := material_picks(meta, recipe)
	for m in picks:
		var used := picks[m] as ItemInstance
		if used != null:
			q = maxi(q, used.def.rarity - int(recipe.material_inputs[m]))
	var after := ItemInstance.create(items.get_def(recipe.output), 0)
	after.set_quality(clampi(q, 0, ItemInstance.QUALITY_MAX))
	return {"before": before, "after": after}


## 说明面板：到第 k 级会打哪一档
static func describe_level(lv: int) -> String:
	if lv <= 0:
		return ""
	return UiText.t("smithy.level_line") % UiText.t("tip.rarity_%d" % clampi(lv, 0, 4))
