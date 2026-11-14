## 进阶难度（069，作者：像杀戮尖塔的进阶，但不只提升数值，要加入机制）。
##
## 一档难度是一份**清单**：开哪些机制（[RunMechanic] 构件，各带参数）、顺带哪些数值修饰（[RunEffect]，062 的 RUN 分支，
## 体力上限、开局钱、商店价、幸运……和局外 buff 同一套构件）。没有难度定义 = 普通难度 = 现在的一切。
## 与 [ChapterDef.difficulty] 不是一回事：那是这一章本身多难（敌人档位用），这是玩家主动加的。
##
## 作者：局外解锁的特殊选项 —— [member requires_unlock] 是局外的解锁 id（[MetaState.unlocks]），空 = 一直可选。
## 走内容管线：`data/authoring/difficulties/*.json` → `data/difficulties/*.tres`。
class_name DifficultyDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 088：别的语言的名字，`{"en": "Knife"}`；界面用 [method Names.of] 取（当前语言没有就用 display_name）
@export var display_names: Dictionary = {}
@export var description: String = ""
## 221 F5: description in other languages, {"en": ...}
@export var descriptions: Dictionary = {}
## 180：开局屏「当前难度」下面的红字 —— 这一级**新加**的挑战，一句话、玩家的说法（数据不累积，开局屏把 1..这一级的逐行列出）。
## [member description] 留给图鉴 / 调试
@export var challenge: String = ""
## 221 F5: challenge in other languages
@export var challenges: Dictionary = {}
## 第几档，0 = 普通。开局屏按它排序
@export var level: int = 0
## 局外解锁 id，空 = 一直可选
@export var requires_unlock: StringName = &""
## 241：在这一档成功撤离就发的局外解锁 id（Ⅰ 发 ascension_2、Ⅱ 发 ascension_3，同 [member ChapterDef.grants_unlock]），空 = 不发
@export var grants_unlock: StringName = &""
## 开哪些机制
@export var mechanics: Array[RunMechanic] = []
## 数值修饰（RunEffect / LootEffect）
@export var effects: Array[Effect] = []
## 127：这一档的搜索保底和阶梯表（[member SearchRules.search_floors]）不一样时写这里（绝对值）：
## `{"normal": [...], "advanced": [...]}`，没写的那种沿用阶梯
@export var search_floors: Dictionary = {}
## 320 A1：普通敌人（猎手以外，精英、核心也算）最大生命多几成（百分数，10 = ×1.10）—— 绝对值，不随档位连乘；0 = 不改。
## 有档案的章（切片、教程）不吃。写成百分数是为了说明文本能写 {enemy_hp_percent}
@export var enemy_hp_percent: int = 0
## 320 A4：普通战斗点里换成更强一种敌人的份额（百分数，[AdvancedPool]，按配额取整）；0 = 不换
@export var advanced_percent: int = 0
## 离入口最近的几场普通战斗不换
@export var advanced_skip_first: int = 2
## 320 A5：猎手最大生命多几成（百分数，乘在段内渐变上）；0 = 不改
@export var hunter_hp_percent: int = 0
## 320 A8：猎手直接攻击伤害多几成（百分数：武器 / 法杖那一下；流血层数、反伤、固定附伤不算）；0 = 不改
@export var hunter_damage_percent: int = 0
## 320 A6：信仰第二阶起的累计门槛多几成（百分数；首阶不变，取整后严格递增）；0 = 不改
@export var faith_threshold_percent: int = 0
## 320 A7：倒计时按行动点多扣几成（百分数；按累计行动点算，向下取整，不逐步进位）；0 = 不改
@export var countdown_percent: int = 0
## 320 A10：猎手追击加速（百分数）：每次原本能走的机会攒这么多，攒满一百多走一步（[HunterSystem]，不和倒计时共用）；0 = 不加
@export var hunter_chase_percent: int = 0
## 320 A10 安全窗口：猎手离玩家只差开打距离再加这么多步时不多走（0 = 只看开打距离）
@export var hunter_chase_window: int = 0


func run_effects() -> Array[RunEffect]:
	var out: Array[RunEffect] = []
	for e in effects:
		if e is RunEffect:
			out.append(e)
	return out


func loot_effects() -> Array[LootEffect]:
	var out: Array[LootEffect] = []
	for e in effects:
		if e is LootEffect:
			out.append(e)
	return out


## 这一档猎手机制的段位表（[member HunterMechanic.bracket_steps] 的一份拷贝）；没开猎手给空。校准工具按它分段
func hunter_bracket_steps() -> Array[int]:
	var out: Array[int] = []
	for m in mechanics:
		if m is HunterMechanic:
			return (m as HunterMechanic).bracket_steps.duplicate()
	return out


## 320 A1：普通敌人生命的最终倍率
func enemy_hp_mult() -> float:
	return 1.0 + float(enemy_hp_percent) / 100.0


## 320 A4：换成更强一种敌人的份额（0～1）
func advanced_share() -> float:
	return float(advanced_percent) / 100.0


## 320 A5：猎手生命倍率
func hunter_hp_mult() -> float:
	return 1.0 + float(hunter_hp_percent) / 100.0


## 320 A8：猎手直接攻击伤害倍率
func hunter_damage_mult() -> float:
	return 1.0 + float(hunter_damage_percent) / 100.0


## 320 A6：按这一档改过门槛的信仰表（原表不动，复制一份）。首阶不变，之后每阶 × 倍率四舍五入，至少比前一阶多 1
func scaled_faiths(defs: Dictionary) -> Dictionary:
	if faith_threshold_percent == 0:
		return defs
	var out := {}
	for fid in defs:
		var src: FaithDef = defs[fid]
		var copy := src.duplicate() as FaithDef
		copy.thresholds = scale_thresholds(src.thresholds, faith_threshold_percent)
		out[fid] = copy
	return out


static func scale_thresholds(src: Array[int], percent: int) -> Array[int]:
	var out: Array[int] = []
	for i in src.size():
		var v := src[i] if i == 0 else roundi(float(src[i]) * (1.0 + float(percent) / 100.0))
		if i > 0:
			v = maxi(v, out[i - 1] + 1)
		out.append(v)
	return out
