## 221 F1（作者 219 F）：界面切到英文 —— 教程会指到的屏（顶端栏、背包窗、战前屏、回放屏）上的字里没有汉字；
## 教程文字用到的 `{ui:}` `{zone:}` 词都在 [constant TextTemplate.TERMS_EN] 里；新加的界面键中英都有
extends RefCounted

const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
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
	var bars := [UiText.t("battle.bar_hp"), UiText.t("battle.bar_stamina")]
	UiText.lang = "zh"
	t.eq(names, ["Small", "Medium", "Large"], "规模名是英文")
	t.check(_han().search(craft) == null, "合成那一句没有汉字：%s" % craft)
	t.eq(bars, ["HP", "Stamina"], "条上的资源名首字母大写")
	t.eq(UiText.t("battle.bar_hp"), "hp", "中文照旧")
