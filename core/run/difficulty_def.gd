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
## 开哪些机制
@export var mechanics: Array[RunMechanic] = []
## 数值修饰（RunEffect / LootEffect）
@export var effects: Array[Effect] = []
## 127：这一档的搜索保底和阶梯表（[member SearchRules.search_floors]）不一样时写这里（绝对值）：
## `{"normal": [...], "advanced": [...]}`，没写的那种沿用阶梯
@export var search_floors: Dictionary = {}


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


## 开局屏的一句话：机制与修饰各自的 describe 连起来
func summary() -> String:
	var parts: Array[String] = []
	for m in mechanics:
		var mech := m as RunMechanic
		if mech != null and mech.describe() != "":
			parts.append(mech.describe())
	for e in effects:
		if e != null and e.has_method("describe") and String(e.call("describe")) != "":
			parts.append(String(e.call("describe")))
	return "　".join(parts) if not parts.is_empty() else "没有额外机制"
