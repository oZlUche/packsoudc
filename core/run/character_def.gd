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
## 221 F5: description in other languages, {"en": ...}
@export var descriptions: Dictionary = {}
## 战斗基线的覆盖项（4.2 的属性键 → 值），没写的沿用 [CombatantBaseline.DEFAULT_STATS]
@export var base_stats: Dictionary = {}
## 体力上限（7.1）
@export var vitality_max: int = 5
## 作战棋盘的尺寸（149：三个人各不相同，7 / 8 / 9 × 6）
@export var board_size: Vector2i = Vector2i(8, 6)
## 149：开局钱的基数（科技「行囊」按它乘百分比）。-1 = 用经济规则的全局 [member EconomyRules.starting_balance]
@export var starting_funds: int = -1
## 初始包：道具 id，可重复。225 起只是「首次见面礼」—— 第一次选这个角色时送进包架（[method MetaState.grant_starting_bags]）；
## 255：选角色屏用一枚小签说一下，送过就不显示。没有开局屏摆盘（测试、直开）时照旧开局摆在棋盘上
@export var starting_bags: Array[StringName] = []
## 129：负重上限（单位「重」）。0 = 不算负重
@export var weight_capacity: int = 0
## 带入件数上限，-1 = 不限
@export var carry_max_items: int = -1
## 带入的稀有度上限（[ItemDef.rarity]），-1 = 不限
@export var carry_rarity_cap: int = -1
## 局内技能（082，作者定）：[RunSkill] 构件 —— 被动常驻（一局规则 / 掉落的效果，开局编进 RunContext）+ 可选的主动一击（地图屏上用，次数与冷却由 [RunSkills] 记账）
@export var skills: Array[RunSkill] = []
## 255：短板 —— 每个角色必有一条（136），和 [member skills] 里的被动同一套构件（一局规则 / 掉落 / 战斗规则），编译时一并算进去，界面上单列、永远排最后
@export var flaw: RunSkill
## 255：随身之物 —— 开局钉在棋盘上的道具（自带底板、拿不下、丢不掉、不进仓库），每局重发
@export var fixed_items: Array[FixedItem] = []
## 255：棋盘缺格（格坐标）；空 = 整块矩形。缺格不能放包、不能放东西，画成透空
@export var board_mask: Array[Vector2i] = []

## 255：角色棋盘最宽几格 —— 导入器拦着；255 补充一（作者 10:51）：所有面板按这么宽定尺寸，窄的棋盘居中、差额是内距
const BOARD_MAX_W := 9


## 这个角色的战斗基线：默认值盖上覆盖项。编译器与战斗不认识角色，只认基线（4.2）
func baseline() -> CombatantBaseline:
	var b := CombatantBaseline.default_baseline()
	for key in base_stats:
		b.base_stats[StringName(String(key))] = float(base_stats[key])
	return b


## 技能与短板（255）—— 编译时一并算的那几条
func traits() -> Array[RunSkill]:
	var out: Array[RunSkill] = []
	for s in skills:
		if s != null:
			out.append(s as RunSkill)
	if flaw != null:
		out.append(flaw)
	return out


## 全部技能（含短板）的被动部分：一局规则的效果
func run_effects() -> Array[RunEffect]:
	var out: Array[RunEffect] = []
	for s in traits():
		out.append_array(s.run_effects())
	return out


func loot_effects() -> Array[LootEffect]:
	var out: Array[LootEffect] = []
	for s in traits():
		out.append_array(s.loot_effects())
	return out


## 136：全部技能（含短板）的战斗规则（编译玩家时挂到单位上）
func combat_rules() -> Array[AbilityRule]:
	var out: Array[AbilityRule] = []
	for s in traits():
		out.append_array(s.rules)
	return out


## 255：短板那一条（选角色屏的最后一行）：名字、说明；没有短板 = 空
func flaw_entry() -> Dictionary:
	if flaw == null:
		return {}
	return {"name": Names.of(flaw), "text": _skill_text(flaw)}


## 255：按这个角色把棋盘造型 —— 缺格挖掉、随身之物钉上去（[method ItemInstance.set_pinned]）。
## [param next_uid] 给了（`func() -> int`）就用它发号（开局屏走局外号段），不给用 [method ItemInstance.create] 自增的。返回钉上去的几件
func shape_board(board: GridInventory, items: ItemDatabase, next_uid: Callable = Callable()) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if board == null:
		return out
	board.begin_batch()
	for c in board_mask:
		board.set_blocked(c, true)
	for f in fixed_items:
		var def := items.get_def(f.id) if items != null and f != null else null
		if def == null:
			continue
		var inst := ItemInstance.create(def, f.rot)
		if next_uid.is_valid():
			inst.uid = int(next_uid.call())
		inst.set_pinned(true)
		if board.place(inst, f.origin, f.rot):
			out.append(inst)
		else:
			push_warning("CharacterDef.shape_board: %s 的随身之物 %s 摆不上 %s" % [id, f.id, f.origin])
	board.end_batch()
	return out


## 255：棋盘总格、缺格、随身之物占格 —— 题字「棋盘 8 × 6 格　可用 46 格」用。{"total", "missing", "pinned", "usable"}
func board_counts(items: ItemDatabase) -> Dictionary:
	var total := board_size.x * board_size.y
	var pinned := 0
	for f in fixed_items:
		var def := items.get_def(f.id) if items != null and f != null else null
		if def != null:
			pinned += def.cells_rotated(f.rot).size()
	return {"total": total, "missing": board_mask.size(), "pinned": pinned, "usable": total - board_mask.size() - pinned}


## 技能的一句话：每个技能「名字（主动、被动各一句）」；166 补充一：主动技能藏着时只列被动
func skills_summary() -> String:
	var parts: Array[String] = []
	for s in skills:
		if s != null and not (RunSkills.ACTIVE_HIDDEN and (s as RunSkill).is_active()):
			parts.append((s as RunSkill).summary())
	return UiText.t("log.skill_sep").join(parts)


## 136：开局屏的分组行：被动在前、主动在后，各一行「被动：名字　说明」（作者定：角色 = 初始面板 + 技能，没有身份这一层）。
## 166 补充一：主动技能藏着（[constant RunSkills.ACTIVE_HIDDEN]）时只有被动行
func skill_lines() -> Array[String]:
	var out: Array[String] = []
	for active in ([false] if RunSkills.ACTIVE_HIDDEN else [false, true]):
		for s in skills:
			var sk := s as RunSkill
			if sk != null and sk.is_active() == active:
				out.append(UiText.t("log.skill_line") % [UiText.t("log.skill_active") if active else UiText.t("log.skill_passive_kind"), _skill_line(sk)])
	return out


## 179：选角色屏一条技能拆成两行由界面排 ——「被动 / 主动」、名字、说明（主动的次数 / 冷却附在说明末尾）；顺序和 [method skill_lines] 一样
func skill_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for active in ([false] if RunSkills.ACTIVE_HIDDEN else [false, true]):
		for s in skills:
			var sk := s as RunSkill
			if sk != null and sk.is_active() == active:
				out.append({"kind": UiText.t("log.skill_active") if active else UiText.t("log.skill_passive_kind"), "name": Names.of(sk), "text": _skill_text(sk), "skill": sk})
	return out


static func _skill_line(sk: RunSkill) -> String:
	return UiText.t("log.skill_name_text") % [Names.of(sk), _skill_text(sk)]


## 技能的说明（主动的次数 / 冷却附在末尾）
static func _skill_text(sk: RunSkill) -> String:
	var text := Names.description_of(sk) if sk.description != "" else sk.summary()
	var bits: Array[String] = []
	if sk.is_active():
		if sk.uses >= 0:
			bits.append(UiText.t("log.skill_uses") % sk.uses)
		if sk.cooldown_steps > 0:
			bits.append(UiText.t("log.skill_cooldown_steps") % sk.cooldown_steps)
	return text + ((UiText.t("log.skill_bits") % UiText.t("log.comma_sep").join(bits)) if not bits.is_empty() else "")


## 带入的东西合不合上限。[param defs] 是要带的（非包）道具定义；返回不合的原因，空串 = 合
func carry_problem(defs: Array) -> String:
	if carry_max_items >= 0 and defs.size() > carry_max_items:
		return UiText.t("log.carry_max") % [carry_max_items, defs.size()]
	if carry_rarity_cap >= 0:
		for d in defs:
			var def := d as ItemDef
			if def != null and def.rarity > carry_rarity_cap:
				return UiText.t("log.carry_rarity") % [def.display_name, def.rarity, carry_rarity_cap]
	return ""
