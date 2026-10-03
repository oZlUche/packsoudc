## 111（作者定）：编辑器里字符串枚举是下拉（值仍是原字符串）；字段按别的字段的值显隐（`FIELD_WHEN`），
## 切走后被藏起来的字段归默认；信仰加成写了超过信仰阶数的「第几阶」导入报错。
extends RefCounted


static func run_string_enum_options(t: TestCase) -> void:
	t.begin("111 · 字符串枚举的可选值原样给出（不当整数枚举解析）")
	var b := FaithBonus.new()
	var opts := ContentImporter._string_choices(b, "mode")
	t.eq(opts, ["tier", "active", "scaled"] as Array[String], "mode 三个选项，值是小写原文")
	t.eq(FieldText.enum_label("tier"), "按阶", "下拉显示中文：按阶")
	t.eq(FieldText.enum_label("active"), "激活即", "激活即")
	t.eq(FieldText.enum_label("scaled"), "按信力", "按信力")


static func run_field_visible(t: TestCase) -> void:
	t.begin("111 · 按方式显隐：tier 只露阶；scaled 露每份信力与叠层上限；active 一个都不露")
	var b := FaithBonus.new()
	b.mode = "tier"
	t.check(ContentSchema.field_visible(b, "tier"), "按阶：显示阶")
	t.check(not ContentSchema.field_visible(b, "per_points"), "按阶：不显示每份信力")
	t.check(not ContentSchema.field_visible(b, "max_stacks"), "按阶：不显示叠层上限")
	b.mode = "scaled"
	t.check(not ContentSchema.field_visible(b, "tier"), "按信力：不显示阶")
	t.check(ContentSchema.field_visible(b, "per_points") and ContentSchema.field_visible(b, "max_stacks"), "按信力：显示每份信力与叠层上限")
	b.mode = "active"
	for key in ["tier", "per_points", "max_stacks"]:
		t.check(not ContentSchema.field_visible(b, key), "激活即：不显示 %s" % key)
	t.check(ContentSchema.field_visible(b, "mods") and ContentSchema.field_visible(b, "mode"), "没列进表的字段照常显示")
	t.eq(ContentSchema.default_of(b, "per_points"), 50, "默认值读脚本：每份 50 信力")


static func run_tier_beyond_thresholds(t: TestCase) -> void:
	t.begin("111 · 按阶的加成写到超过信仰阶数：导入报错；现有内容照常导入")
	var ctx := ContentImporter.Context.new()
	var hunt := load(ContentPaths.asset_file("faiths", "hunt")) as FaithDef
	t.not_null(hunt, "狩猎之神的定义在")
	if hunt == null:
		return
	ctx.register_faith(hunt)
	var tiers := hunt.thresholds.size()
	var src := FileAccess.get_file_as_string(ContentPaths.authoring_file("items", "blessed_longbow"))
	var data: Dictionary = JSON.parse_string(src)
	var ok_report := ImportReport.new()
	ContentImporter.import_item(data.duplicate(true), ctx, ok_report)
	t.check(ok_report.ok(), "原样的祝福长弓导得进来：%s" % ok_report.to_text())

	var bad := data.duplicate(true)
	(bad["faith_bonuses"] as Array).append({"tier": tiers + 1, "mods": [{"flat": 1.0}]})
	var report := ImportReport.new()
	ContentImporter.import_item(bad, ctx, report)
	t.check(not report.ok(), "第 %d 阶（只有 %d 阶）报错" % [tiers + 1, tiers])
	t.check(report.to_text().contains("永远达不到"), "报错说清楚：%s" % report.to_text())

	var odd := data.duplicate(true)
	(odd["faith_bonuses"] as Array).append({"mode": "sometimes", "mods": [{"flat": 1.0}]})
	var report2 := ImportReport.new()
	ContentImporter.import_item(odd, ctx, report2)
	t.check(not report2.ok(), "认不得的方式报错")


static func _picker_in(row: Node) -> OptionButton:
	if row is OptionButton:
		return row
	for c in row.get_children():
		var got := _picker_in(c)
		if got != null:
			return got
	return null


static func frame_form_dropdown_and_hiding(t: TestCase, root: Window) -> void:
	t.begin("111 · 表单：方式是下拉；切到「激活即」阶的框藏起来且归默认；切到「按信力」露出两个数")
	var b := FaithBonus.new()
	b.mode = "tier"
	b.tier = 3
	var form := PropertyForm.create(b, UiPalette.cjk_font())
	root.add_child(form)
	t.check(form.row_visible("mode"), "方式那一行在")
	var picker := _picker_in(form._rows["mode"])
	t.not_null(picker, "方式是下拉框，不是输入框")
	if picker == null:
		form.queue_free()
		return
	t.eq(picker.item_count, 3, "三个选项")
	t.eq(picker.get_item_text(picker.selected), "按阶", "选中的是「按阶」")
	t.check(form.row_visible("tier") and not form.row_visible("per_points") and not form.row_visible("max_stacks"), "按阶：只露阶")

	picker.item_selected.emit(1)     # 激活即
	t.eq(b.mode, "active", "值写回原字符串 active")
	t.check(not form.row_visible("tier") and not form.row_visible("per_points") and not form.row_visible("max_stacks"), "激活即：一个数也不露")
	t.eq(b.tier, 1, "被藏起来的阶归默认（JSON 里不留看不见的旧值）")

	b.per_points = 80
	picker.item_selected.emit(2)     # 按信力
	t.eq(b.mode, "scaled", "按信力")
	t.check(form.row_visible("per_points") and form.row_visible("max_stacks") and not form.row_visible("tier"), "按信力：露每份信力与叠层上限")
	t.eq(b.per_points, 80, "露着的字段不动")
	form.queue_free()
