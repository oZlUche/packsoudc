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


## 能不能升：不是满级、前置都点亮了（118）、材料全齐、钱够
static func ready(meta: MetaState, def: TechDef) -> bool:
	var tier := next_tier(meta, def)
	return tier != null and prereqs_met(meta, def) and items_complete(meta, def) and meta.funds >= tier.funds


#region 树（118）
## 前置都满足：每一项至少 1 级（作者定，满级才开下一个会把六级仓库那一列堵死）
static func prereqs_met(meta: MetaState, def: TechDef) -> bool:
	if def == null:
		return false
	for req in def.requires:
		if level(meta, req) < 1:
			return false
	return true


## 还没点亮的前置（按 [param defs] 查定义；查不到的 id 跳过）
static func missing_prereqs(meta: MetaState, def: TechDef, defs: Array) -> Array[TechDef]:
	var out: Array[TechDef] = []
	if def == null:
		return out
	for req in def.requires:
		if level(meta, req) >= 1:
			continue
		var d := find(defs, req)
		if d != null:
			out.append(d)
	return out


static func find(defs: Array, id: StringName) -> TechDef:
	for d in defs:
		if d is TechDef and (d as TechDef).id == id:
			return d
	return null


## 深度：根 0，其余 = 前置里最深的 + 1。前置不存在的当根看；成环返回 −1（导入器拦着，到不了这里）
static func depth_of(def: TechDef, defs: Array, _seen: Dictionary = {}) -> int:
	if def == null:
		return -1
	if _seen.has(def.id):
		return -1
	if def.requires.is_empty():
		return 0
	_seen[def.id] = true
	var deepest := -1
	for req in def.requires:
		var d := find(defs, req)
		if d == null:
			continue
		var dep := depth_of(d, defs, _seen)
		if dep < 0:
			_seen.erase(def.id)
			return -1
		deepest = maxi(deepest, dep)
	_seen.erase(def.id)
	return deepest + 1


## 成环的那几个科技 id（空 = 没有环）
static func cycle_members(defs: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for d in defs:
		var def := d as TechDef
		if def != null and depth_of(def, defs) < 0:
			out.append(def.id)
	return out


## 树的格位：科技 id → Vector2i(列, 深度)
static func layout(defs: Array) -> Dictionary:
	var out := {}
	for d in defs:
		var def := d as TechDef
		if def != null:
			out[def.id] = Vector2i(def.column, maxi(0, depth_of(def, defs)))
	return out
#endregion


## 升一级：扣钱、清这一项的上交记录、等级 +1、按新级数推算效果（120：和读档同一条路）。不 [method ready] 什么也不动
static func upgrade(meta: MetaState, def: TechDef) -> bool:
	if not ready(meta, def):
		return false
	var tier := next_tier(meta, def)
	meta.funds -= tier.funds
	meta.tech_deposits.erase(String(def.id))
	meta.tech_levels[String(def.id)] = level(meta, def.id) + 1
	if def.effect != null:
		def.effect.derive(meta, level(meta, def.id))
	meta.changed.emit()
	return true


## 120：由进度表（`tech_levels`）推算全部科技派生值 —— 每项科技按已到的级数 [method TechEffect.derive]（仓库行数、保险箱、局外 buff）。
## 读档时在仓库装东西之前、新建空档时、开发区改级数后都调它；存档里不存这些数
static func derive(meta: MetaState, defs: Array) -> void:
	if meta == null:
		return
	for d in defs:
		var def := d as TechDef
		if def != null and def.effect != null:
			def.effect.derive(meta, level(meta, def.id))
	# 118：科技给的 buff 里不属于任何科技的（科技删了 / 改了 buff id）清掉，免得一局悄悄多一条
	var owned := {}
	for d in defs:
		var def := d as TechDef
		if def != null and def.effect is TechRunBuff:
			for id in (def.effect as TechRunBuff).buffs:
				owned[id] = true
	for id in meta.tech_buffs.duplicate():
		if not owned.has(id):
			meta.tech_buffs.erase(id)
