## 信仰重构 C（交接方案 §6.4）：大地之神「空间承托」的布局计算（编译期、纯函数）与开战那一下（战斗中）。
##
## - 大件：占格 ≥ [param min_cells]（基础 5，一阶起 4）、有战斗定义、不是包、没标不参战、没整件休眠。
## - 承托：另一件**不同的**有效道具（有战斗定义、不是包、没标不参战、没整件休眠）和它至少有一条占格边正交相接；
##   角接触不算，同一个邻居多条边只算一次。每件大件最多 [param max_layers] 层。
## - 遍历按格子坐标、邻居按 uid 去重，结果与放置先后、遍历顺序无关
class_name EarthSupport
extends CombatEffect

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## 三阶：开战按承托着的大件数给护甲（每件最大生命的 [member armor_percent]%，合计不超过 [member armor_cap]%）；0 = 不给
@export var armor_percent: int = 0
@export var armor_cap: int = 10
## 有承托的大件几件（编译时填，开战写进战记、给信力行为数）
@export var supported: int = 0


## 能当承托的那一方（大件自己也得满足）
static func counts(board: GridInventory, inst: ItemInstance, active_faith: StringName) -> bool:
	if inst == null or inst.def == null or inst.def.combat == null or board.acts_as_bag(inst.def) or inst.is_benched():
		return false
	return not FaithState.is_inert(inst.def, active_faith)


## uid → 承托层数（只列有承托的大件，uid 升序可复现）
static func layers(board: GridInventory, active_faith: StringName, min_cells: int = 5, max_layers: int = 2) -> Dictionary:
	var out := {}
	if board == null:
		return out
	var uids: Array[int] = []
	for raw in board.items():
		uids.append((raw as ItemInstance).uid)
	uids.sort()
	for uid in uids:
		var inst := board.get_item(uid)
		if not counts(board, inst, active_faith) or ItemVolume.cells_of(inst.def) < min_cells:
			continue
		var mine := inst.absolute_cells(inst.cells())
		var seen := {}
		for c in mine:
			for d in DIRS:
				var other := board.cell_uid(c + d)
				if other == GridInventory.EMPTY_UID or other == uid or seen.has(other):
					continue
				if counts(board, board.get_item(other), active_faith):
					seen[other] = true
		if not seen.is_empty():
			out[uid] = mini(seen.size(), max_layers)
	return out


## 武器（攻击型）减耐力消耗；不是武器的盾、防具（防御型）加自己的格挡 / 护甲上限；别的不领。混合的按武器走，不双领
static func role_of(def: ItemDef) -> StringName:
	if def == null:
		return &""
	if def.tags.has(&"weapon"):
		return &"attack"
	if def.tags.has(&"shield") or def.tags.has(&"armor"):
		return &"defense"
	return &""


func apply(ctx: RuleContext) -> void:
	var e := ctx.event
	if e == null or e.name != BattleEvent.BATTLE_START or ctx.owner == null or supported <= 0:
		return
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": "earth_support", "count": supported})
	if armor_percent <= 0:
		return
	var pct := mini(armor_cap, armor_percent * supported)
	var gain := StatMath.mul(ctx.owner.resources.maximum(BattleStats.RES_HP), StatMath.from_percent(pct))
	if gain <= 0:
		return
	var res := ctx.owner.resources
	if not res.has(BattleStats.RES_ARMOR):
		res.define(BattleStats.RES_ARMOR, 0)
	res.set_max(BattleStats.RES_ARMOR, res.maximum(BattleStats.RES_ARMOR) + gain)     # 上限加多少当前值同量加


func describe() -> String:
	return UiText.t("fx.earth_support")
