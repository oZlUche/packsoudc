## 校准记录（069 第七节第 7 条，报告 073）：真实对局里每走一步记一份玩家的装备配置，攒起来给木桩工具用。
##
## 作者：系统完整后多场测试，每局按 3～5 个时间段取玩家的装备配置，每个配置生成一个平均木桩。
## 这里只记，不算：一行一个 JSON（`snapshots.jsonl`，追加写），记步数、搜索次数、棋盘（layout：定义、落点、朝向）、基线、角色、难度、buff。
## 分段与平均是 [DummyBuilder] 的事 —— 记录是原始数据，怎么切段以后可以改。
class_name CalibrationRecorder
extends RefCounted

const DEFAULT_PATH := "user://calibration/snapshots.jsonl"

var path: String = DEFAULT_PATH
var written: int = 0


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


## 这一刻的玩家配置
static func snapshot(run: RunState) -> Dictionary:
	var stats := {}
	if run.player_baseline != null:
		for key in run.player_baseline.base_stats:
			stats[String(key)] = float(run.player_baseline.base_stats[key])
	return {
		"seed": run.run_seed,
		"chapter": String(run.chapter.id) if run.chapter != null else "",
		"character": String(run.character_id),
		"difficulty": String(run.difficulty_id),
		"steps": run.travel.clock.total if run.travel != null and run.travel.clock != null else 0,
		"searches": run.events.searches_total() if run.events != null else 0,
		"vitality": run.vitality.current if run.vitality != null else 0,
		"board_size": [run.board.size.x, run.board.size.y],
		"requires_bag": run.board.requires_bag,
		"layout": RunState.layout_of(run.board),
		"baseline": stats,
		"buffs": run.meta_buff_ids(),
	}


## 记一行。写不了（目录没有、盘满）返回 false，不影响对局
func record(run: RunState) -> bool:
	if run == null or run.board == null:
		return false
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return false
	f.seek_end()
	f.store_line(JSON.stringify(snapshot(run)))
	f.close()
	written += 1
	return true


## 读回全部（坏行跳过）
static func read_all(p_path: String = DEFAULT_PATH) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(p_path):
		return out
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	f.close()
	return out


## 一份快照的棋盘：按 layout 原样摆回（和一局开局摆 layout 同一条路）
static func board_of(snap: Dictionary, items: ItemDatabase) -> GridInventory:
	var size_raw: Array = snap.get("board_size", [8, 6])
	var board := GridInventory.new(Vector2i(int(size_raw[0]), int(size_raw[1])), RunState.BOARD_ID, bool(snap.get("requires_bag", true)))
	RunState.place_layout(board, snap.get("layout", []), items)
	return board


static func baseline_of(snap: Dictionary) -> CombatantBaseline:
	var b := CombatantBaseline.default_baseline()
	for key in snap.get("baseline", {}):
		b.base_stats[StringName(String(key))] = float((snap["baseline"] as Dictionary)[key])
	return b


## 一份快照编译成战斗单位（棋盘 + 基线；套装与 buff 的加成不记，木桩是「平均玩家」不是「这个玩家」）
static func compile(snap: Dictionary, items: ItemDatabase) -> CombatantSpec:
	return BattleCompiler.compile_board(board_of(snap, items), baseline_of(snap))
