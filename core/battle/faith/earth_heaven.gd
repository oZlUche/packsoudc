## 大地之神（作者牌表 11-26「大地之神」）：核心【天地】的分层（编译期、纯函数）与大地之神的牌在战斗里的那一半。
##
## - 分层（[method roles]）：棋盘上的每件非包道具按摆的位置分三种 ——
##   【大地】至少一格贴着棋盘边界（棋盘最外一圈，或挨着缺格）；
##   【穹顶】不是大地、至少一格落在离边界最远的那一圈（棋盘中央）；
##   【支柱】既不是大地也不是穹顶（夹在中间那几圈）。
##   离边界几圈按四邻从界外 / 缺格往里数（[method depths]），和放的先后、遍历顺序无关。
## - 一条规则（[FaithMechanicTrigger] 听开战、受伤前、伤害）放整套，数由 [EarthHeavenPerk] 编译时按拿了哪些牌、棋盘怎么摆填好：
##   开战时【磐石】给护甲、【厚实】挂一层格挡、【天光】打真实伤害、【冲撞】【万钧】打固定伤害、【玉石俱焚】打伤害、
##   【擎天一柱】给敌人随机元素、【层峦】攒几次「抵挡攻击」；挨打时【反震】还一下真实伤害（冷却）。
## 开战写战记 `faith_mechanic` / `earth_ground`、`earth_dome`（战后的经验值按件数数，见 [MechanicDeed]）
class_name EarthHeaven
extends CombatEffect

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const GROUND := &"ground"
const DOME := &"dome"
const PILLAR := &"pillar"
## 【厚实】那一层格挡的名字（[method CombatantRuntime.set_block_layer]）
const THICK_LAYER := &"earth_thick"

## 大地 / 穹顶 / 支柱几件（参战的）
@export var ground: int = 0
@export var dome: int = 0
@export var pillar: int = 0
## 磐石：开战给的护甲（已经按件数、格子数算好的合计）
@export var armor_gain: int = 0
## 天光：开战打的真实伤害（合计）
@export var sky_true: int = 0
## 冲撞、万钧：开战打的固定伤害；玉石俱焚：开战打的伤害
@export var ram: int = 0
@export var heavy: int = 0
@export var jade: int = 0
## 厚实：开战挂的格挡（固定减伤）
@export var thick: int = 0
## 反震：挨一下攻击还几点真实伤害（0 = 没拿），冷却几秒
@export var quake: int = 0
@export var quake_cd: float = 6.0
## 擎天一柱：开战给敌人几层随机元素（一层一抽）
@export var elements: int = 0
## 层峦：开战攒几次「抵挡接下来的一次攻击」
@export var ranges: int = 0


#region 分层（编译期）
## 每一格离边界几圈：界外 / 缺格的四邻是 0 圈，往里一格多一圈。没法放东西的格（缺格）不在结果里
static func depths(board: GridInventory) -> Dictionary:
	var out := {}
	if board == null:
		return out
	var queue: Array[Vector2i] = []
	for y in board.size.y:
		for x in board.size.x:
			var c := Vector2i(x, y)
			if board.is_blocked(c):
				continue
			for d in DIRS:
				var n := c + d
				if not board.in_bounds(n) or board.is_blocked(n):
					out[c] = 0
					queue.append(c)
					break
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for d in DIRS:
			var n := c + d
			if board.in_bounds(n) and not board.is_blocked(n) and not out.has(n):
				out[n] = int(out[c]) + 1
				queue.append(n)
	return out


## 能分层的道具：棋盘上的非包道具（[param battle_only] 真 = 只算参战的：标了不参战的不算）
static func counts(board: GridInventory, inst: ItemInstance, battle_only: bool = false) -> bool:
	if inst == null or inst.def == null or board.acts_as_bag(inst.def):
		return false
	return not (battle_only and inst.is_benched())


## uid → 大地 / 穹顶 / 支柱（uid 升序可复现）
static func roles(board: GridInventory, battle_only: bool = false) -> Dictionary:
	var out := {}
	if board == null:
		return out
	var deep := depths(board)
	var top := 0
	for c in deep:
		top = maxi(top, int(deep[c]))
	var uids: Array[int] = []
	for raw in board.items():
		uids.append((raw as ItemInstance).uid)
	uids.sort()
	for uid in uids:
		var inst := board.get_item(uid)
		if not counts(board, inst, battle_only):
			continue
		var edge := false
		var centre := false
		for c in inst.absolute_cells(inst.cells()):
			var d := int(deep.get(c, 0))
			if d == 0:
				edge = true
			if top > 0 and d == top:
				centre = true
		out[uid] = GROUND if edge else (DOME if centre else PILLAR)
	return out


## [param role] 那一种有几件
static func count_of(got: Dictionary, role: StringName) -> int:
	var n := 0
	for uid in got:
		if got[uid] == role:
			n += 1
	return n


## [param role] 那一种的 uid（升序）
static func uids_of(got: Dictionary, role: StringName) -> Array[int]:
	var out: Array[int] = []
	for uid in got:
		if got[uid] == role:
			out.append(int(uid))
	out.sort()
	return out
#endregion


func apply(ctx: RuleContext) -> void:
	var e := ctx.event
	if e == null or ctx.owner == null or ctx.owner.dead:
		return
	match e.name:
		BattleEvent.BATTLE_START:
			_start(ctx)
		BattleEvent.BEFORE_DAMAGE:
			_before(ctx)
		BattleEvent.DAMAGE:
			_after(ctx, e)


func _start(ctx: RuleContext) -> void:
	var me := ctx.owner
	if ground > 0:
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "earth_ground", "count": ground})
	if dome > 0:
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "earth_dome", "count": dome})
	if armor_gain > 0:
		var res := me.resources
		if not res.has(BattleStats.RES_ARMOR):
			res.define(BattleStats.RES_ARMOR, 0)
		var add := StatMath.from_float(float(armor_gain))
		res.set_max(BattleStats.RES_ARMOR, res.maximum(BattleStats.RES_ARMOR) + add)     # 上限加多少当前值同量加
	if thick > 0:
		me.set_block_layer(THICK_LAYER, StatMath.from_float(float(thick)))     # 是一个格挡来源：和盾取最高、只挡直接的非真实伤害
	if ranges > 0:
		ctx.state()["ranges"] = ranges
	var foe := ctx.opponent()
	if foe == null or foe.dead:
		return
	if sky_true > 0:
		var p := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(float(sky_true)), foe, me.side, 0, false)
		p.pure = true
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "earth_sky", "count": dome})
		DamageResolver.resolve(ctx.battle, p)
	for pair in [["earth_ram", ram], ["earth_heavy", heavy], ["earth_jade", jade]]:
		var n := int(pair[1])
		if n > 0 and not foe.dead:
			ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": String(pair[0]), "count": 1})
			DamageResolver.deal(ctx.battle, foe, StatMath.from_float(float(n)), DamageTypes.PHYSICAL, me.side, 0, false)
	for i in elements:
		if foe.dead:
			break
		var id := SkillMomentum.ELEMENTS[ctx.roll("earth_pillar_sky", 0, SkillMomentum.ELEMENTS.size() - 1)]
		var path := ContentPaths.asset_file("buffs", String(id))
		var d := load(path) as BuffDef if ResourceLoader.exists(path) else null
		if d != null:
			ApplyStatus.give(ctx, foe, d, 1)


## 层峦：敌人打过来的一下攻击（直接伤害，真实伤害也算）当作没发生
func _before(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null or p.victim != ctx.owner or p.cancelled or not p.direct or p.source_side < 0 or p.source_side == ctx.owner.side:
		return
	var st := ctx.state()
	var left := int(st.get("ranges", 0))
	if left <= 0:
		return
	st["ranges"] = left - 1
	p.cancel()
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": "earth_ranges", "count": 1})


## 反震：受到敌人的一下攻击（被层峦抵挡掉的不算），对敌人造成大地件数的真实伤害，有冷却
func _after(ctx: RuleContext, e: BattleEvent) -> void:
	var me := ctx.owner
	if quake <= 0 or e.side != me.side or e.get_bool(&"cancelled") or not e.get_bool(&"direct"):
		return
	var src := e.get_int(&"source_side", -1)
	if src < 0 or src == me.side:
		return
	var st := ctx.state()
	var now := ctx.battle.now
	if now < int(st.get("quake_at", 0)):
		return
	var foe := ctx.opponent()
	if foe == null or foe.dead:
		return
	st["quake_at"] = now + StatMath.from_float(quake_cd)
	var p := DamagePacket.create(DamageTypes.PHYSICAL, StatMath.from_float(float(quake)), foe, me.side, 0, false)
	p.pure = true
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, me.side, {"effect": SkillMomentum.MECHANIC, "key": "earth_quake", "count": 1})
	DamageResolver.resolve(ctx.battle, p)


func describe() -> String:
	return UiText.t("fx.earth_heaven")
