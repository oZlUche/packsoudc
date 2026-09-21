## 开发期导航（[DevNav] autoload）。
##
## 只测**不会真的切场景**的那几条：这一组跑在测试跑器自己的 SceneTree 里，
## 真让它 change_scene_to_file 一下，整棵树连同还没跑完的用例一起没了。
##
## 所以这里测的是「什么时候不该走」—— 而那恰好也是唯一会出错的部分：
## 「该走的时候走了」肉眼一看便知，「不该走的时候走了」表现为一下午的草稿没了。
extends RefCounted


## 假装自己是当前场景，用来驱动 DevNav 的判断
class FakeScene:
	extends Node
	var dirty: bool = false

	func has_unsaved_changes() -> bool:
		return dirty


class QuietScene:
	extends Node
	# 故意不实现 has_unsaved_changes：绝大多数场景都不会实现它


static func _nav(root: Window):
	return root.get_node_or_null("/root/DevNav")


static func frame_run_visibility(t: TestCase, root: Window) -> void:
	t.begin("开发期导航 · 什么时候露面")

	var nav = _nav(root)
	t.not_null(nav, "DevNav 是 autoload，跑什么都在")
	if nav == null:
		return

	var tree := root.get_tree()
	var saved := tree.current_scene

	# --- 启动选择器里不该有「返回主界面」---
	var launcher := QuietScene.new()
	launcher.scene_file_path = "res://ui/launcher.tscn"
	root.add_child(launcher)
	tree.current_scene = launcher
	nav._relabel()
	t.check(not nav._button.visible, "已经在主界面了，按钮不该出现")

	# --- 别的场景里要有 ---
	var other := QuietScene.new()
	other.scene_file_path = "res://ui/battle/battle_sandbox.tscn"
	root.add_child(other)
	tree.current_scene = other
	nav._relabel()
	t.check(nav._button.visible, "子场景里按钮出现")
	t.check(nav._button.text.contains("F1"), "按钮上写着快捷键")

	tree.current_scene = saved
	launcher.queue_free()
	other.queue_free()


static func frame_run_confirm(t: TestCase, root: Window) -> void:
	t.begin("开发期导航 · 有未保存的东西时先拦一下")

	var nav = _nav(root)
	if nav == null:
		t.check(false, "没有 DevNav")
		return

	var tree := root.get_tree()
	var saved := tree.current_scene

	var scene := FakeScene.new()
	scene.scene_file_path = "res://ui/editor/content_editor.tscn"
	root.add_child(scene)
	tree.current_scene = scene
	nav._armed = false
	nav._relabel()

	# --- 有未保存内容：第一下只是提醒，不走 ---
	scene.dirty = true
	nav._request_back()
	t.check(nav._armed, "第一次按下只是上膛")
	t.eq(tree.current_scene, scene, "**场景没有被换掉**")
	t.check(nav._button.text.contains("未保存"), "按钮上说清楚了为什么没走")

	# --- 提醒会自己过期，不然隔半小时手一滑就直接走了 ---
	nav._process(DevNav.CONFIRM_WINDOW + 1.0)
	t.check(not nav._armed, "过一会儿自动解除")
	t.check(not nav._button.text.contains("未保存"), "按钮文字也恢复")

	# --- 场景一换，上膛状态必须清掉 ---
	scene.dirty = true
	nav._request_back()
	t.check(nav._armed, "又上膛了")
	var another := QuietScene.new()
	another.scene_file_path = "res://ui/battle/battle_sandbox.tscn"
	root.add_child(another)
	tree.current_scene = another
	nav._process(0.0)
	t.check(not nav._armed, "换了场景就不算数了 —— 那半按下去的确认不属于这里")

	# --- 不实现 has_unsaved_changes 的场景一律算干净 ---
	t.check(not nav._dirty(), "没实现那个方法的场景不拦")

	tree.current_scene = saved
	scene.queue_free()
	another.queue_free()
