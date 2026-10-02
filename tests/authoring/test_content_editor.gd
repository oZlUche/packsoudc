## 道具编辑器的草稿缓存与基本可用性（架构文档 10.5）。
##
## 这一组用 `frame_` 前缀：编辑器要进场景树才活得起来，
## 而 `_ready` 得等进入帧循环才派发 —— 在 `_initialize` 里 add_child 之后立刻用，
## 控件全是 null（踩过一次）。
##
## [b]断言只针对机制，不针对内容。[/b] 这些用例跑在 `data/authoring` 里的真实数据上，
## 而那些数据是作者（包括 MOD 作者）随时会改的。写死「弹匣有两个增益格」
## 意味着别人调一下数值，测试就红一次 —— 红得毫无信息量，最后只会被无视。
## 所以这里断言的是「画板拿到的和定义里的一致」这种不变式。
extends RefCounted

const SCENE := "res://ui/editor/content_editor.tscn"


## 找一件带邻接标记的道具；没有就返回空
static func _first_with_adjacency(ed) -> String:
	for id in ed._ids:
		var path := ContentPaths.authoring_file("items", id)
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Dictionary):
			continue
		var adj = (parsed as Dictionary).get("adjacency", null)
		if adj is Dictionary and (adj.has("grant_cells") or adj.has("receive_cells")):
			return id
	return ""


static func frame_run_drafts(t: TestCase, root: Window) -> void:
	t.begin("编辑器 · 草稿缓存")

	var ed = load(SCENE).instantiate()
	root.add_child(ed)

	if ed._ids.size() < 2:
		t.check(false, "data/authoring/items 里至少要有两件道具才能测切换")
		ed.queue_free()
		return

	var first: String = ed._ids[0]
	var second: String = ed._ids[1]

	# --- 刚打开的不该算改过 ---
	ed._open(first)
	var original: String = ed._def.display_name
	t.eq(ed._drafts.size(), 0,
		"刚从盘上读进来不算改过 —— 基准必须在 _bind 之前写好，否则一打开就是脏的")

	# --- 改了就进草稿，列表上有标记 ---
	ed._def.display_name = original + "（改过）"
	ed._refresh()
	t.eq(ed._drafts.size(), 1, "改动进了草稿")
	t.check(ed._list.get_item_text(ed._ids.find(first)).begins_with("●"),
		"列表上打了标记，作者不必靠记忆")

	# --- 切走再切回来，改动还在。这是这套机制存在的全部理由 ---
	ed._open(second)
	t.eq(ed._current_id, second, "切到了另一件")
	t.eq(ed._drafts.size(), 1, "切走之后草稿仍在")
	ed._open(first)
	t.eq(ed._def.display_name, original + "（改过）", "**切回来改动还在**")

	# --- 改回原样，草稿自动撤掉 ---
	ed._def.display_name = original
	ed._refresh()
	t.eq(ed._drafts.size(), 0, "改回去就不算改过了，标记也该消失")
	ed._open(second)
	ed._open(first)
	t.eq(ed._def.display_name, original, "没有草稿时从盘上读")

	# --- 放弃改动 ---
	ed._def.display_name = "临时的名字"
	ed._refresh()
	t.eq(ed._drafts.size(), 1, "又改了一次")
	ed._on_discard()
	t.eq(ed._drafts.size(), 0, "放弃改动清掉了草稿")
	t.eq(ed._def.display_name, original, "并从盘上重读")

	# --- 新建的道具也算草稿（它还没有盘上的对应物）---
	ed._new_item()
	t.check(ed._drafts.has("new_item"), "没存过的新道具也标成未保存")

	ed.queue_free()


static func frame_run_editor_smoke(t: TestCase, root: Window) -> void:
	t.begin("编辑器 · 基本可用")

	var ed = load(SCENE).instantiate()
	root.add_child(ed)

	t.check(ed._ids.size() > 0, "列出了作者数据目录里的道具")
	t.check(ed._def != null, "开场自动打开了一件")

	# 校验走的就是导入器 —— 界面说没问题，命令行就一定过得去
	for id in ed._ids:
		ed._open(id)
		var report: ImportReport = ed._validate()
		t.check(report.ok(), "%s 在编辑器里校验通过：%s" % [id, report.to_text()])

	# JSON 预览就是将要写盘的内容
	t.eq(ed._preview.text, ContentExporter.to_json(ContentExporter.export_item(ed._def)),
		"JSON 预览与导出器一致")

	ed.queue_free()


static func frame_run_shape_painter(t: TestCase, root: Window) -> void:
	t.begin("编辑器 · 画板与定义一致")

	var ed = load(SCENE).instantiate()
	root.add_child(ed)

	var id := _first_with_adjacency(ed)
	if id == "":
		t.check(true, "（现有内容里没有带邻接标记的道具，跳过）")
		ed.queue_free()
		return

	ed._open(id)
	t.check(ed._def.adjacency != null, "%s 有邻接定义" % id)
	t.eq(ed._shape.grant_cells(), ed._def.adjacency.grant_cells,
		"画板读到的增益格与定义一致")
	t.eq(ed._shape.receive_cells(), ed._def.adjacency.receive_cells,
		"画板读到的受益格与定义一致")
	t.eq(ed._shape.to_bits(), ed._def.shape.to_bits(), "画板读到的形状与定义一致")

	# 在画板上加一格，要能回写到定义里
	var before: int = ed._def.adjacency.grant_cells.size()
	ed._shape.layer = ShapeEditor.Layer.GRANT
	ed._shape._grant[Vector2i(0, -3)] = true
	ed._refresh()
	t.eq(ed._def.adjacency.grant_cells.size(), before + 1, "画板上加的格子回写进了定义")
	t.check(ed._def.adjacency.grant_cells.has(Vector2i(0, -3)), "回写的就是那一格")

	ed.queue_free()


## 分类页签。**期望值从 data/authoring 里推出来，不写死** ——
## 标签是作者随手会加会改的东西，写死「有 weapon 这一页」意味着
## 别人改个标签测试就红一次。
static func _tags_on_disk(ed) -> Array[String]:
	var seen := {}
	for id in ed._ids:
		var parsed = JSON.parse_string(
			FileAccess.get_file_as_string(ContentPaths.authoring_file("items", id)))
		if not (parsed is Dictionary):
			continue
		for tag in ((parsed as Dictionary).get("tags", []) as Array):
			seen[String(tag)] = true
	var out: Array[String] = []
	for tag in seen:
		out.append(tag)
	out.sort()
	return out


static func frame_run_tag_tabs(t: TestCase, root: Window) -> void:
	t.begin("编辑器 · 按标签分类")

	var ed = load(SCENE).instantiate()
	root.add_child(ed)

	var tags := _tags_on_disk(ed)
	if tags.is_empty():
		t.check(true, "（现有内容一个标签都没有，跳过）")
		ed.queue_free()
		return

	# --- 页签就是内容里出现过的标签，一个不多一个不少 ---
	var labels: Array[String] = []
	for child in ed._tab_host.get_children():
		labels.append(String((child as Button).get_meta("page")[1]))
	var from_tabs: Array[String] = []
	for s in labels:
		if s != "":
			from_tabs.append(s)
	from_tabs.sort()
	t.eq(from_tabs, tags, "页签与内容里的标签一一对应，不是写死的表")
	t.eq(ed._shown.size(), ed._ids.size(), "默认在「全部」页，一件不少")

	# --- 切到某一页，列表只剩带那个标签的 ---
	var target := tags[0]
	for child in ed._tab_host.get_children():
		var b := child as Button
		# 标签页是唯一带非空标签名的那一档，不必去够编辑器里的枚举
		if String(b.get_meta("page")[1]) == target:
			b.pressed.emit()
	t.check(ed._shown.size() > 0, "%s 这一页不是空的" % target)
	t.check(ed._shown.size() < ed._ids.size() or tags.size() == 1,
		"筛过之后比全集少（除非所有道具都带这一个标签）")
	for id in ed._shown:
		t.check(ed._tags_for(id).has(target), "%s 带着 %s 标签" % [id, target])

	# --- 行号走的是筛过的那一份，不是全集 ---
	# 这条是整块筛选里唯一真正会错的地方：点第三行打开了第五件，
	# 而且只有在加了筛选之后才错
	var first_shown: String = ed._shown[0]
	ed._open(ed._shown[0])
	t.eq(ed._current_id, first_shown, "**点第一行打开的是本页第一件**")

	# --- 选一件不在本页里的，自动退回「全部」 ---
	var outsider := ""
	for id in ed._ids:
		if not ed._shown.has(id):
			outsider = id
			break
	if outsider != "":
		ed._select_in_list(outsider)
		t.eq(ed._shown.size(), ed._ids.size(),
			"选中一件本页看不见的东西时退回「全部」—— 否则等于没选")
		t.check(ed._shown.has(outsider), "它现在看得见了")

	ed.queue_free()


static func frame_run_unsaved_hook(t: TestCase, root: Window) -> void:
	t.begin("编辑器 · 未保存提示")

	var ed = load(SCENE).instantiate()
	root.add_child(ed)
	if ed._ids.is_empty():
		t.check(false, "没有可用道具")
		ed.queue_free()
		return

	ed._open(ed._ids[0])
	t.check(not ed.has_unsaved_changes(), "刚打开没有未保存的东西")

	ed._def.display_name += "（改过）"
	ed._refresh()
	t.check(ed.has_unsaved_changes(), "改了一下就有了 —— DevNav 据此拦住返回")

	ed._on_discard()
	t.check(not ed.has_unsaved_changes(), "放弃改动之后又干净了")

	ed.queue_free()
