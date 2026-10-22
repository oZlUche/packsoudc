## 执行报（10-22）：strip_bbcode 只剥 RichTextLabel 认的标签，正文里的方括号（英文触发词「[When this item activates]」）留着
extends RefCounted

const ForgeTest := preload("res://tests/run/test_forge_175.gd")


static func run_strip_known_tags_only(t: TestCase) -> void:
	t.begin("strip_bbcode · 只剥认识的标签，正文方括号留着；和 RichTextLabel 显示的字一致")
	t.eq(TextTemplate.strip_bbcode("[b]Bold[/b] [color=#ff0000]red[/color] [url=term:x]word[/url]"), "Bold red word", "常用标签剥掉")
	t.eq(TextTemplate.strip_bbcode("[font_size=16][i]a[/i][/font_size][outline_size=2][outline_color=#000]b[/outline_color][/outline_size]"), "ab", "字号、描边剥掉")
	t.eq(TextTemplate.strip_bbcode("x[img=24x24]res://a.png[/img]y"), "xy", "行内图标整个去掉")
	t.eq(TextTemplate.strip_bbcode("[color=@tip_fg]a[/color]"), "a", "样式码颜色剥掉")
	t.eq(TextTemplate.strip_bbcode("[When this item activates]: deal 3"), "[When this item activates]: deal 3", "英文触发词留着")
	t.eq(TextTemplate.strip_bbcode("[b][When this item activates][/b]"), "[When this item activates]", "标签里包着的方括号正文留着")
	t.eq(TextTemplate.strip_bbcode("[Board] and [bag slot]"), "[Board] and [bag slot]", "不是标签名的方括号留着（[b 后面不是 ] = 空格）")
	t.eq(TextTemplate.strip_bbcode("[出手时]"), "[出手时]", "中文方括号文字留着")
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	for s in ["[b][When this item activates][/b]: [color=#c00]Bleed[/color] ×3", "[table=2][cell]a[/cell][cell]b[/cell][/table]", "[u]x[/u] [s]y[/s] [code]z[/code]"]:
		r.text = s
		t.eq(TextTemplate.strip_bbcode(s), r.get_parsed_text(), "和 RichTextLabel 一致：%s" % s)
	r.free()


static func run_forge_sentence_english(t: TestCase) -> void:
	t.begin("strip_bbcode · 英文铸牌那一句剥完还有触发词（原来显示成「Bloodthirsty :  at most once…」）")
	var lang0 := UiText.lang
	UiText.lang = "en"
	var db: ItemDatabase = ForgeTest._db()
	var ench := Forge.forge(db.get_def(&"knife"), db.get_def(&"antler"), db.get_def(&"knife"))
	var plain := Glossary.strip_bbcode(Forge.sentence(ench))
	t.check(plain.contains(UiText.t("trig.self_fired")), "英文那一句有触发词：%s" % plain)
	UiText.lang = lang0
