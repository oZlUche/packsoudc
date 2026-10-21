## 221 F1（作者 219 F）：界面切到英文 —— 教程会指到的屏（顶端栏、背包窗、战前屏、回放屏）上的字里没有汉字；
## 教程文字用到的 `{ui:}` `{zone:}` 词都在 [constant TextTemplate.TERMS_EN] 里；新加的界面键中英都有
extends RefCounted

const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const Drawer139 := preload("res://tests/ui/test_base_drawer_139.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "english_ui_221"
## 切语言那个按钮故意两种字都写
const LANG_SWITCH := ["menu.language", "menu.lang_short"]
const SCAN_DIRS := ["res://data/authoring", "res://core", "res://ui"]


static func _han() -> RegEx:
	return RegEx.create_from_string("[\\x{4e00}-\\x{9fff}]")


static func run_keys(t: TestCase) -> void:
	t.begin("221 F1 · 界面键：每条都有中英、英文里没有汉字（切语言按钮与 {ui:} 词除外）、占位符个数一样")
	var han := _han()
	var pct := RegEx.create_from_string("%[-0-9.]*[dsf%]")
	var term := RegEx.create_from_string("\\{(ui|zone):[^}]*\\}")     # {ui:百科} 渲染时由 TERMS_EN 换
	var bad: Array[String] = []
	for key in UiText.TEXT:
		var entry: Dictionary = UiText.TEXT[key]
		if not entry.has("zh") or not entry.has("en"):
			bad.append("%s：缺一种语言" % key)
			continue
		var en := String(entry["en"])
		if han.search(term.sub(en, "", true)) != null and not LANG_SWITCH.has(key):
			bad.append("%s：英文里有汉字（%s）" % [key, en])
		if pct.search_all(String(entry["zh"])).size() != pct.search_all(en).size():
			bad.append("%s：占位符个数不一样" % key)
	t.eq(bad, [] as Array[String], "%d 条界面键都齐" % UiText.TEXT.size())


static func run_terms(t: TestCase) -> void:
	t.begin("221 F1 · 内容与代码里的 {ui:…} {zone:…} 都登记了英文")
	var re := RegEx.create_from_string("\\{(ui|zone):([^}…]+)\\}")
	var found := {}
	for dir in SCAN_DIRS:
		for path in _files(dir):
			var text := FileAccess.get_file_as_string(path)
			for m in re.search_all(text):
				found[m.get_string(2)] = path
	t.check(found.size() >= 5, "扫到了词（%d 个）" % found.size())
	var missing: Array[String] = []
	for word in found:
		if not TextTemplate.TERMS_EN.has(word):
			missing.append("%s（%s）" % [word, found[word]])
	t.eq(missing, [] as Array[String], "都有英文")
	UiText.lang = "en"
	var out := TextTemplate.render("{zone:地上}{ui:百科}", {})
	UiText.lang = "zh"
	t.check(out.contains("Ground") and out.contains("Encyclopedia") and _han().search(out) == null, "英文下换成英文（%s）" % out)


static func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json") or f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d)))
	return out


static func frame_english_screens(t: TestCase, root: Window) -> void:
	t.begin("221 F1 · 切到英文：顶端栏、背包窗、战前屏、回放屏的字里没有汉字")
	var c := GF._content()
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁边就是战斗点的种子")
		return
	var ch := c.chapter.duplicate() as ChapterDef
	ch.coaches = {}
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	UiText.lang = "en"     # 进树时按设置定了语言（新设置是中文），之后再切
	var flow: GameFlow = game.flow
	flow.chapters = [ch] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	flow.begin(ch, kit, int(found["seed"]), [] as Array[int], null)
	var map = game.base()
	map.pick_spawn(int(found["entry"]))
	var hud: HudHost = map.hud()
	hud.refresh()
	var texts := _texts(hud)
	# 栏上不写字的件（体力画心、倒计时是日规）：停上去的提示也得是英文
	texts.append("vitality：" + hud.widget(&"vitality").text_of())
	var cd := hud.widget(&"countdown")
	if cd.visible:
		texts.append("countdown：" + String(cd.call("tip_plain")))
	_no_han(t, "顶端栏", texts)
	map.toggle_bag()
	t.check(map.bag_open(), "开了背包窗")
	_no_han(t, "背包窗", _texts(map._bag))
	map.toggle_bag()
	map.step(int(found["next"]))
	var pre = game.overlay()
	t.check(pre != null and pre.screen == GameFlow.Screen.PREBATTLE, "到了战前准备")
	if pre != null and pre.screen == GameFlow.Screen.PREBATTLE:
		_no_han(t, "战前屏", _texts(pre))
		var flag: IconButton = pre._start_btn
		t.check(flag.has_art() and flag.icon_id == "fight_en", "the Fight banner uses the English art (%s)" % flag.icon_id)
		t.check(pre.start_battle(), "战前准备 → 开战")
		var screen = game.overlay()
		t.check(screen != null and screen.screen == GameFlow.Screen.BATTLE, "到了回放屏")
		if screen != null and screen.screen == GameFlow.Screen.BATTLE:
			_no_han(t, "回放屏", _texts(screen))
	UiText.lang = "zh"
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup(PREFIX)


## 一屏里看得见的按钮、标签、富文本上的字（调试台那一抽屉不算：开发版才有）
static func _texts(n: Node) -> Array[String]:
	var out: Array[String] = []
	if n == null or n is DevDrawer:
		return out
	if n is CanvasItem and not (n as CanvasItem).visible:
		return out
	if n is Button:
		out.append("%s：%s" % [n.name, (n as Button).text])
	elif n is Label:
		out.append("%s：%s" % [n.name, (n as Label).text])
	elif n is RichTextLabel:
		out.append("%s：%s" % [n.name, (n as RichTextLabel).get_parsed_text()])
	for child in n.get_children():
		out.append_array(_texts(child))
	return out


static func _no_han(t: TestCase, where: String, texts: Array[String]) -> void:
	var han := _han()
	var bad := texts.filter(func(s: String) -> bool: return han.search(s) != null)
	t.check(texts.size() > 0, "%s：有字（%d 处）" % [where, texts.size()])
	t.eq(bad, [], "%s：没有汉字" % where)


## 游戏测试 2026-10-21 第 4 条：开局屏的地图规模、合成那一句、回放屏条上的字在英文里没有汉字
static func run_smoke_221(t: TestCase) -> void:
	t.begin("221 F3 顺带 · 英文：规模名、合成日志、条上的资源名")
	var ch := load(ContentPaths.asset_file("chapters", "free_mode")) as ChapterDef
	UiText.lang = "en"
	var names: Array = ch.map_source.scale_options().map(func(o: Dictionary) -> String: return String(o["display_name"]))
	var craft := UiText.t("craft.done") % ["Knife", "Poison Vial", "Poisoned Knife"]
	var bars := [Glossary.resource_name(&"hp"), Glossary.resource_name(&"stamina"), Glossary.resource_name(&"mana")]
	UiText.lang = "zh"
	t.eq(names, ["Small", "Medium", "Large"], "规模名是英文")
	t.check(_han().search(craft) == null, "合成那一句没有汉字：%s" % craft)
	t.eq(bars, ["Health", "Stamina", "Mana"], "F4：条上的资源名取 Glossary.RESOURCE_NAMES")
	t.eq(Glossary.resource_name(&"hp"), "生命", "中文也写名字，不写键名")



## 复测 2026-10-21 第 1 条：开局第三页出生点小窗的路线名与特点句在英文里没有汉字，中文照旧
static func run_route_text_english(t: TestCase) -> void:
	t.begin("221 F4 顺带 · 英文：出生点小窗的路线名与特点句")
	var bad: Array[String] = []
	UiText.lang = "en"
	for style in RouteStyle.PLAYER_TEXT:
		var rt := RouteStyle.player_text(style)
		if _han().search(String(rt["name"]) + String(rt["text"])) != null:
			bad.append(String(style))
	var en_combat := RouteStyle.player_text(&"combat")
	UiText.lang = "zh"
	t.eq(bad, [] as Array[String], "三种路线英文都没有汉字")
	t.eq(en_combat["name"], "Combat", "战斗路线叫 Combat")
	t.eq(RouteStyle.player_text(&"combat")["name"], "战斗", "中文照旧")
	t.eq(RouteStyle.player_text(&"nope"), {}, "没登记的风格给空")


## 架构设计 2026-10-21：角色技能的英文名写进角色数据（display_names.en），和百科「角色」页用的一致
static func run_skill_names_english(t: TestCase) -> void:
	t.begin("221 F4 顺带 · 角色技能都有英文名")
	var bad: Array[String] = []
	var seen := 0
	for f in DirAccess.get_files_at("res://data/characters"):
		if not f.ends_with(".tres"):
			continue
		var c := load("res://data/characters".path_join(f)) as CharacterDef
		for sk in c.skills:
			seen += 1
			var en := String(sk.display_names.get("en", ""))
			if en == "" or _han().search(en) != null:
				bad.append(String(sk.id))
	t.check(seen >= 9, "三个角色的技能都查了（%d）" % seen)
	t.eq(bad, [] as Array[String], "每个技能都有英文名")


## 221 F5a：英文下每件道具的悬浮窗（规则句、属性、标签、加成）、每个状态的说明、百科里状态 / 反应 / 时机页都没有汉字。
## 道具自己的说明（F5c 的数据）先摘掉再查，这里只管代码拼出来的字
static func run_rule_text_english(t: TestCase) -> void:
	t.begin("221 F5a · 英文：道具悬浮窗、状态说明、百科状态页没有汉字")
	var han := _han()
	var db := ItemDatabase.new()
	db.load_dir()
	UiText.lang = "en"
	var bad: Array[String] = []
	var n := 0
	for id in db.all_ids():
		var def := db.get_def(StringName(id))
		if def == null:
			continue
		n += 1
		var text := ItemTooltip.describe(ItemInstance.create(def))
		var desc := Names.description_of(def)
		if desc != "":
			text = text.replace(desc, "")
		text = _tags_off(text)
		if han.search(text) != null:
			bad.append("%s：%s" % [id, text.left(80)])
	var buffs: Array[String] = []
	for f in DirAccess.get_files_at("res://data/buffs"):
		if f.ends_with(".tres"):
			var b := load("res://data/buffs".path_join(f)) as BuffDef
			var body := _tags_off(Glossary.describe_buff(b, 2))
			if han.search(body) != null:
				buffs.append("%s：%s" % [b.id, body.left(80)])
	var book := Encyclopedia.build(GameFlow.load_help_pages(), db)
	var pages: Array[String] = []
	for id in book.ids():
		if String(id).begins_with("buff:") or String(id).begins_with("reaction:") or String(id).begins_with("trigger:"):
			var shown := _tags_off(TextTemplate.plain(book.render(id), {"char_name": "Brutus"}))
			if han.search(shown) != null:
				pages.append("%s：%s" % [id, shown.left(80)])
	UiText.lang = "zh"
	t.check(n > 100, "查了 %d 件道具" % n)
	t.eq(bad, [] as Array[String], "道具悬浮窗（不算说明）没有汉字")
	t.eq(buffs, [] as Array[String], "状态说明没有汉字")
	t.eq(pages, [] as Array[String], "百科状态 / 反应 / 时机页没有汉字")

## 221 F4：百科英文 —— 54 页机制页标题与正文、固定词条、反应说明都有英文；英文下整本书的页标题没有汉字，
## 机制页正文、反应讲解没有汉字；「相关」写的词条中文键在英文下照样连得上
static func run_encyclopedia_english(t: TestCase) -> void:
	t.begin("221 F4 · 百科英文：机制页、固定词条、反应说明齐全；英文下页标题与机制页正文没有汉字")
	var han := _han()
	var token := RegEx.create_from_string("\\{[^}]*\\}")
	var digit := RegEx.create_from_string("[0-9]")
	var help := GameFlow.load_help_pages()
	var bad: Array[String] = []
	for h in help:
		var def := h as HelpPageDef
		var en := String(def.texts.get("en", ""))
		if String(def.display_names.get("en", "")) == "" or en == "":
			bad.append("%s：没有英文" % def.id)
			continue
		var zh_tokens := token.search_all(def.text).map(func(m: RegExMatch) -> String: return m.get_string())
		var en_tokens := token.search_all(en).map(func(m: RegExMatch) -> String: return m.get_string())
		zh_tokens.sort()
		en_tokens.sort()
		var zh_set := {}
		var en_set := {}
		for x in zh_tokens:
			zh_set[x] = true
		for x in en_tokens:
			en_set[x] = true
		if not _same_keys(zh_set, en_set):
			bad.append("%s：占位符和中文不一样" % def.id)
		var bare := token.sub(en, "", true)
		if bare.contains("**"):
			bad.append("%s：有 **" % def.id)
		for m in digit.search_all(bare):
			if not token.sub(def.text, "", true).contains(m.get_string()):
				bad.append("%s：英文写了中文里没有的数字 %s" % [def.id, m.get_string()])
				break
	for key in Glossary.TERMS:
		var e: Dictionary = Glossary.TERMS[key]
		var en: Dictionary = e.get("en", {})
		if String(en.get("name", "")) == "" or String(en.get("text", "")) == "" or han.search(String(en["name"]) + String(en["text"])) != null:
			bad.append("词条 %s：英文不齐" % key)
	for def in ReactionResolver.all():
		if String(def.descriptions.get("en", "")) == "":
			bad.append("反应 %s：没有英文说明" % def.id)
	t.eq(bad, [] as Array[String], "%d 页机制页、%d 条词条、反应说明都有英文" % [help.size(), Glossary.TERMS.size()])
	var db := ItemDatabase.new()
	db.load_dir()
	UiText.lang = "en"
	var book := Encyclopedia.build(help, db)
	var titles: Array[String] = []
	var bodies: Array[String] = []
	for id in book.ids():
		var p := book.page(id)
		if han.search(String(p["title"])) != null:
			titles.append("%s：%s" % [id, p["title"]])
		if not String(id).contains(":"):
			var shown := TextTemplate.strip_bbcode(TextTemplate.plain(book.render(id), {"char_name": "Brutus"}))
			if han.search(shown) != null:
				bodies.append("%s：%s" % [id, shown.left(60)])
	var intro := Encyclopedia.reaction_intro(ReactionResolver.by_id(&"poison_bleed"))
	var block_page := book.page_for(Glossary.term_name("格挡"))
	UiText.lang = "zh"
	t.eq(titles, [] as Array[String], "英文下页标题没有汉字")
	t.eq(bodies, [] as Array[String], "英文下机制页正文（连「相关」「相关道具」）没有汉字")
	t.check(han.search(intro) == null and intro.begins_with("Fungal Blood: Toxin meets Blood."), "反应讲解是英文：%s" % intro)
	t.eq(block_page, "term:格挡", "英文名「Block」连到格挡那一页")
	t.eq(Glossary.term_text("Block"), Glossary.term_text("格挡"), "中文下按英文名也查得到同一条（取中文说明）")


static func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k):
			return false
	return true


## 去掉 BBCode 标签（小写字母开头的 [tag] / [/tag]），方括号里的扳机句（[At battle start]、[开战时]）留着一起查
static func _tags_off(text: String) -> String:
	return RegEx.create_from_string("\\[/?[a-z_]+[^\\]]*\\]").sub(text, "", true)


## 221 F5b：局外屏切到英文 —— 基地（家与五个页签）、设置屏、读取存档屏的可见字里没有汉字（玩家包：开发区不算）
static func frame_english_base_screens(t: TestCase, root: Window) -> void:
	t.begin("221 F5b · 英文：基地各页、设置屏、读取存档屏没有汉字")
	DevGate.force_player = true
	UiText.lang = "en"
	var f := Drawer139._flow()
	f.achievement_defs = GameFlow.load_achievements()
	for id in [&"knife", &"bandage"]:
		var def := f.items.get_def(id)
		if def != null:
			f.meta.warehouse.try_add(ItemInstance.create(def))
	var base = Drawer139._screen(f, root)
	_no_han(t, "base home", _texts(base))
	for tab in ["warehouse", "sell", "tech", "codex", "achievements"]:
		base.show_tab(tab)
		_no_han(t, "base %s" % tab, _texts(base))
	base.queue_free()
	Drawer139._cleanup()
	var c = NodeScreens._content()
	var sf := Support.flow(c, PREFIX + "_s")
	sf.settings = GameSettings.new()
	var settings = load("res://ui/game/settings_screen.gd").new()
	settings.flow = sf
	settings.font = UiPalette.cjk_font()
	root.add_child(settings)
	settings.open({})
	var st: Array[String] = []
	st.assign(_texts(settings).filter(func(s: String) -> bool: return not s.contains("中文")))     # the language switch names both
	_no_han(t, "settings", st)
	settings.queue_free()
	var slots = load("res://ui/game/slots_screen.gd").new()
	slots.flow = sf
	slots.font = UiPalette.cjk_font()
	root.add_child(slots)
	slots.open({"full": true})
	_no_han(t, "slots", _texts(slots))
	slots.queue_free()
	Support.cleanup(PREFIX + "_s")
	UiText.lang = "zh"
	DevGate.force_player = false


## 221 F5c：数据里给玩家看的说明都有英文、英文里没有汉字（{ui:…} {zone:…} 词除外）
static func run_data_descriptions_english(t: TestCase) -> void:
	t.begin("221 F5c · 数据说明：道具、信仰、角色与技能、难度、腰带、科技、成就、配方、事件都有英文")
	var term := RegEx.create_from_string("\\{(ui|zone):[^}]*\\}")
	var han := _han()
	var bad: Array[String] = []
	var counts := {}
	var check := func(where: String, zh: String, table: Dictionary) -> void:
		if zh.strip_edges() == "":
			return
		var en := String(table.get("en", ""))
		if en == "" or han.search(term.sub(en, "", true)) != null:
			bad.append("%s：%s" % [where, en])
	for dir in [ContentPaths.ITEMS, ContentPaths.FAITHS, ContentPaths.CHARACTERS, ContentPaths.DIFFICULTIES,
			ContentPaths.BELT_SKILLS, ContentPaths.TECHS, ContentPaths.ACHIEVEMENTS, ContentPaths.RECIPES, ContentPaths.EVENTS]:
		for res in ContentPaths.load_resources(dir):
			var where := "%s/%s" % [dir.get_file(), String(res.get("id"))]
			counts[dir.get_file()] = int(counts.get(dir.get_file(), 0)) + 1
			if res is RecipeDef:
				check.call(where, (res as RecipeDef).note, (res as RecipeDef).notes)
			elif res is EventDef:
				var ev := res as EventDef
				check.call(where + " title", ev.title, ev.titles)
				check.call(where + " text", ev.text, ev.texts)
				for o in ev.options:
					check.call(where + " option", o.label, o.labels)
			else:
				check.call(where, String(res.get("description")), res.get("descriptions"))
			if res is FaithDef:
				check.call(where + " god", (res as FaithDef).god, (res as FaithDef).gods)
			if res is CharacterDef:
				for sk in (res as CharacterDef).skills:
					check.call(where + "/" + String(sk.id), sk.description, sk.descriptions)
			if res is DifficultyDef:
				check.call(where + " challenge", (res as DifficultyDef).challenge, (res as DifficultyDef).challenges)
	t.check(int(counts.get("items", 0)) >= 95 and int(counts.get("faiths", 0)) == 7, "items and faiths loaded (%s)" % [counts])
	t.eq(bad, [] as Array[String], "every description has English")


## 221 F5c：游戏英文名 Pack & Extract（作者 2026-10-21）—— 主菜单兜底标题走 game.title，启动屏按设置文件里的语言写
static func run_game_title(t: TestCase) -> void:
	t.begin("221 F5c · 游戏名：中文 背包搜打撤、英文 Pack & Extract；启动屏读设置文件的语言")
	UiText.lang = "en"
	var en := UiText.t("game.title")
	UiText.lang = "zh"
	t.eq(en, "Pack & Extract", "English name")
	t.eq(UiText.t("game.title"), "背包搜打撤", "Chinese name")
	var boot = load("res://ui/boot.gd")
	var path := "user://test_221_boot_settings.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"language": "en"}))
	f.close()
	t.eq(boot.read_lang(path), "en", "settings say en")
	t.eq(String(boot.WORDS["en"]["title"]), en, "boot screen uses the same name")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	t.eq(boot.read_lang(path), "zh", "no settings file: zh")


static func run_baked_text_art_en(t: TestCase) -> void:
	t.begin("221 · English art for images with baked-in words: camp sign, forge sign / handle / backdrop, menu wordmark — same size as the Chinese art, picked by language")
	var old := UiText.lang
	var names := ["rest/sign", "forge/sign_back", "forge/handle_ready", "forge/handle_idle", "forge/handle_off", "forge/bg_lit", "forge/bg_cold", "menu/title"]
	UiText.lang = "en"
	for n in names:
		t.eq(UiTheme.lang_art(n), n + "_en", "%s → English" % n)
		var zh := UiTheme.art(n)
		var en := UiTheme.art(n + "_en")
		t.check(zh != null and en != null and zh.get_size() == en.get_size(), "%s: same size as the Chinese one" % n)
	t.eq(UiTheme.lang_art("rest/fire_lit"), "rest/fire_lit", "no English file: keep the original")
	UiText.lang = "zh"
	t.eq(UiTheme.lang_art("rest/sign"), "rest/sign", "Chinese UI: original art")
	t.check(ResourceLoader.exists(load("res://ui/boot.gd").LOGO_EN), "boot wordmark has an English file")
	UiText.lang = old
