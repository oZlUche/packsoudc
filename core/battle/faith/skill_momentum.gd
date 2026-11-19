## 信仰重构 C（交接方案 §6.5）：技巧之神「动作组合」。一条规则（[FaithMechanicTrigger] 听开战、受伤前、伤害、出手）放整套：
##
## - 原始有效动作分四类：近战 / 远程 / 施法 / 防御（[method category_of]，按标签，不认名字）。
## - 这一下的类别和上一下不同、间隔不超过 [member window_sec]：攒一层【巧劲】（buff，上限 [member cap]）；同类不加。
## - 武器打出的直接伤害**先**用掉攒着的巧劲（一阶起每层 +[member percent_per]%，攒满两层那一下穿透护甲），
##   **再**按这一下的类别更新下一轮 —— 出手事件排在伤害之后结算，所以同一下不会自产自用。
## - 二阶：格挡真的挡下了直接伤害，算一次防御动作（间隔至少 [member defense_gap_sec] 秒）。
## - 三阶：本场头一回打出「防御 → 攻击 → 另一类攻击」，追加一下最后那一击直接伤害的 [member combo_percent]%（一场一次；
##   追加的这一下不算动作、不攒巧劲）。
## - 开战给 [member opening] 层（单类武器也能用上）。
## 连带出手（事件带 [constant RuleEngine.CHAIN]）不是原始动作，不攒。参数由 [SkillMomentumPerk] 按开战时的阶填
class_name SkillMomentum
extends CombatEffect

const BUFF_ID := &"skill_momentum"
const MELEE := &"melee"
const RANGED := &"ranged"
const SPELL := &"spell"
const DEFENSE := &"defense"
## 战记里写的那一句（[BattleNarrator] 认 `faith_mechanic` + key）
const MECHANIC := "faith_mechanic"

@export var tier: int = 0
@export var window_sec: float = 4.0
@export var cap: int = 2
@export var percent_per: int = 5
@export var opening: int = 1
@export var defense_gap_sec: float = 1.0
@export var combo_percent: int = 30

static var _buff: BuffDef = null


static func buff_def() -> BuffDef:
	if _buff == null:
		var path := ContentPaths.asset_file("buffs", String(BUFF_ID))
		_buff = load(path) as BuffDef if ResourceLoader.exists(path) else null
	return _buff


## 这件的动作类别：法杖 = 施法；其次远程、近战；盾 = 防御（盾本身不出手，二阶起靠格挡计）；都不是 = 空
static func category_of(tags: Array[StringName]) -> StringName:
	if tags.has(&"staff"):
		return SPELL
	if tags.has(&"weapon"):
		return RANGED if tags.has(RANGED) else MELEE
	return &""


static func is_attack(cat: StringName) -> bool:
	return cat == MELEE or cat == RANGED or cat == SPELL


func apply(ctx: RuleContext) -> void:
	var e := ctx.event
	if e == null or ctx.owner == null or buff_def() == null:
		return
	match e.name:
		BattleEvent.BATTLE_START:
			if opening > 0:
				ApplyStatus.give(ctx, ctx.owner, buff_def(), mini(opening, cap))
		BattleEvent.BEFORE_DAMAGE:
			_spend(ctx)
		BattleEvent.DAMAGE:
			_on_damage(ctx, e)
		BattleEvent.ITEM_FIRED:
			if e.side == ctx.owner.side and not e.payload.has(RuleEngine.CHAIN):
				var cat := category_of(ctx.owner.tags_of(e.get_int(&"uid")))
				if is_attack(cat):
					_act(ctx, cat, e.get_int(&"uid"))


## 武器打出的直接伤害用掉全部巧劲
func _spend(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null or p.source_side != ctx.owner.side or not p.direct or p.source_uid == 0:
		return
	if not is_attack(category_of(ctx.owner.tags_of(p.source_uid))):
		return
	var n := ctx.owner.stacks_of(BUFF_ID)
	if n <= 0:
		return
	RemoveStatus.take(ctx, ctx.owner, BUFF_ID, n, "spent")
	if tier < 1:
		return
	p.add_percent(StatMath.from_percent(percent_per * n))
	if n >= 2:
		p.penetration = true


func _on_damage(ctx: RuleContext, e: BattleEvent) -> void:
	var st := ctx.state()
	if e.get_int(&"source_side", -1) == ctx.owner.side and e.side != ctx.owner.side and e.get_int(&"uid") != 0 and e.get_bool(&"direct"):
		var hits: Dictionary = st.get("hits", {})
		hits[e.get_int(&"uid")] = maxi(0, e.get_int(&"amount"))
		st["hits"] = hits
		return
	if tier < 2 or e.side != ctx.owner.side or e.get_int(&"block") <= 0 or not e.get_bool(&"direct"):
		return
	var last := int(st.get("defense_at", -1))
	if last >= 0 and ctx.battle.now - last < StatMath.from_float(defense_gap_sec):
		return
	st["defense_at"] = ctx.battle.now
	_act(ctx, DEFENSE, 0)


## 一次原始动作：换了类别、没断档就攒一层；三阶看组合
func _act(ctx: RuleContext, cat: StringName, uid: int) -> void:
	var st := ctx.state()
	var now := ctx.battle.now
	var last_cat := StringName(String(st.get("cat", "")))
	var last_at := int(st.get("at", -1))
	if last_cat != &"" and cat != last_cat and now - last_at <= StatMath.from_float(window_sec):
		if ctx.owner.stacks_of(BUFF_ID) < cap:
			ApplyStatus.give(ctx, ctx.owner, buff_def(), 1)
	st["cat"] = String(cat)
	st["at"] = now
	if tier < 3 or bool(st.get("combo_done", false)):
		return
	var seq: Array = st.get("seq", [])
	seq.append(String(cat))
	while seq.size() > 3:
		seq.pop_front()
	st["seq"] = seq
	if seq.size() == 3 and seq[0] == String(DEFENSE) and is_attack(StringName(seq[1])) and is_attack(StringName(seq[2])) and seq[1] != seq[2]:
		st["combo_done"] = true
		var foe := ctx.opponent()
		var raw := StatMath.mul(int((st.get("hits", {}) as Dictionary).get(uid, 0)), StatMath.from_percent(combo_percent))
		ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": MECHANIC, "key": "skill_combo"})
		if foe != null and not foe.dead and raw > 0:
			DamageResolver.deal(ctx.battle, foe, raw, DamageTypes.PHYSICAL, ctx.owner.side, 0, false)


func describe() -> String:
	return UiText.t("fx.skill_momentum") % [cap, TextTemplate.num(window_sec)]
