## 战斗日志与回放存档的目录（117，作者定）：`user://battle_logs/`，一场三份同名文件 ——
## [codeblock]
## <时间>_<种子>_n<点>_<章节>_<对手>.jsonl         内部日志，一行一条（程序读，tools/replay_log.gd 排版）
## <时间>_<种子>_n<点>_<章节>_<对手>.txt           同一份，人读
## <时间>_<种子>_n<点>_<章节>_<对手>.replay.json   回放存档（BattleResult + 名字表 + 棋盘），开发工具的「战斗回放」翻它
## [endcodeblock]
## 只留最近 [constant KEEP] 场（按文件名 = 时间排，多的三份一起删）。写是 [BattleTraceWriter]，列 / 读 / 删在这里。
## 游戏里**没有入口**（作者定：不给玩家看），只有开发工具与命令行
class_name BattleArchive
extends RefCounted

const DIR := "user://battle_logs"
const KEEP := 50
const REPLAY_EXT := ".replay.json"
const TRACE_EXT := ".jsonl"
const TEXT_EXT := ".txt"
const VERSION := 1

## 总开关。测试入口（tests/run_tests.gd）开跑前关掉，免得几百场测试战斗写满测试的 user://；测 117 的套件自己开
static var enabled: bool = true


## 设置里「战斗日志」的默认值：非导出包（编辑器、本地跑）默认开，导出包默认关
static func default_on() -> bool:
	return not OS.has_feature("template")


## 目录里全部场次的文件名主干（不带扩展名），按名字 = 时间升序
static func stems(dir: String = DIR) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var seen := {}
	for f in d.get_files():
		var stem := _stem_of(f)
		if stem != "" and not seen.has(stem):
			seen[stem] = true
			out.append(stem)
	out.sort()
	return out


static func _stem_of(file: String) -> String:
	for ext in [REPLAY_EXT, TRACE_EXT, TEXT_EXT]:
		if file.ends_with(ext):
			return file.substr(0, file.length() - String(ext).length())
	return ""


## 回放存档列表，**新的在前**：`[{path, stem, when, chapter, node, enemy, winner, duration}]`。读不了的文件跳过
static func list(dir: String = DIR) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all := stems(dir)
	all.reverse()
	for stem in all:
		var path := dir.path_join(stem + REPLAY_EXT)
		if not FileAccess.file_exists(path):
			continue
		var r := load_replay(path)
		if r.is_empty():
			continue
		var res: Dictionary = r.get("result", {})
		out.append({"path": path, "stem": stem, "when": String(r.get("when", "")), "chapter": String(r.get("chapter", "")),
			"node": int(r.get("node", -1)), "enemy": String(r.get("enemy", "")),
			"winner": int(res.get("winner", -1)), "duration": int(res.get("duration", 0))})
	return out


## 读一场回放存档：元数据照原样，`names` / `boards` / `result` 还原成写入时的类型（int 键、定点整数）。坏文件返回空
static func load_replay(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()     # 实例的 parse 不往控制台喷错 —— 坏文件是常态（写到一半被杀），跳过就好
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed = json.data
	if not (parsed is Dictionary) or int(parsed.get("version", -1)) != VERSION:
		return {}
	var out: Dictionary = parsed
	for key in ["names", "boards", "result"]:
		out[key] = JSON.to_native(out.get(key, null))
	if not (out["result"] is Dictionary):
		return {}
	return out


## 回放存档里的那场 → [BattleResult]（[param buff_defs]：buff id → [BuffDef]，查不到的 buff 不画图标）
static func result_of(replay: Dictionary, buff_defs: Dictionary = {}) -> BattleResult:
	var d = replay.get("result", null)
	return BattleResult.from_dict(d, buff_defs) if d is Dictionary else null


## 只留最近 [param keep] 场：多出来的（最旧的）三份文件一起删。返回删了几场
static func prune(dir: String = DIR, keep: int = KEEP) -> int:
	var all := stems(dir)
	var drop := all.size() - keep
	for i in maxi(0, drop):
		for ext in [REPLAY_EXT, TRACE_EXT, TEXT_EXT]:
			var p := dir.path_join(all[i] + String(ext))
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	return maxi(0, drop)


## 这场的文件主干：`<yyyymmdd-hhmmss>_<种子>_n<点>_<章节>_<对手>`；同名已有就加 `-2`、`-3`
static func new_stem(dir: String, info: Dictionary) -> String:
	var t := Time.get_datetime_dict_from_system()
	var stem := "%04d%02d%02d-%02d%02d%02d_%s_n%s_%s_%s" % [int(t["year"]), int(t["month"]), int(t["day"]),
		int(t["hour"]), int(t["minute"]), int(t["second"]), _safe(str(info.get("run_seed", 0))), _safe(str(info.get("node", -1))),
		_safe(String(info.get("chapter", ""))), _safe(String(info.get("enemy", "")))]
	var out := stem
	var n := 2
	while FileAccess.file_exists(dir.path_join(out + REPLAY_EXT)) or FileAccess.file_exists(dir.path_join(out + TRACE_EXT)):
		out = "%s-%d" % [stem, n]
		n += 1
	return out


## 文件名里只留字母、数字、下划线、减号
static func _safe(s: String) -> String:
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		if (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or ch == "_" or ch == "-":
			out += ch
	return out if out != "" else "x"
