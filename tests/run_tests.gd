## 无头测试入口。
##
##     "E:/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tests/run_tests.gd
##
## 全部通过退出码为 0，有失败为 1，便于将来接 CI。
extends SceneTree

const SUITES: Array = [
	preload("res://tests/test_item_shape.gd"),
	preload("res://tests/test_item_instance.gd"),
]


func _initialize() -> void:
	var t := TestCase.new()
	var started := Time.get_ticks_msec()

	for suite in SUITES:
		suite.run(t)

	var elapsed := Time.get_ticks_msec() - started
	print("")
	print("======================================================")
	if t.passed():
		print("通过  %d 项断言，%d 个套件，耗时 %d ms" % [t.checks, SUITES.size(), elapsed])
		print("======================================================")
		quit(0)
		return

	print("失败  %d / %d 项断言未通过：" % [t.failures.size(), t.checks])
	print("------------------------------------------------------")
	for f in t.failures:
		print("  ✗ " + f)
	print("======================================================")
	quit(1)
