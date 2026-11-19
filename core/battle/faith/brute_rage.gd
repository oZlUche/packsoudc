## 信仰重构 D（交接方案 §6.1）：蛮神「承压反击」。一条规则（[FaithMechanicTrigger] 听受伤前、伤害）放整套：
##
## - 受到对手造成的生命伤害（自伤、环境、护甲吸收的都不算）积【怒气】：按累计量，每失去最大生命的 [member percent_per_stack]% 一层，
##   上限 [member cap]。一下伤害按最大生命封顶（超额致死的不多给）。
## - 下一次武器打出的直接伤害**先取出并清零**怒气，每层 +[member damage_per]%；一阶起攒到 [member pen_at] 层的那一下穿透护甲。
## - 二阶：生命低于 [member low_percent]% 时积得快 [member low_bonus]%，上限不变。
## - 三阶的不屈（坚持几秒）走现有的 [member CompileInput.undying_sec]，不在这里。
## 怒气开战为 0，战斗结束就没了。反击写进战记（`faith_mechanic` / `brute_strike`）
class_name BruteRage
extends CombatEffect

const BUFF_ID := &"brute_rage"

@export var tier: int = 0
@export var percent_per_stack: int = 5
@export var cap: int = 5
@export var damage_per: int = 6
@export var pen_at: int = 3
@export var low_percent: int = 35
@export var low_bonus: int = 50

static var _buff: BuffDef = null


static func buff_def() -> BuffDef:
	if _buff == null:
		var path := ContentPaths.asset_file("buffs", String(BUFF_ID))
		_buff = load(path) as BuffDef if ResourceLoader.exists(path) else null
	return _buff


func apply(ctx: RuleContext) -> void:
	var e := ctx.event
	if e == null or ctx.owner == null or buff_def() == null:
		return
	match e.name:
		BattleEvent.BEFORE_DAMAGE:
			_spend(ctx)
		BattleEvent.DAMAGE:
			_gather(ctx, e)


func _gather(ctx: RuleContext, e: BattleEvent) -> void:
	var me := ctx.owner
	if e.side != me.side or me.dead or e.get_bool(&"cancelled"):
		return
	var src := e.get_int(&"source_side", -1)
	if src < 0 or src == me.side:
		return
	var hp_max := me.resources.maximum(BattleStats.RES_HP)
	var lost := mini(e.get_int(&"amount"), hp_max)
	if lost <= 0 or hp_max <= 0:
		return
	var weight := 100
	if tier >= 2 and me.resources.current(BattleStats.RES_HP) * 100 < hp_max * low_percent:
		weight += low_bonus
	var st := ctx.state()
	var per := StatMath.mul(hp_max, StatMath.from_percent(percent_per_stack)) * 100
	if per <= 0:
		return
	var acc := int(st.get("acc", 0)) + lost * weight
	var gain := 0
	var have := me.stacks_of(BUFF_ID)
	while acc >= per and have + gain < cap:
		acc -= per
		gain += 1
	st["acc"] = acc if have + gain < cap else 0     # 满了不攒余量：反击用掉之后从头积
	if gain > 0:
		ApplyStatus.give(ctx, me, buff_def(), gain)


func _spend(ctx: RuleContext) -> void:
	var p := ctx.damage()
	if p == null or p.source_side != ctx.owner.side or not p.direct or p.source_uid == 0:
		return
	if not SkillMomentum.is_attack(SkillMomentum.category_of(ctx.owner.tags_of(p.source_uid))):
		return
	var n := ctx.owner.stacks_of(BUFF_ID)
	if n <= 0:
		return
	RemoveStatus.take(ctx, ctx.owner, BUFF_ID, n, "spent")
	p.add_percent(StatMath.from_percent(damage_per * n))
	if tier >= 1 and n >= pen_at:
		p.penetration = true
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": "brute_strike", "count": n})


func describe() -> String:
	return UiText.t("fx.brute_rage") % [percent_per_stack, cap]
