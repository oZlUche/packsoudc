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

const SUITES: Array = [
	preload("res://tests/test_item_shape.gd"),
	preload("res://tests/test_item_instance.gd"),
	preload("res://tests/test_grid_inventory.gd"),
	preload("res://tests/test_inventory_service.gd"),
	preload("res://tests/test_item_assets.gd"),
	preload("res://tests/test_board_bags.gd"),
	preload("res://tests/test_stat_math.gd"),
	preload("res://tests/test_compiler.gd"),
	preload("res://tests/test_effect_system.gd"),
	preload("res://tests/test_sets.gd"),
	preload("res://tests/test_effect_tree.gd"),
	preload("res://tests/test_damage_pipeline.gd"),
	preload("res://tests/test_content_pipeline.gd"),
	preload("res://tests/test_content_editor.gd"),
	preload("res://tests/test_item_contracts.gd"),
	preload("res://tests/test_drag_layer.gd"),
	preload("res://tests/test_displacement.gd"),
	preload("res://tests/test_item_stash.gd"),
	preload("res://tests/test_dev_nav.gd"),
	preload("res://tests/test_item_value.gd"),
	preload("res://tests/test_map_graph.gd"),
	preload("res://tests/test_vitality.gd"),
	preload("res://tests/test_map_generator.gd"),
	preload("res://tests/test_ring_map_generator.gd"),
	preload("res://tests/test_ring_type_assigner.gd"),
	preload("res://tests/test_map_grid_text.gd"),
	preload("res://tests/test_map_source.gd"),
	preload("res://tests/test_map_travel.gd"),
	preload("res://tests/test_chapter_pipeline.gd"),
	preload("res://tests/test_map_layout.gd"),
	preload("res://tests/test_map_editor.gd"),
	preload("res://tests/test_enemy_pool.gd"),
	preload("res://tests/test_drop_resolver.gd"),
	preload("res://tests/test_node_rules.gd"),
	preload("res://tests/test_search_session.gd"),
	preload("res://tests/test_node_events.gd"),
	preload("res://tests/test_economy.gd"),
	preload("res://tests/test_run_state.gd"),
	preload("res://tests/test_game_flow.gd"),
	preload("res://tests/test_storage_rule.gd"),
	preload("res://tests/test_meta_grid.gd"),
	preload("res://tests/test_run_buffs.gd"),
	preload("res://tests/test_event_layer.gd"),
	preload("res://tests/test_event_editor.gd"),
	preload("res://tests/test_character_setup.gd"),
	preload("res://tests/test_search_reveal.gd"),
	preload("res://tests/test_difficulty.gd"),
	preload("res://tests/test_hunters.gd"),
	preload("res://tests/test_character_skills.gd"),
	preload("res://tests/test_calibration.gd"),
	preload("res://tests/test_erosion.gd"),
	preload("res://tests/test_portals.gd"),
	preload("res://tests/test_event_constructs.gd"),
	preload("res://tests/test_lattice_maps.gd"),
	preload("res://tests/test_sealed_items.gd"),
	preload("res://tests/test_faith.gd"),
	preload("res://tests/test_faith_power.gd"),
	preload("res://tests/test_prologue.gd"),
	preload("res://tests/test_node_screens.gd"),
]


func _initialize() -> void:
	_case = TestCase.new()
	_started = Time.get_ticks_msec()

	# 套件用 run / run_xxx 拆分多组用例，这里自动发现并调用。
	# run 也走自动发现而不是写死调用 —— 只有 frame_ 用例的套件没有 run，
	# 写死会让它一加进来就崩。
	for suite in SUITES:
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
	for suite in SUITES:
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
		print("通过  %d 项断言，%d 个套件，耗时 %d ms" % [_case.checks, SUITES.size(), elapsed])
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
