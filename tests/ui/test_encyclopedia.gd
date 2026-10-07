## 114（作者定）：百科的框架 —— 手写的机制页（help_pages 内容种类）+ 自动生成的词条页、链接跳页与「上一页」、搜索、
## 主菜单与暂停菜单两个入口（Esc 先关百科再关暂停）。机制页的文案由别的线程写，这里只验框架
extends RefCounted

const GAME := "res://ui/game/game.tscn"
## 与 Support.paths("114") 是同一组路径（flow / cleanup 按前缀算）
const SAVE := "user://test_114_run.json"
const META := "user://test_114_meta.json"
const SETTINGS := "user://test_114_settings.json"
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _book() -> Encyclopedia:
	var db := ItemDatabase.new()
	db.load_dir()
	return Encyclopedia.build(GameFlow.load_help_pages(), db)


static func run_pages(t: TestCase) -> void:
	t.begin("114 · 百科的页：机制页走内容管线；每个固定词条、非内部标签、伤害类型、道具里的 buff 都有一页；每页渲染后没有漏换的记号")
	var help := GameFlow.load_help_pages()
	t.check(not help.is_empty(), "至少有一页机制页（%d）" % help.size())
	var db := ItemDatabase.new()
	db.load_dir()
	var book := Encyclopedia.build(help, db)
	for h in help:
		t.check(book.has_page(String(h.id)), "机制页 %s 在" % h.id)
		t.check(HelpPageDef.CATEGORIES.has(String(h.category)), "%s 的分类在清单里" % h.id)
	for name in Glossary.TERMS:
		t.check(book.has_page("term:" + String(name)), "词条「%s」有一页" % name)
	for tag in TagRegistry.ids():
		if not TagRegistry.is_internal(tag) and FaithTags.id_of_tag(tag) == &"":
			t.check(book.has_page("tag:" + String(tag)), "标签 %s 有一页" % tag)
	for d in DamageTypes.ids():
		t.check(book.has_page("dtype:" + String(d)), "伤害类型 %s 有一页" % d)
	var buffs := {}
	for id in db.ids():
		buffs.merge(Glossary.buffs_in_item(db.get_def(id)))
	t.check(not buffs.is_empty(), "道具里有 buff")
	for bid in buffs:
		t.check(book.has_page("buff:" + String(bid)), "buff %s 有一页" % bid)
	var ctx := {"_items": db}
	for id in book.ids():
		var shown := Glossary.strip_bbcode(book.render(id, ctx))
		t.check(not shown.contains("{") and not shown.contains("}"), "%s 渲染后没有漏换的记号" % id)
		t.check(String(book.page(id)["title"]) != "", "%s 有标题" % id)
	# 目录：机制页的分类在前、词条在最后；同名的属性 / 时机不重复开页
	var toc := book.toc()
	t.check(not toc.is_empty() and String(toc[-1]["category"]) == Encyclopedia.TERMS_CATEGORY, "目录最后一栏是词条")
	t.check(not book.has_page("stat:haste") and book.has_page("term:急速"), "属性「急速」和词条同名：不另开页")
	t.eq(book.page_for("合成"), "crafting", "「合成」先跳机制页（压过同名词条）")


static func run_recipe_notes(t: TestCase) -> void:
	t.begin("140 · 百科「合成」页列出全部配方，带作者写的 note；图鉴没点亮的遮名字、不写 note；别的页不列")
	var db := ItemDatabase.new()
	db.load_dir()
	var recipes := RecipeDef.load_all()
	t.check(not recipes.is_empty(), "有配方（%d）" % recipes.size())
	var book := Encyclopedia.build(GameFlow.load_help_pages(), db, recipes)
	var text := book.render(Encyclopedia.RECIPE_PAGE)
	t.check(text.contains("配方："), "合成页有「配方」段")
	for r in recipes:
		t.check(r.note == "" or text.contains(r.note), "%s 的 note 在合成页上" % r.id)
		t.check(text.contains(Names.of(db.get_def(r.output))), "%s 的产物名在" % r.id)
	t.check(not book.render(book.ids()[book.ids().size() - 1]).contains("配方："), "别的页不列配方")
	book.lit = func(_id: StringName) -> bool: return false
	var dark := book.render(Encyclopedia.RECIPE_PAGE)
	t.check(dark.contains("？ + ？ → ？"), "全没点亮：名字遮住")
	t.check(not dark.contains(recipes[0].note), "没点亮不写 note（note 里有道具名）")
	t.check(not Encyclopedia.build(GameFlow.load_help_pages(), db).render(Encyclopedia.RECIPE_PAGE).contains("配方："), "没给配方：不列")


static func run_links_and_search(t: TestCase) -> void:
	t.begin("114 · 链接与搜索：正文里认得的词画成 [url=页 id]（不链自己）；「相关」「相关道具」接在后面，没点亮的道具写「？」；搜索标题命中排前面")
	var book := _book()
	var ctx := {"_items": book.items}
	var crafting := book.render("crafting", ctx)
	t.eq(book.link_words("毒无视护盾，合成也行"), "毒无视[url=shield]护盾[/url]，[url=crafting]合成[/url]也行", "认得的词画成链接（同名先跳机制页：125 起护盾也有机制页）")
	t.eq(book.link_words("合成", "crafting"), "合成", "不链自己那一页")
	t.check(not crafting.contains("[url=crafting]"), "不链自己")
	t.check(crafting.contains("相关道具："), "相关道具一行")
	book.lit = func(id: StringName) -> bool: return id == &"knife"
	var masked := book.render("crafting", ctx)
	t.check(masked.contains(Names.of(book.items.get_def(&"knife"))) and masked.contains("？"), "点亮过的写名字、没点亮的写「？」")
	var hits := book.search("合成", ctx)
	t.check(not hits.is_empty() and (hits[0] == "crafting" or hits[0] == "term:合成"), "搜「合成」：标题命中的排前面（%s）" % str(hits.slice(0, 3)))
	t.check(book.search("   ").is_empty(), "空查询：没有结果")
	# buff 页写「来自」
	for id in book.ids():
		if id.begins_with("buff:"):
			t.check(book.render(id, ctx).contains("来自："), "%s 写着来自哪件道具" % id)
			break


static func run_import_checks(t: TestCase) -> void:
	t.begin("114 · 导入：分类要在清单里、标题正文不空、相关道具是真道具、id 不带冒号；「相关」指到的页 / 词条要存在")
	var ctx := ContentImporter.Context.new()
	var db := ItemDatabase.new()
	db.load_dir()
	ctx.register_item(db.get_def(&"knife"))
	var good := {"id": "p1", "display_name": "一页", "category": "bag", "text": "拿着{item:knife}。", "related": ["合成"], "see_items": ["knife"]}
	var r := ImportReport.new()
	var def := ContentImporter.import_help_page(good, ctx, r)
	t.check(r.ok() and def != null, "好的一页：不报 %s" % r.to_text())
	var bad := {"id": "a:b", "display_name": "", "category": "nope", "text": "", "see_items": ["no_such"]}
	var r2 := ImportReport.new()
	ContentImporter.import_help_page(bad, ctx, r2)
	var txt := r2.to_text()
	for word in ["冒号", "标题", "正文", "nope", "no_such"]:
		t.check(txt.contains(word), "报了「%s」" % word)
	var r3 := ImportReport.new()
	ContentImporter.validate_help_pages(ctx, r3)
	t.check(r3.ok(), "相关指到词条名：不报")
	ContentImporter.import_help_page({"id": "p2", "display_name": "二", "category": "map", "text": "字", "related": ["没有这页"]}, ctx, ImportReport.new())
	ContentImporter.validate_help_pages(ctx, r3)
	t.check(not r3.ok() and r3.to_text().contains("没有这页"), "相关指到不存在的：报错并点名")


static func frame_entries(t: TestCase, root: Window) -> void:
	t.begin("114 · 入口：主菜单「百科」独立一屏（返回 / Esc 回主菜单）；暂停菜单「百科」嵌进遮罩，点链接跳页、「上一页」回得去，Esc 先关百科再关暂停")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("114")
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = SAVE
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	t.check(not flow.help_pages.is_empty(), "导演装了百科的机制页")
	var menu = game.base()
	var has_btn := false
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == UiText.t("menu.encyclopedia"):
			has_btn = true
	t.check(has_btn, "主菜单有「百科」")
	flow.show_encyclopedia("crafting")
	var book = game.base()
	t.eq(flow.screen, GameFlow.Screen.ENCYCLOPEDIA, "→ 百科")
	t.eq(book.current_page(), "crafting", "带 page 直接翻到那页")
	t.check(book.open_page("term:合成"), "点一个链接（词条页）")
	t.eq(book.current_page(), "term:合成", "跳过去了")
	t.check(book.go_previous() and book.current_page() == "crafting", "「上一页」回得去")
	t.check(not book.go_previous(), "再往前没有了")
	book.set_query("合成")
	t.check(book.listed().has("crafting"), "搜索：目录只列命中的页")
	book.set_query("")
	t.check(book.listed().size() > 20, "清掉搜索：全目录（%d 页）" % book.listed().size())
	t.check(game.escape() and flow.screen == GameFlow.Screen.MAIN_MENU, "Esc 回主菜单")

	flow.begin(c.chapter, kit, 7)
	var map = game.base()
	if map.rules_open():
		map.close_rules()
	map.toggle_pause()
	map.pause_encyclopedia()
	t.check(map.encyclopedia_open(), "暂停菜单里开了百科")
	t.check(game.escape() and not map.encyclopedia_open() and map.pause_open(), "Esc 先关百科、暂停菜单还在")
	t.check(game.escape() and not map.pause_open(), "再 Esc 关暂停")
	t.check(flow.run != null and flow.screen == GameFlow.Screen.MAP, "一局还在")
	map.toggle_pause()
	map.pause_encyclopedia("crafting")
	map.toggle_pause()
	t.check(not map.encyclopedia_open(), "关暂停菜单把百科一起关了")
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup("114")
