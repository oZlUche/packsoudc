## 信仰重构 C（交接方案 §6.6）：狩猎之神「目标拆解」。一条规则（[FaithMechanicTrigger] 听开战、伤害）放整套：
##
## - 开战按对手实际有的本事挑标记：护甲（有护甲上限）→ 恢复（每秒回血）→ 攻击节奏（有会出手的东西）→ 都没有就「暴露」。
##   [member mark] 填了就用填的（玩家手选的，不适用的退回推荐）。
## - 本方武器的原始直接命中给对手攒【拆解】（debuff，一层 = 一点），全单位每 [member point_gap_sec] 秒最多一点；持续伤害、追加的不算。
## - 到 [member stage1] 点第一档：一阶起削弱 [member weaken1]%（暴露：受到伤害 +[member exposed1]%），没到一阶只有一半；
##   二阶起到 [member stage2] 点第二档，总计削弱到 [member weaken2]%（暴露 [member exposed2]%）。
## - 削弱只在这一场：护甲按上限的比例拆掉当前值；恢复按每秒回血的比例压（失血轴）；攻击节奏走减速轴（保留最低出手能力）；暴露走易伤轴。
## 首领照样能拆（数值有上限，不封禁攻击或治疗）。到档写进战记
class_name HuntDismantle
extends CombatEffect

const BUFF_ID := &"hunt_dismantle"
const ARMOR := &"armor"
const REGEN := &"regen"
const TEMPO := &"tempo"
const EXPOSED := &"exposed"
const MARKS: Array[StringName] = [ARMOR, REGEN, TEMPO, EXPOSED]

@export var tier: int = 0
@export var mark: StringName = &""
@export var point_gap_sec: float = 0.5
@export var stage1: int = 3
@export var stage2: int = 6
@export var weaken1: int = 10
@export var weaken2: int = 20
@export var exposed1: int = 5
@export var exposed2: int = 10

static var _buff: BuffDef = null


static func buff_def() -> BuffDef:
	if _buff == null:
		var path := ContentPaths.asset_file("buffs", String(BUFF_ID))
		_buff = load(path) as BuffDef if ResourceLoader.exists(path) else null
	return _buff


## 对手有这样本事吗（[param m] 适不适用）
static func applies(m: StringName, foe: CombatantRuntime) -> bool:
	if foe == null:
		return false
	match m:
		ARMOR:
			return foe.resources.has(BattleStats.RES_ARMOR) and foe.resources.maximum(BattleStats.RES_ARMOR) > 0
		REGEN:
			return foe.stat(BattleStats.REGEN_HP, 0) > 0
		TEMPO:
			return not foe.rules.is_empty()
		EXPOSED:
			return true
	return false


## 推荐的标记：按 [constant MARKS] 的顺序，第一个适用的
static func recommended(foe: CombatantRuntime) -> StringName:
	for m in MARKS:
		if applies(m, foe):
			return m
	return EXPOSED


func apply(ctx: RuleContext) -> void:
	var e := ctx.event
	if e == null or ctx.owner == null:
		return
	var foe := ctx.opponent()
	var st := ctx.state()
	match e.name:
		BattleEvent.BATTLE_START:
			var m := mark if mark != &"" and applies(mark, foe) else recommended(foe)
			st["mark"] = String(m)
			ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": "hunt_mark", "arg": "hunt.mark_" + String(m)})
		BattleEvent.DAMAGE:
			if foe == null or foe.dead or buff_def() == null:
				return
			if e.get_int(&"source_side", -1) != ctx.owner.side or e.side == ctx.owner.side or e.get_int(&"uid") == 0 or not e.get_bool(&"direct"):
				return
			if e.get_bool(&"cancelled") or e.get_int(&"amount") <= 0:
				return
			var last := int(st.get("at", -1))
			if last >= 0 and ctx.battle.now - last < StatMath.from_float(point_gap_sec):
				return
			st["at"] = ctx.battle.now
			ApplyStatus.give(ctx, foe, buff_def(), 1)
			var pts := foe.stacks_of(BUFF_ID)
			var reached := int(st.get("stage", 0))
			if reached < 1 and pts >= stage1:
				_reach(ctx, foe, 1)
			elif reached < 2 and tier >= 2 and pts >= stage2:
				_reach(ctx, foe, 2)


## 到第 [param stage] 档：把这一档比上一档多出来的那截削弱落下去
func _reach(ctx: RuleContext, foe: CombatantRuntime, stage: int) -> void:
	var st := ctx.state()
	st["stage"] = stage
	var m := StringName(String(st.get("mark", String(EXPOSED))))
	var total := _total(m, stage)
	var delta := total - int(st.get("applied", 0))
	st["applied"] = total
	if delta <= 0:
		return
	match m:
		ARMOR:
			var cut := StatMath.mul(foe.resources.maximum(BattleStats.RES_ARMOR), StatMath.from_percent(delta))
			if cut > 0:
				foe.resources.change(BattleStats.RES_ARMOR, -cut, BattleEvent.REASON_DAMAGE)
		REGEN:
			var regen := foe.stat(BattleStats.REGEN_HP, 0)
			var flat := ceili(StatMath.to_float(StatMath.mul(regen, StatMath.from_percent(delta))))
			ShiftAxis.shift(ctx.battle, foe, StatAxes.REGEN_HP, -maxi(1, flat), false)
		TEMPO:
			ShiftAxis.shift(ctx.battle, foe, StatAxes.ATTACK_SPEED, -_more_stacks(st, StatAxes.ATTACK_SPEED, total), false)
		EXPOSED:
			ShiftAxis.shift(ctx.battle, foe, StatAxes.DAMAGE_TAKEN, _more_stacks(st, StatAxes.DAMAGE_TAKEN, total), false)
	ctx.battle.emit(BattleEvent.EFFECT_RESOLVED, ctx.owner.side, {"effect": SkillMomentum.MECHANIC, "key": "hunt_stage%d" % stage, "arg": "hunt.mark_" + String(m)})


## 轴的层数按**总量**折（至少 1 层），减去已经落下的 —— 分两档落不会因为各自取整少一层
static func _more_stacks(st: Dictionary, axis: StringName, total_percent: int) -> int:
	var step := float(StatAxes.info(axis).get("step", 1.0))
	var want := maxi(1, roundi(float(total_percent) / step))
	var had := int(st.get("stacks", 0))
	st["stacks"] = want
	return maxi(0, want - had)


## 到第 [param stage] 档时这个标记一共削弱几成（没到一阶：第一档只有一半）
func _total(m: StringName, stage: int) -> int:
	var hi := exposed2 if m == EXPOSED else weaken2
	var lo := exposed1 if m == EXPOSED else weaken1
	if stage >= 2:
		return hi
	@warning_ignore("integer_division")
	return lo if tier >= 1 else lo / 2


func describe() -> String:
	return UiText.t("fx.hunt_dismantle")
