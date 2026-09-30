## 大地 2 级（093）：在神坛锻炼，获得局内临时的额外棋盘空间（每次 +rows 行）
class_name AltarTrainBoardPerk
extends FaithPerk

@export var rows: int = 1
@export var max_times: int = 0
const KEY := "train_board"


func altar_label() -> String:
	return "锻炼（棋盘 +%d 行）" % rows


func altar_available(run: RunState, _node: MapNode) -> String:
	return "" if max_times <= 0 or int(run.faith_rituals.get(KEY, 0)) < max_times else "锻炼已到上限"


func altar_apply(run: RunState, _node: MapNode, _option: StringName = &"") -> String:
	run.board.grow_rows(rows)
	run.faith_rituals[KEY] = int(run.faith_rituals.get(KEY, 0)) + 1
	return "向大地之神锻炼：棋盘多了 %d 行（现在 %d × %d）" % [rows, run.board.size.x, run.board.size.y]


func describe() -> String:
	return note if note != "" else "神坛：锻炼，棋盘 +%d 行（局内）" % rows
