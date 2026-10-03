## 局外科技的逻辑（110）：看 [MetaState] 的等级 / 上交记录与 [TechDef] 算结果。纯逻辑，不存盘、不碰界面 ——
## 存盘由 [GameFlow] 的转发做（和 `store_all` 一样）。
##
## 规矩（作者定）：**上交即消耗**（交一件从仓库移除、记一件，没有取回，分批跨多局都认）；
## **钱在按【升级】时一次扣**；材料交齐且钱够才能升。
class_name TechService
extends RefCounted


## 当前级（没升过 = 0）
static func level(meta: MetaState, id: StringName) -> int:
	return int(meta.tech_levels.get(String(id), 0)) if meta != null else 0


## 下一级要什么；满级返回 null
static func next_tier(meta: MetaState, def: TechDef) -> TechTier:
	if def == null:
		return null
	var lv := level(meta, def.id)
	return def.tiers[lv] if lv < def.tiers.size() else null


## 这一项已交了几件某道具
static func deposited(meta: MetaState, id: StringName, item_id: StringName) -> int:
	var got: Dictionary = meta.tech_deposits.get(String(id), {})
	return int(got.get(String(item_id), 0))


## 道具 id（字符串）→ 还差几件（需要 − 已交，最低 0）。满级 / 只要钱的一级返回空
static func needed(meta: MetaState, def: TechDef) -> Dictionary:
	var out := {}
	var tier := next_tier(meta, def)
	if tier == null:
		return out
	for key in tier.items:
		out[String(key)] = maxi(0, int(tier.items[key]) - deposited(meta, def.id, StringName(String(key))))
	return out


## 这件是不是下一级还差的材料
static func can_submit(meta: MetaState, def: TechDef, item_def: ItemDef) -> bool:
	if item_def == null:
		return false
	return int(needed(meta, def).get(String(item_def.id), 0)) > 0


## 交一件：从仓库移除、计数 +1。不需要这件 / 仓库里没有返回 false
static func submit(meta: MetaState, def: TechDef, uid: int) -> bool:
	if meta == null or def == null:
		return false
	var inst := meta.warehouse.get_item(uid)
	if inst == null or not can_submit(meta, def, inst.def):
		return false
	meta.warehouse.remove(uid)
	return deposit(meta, def, inst.def)


## 记一件（东西已经离开仓库：拖进上交区的那一件）。不需要这件返回 false、什么也不记
static func deposit(meta: MetaState, def: TechDef, item_def: ItemDef) -> bool:
	if meta == null or not can_submit(meta, def, item_def):
		return false
	var key := String(def.id)
	var got: Dictionary = meta.tech_deposits.get(key, {})
	got[String(item_def.id)] = int(got.get(String(item_def.id), 0)) + 1
	meta.tech_deposits[key] = got
	meta.changed.emit()
	return true


## 材料全齐（没缺的）
static func items_complete(meta: MetaState, def: TechDef) -> bool:
	var left := needed(meta, def)
	for key in left:
		if int(left[key]) > 0:
			return false
	return true


## 能不能升：不是满级、材料全齐、钱够
static func ready(meta: MetaState, def: TechDef) -> bool:
	var tier := next_tier(meta, def)
	return tier != null and items_complete(meta, def) and meta.funds >= tier.funds


## 升一级：扣钱、清这一项的上交记录、等级 +1、施加效果。不 [method ready] 什么也不动
static func upgrade(meta: MetaState, def: TechDef) -> bool:
	if not ready(meta, def):
		return false
	var tier := next_tier(meta, def)
	meta.funds -= tier.funds
	meta.tech_deposits.erase(String(def.id))
	meta.tech_levels[String(def.id)] = level(meta, def.id) + 1
	if def.effect != null:
		def.effect.apply(meta)
	meta.changed.emit()
	return true


## 读档后的自检：每项科技按已到的级数让效果补齐（只补不缩，见 [method TechEffect.heal]）
static func heal(meta: MetaState, defs: Array) -> void:
	if meta == null:
		return
	for d in defs:
		var def := d as TechDef
		if def != null and def.effect != null:
			def.effect.heal(meta, level(meta, def.id))
