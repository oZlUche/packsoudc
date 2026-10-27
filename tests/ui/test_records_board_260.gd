## 260（作者 14:13 选 B 军功碑，「最后对局不再显示」）：基地家页的战绩是一座碑 —— 碑额最佳一局、四枚军功牌（分阶从数据读）、碑脚累计账；
## 空档、满档、三档字号都在中列里放得下；最佳一局存读往返
extends RefCounted

const META := "user://test_260_meta.json"
const SETTINGS := "user://test_260_settings.json"
const MIDDLE := Vector2(508, 952)


static func _flow() -> GameFlow:
	var db := ItemDatabase.new()
	db.load_dir()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), MetaState.new(GameFlow.load_meta_rules()))
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	f.chapters = GameFlow.load_chapters()
	f.characters = GameFlow.load_characters()
	return f


static func _screen(f: GameFlow, root: Window) -> Control:
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	return screen


static func _cleanup() -> void:
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func _fill(m: MetaState, big: bool) -> void:
	m.runs = 9999 if big else 4
	m.extractions = 999 if big else 6
	m.boss_kills = 0
	m.battles_won = 99999 if big else 17
	m.deaths = 999 if big else 1
	m.score = 9999999 if big else 5414
	m.funds = 9999999 if big else 357
	m.best_value = 999999 if big else 3168
	m.best_run = {"value": m.best_value, "chapter": "free_mode", "outcome": "extracted", "character": "", "run_no": 9999 if big else 3,
		"steps": 999 if big else 28, "battles_won": 99 if big else 6}


static func frame_stele(t: TestCase, root: Window) -> void:
	t.begin("260 · 家页只立一座军功碑：碑额最佳一局、四枚军功牌按次数分阶（阈值从数据读）、碑脚累计账；不再有刚才这一局")
	var f := _flow()
	_fill(f.meta, false)
	var who: CharacterDef = f.characters[0] if not f.characters.is_empty() else null
	if who != null:
		f.meta.best_run["character"] = String(who.id)
	var screen = _screen(f, root)
	var stele: RecordsStele = screen._stele
	t.not_null(stele, "家页有碑")
	if stele == null:
		screen.free()
		_cleanup()
		return
	t.check((screen._pages["home"] as Control).is_ancestor_of(stele), "碑在家页里")
	t.check(stele.custom_minimum_size.x <= MIDDLE.x and stele.custom_minimum_size.y <= MIDDLE.y, "碑 %s 放得进中列 %s" % [stele.custom_minimum_size, MIDDLE])
	var lines: Array = stele.lines()
	t.check(String(lines[0]).contains(Names.of(f.chapter_of(&"free_mode"))), "碑额第一行有章节：%s" % lines[0])
	t.check(String(lines[0]).contains(UiText.t("records.outcome_extracted")), "有结局")
	if who != null:
		t.check(String(lines[0]).contains(Names.of(who)), "有角色")
	t.eq(lines[1], UiText.t("records.best_tally") % [3, 28, 6], "第二行：第几局 · 几步 · 赢几场")
	t.eq(stele._best.amount, 3168, "大数是单局价值（金币）")
	t.eq(stele._funds.amount, 357, "碑脚金币")
	t.eq(stele.ledger(), UiText.t("records.ledger") % [4, 5414, f.meta.codex.size(), f.items.ids(true).size()], "碑脚账：局数 · 总分 · 图鉴")
	var tiers: Dictionary = f.meta.rules.medal_tiers
	t.eq(stele.row(0)["tier"], RecordsStele.tier_of(6, tiers["extractions"]), "撤离 6 次的阶从数据算")
	t.eq(stele.row(0)["tier"], 2, "撤离 6 次 = 银")
	t.eq(stele.row(0)["label"], UiText.t("records.medal_extract") + " · " + UiText.t("records.tier_silver"), "名目带阶名")
	t.eq(stele.row(1)["tier"], 0, "核心 0 次：还没到铜")
	t.eq(stele.row(1)["label"], UiText.t("records.medal_core"), "没到铜不写阶")
	t.eq(stele.row(2)["tier"], 1, "打赢 17 场 = 铜")
	t.eq(stele.row(3)["label"], UiText.t("records.medal_deaths"), "战败不分阶")
	t.eq(stele.row(3)["count"], 1, "战败 1 次")
	t.eq(stele._get_tooltip(stele.row_rect(0).get_center()), UiText.t("records.next_tier") % [UiText.t("records.tier_gold"), 9], "悬停撤离：下一阶金还差 9 次")
	t.eq(stele._get_tooltip(stele.row_rect(3).get_center()), "", "战败那行不说下一阶")
	for i in 4:
		t.not_null(stele.medal_texture(i), "第 %d 枚圆牌有图（没定稿用军团圆牌占位）" % i)
		t.check(Rect2(stele.ORIGIN, stele.BODY).encloses(stele.row_rect(i)), "第 %d 行在碑身里" % i)
	t.check(Rect2(stele.ORIGIN, stele.BODY).encloses(stele.tablet_rect()) and Rect2(stele.ORIGIN, stele.BODY).encloses(stele.band_rect()), "碑额、碑脚在碑身里")
	var texts: Array[String] = []
	_collect_text(screen._pages["home"], texts)
	t.eq(texts, [] as Array[String], "家页没有 Label 散字（字刻在碑上）")
	screen.free()
	_cleanup()


static func frame_empty_and_big(t: TestCase, root: Window) -> void:
	t.begin("260 · 空档一行「还没有撤离过」、不画大数；满档大数三档字号都放得下（缩字）")
	var f := _flow()
	var screen = _screen(f, root)
	var stele: RecordsStele = screen._stele
	t.eq(stele.lines(), [UiText.t("records.no_best"), ""], "一局没撤离过：碑额一行")
	t.check(not stele._best.visible, "不画大数")
	for i in 4:
		t.eq(stele.row(i)["count"], 0, "第 %d 枚 0 次" % i)
	screen.free()
	_fill(f.meta, true)
	f.meta.best_run = {}
	var s2 = _screen(f, root)
	t.eq(s2._stele.lines(), [UiText.t("records.best"), ""], "老存档只有数：一行「最佳一局」")
	s2.free()
	_fill(f.meta, true)
	for lang in ["zh", "en"]:
		for tier in [&"small", &"medium", &"large"]:
			UiText.lang = lang
			UiTheme.with_text_size(tier, func():
				var st := RecordsStele.new()
				root.add_child(st)
				st.setup(f)
				var font := UiPalette.cjk_font()
				t.check(st.ledger_width(font, st.ledger_size()) <= st.BAND.size.x - 2.0 * st.BAND_PAD + 0.5 or st.ledger_size() == st.MIN_SIZE,
					"%s %s：碑脚一行放得进铭文带（%d 号）" % [lang, tier, st.ledger_size()])
				var inner: float = st.TABLET.size.x - 2.0 * st.BAND_PAD
				for line in st.lines():
					var px := RecordsStele.fit_size(font, String(line), UiTheme.sz(st.LINE1_SIZE), inner)
					t.check(font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= inner or px == st.MIN_SIZE, "%s %s：碑额一行放得下" % [lang, tier])
				var bs: Vector2 = st._best.get_combined_minimum_size()
				t.check(bs.x <= st.TABLET.size.x, "%s %s：大数 %.0f 宽放得进碑额" % [lang, tier, bs.x])
				st.free())
	UiText.lang = "zh"
	_cleanup()


static func run_best_run_round_trip(t: TestCase) -> void:
	t.begin("260 · 最佳一局：价值更高才换，第几局 / 角色 / 难度记下来，存读往返")
	var db := ItemDatabase.new()
	db.load_dir()
	var m := MetaState.new(GameFlow.load_meta_rules())
	var r := RunResult.new()
	r.outcome = &"extracted"
	r.chapter_id = &"free_mode"
	r.character_id = &"marcus"
	r.difficulty_id = &"normal"
	r.value = 100
	r.steps = 20
	r.battles_won = 3
	r.ended_at = 1700000000
	m.absorb(r)
	t.eq(m.best_run.get("run_no"), 1, "第 1 局")
	t.eq(m.best_run.get("character"), "marcus", "角色")
	t.eq(m.best_run.get("difficulty"), "normal", "难度")
	var low := RunResult.new()
	low.outcome = &"extracted"
	low.value = 50
	m.absorb(low)
	t.eq(m.best_run.get("run_no"), 1, "更低的那局不换")
	var dead := RunResult.new()
	dead.outcome = &"defeated"
	dead.value = 0
	m.absorb(dead)
	t.eq(m.best_run.get("value"), 100, "战败不换")
	var back := MetaState.from_dict(m.to_dict(), db, GameFlow.load_meta_rules())
	t.eq(back.best_run, m.best_run, "存读往返")
	var old := MetaState.new(GameFlow.load_meta_rules()).to_dict()
	old.erase("best_run")
	var reread := MetaState.from_dict(old, db, GameFlow.load_meta_rules())
	t.eq(reread.best_run if reread != null else null, {}, "老存档没有：空")
	t.eq(r.to_dict().get("character"), "marcus", "RunResult 字典里有角色（对局记录也用）")
	t.eq(r.to_dict().get("ended_at"), 1700000000, "结束时间")


static func run_medal_tiers_from_data(t: TestCase) -> void:
	t.begin("260 · 军功牌五档门槛在 meta_rules 里：撤离 / 核心 / 打赢各五档升序，战败没有")
	var rules := GameFlow.load_meta_rules()
	for k in ["extractions", "boss_kills", "battles_won"]:
		var steps: Array = rules.medal_tiers.get(k, [])
		t.eq(steps.size(), 5, "%s 五档" % k)
		var sorted := steps.duplicate()
		sorted.sort()
		t.eq(steps, sorted, "%s 升序" % k)
	t.check(not rules.medal_tiers.has("deaths"), "战败不分阶")
	t.eq(RecordsStele.tier_of(0, [1, 5, 15, 30, 60]), 0, "0 次没到")
	t.eq(RecordsStele.tier_of(60, [1, 5, 15, 30, 60]), 5, "到顶 = 桂冠")


static func _collect_text(n: Node, out: Array[String]) -> void:
	for c in n.get_children():
		if c is Label and (c as Label).visible and (c as Label).text != "":
			out.append((c as Label).text)
		_collect_text(c, out)
