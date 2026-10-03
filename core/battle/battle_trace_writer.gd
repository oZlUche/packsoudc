## 把一场的内部日志与回放存档写进 [constant BattleArchive.DIR]（117）：`.jsonl` + `.txt` + `.replay.json`，写完滚动删旧。
##
## [param info] 由开打的那一方填（[NodeEvents]、战斗沙盒）：
## [codeblock]
## run_seed, chapter, node, enemy（对手 id）, enemy_content（敌人内容原样）, rng_seed, time_limit（秒）,
## names: [{uid: 名字}, {uid: 名字}],  boards: [GridInventory.to_dict 或 {}, ...]
## [endcodeblock]
## 文件头再补上现实时间、开战快照、胜负与时长。回放存档**不存双方编译结果**（作者定：回放用不上，日志里有全过程，真要重算有种子 + 沙盒）
class_name BattleTraceWriter
extends RefCounted


## 写三份文件，返回这场的文件主干的完整路径（不带扩展名）；写不了返回空
static func write(trace: BattleTrace, result: BattleResult, info: Dictionary, dir: String = BattleArchive.DIR, keep: int = BattleArchive.KEEP) -> String:
	if trace == null or result == null:
		return ""
	DirAccess.make_dir_recursive_absolute(dir)
	var when := Time.get_datetime_string_from_system(false, true)
	var head := info.duplicate(true)
	head.erase("boards")     # 棋盘只进回放存档：日志头写道具名表就够查，整张棋盘太占地方
	head["when"] = when
	head["winner"] = result.winner
	head["duration"] = result.duration
	head["initial"] = result.initial
	trace.header = head
	var stem := BattleArchive.new_stem(dir, info)
	var base := dir.path_join(stem)
	if not _store(base + BattleArchive.TRACE_EXT, trace.to_jsonl()):
		return ""
	_store(base + BattleArchive.TEXT_EXT, trace.to_text())
	var replay := {
		"version": BattleArchive.VERSION, "when": when, "run_seed": info.get("run_seed", 0), "chapter": String(info.get("chapter", "")),
		"node": int(info.get("node", -1)), "enemy": String(info.get("enemy", "")), "enemy_content": info.get("enemy_content", {}),
		"names": JSON.from_native(info.get("names", [{}, {}])), "boards": JSON.from_native(info.get("boards", [{}, {}])),
		"result": JSON.from_native(result.to_dict()),
	}
	_store(base + BattleArchive.REPLAY_EXT, JSON.stringify(replay))
	BattleArchive.prune(dir, keep)
	return base


static func _store(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("BattleTraceWriter: 写不了 %s（%s）" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	return true
