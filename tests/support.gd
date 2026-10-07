## 套件共用的帮助函数（102 第 A-5 条）：装内容。临时文件路径与收尾在 `tests/run/flow_support.gd`。
##
## 以前每个套件各写一份 `_content()` / `_cleanup()`，改一处内容装载要改十几个文件。
## 100 第 4 步落地之后 [method content] 就是 `ContentLibrary.load_all()` 的一行转发。
class_name TestSupport
extends RefCounted


## 一份内容（道具、敌人、套装、buff、事件、章节、关卡与角色……）。
## 返回字典而不是一个类型，是为了和现有套件里的 `_content()` 形状一致，搬过来不用改断言
static func content() -> Dictionary:
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	return {
		"items": items,
		"enemies": enemies,
		"sets": sets,
		"buffs": GameFlow.load_run_buffs(),
		"events": GameFlow.load_events(),
		"faiths": GameFlow.load_faiths(),
		"recipes": GameFlow.load_recipes(),
		"chapters": GameFlow.load_chapters(),
		"loadouts": GameFlow.load_loadouts(),
		"characters": GameFlow.load_characters(),
		"hunters": GameFlow.load_hunters(),
		"difficulties": GameFlow.load_difficulties(),
	}
