## 171 §2（作者定）：标签分大类 —— 用途 / 属性 / 材料 / 归属 / 来源 / 内部；标签先在标签制作器里建，道具只能从下拉里挑，没登记的导入报错；
## 每件材料在来源类（工艺 / 自然 / 魔法）里恰好一个；悬浮窗副行按大类排。
extends RefCounted


static func _ctx_with_tags() -> ContentImporter.Context:
	var ctx := ContentImporter.Context.new()
	for id in TagRegistry.ids():
		ctx.register_tag(TagRegistry.get_def(id))
	return ctx


static func _item(tags: Array) -> Dictionary:
	return {"id": "probe_171", "display_name": "探针", "shape": ["1"], "tags": tags}


static func _material(tags: Array) -> Dictionary:
	var d := _item(tags)
	d["material"] = "metal"
	return d


static func run_categories(t: TestCase) -> void:
	t.begin("171 · 标签大类：每条登记的标签都归了类；bow / wood 补登记；by_category / category_of；faith:<id> 算归属；按大类排序")
	TagRegistry.reset()
	for id in TagRegistry.ids():
		var def := TagRegistry.get_def(id)
		t.check(TagRegistry.CATEGORY_ORDER.has(def.category), "「%s」归了类（%s）" % [id, def.category])
	t.eq(TagRegistry.category_of(&"weapon"), "kind", "武器：类别（250：用途改叫类别）")
	t.eq(TagRegistry.category_of(&"wood"), "", "木制：250 起材质不是标签（ItemDef.material）")
	t.eq(TagRegistry.category_of(&"fire"), "element", "火焰：属性类")
	t.eq(TagRegistry.category_of(&"imperial"), "affiliation", "帝国：归属类")
	t.eq(TagRegistry.category_of(&"faith:sun"), "affiliation", "faith:<id> 算归属")
	t.eq(TagRegistry.by_category("source"), [&"crafted", &"magic", &"nature"], "本源类：工艺 / 魔法 / 自然（待定 1 A）")
	t.check(TagRegistry.by_category("internal").has(&"rapid"), "快攻在内部类")
	t.check(TagRegistry.by_category("internal").all(func(id): return TagRegistry.is_internal(id)), "内部类的都是内部标签")
	t.eq(TagRegistry.category_of(&"zz_nobody"), "", "没登记的没有类")
	var sorted := TagRegistry.sorted_by_category([&"melee", &"imperial", &"fire", &"weapon", &"crafted", &"bleed"])
	t.eq(sorted, [&"weapon", &"fire", &"bleed", &"crafted", &"imperial", &"melee"], "类别 → 属性 → 本源 → 归属 → 内部（250），同类保持原顺序")


static func run_import_rules(t: TestCase) -> void:
	t.begin("171 · 导入：标签得归一类；道具上没登记的标签报错（faith:<id> 除外）；材料按来源类恰好一个")
	var r0 := ImportReport.new()
	ContentImporter.import_tag({"id": "zz_new", "display_name": "新"}, ContentImporter.Context.new(), r0)
	t.check(not r0.ok(), "没写 category：报错")
	var r1 := ImportReport.new()
	ContentImporter.import_tag({"id": "zz_new", "display_name": "新", "category": "kind"}, ContentImporter.Context.new(), r1)
	t.check(r1.ok(), "写了 category：过")
	var r2 := ImportReport.new()
	ContentImporter.import_tag({"id": "zz_new", "display_name": "新", "category": "nope"}, ContentImporter.Context.new(), r2)
	t.check(not r2.ok(), "类别不在表里：报错")

	var ctx := _ctx_with_tags()
	var bad := ImportReport.new()
	ContentImporter.import_item(_item(["treasure", "zz_unregistered"]), ctx, bad)
	t.check(not bad.ok(), "道具带没登记的标签：报错（不再漏过）")
	var faith := ImportReport.new()
	ContentImporter.import_item(_item(["treasure", "faith:sun"]), ctx, faith)
	t.check(not faith.to_text().contains("zz_") and not faith.to_text().contains("没有登记的标签"), "faith:<id> 不算没登记")
	var none := ImportReport.new()
	ContentImporter.import_item(_material(["material"]), ctx, none)
	t.check(none.to_text().contains("本源"), "素材没带本源：报错")
	var two := ImportReport.new()
	ContentImporter.import_item(_material(["material", "crafted", "nature"]), ctx, two)
	t.check(two.to_text().contains("本源"), "素材带了两个本源：报错")
	var one := ImportReport.new()
	ContentImporter.import_item(_material(["material", "crafted"]), ctx, one)
	t.check(one.ok(), "恰好一个：过（%s）" % one.to_text())


static func frame_tag_dropdown(t: TestCase, root: Window) -> void:
	t.begin("171 · 道具编辑器：标签栏不能手打，下拉按大类分组只列登记过的，选一个加一个，每块后面一个 × 能删")
	var saved := UiText.lang
	UiText.lang = "zh"
	var def := ItemDef.new()
	def.id = &"probe"
	def.shape = ItemShape.new()
	def.tags = [&"weapon"] as Array[StringName]
	var form := PropertyForm.create(def, UiPalette.cjk_font())
	root.add_child(form)
	var rows := form.find_children("*", "HBoxContainer", true, false).filter(func(n): return (n as Node).has_meta("tag_options"))
	t.check(not rows.is_empty(), "tags 字段是标签块 + 下拉")
	if not rows.is_empty():
		var row: Control = rows[0]
		t.check(row.get_children().all(func(c): return c is HFlowContainer or c is OptionButton), "只有标签块与下拉，没有手打的输入框")
		var ob: OptionButton = row.get_meta("tag_options")
		var choices: Array = row.get_meta("tag_choices")
		var seps := 0
		for i in ob.item_count:
			if ob.is_item_separator(i):
				seps += 1
		t.eq(seps, PropertyForm.tag_groups().size(), "每个大类一个分组标题（%d）" % seps)
		t.check(ob.get_item_text(1) == "类别", "第一组是类别")
		t.check(not choices.has("zz_nobody"), "只列登记过的")
		var at := choices.find("fire")
		ob.item_selected.emit(at)
		t.check(def.tags.has(&"fire") and def.tags.has(&"weapon"), "选一个就追加：%s" % str(def.tags))
		ob.item_selected.emit(choices.find("weapon"))
		t.eq(def.tags.size(), 2, "已有的不重复加")
		var chips: Control = row.get_meta("tag_chips")
		var first := chips.get_child(0) as Button
		t.check(first.text.ends_with("×"), "每块后面一个 ×（%s）" % first.text)
		first.pressed.emit()
		t.check(not def.tags.has(&"weapon") and def.tags.has(&"fire"), "点 × 删掉那一个")
	form.queue_free()
	UiText.lang = saved


static func frame_tag_editor(t: TestCase, root: Window) -> void:
	t.begin("171 · 标签制作器：能开、列出全部标签；新建的有类别；校验走导入器（没类别报错）")
	var scene: PackedScene = load("res://ui/tag_editor/tag_editor.tscn")
	var ed = scene.instantiate()
	root.add_child(ed)
	t.check(ed.def() is TagDef, "打开了一条标签")
	t.eq(ed._ids.size(), TagRegistry.ids().size(), "列表 = 全部登记的标签（%d）" % ed._ids.size())
	ed._new_tag()
	t.eq(ed.def().category, "kind", "新建的默认类别（250）")
	t.check(ed._validate().ok(), "新建的校验通过")
	ed.def().category = ""
	t.check(not ed._validate().ok(), "去掉类别：校验报错")
	ed.queue_free()
