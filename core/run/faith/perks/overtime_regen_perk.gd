## 自然 5 级（103，作者定；替换 093 的「平局算胜」—— 加时与衰竭之后已经不会平局）：加时阶段大量回血。
## 往玩家身上挂一条普通规则：自己身上出现「鏖战」（加时开始，第 30 秒）→ 获得「回春」（不可叠层、永续、每秒回血 +[member amount]）。
## 回春是普通 buff（不是系统效果）：进 buff 栏，也能被对手净化 —— 被净化了，下一次加时叠层时再上身
class_name OvertimeRegenPerk
extends FaithPerk

const BUFF_ID := &"nature_overtime_regen"

## 每秒回血（保留可调：nature.json 里填）
@export var amount: float = 8.0


func modify_spec(spec: CombatantSpec, _board: GridInventory, _run: RunState) -> void:
	spec.set_rules.append(rule())


## 那一条规则（测试与预估也用它）
func rule() -> AbilityRule:
	var r := AbilityRule.new()
	var trig := OnStacksAtLeast.new()
	trig.buff_id = OvertimeRules.OVERTIME_ID
	trig.stacks = 1
	trig.on_self = true
	r.trigger = trig
	r.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	var eff := ApplyStatus.new()
	eff.target = CombatEffect.Target.SELF
	eff.buff = regen_buff()
	r.effects.append(eff)
	return r


func regen_buff() -> BuffDef:
	var b := BuffDef.new()
	b.id = BUFF_ID
	b.display_name = "回春"
	b.display_names = {"en": "Rejuvenation"}
	b.max_stacks = 1
	var m := StatModifier.new()
	m.stat = BattleStats.REGEN_HP
	m.flat = amount
	b.mods.append(m)
	return b


func describe() -> String:
	return note if note != "" else "加时开始后获得回春：每秒回血 +%.0f" % amount
