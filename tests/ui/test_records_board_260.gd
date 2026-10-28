## 260（作者 14:13 选 B 军功碑，「最后对局不再显示」）：基地家页的战绩是一座碑 —— 碑额仓库总价值（补充一）、三枚军功牌（分阶从数据读；补充二：战败去掉）、碑脚累计账；
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
	t.begin("260 · 家页只立一座军功碑：碑额金币 + 罗马数字（仓库总价值，补充一）、军功牌按次数分阶（阈值从数据读，碑面不写阶名）、碑脚累计账")
	var f := _flow()
	_fill(f.meta, false)
	for id in [&"knife", &"iron_ore", &"hardwood_plank"]:
		f.meta.warehouse.try_add(ItemInstance.create(f.items.get_def(id), f.meta.allocate_uid()), true)
	var screen = _screen(f, root)
	var stele: RecordsStele = screen._stele
	t.not_null(stele, "家页有碑")
	if stele == null:
		screen.free()
		_cleanup()
		return
	t.check((screen._pages["home"] as Control).is_ancestor_of(stele), "碑在家页里")
	t.check(stele.custom_minimum_size.x <= MIDDLE.x and stele.custom_minimum_size.y <= MIDDLE.y, "碑 %s 放得进中列 %s" % [stele.custom_minimum_size, MIDDLE])
	var worth := f.meta.warehouse_value()
	t.check(worth > 0, "仓库有三件：总价值 %d" % worth)
	t.eq(stele.worth(), worth, "碑额是仓库总价值")
	t.eq(stele.worth_text(), RecordsStele.roman(worth) if worth < 1000 else stele.worth_text(), "罗马数字（1000 以下没有横线）")
	t.eq(stele._numeral, RecordsStele.numeral_parts(worth), "碑额按现代计数拆")
	t.eq(stele._get_tooltip(stele.tablet_rect().get_center()), UiText.t("records.vault_worth") % worth, "悬停碑额：阿拉伯数字")
	t.eq(stele._funds.amount, 357, "碑脚金币")
	t.eq(stele.ledger(), UiText.t("records.ledger") % [4, 5414, f.meta.codex.size(), f.items.ids(true).size()], "碑脚账：局数 · 总分 · 图鉴")
	var tiers: Dictionary = f.meta.rules.medal_tiers
	t.eq(stele.row(0)["tier"], RecordsStele.tier_of(6, tiers["extractions"]), "撤离 6 次的阶从数据算")
	t.eq(stele.row(0)["tier"], 2, "撤离 6 次 = 银")
	t.eq(stele.row(0)["label"], UiText.t("records.medal_extract"), "补充一：名目不带阶名（阶由圆牌说）")
	t.eq(stele.row(1)["tier"], 0, "核心 0 次：还没到铜")
	t.eq(stele.row(2)["tier"], 1, "打赢 17 场 = 铜")
	t.eq(stele.row_count(), 3, "补充二：三枚（撤离 / 击败核心 / 打赢），战败不上碑")
	t.eq([stele.row(0)["kind"], stele.row(1)["kind"], stele.row(2)["kind"]], ["escape", "core", "win"], "三枚的次序")
	UiText.lang = "en"
	var en := RecordsStele.new()
	en.setup(f)
	f.meta.extractions = 1
	var en_one := RecordsStele.new()
	en_one.setup(f)
	t.eq(en_one.row(0)["label"], UiText.t("records.medal_extract_one"), "英文 1 次写单数")
	en_one.free()
	f.meta.extractions = 6
	t.eq(en.row(1)["label"], "cores defeated", "0 次写复数")
	f.meta.runs = 1
	var en1 := RecordsStele.new()
	en1.setup(f)
	t.check(en1.ledger().begins_with("1 run ·"), "英文 1 局写单数（%s）" % en1.ledger())
	en1.free()
	f.meta.runs = 4
	en.free()
	UiText.lang = "zh"
	t.eq(stele.medal_texture(0), UiTheme.art_cached("records/record_escape_silver"), "撤离银阶：定稿圆牌")
	t.eq(stele.medal_texture(1), UiTheme.art_cached("records/record_core_locked"), "核心没到铜：锁着那枚")
	t.eq(stele.medal_texture(2), UiTheme.art_cached("records/record_win_bronze"), "打赢铜阶")
	t.eq(stele._get_tooltip(stele.row_rect(0).get_center()), UiText.t("records.next_tier") % 9, "悬停撤离：下一阶还差 9 次")
	var face := Rect2(stele.ORIGIN + Vector2(0, stele.TABLET.end.y), Vector2(stele.BODY.x, stele.BAND.position.y - stele.TABLET.end.y))
	for i in 3:
		t.not_null(stele.medal_texture(i), "第 %d 枚圆牌有图" % i)
		t.check(face.encloses(stele.row_rect(i)), "第 %d 行在碑额底与碑脚带顶之间" % i)
	var block_top := stele.row_rect(0).position.y - face.position.y
	var block_bottom := face.end.y - stele.row_rect(2).end.y
	t.check(absf(block_top - block_bottom) <= 1.0, "三枚整块竖向居中（上 %.0f / 下 %.0f）" % [block_top, block_bottom])
	t.check(stele.tablet_rect().end.y <= stele.row_rect(0).position.y and stele.row_rect(2).end.y <= stele.band_rect().position.y, "不压碑额、不压碑脚带")
	for i in 3:
		var label := String(stele.row(i)["label"])
		t.check(not label.contains("战败") and not label.contains("阶"), "碑面第 %d 行没有「战败」「阶」字样（%s）" % [i, label])
	t.check(Rect2(stele.ORIGIN, stele.BODY).encloses(stele.tablet_rect()) and Rect2(stele.ORIGIN, stele.BODY).encloses(stele.band_rect()), "碑额、碑脚在碑身里")
	var texts: Array[String] = []
	_collect_text(screen._pages["home"], texts)
	t.eq(texts, [] as Array[String], "家页没有 Label 散字（字刻在碑上）")
	screen.free()
	_cleanup()


static func run_roman(t: TestCase) -> void:
	t.begin("260 补充四 · 碑额现代计数：只刻最高一段，每 ÷ 1000 加一道横线（K / M / B），向下取整；0 写「—」；金币固定 52；横线整块竖向居中")
	t.eq(RecordsStele.roman(3168), "MMMCLXVIII", "3168")
	t.eq(RecordsStele.roman(3888), "MMMDCCCLXXXVIII", "3888")
	t.eq(RecordsStele.numeral_parts(0), ["—", 0], "0 → —")
	t.eq(RecordsStele.numeral_parts(742), ["DCCXLII", 0], "742 没有横线")
	t.eq(RecordsStele.numeral_parts(999), ["CMXCIX", 0], "999 没有横线")
	t.eq(RecordsStele.numeral_parts(1000), ["I", 1], "1000 = I̅")
	t.eq(RecordsStele.numeral_parts(5414), ["V", 1], "5414 = V̅（零头不写）")
	t.eq(RecordsStele.numeral_parts(38888), ["XXXVIII", 1], "38888 = X̅X̅X̅V̅I̅I̅I̅")
	t.eq(RecordsStele.numeral_parts(388888), ["CCCLXXXVIII", 1], "388888 = C̅C̅C̅L̅X̅X̅X̅V̅I̅I̅I̅")
	t.eq(RecordsStele.numeral_parts(3888888), ["III", 2], "3888888 = 两道线的 III（M）")
	t.eq(RecordsStele.numeral_parts(3888888888), ["III", 3], "3888888888 = 三道线的 III（B）")
	var st := RecordsStele.new()
	st._numeral = RecordsStele.numeral_parts(3888888)
	t.eq(st.worth_text(), "I\u0305\u0305I\u0305\u0305I\u0305\u0305", "两道：每个字母后面两个组合横线")
	st._numeral = RecordsStele.numeral_parts(742)
	t.eq(st.worth_text(), "DCCXLII", "没有横线")
	st.free()
	t.eq(RecordsStele.overline_stack(50, 0), 0.0, "0 道：横线不占高")
	t.eq(RecordsStele.overline_stack(50, 1), 5.0 + 3.0, "1 道：缝 5 + 线粗 3")
	t.eq(RecordsStele.overline_stack(50, 3), 5.0 + 3 * 3.0 + 2 * 2.5, "3 道：缝 + 3 道线 + 2 道间距")
	t.check(RecordsStele.overline_stack(50, 3) + 50 * RecordsStele.CAP_AT < RecordsStele.TABLET.size.y - 40.0, "三道线连字整块放得进碑额")
	var fb := UiPalette.cjk_font_bold()
	t.eq(RecordsStele.worth_width(fb, "", 20), float(UiTheme.sz(RecordsStele.WORTH_COIN)) + RecordsStele.WORTH_GAP + fb.get_string_size("", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, "金币固定 52，不跟字缩")
	for v in [388888, 3888888888, 888888]:
		var big := RecordsStele.new()
		big._numeral = RecordsStele.numeral_parts(v)
		var px := big.worth_size(fb)
		t.check(px >= 30, "%d 一行字号 %d 不缩成点" % [v, px])
		big.free()


static func run_warehouse_value(t: TestCase) -> void:
	t.begin("260 补充一 · 仓库总价值：仓库各页所有物件（锁住的也算）+ 包架上的包，不含钱")
	var db := ItemDatabase.new()
	db.load_dir()
	var m := MetaState.new(GameFlow.load_meta_rules())
	t.eq(m.warehouse_value(), 0, "空仓 0")
	m.funds = 9999
	var sum := 0
	for id in [&"knife", &"iron_ore", &"hardwood_plank"]:
		var inst := ItemInstance.create(db.get_def(id), m.allocate_uid())
		m.warehouse.try_add(inst, true)
		sum += ItemValue.of_instance(inst)
	(m.warehouse.items()[0] as ItemInstance).set_locked(true)
	var bag_def: ItemDef = null
	for id in db.ids():
		var d := db.get_def(id)
		if BagRack.holds(d):
			bag_def = d
			break
	if bag_def != null:
		var bag := ItemInstance.create(bag_def, m.allocate_uid())
		m.rack.insert(bag)
		sum += ItemValue.of_instance(bag)
	t.eq(m.warehouse_value(), sum, "三件 + 一只包 = %d（锁住的也算，钱不算）" % sum)


static func frame_empty_and_big(t: TestCase, root: Window) -> void:
	t.begin("260 · 空仓碑额写「—」；满档碑额、碑脚三档字号都放得下（缩字）")
	var f := _flow()
	var screen = _screen(f, root)
	var stele: RecordsStele = screen._stele
	t.eq(stele.worth_text(), "—", "空仓：碑额「—」")
	for i in stele.row_count():
		t.eq(stele.row(i)["count"], 0, "第 %d 枚 0 次" % i)
	screen.free()
	_fill(f.meta, true)
	for lang in ["zh", "en"]:
		for tier in [&"small", &"medium", &"large"]:
			UiText.lang = lang
			UiTheme.with_text_size(tier, func():
				var st := RecordsStele.new()
				root.add_child(st)
				st.setup(f)
				st._numeral = RecordsStele.numeral_parts(888888)     # 最长的那种
				var font := UiPalette.cjk_font()
				var fb := UiPalette.cjk_font_bold()
				t.check(st.ledger_width(font, st.ledger_size()) <= st.BAND.size.x - 2.0 * st.BAND_PAD + 0.5 or st.ledger_size() == st.MIN_SIZE,
					"%s %s：碑脚一行放得进铭文带（%d 号）" % [lang, tier, st.ledger_size()])
				var px: int = st.worth_size(fb)
				var whole := String(st._numeral[0])
				t.check(RecordsStele.worth_width(fb, whole, px) <= st.WORTH_ROOM or px == st.MIN_SIZE, "%s %s：碑额一行（%d 号）放得进 330" % [lang, tier, px])
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
