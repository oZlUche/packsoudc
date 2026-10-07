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
## 088：别的语言的名字，`{"en": "Knife"}`；界面用 [method Names.of] 取（当前语言没有就用 display_name）
@export var display_names: Dictionary = {}
@export var description: String = ""
## 战斗基线的覆盖项（4.2 的属性键 → 值），没写的沿用 [CombatantBaseline.DEFAULT_STATS]
@export var base_stats: Dictionary = {}
## 体力上限（7.1）
@export var vitality_max: int = 5
## 作战棋盘的尺寸
@export var board_size: Vector2i = Vector2i(8, 6)
## 初始包：道具 id，可重复。开局摆在棋盘上；带入的东西只能放进它们
@export var starting_bags: Array[StringName] = []
## 129：负重上限（单位「重」）。0 = 不算负重
@export var weight_capacity: int = 0
## 带入件数上限，-1 = 不限
@export var carry_max_items: int = -1
## 带入的稀有度上限（[ItemDef.rarity]），-1 = 不限
@export var carry_rarity_cap: int = -1
## 局内技能（082，作者定）：[RunSkill] 构件 —— 被动常驻（一局规则 / 掉落的效果，开局编进 RunContext）+ 可选的主动一击（地图屏上用，次数与冷却由 [RunSkills] 记账）
@export var skills: Array[RunSkill] = []
## 136：身份（worldview 第三节「身份 = 立场与开局」）：slave / legion。事件条件 [IdentityIs] 按它分支；空 = 不分
@export var identity: StringName = &""


## 这个角色的战斗基线：默认值盖上覆盖项。编译器与战斗不认识角色，只认基线（4.2）
func baseline() -> CombatantBaseline:
	var b := CombatantBaseline.default_baseline()
	for key in base_stats:
		b.base_stats[StringName(String(key))] = float(base_stats[key])
	return b


## 全部技能的被动部分：一局规则的效果
func run_effects() -> Array[RunEffect]:
	var out: Array[RunEffect] = []
	for s in skills:
		if s != null:
			out.append_array((s as RunSkill).run_effects())
	return out


func loot_effects() -> Array[LootEffect]:
	var out: Array[LootEffect] = []
	for s in skills:
		if s != null:
			out.append_array((s as RunSkill).loot_effects())
	return out


## 136：全部技能的战斗规则（编译玩家时挂到单位上）
func combat_rules() -> Array[AbilityRule]:
	var out: Array[AbilityRule] = []
	for s in skills:
		if s != null:
			out.append_array((s as RunSkill).rules)
	return out


## 有主动一击的技能
func active_skills() -> Array[RunSkill]:
	var out: Array[RunSkill] = []
	for s in skills:
		if s != null and (s as RunSkill).is_active():
			out.append(s)
	return out


## 技能的一句话：每个技能「名字（主动、被动各一句）」
func skills_summary() -> String:
	var parts: Array[String] = []
	for s in skills:
		if s != null:
			parts.append((s as RunSkill).summary())
	return "　".join(parts)


## 136：开局屏的分组行：按槽（身份 / 擅长 / 主动）各一行「身份：名字　说明」；没写槽的技能排在最后、不带前缀
const SLOT_NAMES := {&"identity": "身份", &"talent": "擅长", &"active": "主动"}

func skill_lines() -> Array[String]:
	var out: Array[String] = []
	var loose: Array[String] = []
	for slot in SLOT_NAMES:
		for s in skills:
			var sk := s as RunSkill
			if sk != null and sk.slot == slot:
				out.append("%s：%s" % [SLOT_NAMES[slot], _skill_line(sk)])
	for s in skills:
		var sk := s as RunSkill
		if sk != null and not SLOT_NAMES.has(sk.slot):
			loose.append(_skill_line(sk))
	out.append_array(loose)
	return out


static func _skill_line(sk: RunSkill) -> String:
	var text := Names.description_of(sk) if sk.description != "" else sk.summary()
	var bits: Array[String] = []
	if sk.is_active():
		if sk.uses >= 0:
			bits.append("%d 次" % sk.uses)
		if sk.cooldown_steps > 0:
			bits.append("冷却 %d 步" % sk.cooldown_steps)
	return "%s　%s%s" % [sk.display_name, text, ("（" + "，".join(bits) + "）") if not bits.is_empty() else ""]


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
