## 套件共用的帮助函数（102 第 A-5 条）：装内容、临时文件路径、收尾。
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


## 一组互不打扰的临时文件路径（存档、局外、设置）。同一个前缀同一组，套件之间不会撞
static func temp_paths(prefix: String) -> Dictionary:
	return {
		"run": "user://%s_run.json" % prefix,
		"meta": "user://%s_meta.json" % prefix,
		"settings": "user://%s_settings.cfg" % prefix,
		"slots": "user://%s_slots" % prefix,
	}


## 删掉这些路径下的文件（[method temp_paths] 的产物直接丢进来）
static func cleanup(paths: Dictionary) -> void:
	for key in paths:
		var path := String(paths[key])
		if path.ends_with(".json") or path.ends_with(".cfg"):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
