## 大地 2 级（093）：在神坛锻炼，获得局内临时的额外棋盘空间（每次 +rows 行）
class_name AltarTrainBoardPerk
extends FaithPerk

@export var rows: int = 1
@export var max_times: int = 0
const KEY := "train_board"


func altar_label() -> String:
	return UiText.t("perk.train_label") % rows


func altar_available(run: RunState, _node: MapNode) -> String:
	var rituals := AltarModule.rituals_of(run)
	return "" if max_times <= 0 or int(rituals.get(KEY, 0)) < max_times else UiText.t("perk.train_capped")


func altar_apply(run: RunState, _node: MapNode, _option: StringName = &"") -> String:
	run.board.grow_rows(rows)
	var rituals := AltarModule.rituals_of(run)
	rituals[KEY] = int(rituals.get(KEY, 0)) + 1
	return UiText.t("perk.train_done") % [rows, run.board.size.x, run.board.size.y]


func _summary() -> String:
	return UiText.t("perk.train_summary") % rows
