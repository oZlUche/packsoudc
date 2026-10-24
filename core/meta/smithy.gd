## 251：基地铁匠铺（作者 2026-10-24：「有特定配方，可以通过素材和金钱合成武器、防具」）—— 科技「铁匠铺」点出来，级数 = 能打哪一档配方（[member SmithRecipeDef.level]）。
##
## 只吃**仓库**里的素材（不碰保险箱、包架），锁住的（230）不算有；产物进仓库按页序第一处空位，放不下不打（不扣素材、不扣钱）。
## 扣素材按仓库顺序先扣前面的。产物是局外号段的新实例，图鉴点亮。纯逻辑，存盘由 [GameFlow] 做
class_name Smithy
extends RefCounted

const ID := &"smithy"


static func level(meta: MetaState) -> int:
	return meta.facility_level(ID) if meta != null else 0


## {"ready": 这一级会打的, "locked": 级数还不够的}，各自按配方的先后
static func recipes_for(meta: MetaState, recipes: Array) -> Dictionary:
	var out := {"ready": [] as Array[SmithRecipeDef], "locked": [] as Array[SmithRecipeDef]}
	var lv := level(meta)
	for r in recipes:
		var def := r as SmithRecipeDef
		if def != null:
			(out["ready" if def.level <= lv else "locked"] as Array).append(def)
	return out


## 仓库里每样素材有几件（锁住的不算）：道具 id 字符串 → 件数，只列配方要的
static func have(meta: MetaState, recipe: SmithRecipeDef) -> Dictionary:
	var out := {}
	if recipe == null:
		return out
	for key in recipe.inputs:
		out[String(key)] = 0
	if meta == null:
		return out
	for inst in meta.warehouse.items():
		var it := inst as ItemInstance
		var key := String(it.def.id)
		if out.has(key) and not it.is_locked_by_player():
			out[key] = int(out[key]) + 1
	return out


## 能不能打：空串 = 行；否则是说给玩家听的那一句（级不够 / 缺素材 / 钱不够 / 仓库放不下）
static func can_forge(meta: MetaState, recipe: SmithRecipeDef, items: ItemDatabase) -> String:
	if meta == null or recipe == null or items == null or items.get_def(recipe.output) == null:
		return UiText.t("smithy.no_recipe")
	if recipe.level > level(meta):
		return UiText.t("smithy.need_level") % recipe.level
	var got := have(meta, recipe)
	for key in recipe.inputs:
		if int(got.get(String(key), 0)) < int(recipe.inputs[key]):
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
	meta.warehouse.begin_batch()
	var left := {}
	for key in recipe.inputs:
		left[String(key)] = int(recipe.inputs[key])
	for inst in meta.warehouse.items():
		var it := inst as ItemInstance
		var key := String(it.def.id)
		if int(left.get(key, 0)) > 0 and not it.is_locked_by_player():
			meta.warehouse.remove(it.uid)
			left[key] = int(left[key]) - 1
	var placed := meta.warehouse.try_add(out, true)
	meta.warehouse.end_batch()
	if not placed:
		push_warning("Smithy.forge: %s 放不进仓库（can_forge 查过，不该到这里）" % recipe.output)
		return null
	meta.spend_funds(recipe.funds)
	meta.light_codex(out.def)
	meta.changed.emit()
	return out


## 说明面板：到第 k 级会打哪一档
static func describe_level(lv: int) -> String:
	if lv <= 0:
		return ""
	return UiText.t("smithy.level_line") % UiText.t("tip.rarity_%d" % clampi(lv, 0, 4))
