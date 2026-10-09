## 146（作者定）：buff 是独立内容（道具按 id 引用）；扳机 / 节奏 / 消耗 / 效果可以存进规则构件库，规则里写 `"@id"` 引用（导入时复制一份）。
extends RefCounted


static func _ctx_with_part(id: String, slot: String, data: Dictionary) -> ContentImporter.Context:
	var ctx := ContentImporter.Context.new()
	var report := ImportReport.new()
	ContentImporter.import_rule_part({"id": id, slot: data}, ctx, report)
	return ctx


static func run_part_refs_import(t: TestCase) -> void:
	t.begin("146 · 规则里的 @id：复制一份、打上来源；类不对 / 在 buff 里 / 构件套构件都报错")
	var ctx := _ctx_with_part("tick", "trigger", {"type": "on_schedule"})
	ContentImporter.import_rule_part({"id": "hit", "effect": {"type": "deal_damage", "amount": 3}}, ctx, ImportReport.new())
	var report := ImportReport.new()
	var rule := ContentImporter._make_object(&"AbilityRule",
		{"trigger": "@tick", "cadence": {"type": "always"}, "effects": ["@hit", "@hit"]}, "r", ctx, report) as AbilityRule
	t.check(report.ok(), "引用都解析得了：" + report.to_text())
	t.check(rule.trigger is OnSchedule, "扳机是库里那份的类型")
	t.eq(String(rule.trigger.get_meta(RulePartDef.REF_META, "")), "tick", "打上了来源 part_ref")
	t.check(rule.trigger != ctx.rule_parts[&"tick"].trigger, "是复制出来的一份，不是库里那个对象")
	t.check(rule.effects[0] != rule.effects[1], "同一个构件引用两次是两份")
	t.eq((rule.effects[0] as DealDamage).amount, 3.0, "数值照库里")

	var bad := ImportReport.new()
	ContentImporter._make_object(&"AbilityRule", {"trigger": "@hit", "cadence": {"type": "always"}, "effects": ["@hit"]}, "r", ctx, bad)
	t.check(not bad.ok() and bad.to_text().contains("CombatEffect"), "把效果填进扳机：报错说类不对")
	var missing := ImportReport.new()
	ContentImporter._make_object(&"AbilityRule", {"trigger": "@nope", "cadence": {"type": "always"}, "effects": ["@hit"]}, "r", ctx, missing)
	t.check(not missing.ok() and missing.to_text().contains("找不到规则构件"), "库里没有：报错")
	ContentLibrary.reset()
	var loose := ImportReport.new()
	var from_disk := ContentImporter._make_object(&"AbilityRule", {"trigger": "@on_schedule", "cadence": {"type": "always"}, "effects": [{"type": "deal_damage"}]}, "r", ContentImporter.Context.new(), loose)
	t.check(from_disk != null and (from_disk as AbilityRule).trigger is OnSchedule, "登记表里没有：单件导入到盘上的库里找")
	var strict_ctx := ContentImporter.Context.new()
	strict_ctx.strict = true
	var strict_rep := ImportReport.new()
	ContentImporter._make_object(&"AbilityRule", {"trigger": "@on_schedule", "cadence": {"type": "always"}, "effects": [{"type": "deal_damage"}]}, "r", strict_ctx, strict_rep)
	t.check(not strict_rep.ok(), "批量导入（strict）只认这一趟登记的：报错")

	var in_buff := ImportReport.new()
	ContentImporter.import_buff({"id": "b146", "rules": [{"trigger": "@tick", "cadence": {"type": "always"}, "effects": [{"type": "deal_damage"}]}]}, ctx, in_buff)
	t.check(not in_buff.ok() and in_buff.to_text().contains("buff 的规则请内联"), "buff 自己的规则不能引用构件")
	var nested := ImportReport.new()
	ContentImporter.import_rule_part({"id": "x", "trigger": "@tick"}, ctx, nested)
	t.check(not nested.ok() and nested.to_text().contains("构件里不能再引用构件"), "构件不套构件")
	var two := ImportReport.new()
	ContentImporter.import_rule_part({"id": "y", "trigger": {"type": "on_schedule"}, "cadence": {"type": "always"}}, ctx, two)
	t.check(not two.ok(), "一份构件填了两样：报错")


static func run_library_refs_export(t: TestCase) -> void:
	t.begin("146 · 导出：库里的 buff 写 id、来自库的构件写 @id；改过 / 断开的整份内联")
	ContentLibrary.reset()
	var bleed: BuffDef = ContentLibrary.buffs().get(&"bleed", null)
	t.not_null(bleed, "流血在库里（data/buffs/bleed.tres）")
	var tick := ContentLibrary.part(&"on_schedule")
	t.not_null(tick, "「自发」在构件库里")
	if bleed == null or tick == null:
		return
	var apply := ApplyStatus.new()
	apply.buff = bleed
	t.eq(ContentExporter.dump(apply)["buff"], "bleed", "库里那份：写 id")
	var mine := bleed.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as BuffDef
	apply.buff = mine
	t.eq(ContentExporter.dump(apply)["buff"], "bleed", "内容一样的拷贝也写 id")
	mine.display_name = "我自己的流血"
	t.check(ContentExporter.dump(apply)["buff"] is Dictionary, "改过的：整份内联")

	var rule := AbilityRule.new()
	rule.trigger = ContentLibrary.instance_of(tick)
	rule.cadence = Always.new()
	rule.effects.append(DealDamage.new())
	t.eq(ContentExporter.dump(rule)["trigger"], "@on_schedule", "来自库的扳机写 @id")
	rule.trigger.remove_meta(RulePartDef.REF_META)
	t.check(ContentExporter.dump(rule)["trigger"] is Dictionary, "断开之后整份内联")

	# 迁移之后：作者数据里引用的 buff 都在库里，没有同 id 还内联着的
	var inline_left: Array[String] = []
	for id in ContentPaths.ids_in(ContentPaths.dirs_of("items")[0]):
		var text := FileAccess.get_file_as_string(ContentPaths.authoring_file("items", id))
		for bid in ContentLibrary.buffs():
			if text.contains("\"id\": \"%s\"" % bid) and text.contains("\"buff\": {"):
				inline_left.append("%s/%s" % [id, bid])
	t.check(inline_left.is_empty(), "道具里不再内联库里有的 buff" if inline_left.is_empty() else ", ".join(inline_left))
	t.check(ContentLibrary.buffs().size() >= 10, "库里有 %d 个 buff" % ContentLibrary.buffs().size())
	t.check(ContentLibrary.parts().size() >= 10, "构件库里有 %d 个" % ContentLibrary.parts().size())


static func frame_run_editor_library(t: TestCase, root: Window) -> void:
	t.begin("146 · 编辑器：下拉里有「库：」、来自库的只读能断开、buff 字段选库里的")
	ContentLibrary.reset()
	var tick := ContentLibrary.part(&"on_schedule")
	if tick == null:
		t.check(false, "构件库里没有 on_schedule")
		return
	var rule := AbilityRule.new()
	var form := PropertyForm.create(rule, null)
	root.add_child(form)
	var lib_pick: OptionButton = null
	for n in form.find_children("*", "HBoxContainer", true, false):
		if n.has_meta("library"):
			lib_pick = n.get_meta("library")
			break
	t.not_null(lib_pick, "扳机的「添加」下拉有库那一组")
	if lib_pick == null:
		form.queue_free()
		return
	var at := -1
	for i in lib_pick.item_count:
		if lib_pick.get_item_text(i) == "库：" + PropertyForm.part_label(tick):
			at = i
	t.check(at >= 0, "列着「库：%s」" % PropertyForm.part_label(tick))
	lib_pick.select(at)
	(lib_pick.get_parent().get_child(1) as Button).pressed.emit()
	t.eq(PropertyForm.part_ref_of(rule.trigger), "on_schedule", "选了库项 = 复制一份、来自库")
	var subs := form.find_children("*", "PropertyForm", true, false)
	t.check(not subs.is_empty() and subs[0].locked, "来自库的那块表单只读")
	var unlink: Button = null
	for b in form.find_children("*", "Button", true, false):
		if (b as Button).text == "断开":
			unlink = b
	t.not_null(unlink, "有「断开」")
	if unlink != null:
		unlink.pressed.emit()
		t.eq(PropertyForm.part_ref_of(rule.trigger), "", "断开之后不再来自库")
	form.queue_free()

	# 构件编辑器自己的表单不列库（构件不套构件）
	var part_form := PropertyForm.create(RulePartDef.new(), null)
	part_form.parts_allowed = false
	root.add_child(part_form)
	var has_lib := false
	for n in part_form.find_children("*", "HBoxContainer", true, false):
		has_lib = has_lib or n.has_meta("library")
	t.check(not has_lib, "不许用库的表单里没有库那一组")
	part_form.queue_free()

	# buff 字段：选了库里的流血 = 引用，只读
	var apply := ApplyStatus.new()
	apply.buff = ContentLibrary.buffs().get(&"bleed", null)
	var bform := PropertyForm.create(apply, null)
	root.add_child(bform)
	var picker: OptionButton = null
	for n in bform.find_children("*", "VBoxContainer", true, false):
		if n.has_meta("buff_picker"):
			picker = n.get_meta("buff_picker")
	t.not_null(picker, "buff 字段是下拉")
	if picker != null:
		t.eq(picker.get_item_text(picker.selected), PropertyForm.buff_id_label("bleed"), "停在库里的流血上")
		picker.select(0)
		picker.item_selected.emit(0)
		t.check(apply.buff != ContentLibrary.buffs()[&"bleed"], "选「内联」= 拷一份成这一件自己的")
	bform.queue_free()


static func frame_run_part_editor(t: TestCase, root: Window) -> void:
	t.begin("146 · 构件编辑器：按类分页、谁在用")
	ContentLibrary.reset()
	var ed = load("res://ui/part_editor/part_editor.tscn").instantiate()
	root.add_child(ed)
	t.check(ed._ids.size() >= 10, "列表里有库里的构件")
	ed._group = 1     # 扳机
	ed._repaint_list()
	var all_triggers := true
	for id in ed._shown:
		all_triggers = all_triggers and ed._slot_for(id) == "trigger"
	t.check(not ed._shown.is_empty() and all_triggers, "「扳机」页只有扳机")
	t.check(not ed.users("on_schedule").is_empty(), "「自发」有人在用")
	ed._open("on_schedule")
	t.check(ed._preview.text != "", "顶上有一句预览")
	ed.queue_free()
