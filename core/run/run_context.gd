## 一局的规则被 buff 改成了什么样（059）：[RunEffect] 往这里加数，[RunState] 与各会话读自己关心的那一项。
##
## 每个字段都是「相对默认的偏移」：没有 buff 时全是 0 / 1，各系统照旧。
## 加一种可改的机制 = 这里多一个字段 + 一个 [RunEffect] 构件 + 那个系统去读。
class_name RunContext
extends RefCounted

## 体力上限加多少（开局时并入 Vitality）
var vitality_max_bonus: int = 0
## 开局钱加多少
var starting_funds_bonus: int = 0
## 2026-10-22（作者定）：战败时保住钱包里剩的钱的百分之几（行囊科技）——
## 按战败那一刻 wallet 里**实际剩的**算，不是按带进来的原始金额（否则中途花掉的钱也会被退，等于凭空造钱）
var death_refund_percent: int = 0
## 149：有基数的三样按百分比加（Σ百分数，相加不相乘）：终值 = roundi(基数 ×（1 + Σ%/100）) + Σ加算（133 的先乘后加）。
## 基数是角色的数（体力上限、负重、开局钱），见 [method scaled]
var vitality_max_mult: int = 0
var carry_capacity_mult: int = 0
var starting_funds_mult: int = 0
## 每个搜索点多搜几次
var extra_searches: int = 0
## 商店售价的倍数（1 = 原价；0.9 = 九折）
var shop_price_mult: float = 1.0
## 幸运值加多少（掉落：每点加 DropRule.luck_bonus）
var luck_bonus: int = 0
## 猎手相关（069 第六节的角色技能接口）：侦察距离（隐形的猎手在这么远以内可见，0 = 不侦察）、猎手感知距离的倍率、逃跑成功率加成
var scout_range: float = 0.0
var sense_mult: float = 1.0
var flee_bonus: float = 0.0
## 角色技能（082）：输给节点敌人前几次不扣体力（[NodeEvents] 读）；战斗基线加成，属性键 → 加多少（[RunState.compile_player] 读）
var free_losses: int = 0
var stat_bonus: Dictionary = {}
## 149：战斗基线的乘算，属性键 → Σ百分数（[StatBonus] 的 MULT）。[RunState.effective_baseline] 先乘这个再加 stat_bonus
var stat_mult: Dictionary = {}
## 149：败仗少扣几点体力（科技「不屈」；最少扣一点，[NodeEvents] 读）
var loss_discount: int = 0
## 129：负重上限加多少（科技「扛重」）
var carry_capacity_bonus: int = 0
## 136 角色：每走几步下一步不花行动点（0 = 没有；[MapTravel] 读）；休息区多回几点体力；侵蚀扣体力时少扣几点；打赢节点敌人的钱乘几
var free_step_every: int = 0
var rest_bonus: int = 0
var erosion_resist: int = 0
var battle_reward_mult: float = 1.0
## 256（安德烈乌斯「求饶」）：打输了对方开价 = 打赢的钱 × 它；0 = 不能求饶
var ransom_mult: float = 0.0
## 147：腰带多几格（默认格数在 [member BeltModule.slots]）
var belt_slots_bonus: int = 0
## 160 补一：开局往腰带里发的随身技能（id → 几个；角色能力 / 局外 buff 的 [StartingBelt]）
var belt_start: Dictionary = {}


func snapshot() -> Dictionary:
	return {
		"vitality_max_bonus": vitality_max_bonus,
		"starting_funds_bonus": starting_funds_bonus,
		"extra_searches": extra_searches,
		"shop_price_mult": shop_price_mult,
		"luck_bonus": luck_bonus,
		"scout_range": scout_range,
		"sense_mult": sense_mult,
		"flee_bonus": flee_bonus,
		"free_losses": free_losses,
		"stat_bonus": stat_bonus.duplicate(),
		"stat_mult": stat_mult.duplicate(),
		"vitality_max_mult": vitality_max_mult,
		"carry_capacity_mult": carry_capacity_mult,
		"starting_funds_mult": starting_funds_mult,
		"loss_discount": loss_discount,
		"carry_capacity_bonus": carry_capacity_bonus,
		"free_step_every": free_step_every,
		"rest_bonus": rest_bonus,
		"erosion_resist": erosion_resist,
		"battle_reward_mult": battle_reward_mult,
		"ransom_mult": ransom_mult,
		"belt_slots_bonus": belt_slots_bonus,
		"belt_start": belt_start.duplicate(),
	}


## 149：基数按百分比放大再加固定值：roundi(基数 ×（100 + Σ%）/ 100) + Σ加算。整数算，避免 40 × 1.15 落成 45.999…
static func scaled(base: int, percent: int, add: int) -> int:
	return roundi(base * (100 + percent) / 100.0) + add


## 149：体力上限（不含章节加成，章节的仍是加算，调用方自己加）
func vitality_max_of(base: int) -> int:
	return scaled(base, vitality_max_mult, vitality_max_bonus)


func carry_capacity_of(base: int) -> int:
	return scaled(base, carry_capacity_mult, carry_capacity_bonus)


func starting_funds_of(base: int) -> int:
	return scaled(base, starting_funds_mult, starting_funds_bonus)
