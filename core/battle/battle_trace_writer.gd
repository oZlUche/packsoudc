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


## 236 第二项：拼三份文本、写盘、滚动删旧都在工作线程上做（开着日志时开战那一帧不再卡）；同一时间只有一份在写，
## 下一场开写前先等上一份写完（文件名要看目录里有没有重名）
static var _task: int = -1


## 写三份文件，返回这场的文件主干的完整路径（不带扩展名）；写不了返回空。
## 文件头与文件名在调用的这一帧定好，文本与写盘交给工作线程 —— 要马上读文件的先 [method flush]
static func write(trace: BattleTrace, result: BattleResult, info: Dictionary, dir: String = BattleArchive.DIR, keep: int = BattleArchive.KEEP) -> String:
	if trace == null or result == null:
		return ""
	flush()
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		push_warning("BattleTraceWriter: 建不了 %s" % dir)
		return ""
	var when := Time.get_datetime_string_from_system(false, true)
	var head := info.duplicate(true)
	head.erase("boards")     # 棋盘只进回放存档：日志头写道具名表就够查，整张棋盘太占地方
	head["when"] = when
	head["winner"] = result.winner
	head["duration"] = result.duration
	head["initial"] = result.initial
	trace.header = head
	var base := dir.path_join(BattleArchive.new_stem(dir, info))
	var copy := info.duplicate(true)
	_task = WorkerThreadPool.add_task(_write_files.bind(trace, result, copy, when, base, dir, keep), false, "BattleTraceWriter")
	return base


## 等手上那一份写完（测试查文件前、回放浏览器列目录前、退出前）
static func flush() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## 工作线程上：开战之后 trace / result 不再被改，读它们是安全的
static func _write_files(trace: BattleTrace, result: BattleResult, info: Dictionary, when: String, base: String, dir: String, keep: int) -> void:
	if not _store(base + BattleArchive.TRACE_EXT, trace.to_jsonl()):
		return
	_store(base + BattleArchive.TEXT_EXT, trace.to_text())
	var replay := {
		"version": BattleArchive.VERSION, "when": when, "run_seed": info.get("run_seed", 0), "chapter": String(info.get("chapter", "")),
		"node": int(info.get("node", -1)), "enemy": String(info.get("enemy", "")), "enemy_content": info.get("enemy_content", {}),
		"names": JSON.from_native(info.get("names", [{}, {}])), "boards": JSON.from_native(info.get("boards", [{}, {}])),
		"result": JSON.from_native(result.to_dict()),
	}
	_store(base + BattleArchive.REPLAY_EXT, JSON.stringify(replay))
	BattleArchive.prune(dir, keep)


static func _store(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("BattleTraceWriter: 写不了 %s（%s）" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	return true
