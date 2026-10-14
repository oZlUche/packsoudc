## 171 §1（作者定）：buff 加「是否有专属解说」与解说文本 —— 悬浮窗的句子提到这个 buff 时，有解说写解说、没有只写名字。
extends RefCounted


static func run_blurb_fields(t: TestCase) -> void:
	t.begin("171 · buff 解说：has_blurb / blurb 存读；勾了没写提醒；句子里有解说写解说（当前语言没有用中文）、没有写名字；表单只在勾上时显示解说栏")
	var def := BuffDef.new()
	def.id = &"probe_blurb"
	def.display_name = "血怒"
	t.eq(def.sentence_text(), "血怒", "没勾：写名字")
	def.has_blurb = true
	t.eq(def.sentence_text(), "血怒", "勾了没写：还是名字")
	var empty := ImportReport.new()
	ContentImporter.import_buff(ContentExporter.export_buff(def), ContentImporter.Context.new(), empty)
	t.check(empty.to_text().contains("解说是空的"), "勾了没写：导入提醒")
	def.blurb = "受伤越多打得越狠"
	def.blurbs = {"en": "Hits harder the more it is hurt"}
	t.eq(def.sentence_text("zh"), "受伤越多打得越狠", "有解说：写解说")
	t.eq(def.sentence_text("en"), "Hits harder the more it is hurt", "英文写英文解说")
	t.eq(def.sentence_text("ja"), "受伤越多打得越狠", "没有这门语言：用中文")
	var data := ContentExporter.export_buff(def)
	t.check(bool(data.get("has_blurb", false)) and String(data.get("blurb", "")) != "", "导出带着两栏")
	var report := ImportReport.new()
	var back := ContentImporter.import_buff(data, ContentImporter.Context.new(), report)
	t.check(report.ok() and back.has_blurb and back.blurb == def.blurb and back.blurbs == def.blurbs, "导回来一样")
	t.eq(ContentExporter.export_buff(BuffDef.new()).has("has_blurb"), false, "默认没勾：JSON 里不写")
	t.eq(BuffDef.FIELD_WHEN["blurb"], {"has_blurb": [true]}, "解说栏只在勾上时显示（111 FIELD_WHEN）")
