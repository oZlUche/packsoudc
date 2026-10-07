## 141：内容编辑器的「列表 / 草稿 / 存盘」只有 [AuthoringEditor] 一份 —— 每个编辑器走同一套：新建算草稿、进列表；
## 改 id 不留孤儿；存盘后不脏；改一字又脏、再存又不脏；盘上删了、重扫后从列表消失
extends RefCounted

const PROBE := "zz_141_probe"
## 场景 → [种类, 拿来改一字的字段]
const EDITORS := {
	"res://ui/buff_editor/buff_editor.tscn": ["buffs", "display_name"],
	"res://ui/set_editor/set_editor.tscn": ["sets", "display_name"],
}


static func _remove(kind: String, id: String) -> void:
	for p in [ContentPaths.authoring_file(kind, id), ContentPaths.asset_file(kind, id)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func frame_shared_draft_flow(t: TestCase, root: Window) -> void:
	t.begin("141 · 每个内容编辑器都继承 AuthoringEditor：草稿 / 改名 / 存盘 / 判脏 / 重扫一套规矩")
	for scene in EDITORS:
		var kind: String = EDITORS[scene][0]
		var field: String = EDITORS[scene][1]
		var dirs := ContentPaths.dirs_of(kind)
		var had := [DirAccess.dir_exists_absolute(dirs[0]), DirAccess.dir_exists_absolute(dirs[1])]
		_remove(kind, PROBE)
		_remove(kind, PROBE + "_x")
		var ed = (load(scene) as PackedScene).instantiate()
		root.add_child(ed)
		t.check(ed is AuthoringEditor, "%s 是 AuthoringEditor" % kind)
		ed._new_entry()
		ed._def.id = StringName(PROBE + "_x")
		ed._refresh()
		t.check(ed._ids.has(PROBE + "_x") and ed.has_unsaved_changes(), "%s：新建没存 = 草稿、进列表" % kind)
		ed._def.id = StringName(PROBE)
		ed._refresh()
		t.check(ed._ids.has(PROBE) and not ed._ids.has(PROBE + "_x") and not ed._drafts.has(PROBE + "_x"), "%s：改 id 不留旧名字" % kind)
		ed._save()
		t.check(FileAccess.file_exists(ContentPaths.authoring_file(kind, PROBE)), "%s：存了" % kind)
		t.check(not ed.has_unsaved_changes(), "%s：存完不脏" % kind)
		ed._def.set(field, "探针 141")
		ed._refresh()
		t.check(ed.has_unsaved_changes() and ed._drafts.has(PROBE), "%s：改一字就脏" % kind)
		ed._save()
		t.check(not ed.has_unsaved_changes(), "%s：再存又不脏" % kind)
		_remove(kind, PROBE)
		ed._on_rescan()
		t.eq(ed._ids, ContentPaths.ids_in(dirs[0]), "%s：重扫后列表 = 盘上（删了的那件不在了）" % kind)
		ed.queue_free()
		for i in 2:
			if not had[i] and DirAccess.dir_exists_absolute(dirs[i]) and ContentPaths.ids_in(dirs[i]).is_empty() and DirAccess.get_files_at(dirs[i]).is_empty():
				DirAccess.remove_absolute(dirs[i])
