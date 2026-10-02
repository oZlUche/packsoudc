## 日神 1 / 3 级（093）：开战时 [member count] 把武器（0 = 全部）火焰附魔 —— 每出手附带火焰伤害
## max(固定值, 武器伤害 × 百分比)。[member stamina_cost_percent] 非 0 时顺带改武器的耐力消耗（3 级：-20）。
##
## 105：这条 perk 不再自己遍历编译结果、自己掷随机、自己挂规则 —— 它只往 [CompileInput] 放一条
## [ScopedMod]（筛武器、要有规则、按种子挑 count 把、给它们挂附火规则与改耐力消耗），筛与挑都是编译器做的。
## 祈祷攒的火焰加成也不再塞进 [FireEnchant]：它是标准轴 `fire_damage`（[AltarPrayFirePerk]），
## 所以灼烧之类别的火焰来源一起吃到
class_name EnchantWeaponsPerk
extends FaithPerk

@export var count: int = 3
@export var fixed: float = 3.0
@export var percent: int = 30
@export var stamina_cost_percent: int = 0
@export var weapon_tag: StringName = &"weapon"


func compile_into(input: CompileInput, _board: GridInventory, _run: RunState) -> void:
	var scope := ScopedMod.new()
	scope.tags = [weapon_tag] as Array[StringName]
	scope.require_active = true     # 没规则的武器根本不出手，附上去也不会触发
	scope.pick = count
	scope.rules = [rule()] as Array[AbilityRule]
	if stamina_cost_percent != 0:
		var m := StatModifier.new()
		m.stat = BattleStats.STAMINA_COST
		m.mult_category = StatMath.Buff.EMPOWER
		m.mult_percent = stamina_cost_percent
		scope.mods = [m] as Array[StatModifier]
	input.scoped.append(scope)


## 那一条附火规则（测试也用它）。`source_uids` 由编译器按件绑成「只听自己」
func rule() -> AbilityRule:
	var r := AbilityRule.new()
	r.trigger = EffectRegistry.instantiate(&"trigger", &"on_item_fired")
	r.cadence = EffectRegistry.instantiate(&"cadence", &"always")
	var eff := FireEnchant.new()
	eff.fixed = fixed
	eff.percent = percent
	r.effects.append(eff)
	return r


func _summary() -> String:
	return "开战时%s火焰附魔（每击 max(%.0f, %d%% 武器伤害) 火焰）%s" % ["全部武器" if count <= 0 else "随机 %d 把武器" % count, fixed, percent, ("，武器耐力消耗 %d%%" % stamina_cost_percent) if stamina_cost_percent != 0 else ""]
