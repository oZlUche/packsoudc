## 编译一个战斗单位要的全部外来加成（报告 105 第三节）。
##
## [b]战斗单位只有一个来源[/b]：`core/run` 把套装、一局 buff、信力、信仰效果全部翻译成这一份输入，
## [BattleCompiler] 自己并；谁都不再拿着编译结果改。在它之前，信仰的 8 条 perk 是编译完再
## `modify_spec(spec)` —— 同一个单位两个来源，预估与真打也就有了两套代码路径。
##
## 编译器不认识 [RunState]：随机挑选要的那点随机性以 [member seed] 的形式传进来，
## 所以 `compile` 仍是纯函数 —— 同样的棋盘 + 同样的这份输入，永远同样的结果。
class_name CompileInput
extends RefCounted

## 角色自带的那份属性；null = 用 [method CombatantBaseline.default_baseline]
var baseline: CombatantBaseline = null
## 信力（082）：信仰标签 → 现在第几阶
var faith_tiers: Dictionary = {}
## 信力：信仰标签 → 现在多少点
var faith_points: Dictionary = {}

## 整单位：给每一件参战道具（套装、一局 buff）
var mods: Array[StatModifier] = []
## 单位级规则（套装、一局 buff、低血增伤、加时回春）：挂在单位上，来源 uid 为 0
var rules: Array[AbilityRule] = []
## 施加到基线（食物护盾、`stat_mod(baseline)`）。第 9 步才算 `max_hp`，所以改基线生命不用再手工补账
var baseline_mods: Array[StatModifier] = []
## 按件（3.2）：按下标顺序施加
var scoped: Array[ScopedMod] = []

## 标准轴（4.3）→ 开战时的层数。种进**系统层**：这一场的常驻加成，对手的净化洗不掉
var axes: Dictionary = {}

## 结算旗子（093 蛮神 4 级）：生命归零后还能坚持几秒。多个来源取最大
var undying_sec: float = 0.0

## 按件随机挑选用。调用方算好（`hash(run_seed, "compile", clock.total)`），一局之内不变 ——
## 所以拖动预估挑的和真打挑的是同一批
var seed: int = 0


## 六个参数的老签名用的那条路（测试与只关心棋盘的调用方）
static func of(
	baseline: CombatantBaseline = null,
	mods: Array[StatModifier] = [] as Array[StatModifier],
	rules: Array[AbilityRule] = [] as Array[AbilityRule],
	faith_tiers: Dictionary = {}, faith_points: Dictionary = {}
) -> CompileInput:
	var input := CompileInput.new()
	input.baseline = baseline
	input.mods = mods
	input.rules = rules
	input.faith_tiers = faith_tiers
	input.faith_points = faith_points
	return input


## 多个来源的坚持时间取最大（而不是相加）
func keep_undying(seconds: float) -> void:
	undying_sec = maxf(undying_sec, seconds)


## 往一条轴上加层
func shift_axis(axis: StringName, stacks: int) -> void:
	if stacks == 0:
		return
	axes[axis] = int(axes.get(axis, 0)) + stacks
