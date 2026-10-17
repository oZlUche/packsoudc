## 日神 1 / 3 级（093）：开战时 [member count] 把武器（0 = 全部）火焰附魔 —— 每出手附带火焰伤害
## max(固定值, 武器伤害 × 百分比)。
##
## 105：这条 perk 不再自己遍历编译结果、自己掷随机、自己挂规则 —— 它只往 [CompileInput] 放一条
## [ScopedMod]（筛武器、要有规则、按种子挑 count 把、给它们挂附火规则），筛与挑都是编译器做的。
## 祈祷攒的火焰加成也不再塞进 [FireEnchant]：它是标准轴 `fire_damage`（[AltarPrayFirePerk]），
## 所以灼烧之类别的火焰来源一起吃到。
##
## 105 第十节：原来的 `stamina_cost_percent`（3 级给武器 −20% 耐力消耗）也搬走了 ——
## 那是「开战带几层灵巧」，归通用的 [AxisBoostPerk]，和附魔是两件事
class_name EnchantWeaponsPerk
extends FaithPerk

@export var count: int = 3
@export var fixed: float = 3.0
@export var percent: int = 30
@export var weapon_tag: StringName = &"weapon"
## 175 补充五（待定 补 5.1 A）：每下附火给对手施加几层哪个状态 —— 附火只是火焰伤害，灼伤要另写施加（空 / 0 = 不施加）
@export var applies_buff: StringName = &"scorch"
@export var applies_stacks: int = 1


func compile_into(input: CompileInput, _board: GridInventory, run: RunState) -> void:
	var scope := ScopedMod.new()
	var faith := run.active_faith() if run != null else null
	scope.origin = FaithTags.tag_of(faith.id) if faith != null else &""     # 108：武器悬浮窗写「← 日神」
	scope.tags = [weapon_tag] as Array[StringName]
	scope.require_active = true     # 没规则的武器根本不出手，附上去也不会触发
	scope.pick = count
	scope.rules = [rule()] as Array[AbilityRule]
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
	var b: BuffDef = ContentLibrary.buffs().get(applies_buff, null) if applies_buff != &"" and applies_stacks > 0 else null
	if b != null:
		var app := ApplyStatus.new()
		app.buff = b
		app.stacks = applies_stacks
		r.effects.append(app)
	return r


func _summary() -> String:
	var line := "开战时%s火焰附魔（每击附带火焰伤害：武器伤害的 %d%%，至少 %.0f 点）" % ["全部武器" if count <= 0 else "随机 %d 把武器" % count, percent, fixed]
	if applies_buff != &"" and applies_stacks > 0:
		line += "，并施加 %d 层%s" % [applies_stacks, Glossary.status_name(applies_buff)]
	return line
