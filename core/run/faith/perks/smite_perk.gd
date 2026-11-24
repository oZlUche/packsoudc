## 蛮神 3 级（093；188 补充一作者改写）：消耗 [member vitality_cost] 体力，立即击败非首领敌人 —— 战前准备屏一个按钮。
## 372：祈愿删了，花祈愿的那个按钮跟着去掉；第二批改成「拿到这张质变牌得 N 次」
class_name SmitePerk
extends FaithPerk

@export var vitality_cost: int = 1
## 哪些点能用（核心 = 首领，不在里面）
@export var types: Array[StringName] = [&"battle", &"elite"]
const VITALITY := &"vitality"
## 388 第 1 批：蛮神的【神罚】—— 填了 [member card] 就改成「拿了这张牌、一局几次」：普通敌人用一次；
## 拿了 [member up_card] 精英、猎手也能用、一次耗 [member up_cost]（牌里的 `cost`）；次数 = 这几张牌的 `uses` 相加。不耗体力
@export var card: StringName = &""
@export var up_card: StringName = &""
@export var more_card: StringName = &""
const USES := &"uses"
## 用掉的次数记在 [member LevelModule.god_state] 里的这一格
const USED_KEY := "smite_used"


## 388：一局一共几次（没拿牌 = 0）
func uses_total(run: RunState) -> int:
	var lv := LevelModule.of(run)
	if lv == null or card == &"" or not lv.has_card(card):
		return 0
	return roundi(lv.god_value(card, "uses") + lv.god_value(up_card, "uses") + lv.god_value(more_card, "uses"))


func uses_left(run: RunState) -> int:
	var lv := LevelModule.of(run)
	return maxi(0, uses_total(run) - int(lv.god_state.get(USED_KEY, 0))) if lv != null else 0


## 388：这一类点用一次耗几次（用不了 = 0）
func cost_for(run: RunState, type: StringName) -> int:
	if type == &"battle":
		return 1
	var lv := LevelModule.of(run)
	if lv != null and up_card != &"" and lv.has_card(up_card) and type in [&"elite", &"hunter"]:
		return maxi(1, roundi(lv.god_value(up_card, "cost", 2.0)))
	return 0


func prebattle_actions(run: RunState, type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if card != &"":
		var cost := cost_for(run, type) if uses_total(run) > 0 else 0
		if cost > 0:
			out.append({"option": USES, "label": UiText.t("perk.smite_uses") % [cost, uses_left(run)],
				"why": "" if uses_left(run) >= cost else UiText.t("perk.smite_uses_short")})
		return out
	if not types.has(type) or run == null or run.vitality == null:
		return out
	out.append({"option": VITALITY, "label": UiText.t("perk.smite_vitality") % vitality_cost,
		"why": "" if run.vitality.current > vitality_cost else UiText.t("perk.smite_vitality_short")})
	return out


func prebattle_apply(run: RunState, option: StringName = VITALITY) -> bool:
	if run == null or run.events.pending_battle.is_empty():
		return false
	var type := StringName(String(run.events.pending_battle.get("type", "battle")))
	for a in prebattle_actions(run, type):
		if a["option"] != option:
			continue
		if String(a["why"]) != "":
			return false
		if option == USES:
			var lv := LevelModule.of(run)
			lv.god_state[USED_KEY] = int(lv.god_state.get(USED_KEY, 0)) + cost_for(run, type)
			return run.events.smite_pending_battle()
		run.vitality.spend(vitality_cost, &"smite")
		return run.events.smite_pending_battle()
	return false


func _summary() -> String:
	if card != &"":
		return ""     # 388：神罚的字在牌上
	return UiText.t("perk.smite_summary") % vitality_cost
