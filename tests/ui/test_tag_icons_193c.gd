## 193 补充三：道具悬浮窗副行的标签画成图标（没图的退回文字），钉住后停上去开子窗写名字；只写名字的子窗按名字收窄。
## 193 补充二：格位图标 40
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func run_icon_row(t: TestCase) -> void:
	t.begin("193 补充三 · 副行：有图的标签是 [url=term:tag:<id>][img] 图标，另起一行；没图的照写名字；词条 tag:<id> 带名字")
	var db := _db()
	var blade := ItemInstance.create(db.get_def(&"festering_blade"))     # 250：每轴只列一个 —— 武器 + 流血两枚图标
	var full := ItemTooltip.describe_full(blade)
	var head := String(full["head"])
	var lines := head.split("\n")
	t.check(lines.size() >= 3 and not lines[1].contains("[img=") and lines[2].contains("[img=%d]" % ItemTooltip.TAG_ICON_SIZE), "稀有度名一行、图标另起一行（待定 3.1 A）")
	t.check(not head.contains(" · "), "不再用「 · 」隔开")
	var terms: Dictionary = full["terms"]
	t.check(terms.has("tag:weapon") and terms.has("tag:bleed"), "图标各有一条词条")
	t.eq(String((terms["tag:weapon"] as Dictionary)["name"]), Glossary.tag_name(&"weapon"), "词条名字 = 标签显示名")
	t.eq(ItemTooltip.TAG_ICON_SIZE, 32, "32 px，和献祭栏一样")
	# 没图的标签：写字，不出图标、不出 tag: 词条
	var fake := TagDef.new()
	fake.id = &"zz_noicon_193c"
	fake.display_name = "无图标签"
	fake.category = "element"
	TagRegistry.register(fake)
	var row := ItemTooltip.tag_icons([&"weapon", &"zz_noicon_193c"])
	t.check(row.contains("weapon.png") and row.contains("[color=@tip_meta]无图标签[/color]"), "有图画图、没图写名字（%s）" % row)
	t.check(not ItemTooltip.tag_icon_terms([&"zz_noicon_193c"]).has("tag:zz_noicon_193c"), "没图的不进 tag: 词条（还按文字找）")
	TagRegistry.reset()
	for id in [&"cloth", &"herb", &"clay"]:
		t.check(TagRegistry.icon_path(id) != "", "195 的三枚图标接上了：%s" % id)


static func run_marker_side(t: TestCase) -> void:
	t.begin("193 补充二 · 格位图标 40：格 60 时 40，格子小了按 0.67 缩，拖拽残影同尺寸")
	t.eq(InventoryView.marker_side(60.0), 40.0, "格 60：40")
	t.eq(InventoryView.marker_side(InventoryView.CELL), minf(40.0, InventoryView.CELL * 0.67), "默认格")
	t.check(is_equal_approx(InventoryView.marker_side(30.0), 20.1), "格 30：按 0.67 缩")
	var tex := UiTheme.slot_icon("grant", true)
	t.check(tex != null and tex.get_width() == 40, "新图 40×40（v3）")


static func frame_name_only_child(t: TestCase, root: Window) -> void:
	t.begin("193 补充三 · 钉住后停在标签图标上开子窗：只写名字，按名字宽收窄")
	var db := _db()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var board := GridInventory.new(Vector2i(4, 3), 1)
	board.place(ItemInstance.create(db.get_def(&"knife")), Vector2i(0, 0), 0)
	var view := InventoryView.new()
	view.inventory = board
	view.position = Vector2(20, 20)
	view.size = Vector2(board.size) * InventoryView.CELL
	host.add_child(view)
	var tip := HoverTip.new()
	host.add_child(tip)
	tip.watch(view)
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(24, 24)
	view.gui_input.emit(mm)
	var src := view.get_global_position() + mm.position     # 作者 10-27：停在道具上才钉
	tip.tick(0.3, src)
	tip.tick(0.31 + HoverTip.PIN_DELAY_SEC + HoverTip.PIN_SEC, src)
	var inside := tip._panel.global_position + tip._panel.size * 0.5
	t.check(tip.is_pinned(), "钉住")
	var terms: Dictionary = tip._panel.terms
	t.check(terms.has("tag:weapon"), "主窗认得 tag:weapon")
	tip._panel.hover("term:tag:weapon")
	tip.tick(0.3, inside)
	t.eq(tip.windows().size(), 2, "停 0.25 秒开子窗")
	if tip.windows().size() == 2:
		var child: HoverTip.TipWindow = tip.windows()[1]
		t.check(child.text().contains(Glossary.tag_name(&"weapon")), "子窗写名字")
		t.check(child.size.x < HoverTip.MIN_WIDTH, "只写名字：比最窄的主窗还窄（%.0f）" % child.size.x)
	host.queue_free()
