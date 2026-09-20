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

const SUITES: Array = [
	preload("res://tests/test_item_shape.gd"),
	preload("res://tests/test_item_instance.gd"),
	preload("res://tests/test_grid_inventory.gd"),
	preload("res://tests/test_inventory_service.gd"),
	preload("res://tests/test_item_assets.gd"),
	preload("res://tests/test_board_bags.gd"),
	preload("res://tests/test_stat_math.gd"),
	preload("res://tests/test_compiler.gd"),
	preload("res://tests/test_drag_layer.gd"),
]


func _initialize() -> void:
	var t := TestCase.new()
	var started := Time.get_ticks_msec()

	for suite in SUITES:
		suite.run(t)
		# 套件可用 run_xxx 拆分多组用例，这里自动发现并调用
		for m in suite.get_script_method_list():
			var n: String = m["name"]
			if n.begins_with("run_") and m["args"].size() == 1:
				suite.call(n, t)

	var elapsed := Time.get_ticks_msec() - started
	print("")
	print("======================================================")
	if t.passed():
		print("通过  %d 项断言，%d 个套件，耗时 %d ms" % [t.checks, SUITES.size(), elapsed])
		print("======================================================")
		_finished = true
		quit(0)
		return

	print("失败  %d / %d 项断言未通过：" % [t.failures.size(), t.checks])
	print("------------------------------------------------------")
	for f in t.failures:
		print("  ✗ " + f)
	print("======================================================")
	_finished = true
	quit(1)


## 兜底：若 _initialize 被脚本错误中断，这里会在第一帧把进程结束掉，
## 而不是让无头进程挂到超时。退出码 2 专表示“测试自身崩了”。
func _process(_delta: float) -> bool:
	if not _finished:
		push_error("run_tests: _initialize 未正常完成，往上看脚本错误")
		print("")
		print("======================================================")
		print("中断  测试未跑完（脚本错误），请检查上方 SCRIPT ERROR")
		print("======================================================")
		quit(2)
	return true
