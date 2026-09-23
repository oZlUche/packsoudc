## 角色（058 第 2 条，报告 067）：开一局时按角色变的那几样 —— 战斗基线、体力上限、棋盘尺寸、初始包、带入上限。
##
## 7.1 说过「等真的有第三样按角色变的东西再建」；带入限制是第三样，现在建。**没有搜索速度**（作者：搜索在战斗外、不是实时的）。
## 带入的真正限制是初始包的空间：开局屏把初始包摆在棋盘上，从仓库往包里拖，放得进的就是带的（包不能带入，仓库里本来也没有包）。
## 件数与稀有度上限是字段，默认 -1 = 不限（作者：改成字段，默认不限）。
##
## 走内容管线：`data/authoring/characters/*.json` → `data/characters/*.tres`，排在道具与开局装备之后（初始包对着道具查）。
## 现在一个占位角色 `default`；角色系统落地时加文件，界面上就多一张卡。
class_name CharacterDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
## 战斗基线的覆盖项（4.2 的属性键 → 值），没写的沿用 [CombatantBaseline.DEFAULT_STATS]
@export var base_stats: Dictionary = {}
## 体力上限（7.1）
@export var vitality_max: int = 5
## 作战棋盘的尺寸
@export var board_size: Vector2i = Vector2i(8, 6)
## 初始包：道具 id，可重复。开局摆在棋盘上；带入的东西只能放进它们
@export var starting_bags: Array[StringName] = []
## 带入件数上限，-1 = 不限
@export var carry_max_items: int = -1
## 带入的稀有度上限（[ItemDef.rarity]），-1 = 不限
@export var carry_rarity_cap: int = -1
## 被动技能（069 第六节）：一局规则的效果构件（侦察、潜行、逃跑……和 buff 同一套），开局编进 RunContext；主动技能以后走事件层
@export var skills: Array[Effect] = []


## 这个角色的战斗基线：默认值盖上覆盖项。编译器与战斗不认识角色，只认基线（4.2）
func baseline() -> CombatantBaseline:
	var b := CombatantBaseline.default_baseline()
	for key in base_stats:
		b.base_stats[StringName(String(key))] = float(base_stats[key])
	return b


func run_effects() -> Array[RunEffect]:
	var out: Array[RunEffect] = []
	for e in skills:
		if e is RunEffect:
			out.append(e)
	return out


func loot_effects() -> Array[LootEffect]:
	var out: Array[LootEffect] = []
	for e in skills:
		if e is LootEffect:
			out.append(e)
	return out


## 技能的一句话
func skills_summary() -> String:
	var parts: Array[String] = []
	for e in skills:
		if e != null and e.has_method("describe") and String(e.call("describe")) != "":
			parts.append(String(e.call("describe")))
	return "　".join(parts)


## 带入的东西合不合上限。[param defs] 是要带的（非包）道具定义；返回不合的原因，空串 = 合
func carry_problem(defs: Array) -> String:
	if carry_max_items >= 0 and defs.size() > carry_max_items:
		return "最多带 %d 件，现在 %d 件" % [carry_max_items, defs.size()]
	if carry_rarity_cap >= 0:
		for d in defs:
			var def := d as ItemDef
			if def != null and def.rarity > carry_rarity_cap:
				return "「%s」的稀有度 %d 超过上限 %d" % [def.display_name, def.rarity, carry_rarity_cap]
	return ""
