## 179（作者 2026-10-16）：选角色屏重排 —— 三栏凹槽板（中栏撑满、棋盘贴右）、三块图标牌、技能名放大描边、说明改书面句，
## 角色说明与「背包：」一行不放；开局三页坐大厅背景、不再是石板；「行动点」一词退役（玩家面前只说步）
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const Support := preload("res://tests/run/flow_support.gd")


static func _labels(n: Node) -> Array[Label]:
	var out: Array[Label] = []
	for c in n.find_children("*", "Label", true, false):
		out.append(c as Label)
	return out


static func frame_character_page(t: TestCase, root: Window) -> void:
	t.begin("179 · 选角色页：三栏凹槽板、中栏撑满、棋盘贴右；三块图标牌；技能名 22 粗体描边、说明 17；没有角色说明与「背包：」；不在石板上")
	Support.cleanup("setup179")
	var p := Support.paths("setup179")
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	t.eq(setup.screen, GameFlow.Screen.SETUP, "→ 开局屏")
	t.is_null(setup.screen_slab(), "不再是整块石板")
	t.not_null(setup.get_node_or_null(^"PaintedContent"), "内容区铺满全屏（大厅背景上）")
	t.eq(setup._grooves.size(), 3, "三栏三块板")
	for g in setup._grooves:
		t.eq((g as PanelContainer).theme_type_variation, UiTheme.PANEL_GROOVE, "凹槽板变体")
	t.eq(UiTheme.tone_of(UiTheme.PANEL_GROOVE), UiTheme.TONE_DARK, "凹槽板深底（白字）")
	t.eq(setup._grooves[1].size_flags_horizontal, Control.SIZE_EXPAND_FILL, "中栏撑满")
	t.eq(setup._grooves[2].size_flags_horizontal, Control.SIZE_SHRINK_END, "棋盘栏贴右")
	t.eq((setup._grooves[0].get_parent() as HBoxContainer).get_theme_constant("separation"), 36, "三栏间距一律 36")
	# 作者 2026-10-17：选人大厅白天版定稿 —— 浅底；直接写在背景上的标题墨字，凹槽板里照旧浅色字
	t.eq(setup.find_children("PaintedBackdrop", "TextureRect", true, false).size(), 1, "大厅背景画铺上了")
	t.eq(UiTheme.art_tone(UiTheme.ART_SETUP_BG), UiTheme.TONE_LIGHT, "大厅背景标浅底")
	t.eq(UiTheme.tone_at(setup._area), UiTheme.TONE_LIGHT, "内容区记着浅底")
	t.check(setup._title is TitlePlate and setup._title.text == "选角色", "226 批二：页标题刻在标题牌上、页码去掉（%s）" % setup._title.text)
	for g in setup._grooves:
		t.eq(UiTheme.tone_at(g), UiTheme.TONE_DARK, "凹槽板里是深底")
		t.check(not g.theme_type_variation.is_empty() and (g as Control).theme == null, "凹槽板没挂墨字主题")
	# 作者 2026-10-17 08:02：大厅只给第一页，第二页木板拼接 / 仓库，第三页桌上的军用地图 —— 翻页换画；没图纯色底、标题白字
	t.eq(setup.PAGE_ART, [UiTheme.ART_SETUP_BG, UiTheme.ART_SETUP_KIT_BG, UiTheme.ART_SETUP_MAP_BG], "三页三幅画")
	for page in [1, 2, 0]:
		setup.show_page(page)
		var art_name: String = setup.PAGE_ART[page]
		var pics: Array = setup.find_children("PaintedBackdrop", "TextureRect", true, false)
		var has_art := UiTheme.art(art_name) != null
		t.eq(pics.size(), 1 if has_art else 0, "第 %d 页：%s" % [page + 1, "铺着 " + art_name if has_art else "没图，纯色底"])
		if has_art:
			t.eq((pics[0] as TextureRect).texture, UiTheme.art(art_name), "第 %d 页是自己那幅" % (page + 1))
		var tone := UiTheme.art_tone(art_name) if has_art else UiTheme.TONE_DARK
		t.eq(UiTheme.tone_at(setup._area), tone, "第 %d 页内容区按画的深浅" % (page + 1))
		t.eq(setup._title.text, UiText.t(setup.PAGE_TITLES[page]), "第 %d 页标题牌跟着换字（石牌浅底墨字，不随画变）" % (page + 1))
	var groove_label := UiTheme.make_label("x", 15, UiPalette.DIM)
	setup._grooves[0].add_child(groove_label)
	t.eq(groove_label.get_theme_color("font_color"), UiPalette.DIM, "凹槽板里的字照旧浅色")
	groove_label.free()

	for i in flow.characters.size():
		setup.choose_character(i)
		var ch: CharacterDef = setup.character()
		t.eq(setup._grooves[2].custom_minimum_size.x, ch.board_size.x * InventoryView.CELL + 2.0 * (setup.RIGHT_PAD + BoardFrame.box("player", false).content_margin_left), "%s：棋盘栏按棋盘宽（227：加皮带框两边的缩进）" % ch.id)
		var texts: Array[String] = []
		for l in _labels(setup._card) + _labels(setup._preview_host):
			texts.append(l.text)
		t.check(not texts.has(Names.description_of(ch)), "%s：角色说明不放" % ch.id)
		t.check(not texts.any(func(s: String) -> bool: return s.begins_with("背包：")), "%s：棋盘下面不列背包" % ch.id)
		var tiles: Array = setup._cap_tiles
		t.eq(tiles.size(), 3, "%s：三块图标牌" % ch.id)
		t.eq(tiles.map(func(c: CapTile) -> String: return c.value_label.text),
			[str(ch.weight_capacity), "%d × %d" % [ch.board_size.x, ch.board_size.y], str(ch.starting_funds)], "%s：负重 / 棋盘 / 开局金币的数" % ch.id)
		t.eq(tiles.map(func(c: CapTile) -> String: return c.caption_label.text), ["负重上限", "棋盘", "开局金币"], "说明")
		t.check(tiles.all(func(c: CapTile) -> bool: return c.has_art() and ((c.icon as TextureRect).texture.resource_path.begins_with(CapTile.ICON_DIR))), "%s：三块牌都用美术定稿的图标" % ch.id)
		t.eq((tiles[0] as CapTile).icon.modulate, Color.WHITE, "彩色成品，不调色")
		t.eq((tiles[0] as CapTile).value_label.get_theme_font_size("font_size"), 28, "数字 28")
		var names: Array = setup._skill_names
		t.eq(names.size(), ch.skill_entries().size(), "%s：每条技能一个名字" % ch.id)
		for n in names:
			var l := n as Label
			t.eq(l.get_theme_font_size("font_size"), 22, "%s 字号 22" % l.text)
			t.check(l.get_theme_constant("outline_size") > 0, "%s 带描边" % l.text)
			t.eq(l.get_theme_color("font_color"), UiPalette.BTN_PRIMARY_HOVER, "%s 亮黄铜色" % l.text)
		t.check(not texts.any(func(s: String) -> bool: return s.contains("行动点")), "%s：这一屏没有「行动点」" % ch.id)
		t.check(not texts.any(func(s: String) -> bool: return s.contains("被动")), "%s：技能行不写「被动」（作者 2026-10-17）" % ch.id)
	game.queue_free()
	Support.cleanup("setup179")


static func run_skill_entries(t: TestCase) -> void:
	t.begin("179 · 技能说明是书面功能句，界面按「名字 / 说明」两行排（「被动」不上屏）；熟门熟路不再说行动点")
	var chars := {}
	for f in DirAccess.get_files_at("res://data/characters/"):
		if f.ends_with(".tres"):
			var ch := load("res://data/characters/" + f) as CharacterDef
			if ch != null:
				chars[ch.id] = ch
	var an: CharacterDef = chars.get(&"andreus")
	t.not_null(an, "安德烈乌斯在")
	if an == null:
		return
	var e: Array[Dictionary] = an.skill_entries()
	t.eq(String(e[0]["kind"]), "被动", "被动在前")
	t.eq(String(e[0]["name"]), "熟门熟路", "名字单独一项")
	t.check(String(e[0]["text"]).ends_with("步，下一步不计入倒计时。"), "说明：%s" % e[0]["text"])
	t.check(String(e[1]["text"]).contains("首次战败于敌人时"), "书面用语：%s" % e[1]["text"])
	t.eq(e.size(), an.skill_lines().size(), "条数和 skill_lines 一样")
	for ch in chars.values():
		for s in (ch as CharacterDef).skills:
			var d := Names.description_of(s)
			t.check(not d.contains("行动点") and not d.contains("头一回"), "%s：%s" % [(s as RunSkill).display_name, d])


## 179：玩家看得见的字里不再有「行动点」—— 扫 core / ui 的 .gd 字符串字面量（注释不算）与 data 下的 .json / .tres
static func run_no_action_points_word(t: TestCase) -> void:
	t.begin("179 · 「行动点」一词退役：core / ui 脚本的字符串、data 下的内容与帮助页里都没有")
	var str_re := RegEx.create_from_string("\"(?:[^\"\\\\\\n]|\\\\.)*\"")
	var hits: Array[String] = []
	for dir in ["res://core", "res://ui", "res://data"]:
		for path in _files(dir):
			if path.ends_with(".gd"):
				var n := 0
				for line in FileAccess.get_file_as_string(path).split("\n"):
					n += 1
					if line.strip_edges().begins_with("#"):
						continue
					for m in str_re.search_all(line):
						if m.get_string().contains("行动点"):
							hits.append("%s:%d" % [path, n])
			elif path.ends_with(".json") or path.ends_with(".tres"):
				if FileAccess.get_file_as_string(path).contains("行动点"):
					hits.append(path)
	t.check(hits.is_empty(), "还有：%s" % [hits])


static func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			out.append_array(_files(dir.path_join(sub)))
	return out
