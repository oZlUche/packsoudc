## 自然 5 级（103，作者定；替换 093 的「平局算胜」—— 加时与衰竭之后已经不会平局）：加时阶段大量回血。
## 往玩家身上挂一条普通规则：自己「受到伤害」轴的系统层出现（加时开始，第 30 秒）→ 回血轴 +[member stacks] 层（标准轴 4.3，
## 每层每秒 +1，默认 +8 / 秒），一场一次。它记在内容层（不是系统层）：进 buff 栏显示成「回春」，也能被对手净化
class_name OvertimeRegenPerk
extends FaithPerk

## 回血轴加几层（每层每秒回 1；保留可调：nature.json 里填 stacks）
@export var stacks: int = 8


func modify_spec(spec: CombatantSpec, _board: GridInventory, _run: RunState) -> void:
	spec.set_rules.append(rule())


## 那一条规则（测试与预估也用它）
func rule() -> AbilityRule:
	var r := AbilityRule.new()
	var trig := OnAxisAtLeast.new()
	trig.axis = StatAxes.DAMAGE_TAKEN
	trig.stacks = 1
	trig.on_self = true
	trig.layer = OnAxisAtLeast.Layer.SYSTEM
	r.trigger = trig
	r.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	var once := UsesCost.new()
	once.max_uses = 1
	r.costs.append(once)
	var eff := ShiftAxis.new()
	eff.target = CombatEffect.Target.SELF
	eff.axis = StatAxes.REGEN_HP
	eff.delta = stacks
	r.effects.append(eff)
	return r


func _summary() -> String:
	return "加时开始后回春：每秒回血 +%d" % roundi(stacks * StatAxes.step_of(StatAxes.REGEN_HP))
