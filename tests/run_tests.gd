## 无头测试入口。
##
##     "E:/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_tests.gd
##
## 全部通过退出码为 0，有失败为 1，便于将来接 CI。
extends SceneTree

## GDScript 的运行时错误会中断 _initialize，使 quit() 永远执行不到，
## 无头进程就会一直挂着（CI 里表现为超时而不是失败）。
## 这个标志让第一帧 _process 兜底退出。
var _finished: bool = false

## 两个阶段：
##
## - `run_*(t)` 在 _initialize 里跑，纯逻辑用例都在这一档；
## - `frame_*(t, root)` 在**第一帧**跑，需要节点进场景树的用例在这一档 ——
##   `_ready` 要等进入帧循环才派发，在 _initialize 里 add_child 之后立刻用，
##   控件全是 null。
##
## 分两档而不是把所有用例都挪到帧里：绝大多数用例不需要场景树，
## 让它们等一帧只是白等，而且出错时的栈更难读。
var _phase1_ok: bool = false
var _case: TestCase = null
var _started: int = 0

## 102：套件不再手写登记 —— `tests/**/test_*.gd` 扫出来（路径排序），新套件放进目录里就跑。
## 过滤：`--script res://tests/run_tests.gd -- safe` 只跑路径或用例标题里含 `safe` 的套件（`tools/test.sh safe` 透传）
const SUITE_ROOT := "res://tests"
## 不是套件的：断言收集器自己
const NOT_SUITES := ["test_case.gd"]

var _suites: Array = []


## 扫出所有套件脚本（含子目录；路径排序 —— 要先后关系就按文件名排）
static func discover(root: String = SUITE_ROOT) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and not NOT_SUITES.has(f):
			out.append(root.path_join(f))
	for sub in dir.get_directories():
		out.append_array(discover(root.path_join(sub)))
	out.sort()
	return out


## 这个套件要不要跑：空模式全跑；否则路径或某个用例标题（`t.begin("…")`）里含这个词（不分大小写）
static func matches(path: String, pattern: String) -> bool:
	if pattern == "":
		return true
	var needle := pattern.to_lower()
	if path.to_lower().contains(needle):
		return true
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n"):
		if line.contains("t.begin(") and line.to_lower().contains(needle):
			return true
	return false


## 命令行里 `--` 之后的第一个词就是过滤模式
static func pattern_of_args() -> String:
	var args := OS.get_cmdline_user_args()
	return String(args[0]).strip_edges() if not args.is_empty() else ""


func _load_suites() -> void:
	var pattern := pattern_of_args()
	for path in discover():
		if matches(path, pattern):
			var script: Resource = load(path)
			if script != null:
				_suites.append(script)
	if pattern != "":
		print("只跑含「%s」的套件：%d 个" % [pattern, _suites.size()])



func _initialize() -> void:
	_case = TestCase.new()
	_started = Time.get_ticks_msec()
	BattleArchive.enabled = false     # 117：几百场测试战斗不写战斗日志；测日志的套件自己开、自己关
	UiTheme.install()     # 121：和游戏一样装上界面主题（frame_ 用例进树的控件下一帧起都继承到）
	GameDirector.fades_allowed = false     # 157：换屏不淡入，屏幕用例的时序和以前一样
	_load_suites()

	# 套件用 run / run_xxx 拆分多组用例，这里自动发现并调用。
	# run 也走自动发现而不是写死调用 —— 只有 frame_ 用例的套件没有 run，
	# 写死会让它一加进来就崩。
	for suite in _suites:
		for m in suite.get_script_method_list():
			var n: String = m["name"]
			if (n == "run" or n.begins_with("run_")) and m["args"].size() == 1:
				suite.call(n, _case)

	_phase1_ok = true


## 第二阶段 + 兜底。
##
## 兜底：若 _initialize 被脚本错误中断，这里会把进程结束掉，
## 而不是让无头进程挂到超时。退出码 2 专表示“测试自身崩了”。
func _process(_delta: float) -> bool:
	if not _phase1_ok:
		push_error("run_tests: _initialize 未正常完成，往上看脚本错误")
		print("")
		print("======================================================")
		print("中断  测试未跑完（脚本错误），请检查上方 SCRIPT ERROR")
		print("======================================================")
		quit(2)
		return true

	# 需要场景树的用例：到这里 _ready 才派发得了
	for suite in _suites:
		for m in suite.get_script_method_list():
			var n: String = m["name"]
			if n.begins_with("frame_") and m["args"].size() == 2:
				suite.call(n, _case, root)

	_report()
	return true


func _report() -> void:
	var elapsed := Time.get_ticks_msec() - _started
	print("")
	print("======================================================")
	if _case.passed():
		print("通过  %d 项断言，%d 个套件，耗时 %d ms" % [_case.checks, _suites.size(), elapsed])
		print("======================================================")
		_finished = true
		quit(0)
		return

	print("失败  %d / %d 项断言未通过：" % [_case.failures.size(), _case.checks])
	print("------------------------------------------------------")
	for f in _case.failures:
		print("  ✗ " + f)
	print("======================================================")
	_finished = true
	quit(1)
