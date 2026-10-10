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
## 129：负重上限加多少（科技「扛重」）
var carry_capacity_bonus: int = 0
## 136 角色：每走几步下一步不花行动点（0 = 没有；[MapTravel] 读）；休息区多回几点体力；侵蚀扣体力时少扣几点；打赢节点敌人的钱乘几
var free_step_every: int = 0
var rest_bonus: int = 0
var erosion_resist: int = 0
var battle_reward_mult: float = 1.0
## 147：腰带多几格（默认格数在 [member BeltModule.slots]）
var belt_slots_bonus: int = 0


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
		"carry_capacity_bonus": carry_capacity_bonus,
		"free_step_every": free_step_every,
		"rest_bonus": rest_bonus,
		"erosion_resist": erosion_resist,
		"battle_reward_mult": battle_reward_mult,
		"belt_slots_bonus": belt_slots_bonus,
	}
