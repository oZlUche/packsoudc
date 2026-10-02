## 事件编辑器（报告 064）：列表与校验、草稿、保存往返、导入配图、挂进节点规则。
##
## 全是 `frame_` 用例：编辑器要进场景树才活得起来。
## **断言只针对机制，不针对内容** —— 跑在 `data/authoring/events` 的真实数据上，期望值从盘上推出来。
## 往盘上写的东西（探针事件、探针图片、节点规则里的一行）用完都收回，收回之后与之前逐字节相同。
extends RefCounted

const SCENE := "res://ui/event_editor/event_editor.tscn"
const PROBE := "zz_editor_probe"


static func _make(root: Window) -> Node:
	var ed: Node = load(SCENE).instantiate()
	root.add_child(ed)
	return ed


static func _remove(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


## 预览是两栏的（左图右文），按钮在右栏里，递归找
static func _collect_buttons(node: Node, out: Array[String]) -> void:
	for c in node.get_children():
		if c is Button:
			out.append((c as Button).text)
		_collect_buttons(c, out)


static func _cleanup_probe() -> void:
	_remove(ContentPaths.authoring_file("events", PROBE))
	_remove(ContentPaths.asset_file("events", PROBE))
	for ext in EventImage.EXTENSIONS:
		_remove("res://assets/events/%s.%s" % [PROBE, ext])
		_remove("res://assets/events/%s.%s.import" % [PROBE, ext])


static func frame_run_smoke(t: TestCase, root: Window) -> void:
	t.begin("事件编辑器 · 列表、校验与预览")
	_cleanup_probe()
	var ed := _make(root)

	var on_disk: Array[String] = []
	var d := DirAccess.open(ContentPaths.AUTHORING_EVENTS)
	for f in d.get_files():
		if f.ends_with(".json"):
			on_disk.append(f.get_basename())
	on_disk.sort()
	t.eq(ed._ids, on_disk, "列表就是作者数据目录里的事件")
	t.check(ed._def != null, "开场自动打开了一个")

	for id in ed._ids:
		ed._open(id)
		var report: ImportReport = ed._validate()
		t.check(report.ok(), "%s 在编辑器里校验通过：%s" % [id, report.to_text()])
		# 预览：一个选项一个按钮，顺序一致
		var buttons: Array[String] = []
		_collect_buttons(ed._preview_host, buttons)
		var labels: Array[String] = []
		for o in ed._def.options:
			labels.append((o as EventOption).label)
		t.eq(buttons, labels, "%s 的预览里每个选项一个按钮" % id)
	t.eq(ed._json.text, ContentExporter.to_json(ContentExporter.export_event(ed._def)), "JSON 预览与导出器一致")
	t.check(ed._placement.text.begins_with("现在挂在："), "写着现在挂在哪")

	# 挂在哪是从节点规则里读的：搜索点默认事件在 standard 的 search 下（从数据推）
	var rules_json = JSON.parse_string(FileAccess.get_file_as_string(ContentPaths.authoring_file("node_rules", "standard")))
	if rules_json is Dictionary and (rules_json as Dictionary).has("events_by_type"):
		var ebt: Dictionary = rules_json["events_by_type"]
		for type in ebt:
			for eid in ebt[type]:
				if ed._ids.has(String(eid)):
					ed._open(String(eid))
					t.check(ed._placement.text.contains("standard · %s" % type), "%s 显示挂在 standard · %s 下" % [eid, type])
					break
			break

	# 校验走导入器：没有选项就报错
	ed._new_event()
	ed._def.options.clear()
	ed._refresh()
	t.check(not ed._validate().ok(), "没有选项的事件校验不过（导入器的规则）")
	t.check(ed._status.text.contains("✗"), "校验栏里有错")

	ed.queue_free()


static func frame_run_drafts(t: TestCase, root: Window) -> void:
	t.begin("事件编辑器 · 草稿缓存")
	var ed := _make(root)
	if ed._ids.size() < 2:
		t.check(false, "data/authoring/events 里至少要有两个事件才能测切换")
		ed.queue_free()
		return
	var first: String = ed._ids[0]
	var second: String = ed._ids[1]

	ed._open(first)
	var original: String = ed._def.title
	t.eq(ed._drafts.size(), 0, "刚从盘上读进来不算改过")

	ed._title_edit.text = original + "（改过）"
	ed._on_title_changed(ed._title_edit.text)
	t.eq(ed._def.title, original + "（改过）", "标题框改了就写进定义")
	t.eq(ed._drafts.size(), 1, "改动进了草稿")
	t.check(ed._list.get_item_text(ed._ids.find(first)).begins_with("●"), "列表上打了标记")

	ed._open(second)
	t.eq(ed._current_id, second, "切到了另一个")
	ed._open(first)
	t.eq(ed._def.title, original + "（改过）", "切回来改动还在")

	ed._def.title = original
	ed._refresh()
	t.eq(ed._drafts.size(), 0, "改回去就不算改过了")

	ed._def.text += "\n再加一行"
	ed._refresh()
	t.eq(ed._drafts.size(), 1, "改正文也算")
	t.check(ed.has_unsaved_changes(), "DevNav 会拦一下返回")
	ed._on_discard()
	t.eq(ed._drafts.size(), 0, "放弃改动清掉了草稿")
	t.eq(ed._def.title, original, "并从盘上重读")
	t.check(not ed.has_unsaved_changes(), "又干净了")

	ed._new_event()
	t.check(ed._drafts.has("new_event"), "没存过的新事件也标成未保存")
	ed.queue_free()


static func frame_run_save_roundtrip(t: TestCase, root: Window) -> void:
	t.begin("事件编辑器 · 保存 = JSON + .tres，且是往返不动点")
	_cleanup_probe()
	var ed := _make(root)

	ed._new_event()
	ed._id_edit.text = PROBE
	ed._on_id_changed(PROBE)
	ed._on_title_changed("探针")
	ed._text_edit.text = "第一行\n第二行"
	ed._on_text_changed()
	var opt := EventOption.new()
	opt.label = "付钱"
	var cond := ContentSchema.make(&"EventCondition", &"can_afford") as EventCondition
	cond.set("amount", 7)
	opt.requires.append(cond)
	var pay := ContentSchema.make(&"EventOutcome", &"change_money") as EventOutcome
	pay.set("amount", -7)
	opt.outcomes.append(pay)
	var say := ContentSchema.make(&"EventOutcome", &"say") as EventOutcome
	say.set("text", "谢了。")
	opt.outcomes.append(say)
	ed._def.options.insert(0, opt)
	ed._refresh()
	t.check(ed._validate().ok(), "探针事件校验通过：%s" % ed._validate().to_text())

	ed._save()
	var json_path := ContentPaths.authoring_file("events", PROBE)
	var tres_path := ContentPaths.asset_file("events", PROBE)
	t.check(FileAccess.file_exists(json_path), "写了作者数据")
	t.check(FileAccess.file_exists(tres_path), "顺手产出了资产")
	t.check(ed._ids.has(PROBE), "列表里有它了")
	t.eq(ed._drafts.size(), 0, "存了就不是草稿了")

	# 往返不动点：盘上的 JSON 读回来再导出逐字节相同（和 normalize_content 的约定一致）
	var text := FileAccess.get_file_as_string(json_path)
	var parsed = JSON.parse_string(text)
	var report := ImportReport.new()
	var again := ContentImporter.import_event(parsed, ContentImporter.Context.new(), report)
	t.check(report.ok(), "读回来没有错：%s" % report.to_text())
	t.eq(ContentExporter.to_json(ContentExporter.export_event(again)), text, "盘上的 JSON 是往返不动点")
	t.eq(again.options.size(), 2, "两个选项都在")
	t.eq(again.options[0].requires.size(), 1, "条件在")
	t.eq(int(again.options[0].requires[0].get("amount")), 7, "条件的数在")
	t.eq(again.options[0].outcomes.size(), 2, "两个后果都在")

	var asset := load(tres_path) as EventDef
	t.check(asset != null and asset.id == StringName(PROBE), "资产装得回来、id 对")
	t.eq(asset.text, "第一行\n第二行", "多行正文原样进了资产")

	# 有错就不写盘
	ed._def.options.clear()
	ed._refresh()
	var before := FileAccess.get_file_as_string(json_path)
	ed._save()
	t.eq(FileAccess.get_file_as_string(json_path), before, "校验不过时盘上的文件不动")

	ed.queue_free()
	_cleanup_probe()
	t.check(not FileAccess.file_exists(json_path), "探针收回了")


static func frame_run_image_import(t: TestCase, root: Window) -> void:
	t.begin("事件编辑器 · 导入配图")
	_cleanup_probe()
	var ed := _make(root)

	var img := Image.create(8, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.5, 0.8))
	var src := "user://probe_src.png"
	img.save_png(src)
	var src_abs := ProjectSettings.globalize_path(src)

	ed._new_event()
	ed._on_id_changed(PROBE)
	var dest: String = ed._import_image(src_abs)
	t.eq(dest, "res://assets/events/%s.png" % PROBE, "复制到 assets/events/<id>.<ext>")
	t.check(FileAccess.file_exists(dest), "文件真的在")
	t.eq(ed._def.image, dest, "路径写进了事件")
	t.eq(ed._image_edit.text, dest, "配图框跟着变")
	var tex := EventImage.load_texture(dest)
	t.check(tex != null, "引擎没导入过也装得出来（按原始文件读）")
	if tex != null:
		t.eq(tex.get_size(), Vector2(8, 6), "尺寸对")
	t.check(ed._thumb.texture != null, "缩略图画出来了")
	t.check(ed._validate().ok(), "配图读得到，不警告")

	ed._on_image_changed("res://assets/events/does_not_exist.png")
	t.check(ed._validate().ok(), "配图读不到不算错（事件屏画占位）")
	t.check(not ed._validate().warnings.is_empty(), "但会警告")
	t.is_null(EventImage.load_texture("res://assets/events/does_not_exist.png"), "读不到就是 null")
	t.is_null(EventImage.load_texture(""), "空路径是 null")

	ed._clear_image()
	t.eq(ed._def.image, "", "清除")

	t.eq(ed._import_image(ProjectSettings.globalize_path("user://probe.txt")), "", "不是图片的不收")
	ed._on_id_changed("")
	t.eq(ed._import_image(src_abs), "", "没有 id 不收（配图按 id 命名）")

	ed.queue_free()
	_cleanup_probe()
	_remove(src)
	t.check(not FileAccess.file_exists(dest), "探针图片收回了")


static func frame_run_attach_rules(t: TestCase, root: Window) -> void:
	t.begin("事件编辑器 · 挂进节点规则")
	var ed := _make(root)
	var rules_ids: Array[String] = ed._rules_ids()
	if rules_ids.is_empty() or ed._ids.is_empty():
		t.check(false, "需要至少一份节点规则和一个事件")
		ed.queue_free()
		return
	var rid := rules_ids[0]
	var path := ContentPaths.authoring_file("node_rules", rid)
	var before := FileAccess.get_file_as_string(path)
	var tres_before := FileAccess.get_file_as_string(ContentPaths.asset_file("node_rules", rid))

	# 挑一种这个事件还没挂着的点
	var eid: String = ed._ids[0]
	ed._open(eid)
	var parsed = JSON.parse_string(before)
	var ebt: Dictionary = (parsed as Dictionary).get("events_by_type", {})
	var type := ""
	for candidate in MapNodeTypes.ALL:
		var table = ebt.get(String(candidate), {})
		if not (table is Dictionary and (table as Dictionary).has(eid)):
			type = String(candidate)
			break
	t.check(type != "", "找得到一种还没挂的点")

	var report: ImportReport = ed._attach(rid, type, 3)
	t.check(report.ok(), "挂上了：%s" % report.to_text())
	var after = JSON.parse_string(FileAccess.get_file_as_string(path))
	t.eq(int((after as Dictionary)["events_by_type"][type][eid]), 3, "权重写进了 events_by_type")
	var rules := ResourceLoader.load(ContentPaths.asset_file("node_rules", rid), "", ResourceLoader.CACHE_MODE_IGNORE) as NodeRules
	t.check(rules != null and rules.events_by_type.has(type), "资产也更新了（绕过资源缓存读）")
	ed._placement.text = ed._placement_text()
	t.check(ed._placement.text.contains("%s · %s" % [rid, type]), "编辑器显示挂在那儿了")

	# 引用不存在的事件会被导入器拦下，文件不动
	var mid := FileAccess.get_file_as_string(path)
	ed._def.id = &"no_such_event"
	var bad: ImportReport = ed._attach(rid, type, 1)
	t.check(not bad.ok(), "没保存过的事件挂不上")
	t.eq(FileAccess.get_file_as_string(path), mid, "文件不动")
	ed._def.id = StringName(eid)

	var off: ImportReport = ed._attach(rid, type, 0)
	t.check(off.ok(), "摘下")
	t.eq(FileAccess.get_file_as_string(path), before, "摘下之后 JSON 与之前逐字节相同")
	var restored := ResourceLoader.load(ContentPaths.asset_file("node_rules", rid), "", ResourceLoader.CACHE_MODE_IGNORE) as NodeRules
	t.check(restored != null and not (restored.events_by_type.get(type, {}) as Dictionary).has(eid), "资产也回到原样：那种点下没有它了")
	# .tres 的子资源 id 每次保存都是随机的，逐字节比不了；把原来的字节写回去，别让测试弄脏仓库
	var f := FileAccess.open(ContentPaths.asset_file("node_rules", rid), FileAccess.WRITE)
	f.store_string(tres_before)
	f.close()

	ed.queue_free()


## 091：事件链视图（出去的 next_event、被谁引用）与语言切换（英文标题 / 正文写进 titles / texts）
static func frame_run_chain_and_lang(t: TestCase, root: Window) -> void:
	t.begin("事件编辑器 · 事件链（被预设图 / 节点规则引用、next_event 递归）与语言切换")
	var ed := _make(root)
	if not ed._ids.has("tut_search_1") or not ed._ids.has("search_default"):
		t.check(false, "缺 tut_search_1 / search_default")
		ed.queue_free()
		return
	ed._open("tut_search_1")
	var texts: Array[String] = []
	for line in ed.chain_lines():
		texts.append(String(line["text"]))
	t.check(texts[0].contains("tut_search_1"), "第一行是自己")
	t.check(texts.any(func(s: String) -> bool: return s.contains("预设图 prologue")), "被序章预设图引用：%s" % str(texts))
	ed._open("search_default")
	texts.clear()
	for line in ed.chain_lines():
		texts.append(String(line["text"]))
	t.check(texts.any(func(s: String) -> bool: return s.contains("节点规则 standard")), "被标准节点规则引用：%s" % str(texts))

	# 链：新建一个事件，选项接 next_event → search_default → 递归列出 search_default 自己的 next_event（如果有）
	ed._new_event()
	var def: EventDef = ed._def
	var ne := NextEvent.new()
	ne.event = &"search_default"
	(def.options[0] as EventOption).outcomes.append(ne)
	ed._refresh()
	var lines: Array = ed.chain_lines()
	var hop := lines.filter(func(l: Dictionary) -> bool: return int(l["depth"]) == 1 and String(l["text"]).contains("→ search_default"))
	t.eq(hop.size(), 1, "链里有「选项 → search_default」这一跳")
	t.eq(String(hop[0]["id"]), "search_default", "那一行带着能跳过去的 id")
	ne.event = &"no_such_event"
	ed._refresh()
	t.check(ed.chain_lines().any(func(l: Dictionary) -> bool: return String(l["text"]).contains("找不到")), "指向不存在的事件：标出来")
	# 环：自己指自己
	ne.event = def.id
	ed._refresh()
	t.check(ed.chain_lines().any(func(l: Dictionary) -> bool: return String(l["text"]).contains("环")), "自己指自己：标成环、不无限递归")
	ed._on_discard()

	# 语言
	ed._open("tut_search_1")
	var zh_title: String = ed._def.title
	ed.set_lang("en")
	t.eq(ed.lang(), "en", "切到英文")
	t.eq(ed._title_edit.text, "", "英文标题还没写：框空着")
	ed._title_edit.text = "Search here"
	ed._on_title_changed("Search here")
	t.eq(String(ed._def.titles.get("en", "")), "Search here", "英文写进 titles")
	t.eq(ed._def.title, zh_title, "中文原文没动")
	t.eq(ed._def.title_for("en"), "Search here", "取英文得英文")
	t.eq(ed._def.title_for("zh"), zh_title, "取中文得原文")
	t.eq(ed._def.title_for("fr"), zh_title, "没写的语言回落原文")
	ed._on_title_changed("")
	t.check(not ed._def.titles.has("en"), "清空 = 删掉那一条")
	ed.set_lang("zh")
	t.eq(ed._title_edit.text, zh_title, "切回中文：框里是原文")
	ed._on_discard()
	ed.queue_free()
