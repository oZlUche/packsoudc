## 套装编辑器（091，作者定）：新建 → 改 id / 加档位 → 校验 → 保存 = JSON + .tres → 往返不动点；成员按道具的 set_id 算
extends RefCounted

const SCENE := "res://ui/set_editor/set_editor.tscn"
const PROBE := "zz_set_probe"


static func _remove_probe() -> void:
	for p in [ContentPaths.authoring_file("sets", PROBE), ContentPaths.asset_file("sets", PROBE)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func frame_set_editor(t: TestCase, root: Window) -> void:
	t.begin("套装编辑器 · 新建 / 改 id / 加档位 / 摘要 / 校验 / 保存产出 JSON + .tres / 往返 / 成员")
	var had_dir := DirAccess.dir_exists_absolute(ContentPaths.AUTHORING_SETS)
	_remove_probe()
	var ed = (load(SCENE) as PackedScene).instantiate()
	root.add_child(ed)
	t.check(ed.def() != null, "打开就有一套在编（盘上有就是第一套，没有就是新建）")
	ed._new_set()
	var def: ItemSetDef = ed.def()
	t.check(def != null and String(def.id) == "new_set" and def.tiers.size() == 1, "新建：new_set、一档 2 件")
	ed._id_edit.text = PROBE
	ed._id_edit.text_changed.emit(PROBE)
	ed._name_edit.text = "探针套"
	ed._name_edit.text_changed.emit("探针套")
	t.check(String(def.id) == PROBE and def.display_name == "探针套", "id / 名字改进定义")
	t.check(ed._drafts.has(PROBE) and ed._ids.has(PROBE), "没存过的算草稿、进列表")
	ed.add_tier(4)
	t.eq(def.tiers.size(), 2, "加了一档")
	t.check(def.tiers[0].pieces == 2 and def.tiers[1].pieces == 4, "档位按件数升序")
	var summary: String = ed.summary_text()
	t.check(summary.contains("探针套") and summary.contains("2 件") and summary.contains("4 件"), "摘要有名字与两档（%s）" % summary.replace("\n", " / "))
	t.check(ed.members().is_empty(), "还没有道具认这套")
	t.check(ed._validate().ok(), "校验过")
	t.check(ed.has_unsaved_changes(), "有未保存的改动")
	ed._save()
	var json_path := ContentPaths.authoring_file("sets", PROBE)
	var tres_path := ContentPaths.asset_file("sets", PROBE)
	t.check(FileAccess.file_exists(json_path), "存了 JSON")
	t.check(FileAccess.file_exists(tres_path), "存了 .tres")
	t.check(not ed._drafts.has(PROBE) and not ed.has_unsaved_changes(), "存完不算草稿")
	t.eq(ed._current_id, PROBE, "当前就是它")
	# 往返：JSON → 导入 → 导出 → 一样
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	t.check(parsed is Dictionary, "JSON 读得通")
	if parsed is Dictionary:
		var report := ImportReport.new()
		var back := ContentImporter.import_set(parsed, ContentImporter.Context.new(), report)
		t.check(report.ok() and back != null and String(back.id) == PROBE and back.tiers.size() == 2, "导回来是它")
		t.eq(ContentExporter.to_json(ContentExporter.export_set(back)), ContentExporter.to_json(ContentExporter.export_set(ed.def())), "往返不动点（导回来再导出 = 编辑器里那份导出）")
	var loaded = ResourceLoader.load(tres_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	t.check(loaded is ItemSetDef and String(loaded.id) == PROBE, ".tres 读回来是套装")
	# 成员：随便找一件道具把 set_id 指过来（只在内存里）
	var items: ItemDatabase = ed._items
	if items != null and not items.all_ids().is_empty():
		var some: ItemDef = items.get_def(items.all_ids()[0])
		var old := some.set_id
		some.set_id = StringName(PROBE)
		t.eq(ed.members(), [String(some.id)], "道具的 set_id 写这个 id 就是成员")
		some.set_id = old
	# 改坏：没 id 存不了
	ed._id_edit.text_changed.emit("")
	ed._save()
	t.check(ed._status.text.contains("先给一个 id"), "空 id 拒存")
	ed._id_edit.text_changed.emit(PROBE)
	ed._on_discard()
	t.check(ed.def() != null and String(ed.def().id) == PROBE and not ed._drafts.has(PROBE), "放弃改动：回到盘上那份")
	ed.queue_free()
	_remove_probe()
	if not had_dir and DirAccess.dir_exists_absolute(ContentPaths.AUTHORING_SETS):
		DirAccess.remove_absolute(ContentPaths.AUTHORING_SETS)
