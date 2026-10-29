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
	t.begin("260 · 家页只立一座军功碑：碑额金币 + 仓库总价值（补充一；补充六默认罗马两段，点一下换 K / M / B）、军功牌按次数分阶（阈值从数据读，碑面不写阶名）、碑脚累计账")
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
	t.check((screen._pages["expedition"] as Control).is_ancestor_of(stele), "碑在出征页里（264，原家页）")
	t.check(stele.custom_minimum_size.x <= MIDDLE.x and stele.custom_minimum_size.y <= MIDDLE.y, "碑 %s 放得进中列 %s" % [stele.custom_minimum_size, MIDDLE])
	var worth := f.meta.warehouse_value()
	t.check(worth > 0, "仓库有三件：总价值 %d" % worth)
	t.eq(stele.worth(), worth, "碑额是仓库总价值")
	t.check(stele.roman_on() and f.settings.stele_roman, "补充六：默认罗马写法")
	t.eq(stele.parts(), RecordsStele.roman_parts(worth), "碑额写罗马两段")
	t.eq(stele._get_tooltip(stele.tablet_rect().get_center()), UiText.t("records.vault_worth") % worth + "\n" + UiText.t("records.numeral_toggle"), "悬停碑额：准数 + 点击切换的提示")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = stele.tablet_rect().get_center()
	stele._gui_input(click)
	t.check(not stele.roman_on() and not f.settings.stele_roman, "点碑额：换阿拉伯写法、记进设置")
	t.eq(stele.worth_text(), RecordsStele.compact(worth), "阿拉伯写法写 K / M / B 两位小数")
	t.check(not GameSettings.load_from(SETTINGS).stele_roman, "存盘了")
	var reopened := RecordsStele.new()
	reopened.setup(f)
	t.check(not reopened.roman_on(), "再开家页照上次的写法")
	reopened.free()
	click.position = stele.row_rect(0).get_center()
	stele._gui_input(click)
	t.check(not stele.roman_on(), "点圆牌那几行不换")
	click.position = stele.tablet_rect().get_center()
	stele._gui_input(click)
	t.check(stele.roman_on() and GameSettings.load_from(SETTINGS).stele_roman, "再点一下：回罗马")
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
	_collect_text(stele, texts)
	t.eq(texts, [] as Array[String], "碑上没有 Label 散字（字刻在碑上）")
	screen.free()
	_cleanup()


static func run_compact(t: TestCase) -> void:
	t.begin("260 补充五 / 六 · 碑额阿拉伯写法 K / M / B / T（大写）带两位小数：向下截不进位、末尾 0 去掉；1000 以下整数；0 写「—」；金币固定 52")
	t.eq(RecordsStele.compact(0), "—", "0 → —")
	t.eq(RecordsStele.compact(742), "742", "742")
	t.eq(RecordsStele.compact(999), "999", "999")
	t.eq(RecordsStele.compact(1000), "1K", "1000 → 1K（末尾 0 去掉）")
	t.eq(RecordsStele.compact(3000), "3K", "3000 → 3K")
	t.eq(RecordsStele.compact(5414), "5.41K", "5414 → 5.41K")
	t.eq(RecordsStele.compact(15439), "15.43K", "15439 → 15.43K（向下截）")
	t.eq(RecordsStele.compact(10500), "10.5K", "10500 → 10.5K")
	t.eq(RecordsStele.compact(388888), "388.88K", "388888 → 388.88K")
	t.eq(RecordsStele.compact(999999), "999.99K", "999999 → 999.99K（不进位）")
	t.eq(RecordsStele.compact(2345678), "2.34M", "2345678 → 2.34M")
	t.eq(RecordsStele.compact(3100000000), "3.1B", "3100000000 → 3.1B")
	t.eq(RecordsStele.compact(7250000000000), "7.25T", "万亿起 T")
	t.eq(RecordsStele.compact(9223372036854775807), "9223372.03T", "int 上限不溢出")
	var st := RecordsStele.new()
	st._worth = 2345678
	st._roman = false
	t.eq(st.worth_text(), "2.34M", "阿拉伯写法：碑额写的就是这个字符串")
	t.eq(st.parts(), [["2.34M", 0]], "一段、不画线")
	st.free()
	var fb := UiPalette.cjk_font_bold()
	t.eq(RecordsStele.worth_width(fb, [["", 0]], 20), float(UiTheme.sz(RecordsStele.WORTH_COIN)) + RecordsStele.WORTH_GAP + fb.get_string_size("", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, "金币固定 52，不跟字缩")
	for v in [388888, 3100000000, 999999]:
		var big := RecordsStele.new()
		big._worth = v
		big._roman = false
		var px := big.worth_size(fb)
		t.check(px >= 40, "%d 一行字号 %d" % [v, px])
		big.free()


static func run_roman_parts(t: TestCase) -> void:
	t.begin("260 补充六 · 碑额罗马写法：千以下一段不画线；千起两段（最高一段 k 道横线、下一段前两位 k − 1 道），截完是 0 不写；段间空 0.12 字号")
	t.eq(RecordsStele.roman_parts(0), [["—", 0]], "0 → —")
	t.eq(RecordsStele.roman_parts(742), [["DCCXLII", 0]], "742 → DCCXLII，不画线")
	t.eq(RecordsStele.roman_parts(3000), [["III", 1]], "3000 → III（1 道），第二段 0 不写")
	t.eq(RecordsStele.roman_parts(5400), [["V", 1], ["CD", 0]], "5400 → V CD")
	t.eq(RecordsStele.roman_parts(5414), [["V", 1], ["CDX", 0]], "5414 → V CDX（= 5.41K）")
	t.eq(RecordsStele.roman_parts(15439), [["XV", 1], ["CDXXX", 0]], "15439 → XV CDXXX")
	t.eq(RecordsStele.roman_parts(388888), [["CCCLXXXVIII", 1], ["DCCCLXXX", 0]], "388888 → CCCLXXXVIII DCCCLXXX")
	t.eq(RecordsStele.roman_parts(999999), [["CMXCIX", 1], ["CMXC", 0]], "999999 → CMXCIX CMXC（990，向下截）")
	t.eq(RecordsStele.roman_parts(1005), [["I", 1]], "1005 → I（5 截没了）")
	t.eq(RecordsStele.roman_parts(2345678), [["II", 2], ["CCCXL", 1]], "2345678 → II（2 道）CCCXL（1 道）")
	t.eq(RecordsStele.roman_parts(3100000000), [["III", 3], ["C", 2]], "3100000000 → III（3 道）C（2 道）")
	t.eq(RecordsStele.roman_parts(7250000000000), [["VII", 4], ["CCL", 3]], "万亿 4 道")
	t.eq(RecordsStele.roman_parts(9223372036854775807), [["IX", 6], ["CCXX", 5]], "int 上限不溢出")
	var st := RecordsStele.new()
	st._worth = 5414
	t.check(st.roman_on(), "没设置也默认罗马")
	t.eq(st.worth_text(), "V\u0305 CDX", "worth_text：横线道数个组合上横线，段间空格")
	var fb := UiPalette.cjk_font_bold()
	var segs := st.parts()
	var w := float(UiTheme.sz(RecordsStele.WORTH_COIN)) + RecordsStele.WORTH_GAP + 40 * RecordsStele.PART_GAP
	for seg in segs:
		w += fb.get_string_size(String(seg[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	t.eq(RecordsStele.worth_width(fb, segs, 40), w, "整行宽 = 金币 + 空 + 两段 + 0.12 字号")
	st._worth = 888888
	var px := st.worth_size(fb)
	t.check(px < RecordsStele.WORTH_SIZE and RecordsStele.worth_width(fb, st.parts(), px) <= RecordsStele.WORTH_ROOM, "最长的 888888（20 个字母）缩到 %d 号放得下" % px)
	# 补充七（作者 17:00 / 17:14）：一行要缩到 36 号以下就分两行，同字号、两行居中、横线跟着各自那行，整块竖向居中
	var lay: Dictionary = st.tablet_layout(fb)
	var rows: Array = lay["rows"]
	t.eq(rows.size(), 2, "888888：两行")
	var p2 := int(lay["px"])
	t.check(p2 > px and p2 <= UiTheme.sz(RecordsStele.TWO_ROW_MAX), "两行字号 %d 比一行（%d）大、不过 44" % [p2, px])
	t.eq([rows[0]["segs"][0][1], rows[1]["segs"][0][1]], [1, 0], "第一行 1 道、第二行 0 道")
	var c0: float = float(rows[0]["x"]) + fb.get_string_size(String(rows[0]["segs"][0][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, p2).x * 0.5
	var c1: float = float(rows[1]["x"]) + fb.get_string_size(String(rows[1]["segs"][0][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, p2).x * 0.5
	t.check(absf(c0 - c1) < 0.5, "两行居中对齐（%.1f / %.1f）" % [c0, c1])
	var top := RecordsStele.ORIGIN.y + RecordsStele.TABLET.position.y
	var block_top := float(rows[0]["base"]) - p2 * RecordsStele.CAP_AT - RecordsStele.overline_stack(p2, 1)
	t.check(block_top >= top + RecordsStele.TABLET_PAD - 0.5 and float(rows[1]["base"]) <= top + RecordsStele.TABLET.size.y - RecordsStele.TABLET_PAD + 0.5, "整块在碑额里、上下留 10")
	var coin: Rect2 = lay["coin"]
	t.check(absf(coin.get_center().y - (block_top + float(rows[1]["base"])) * 0.5) < 0.5, "金币对准整块中线")
	t.check(coin.end.x + RecordsStele.WORTH_GAP <= minf(float(rows[0]["x"]), float(rows[1]["x"])) + 0.5, "金币在两行左边")
	for v in [15439, 2345678, 3100000000, 742]:
		st._worth = v
		t.eq((st.tablet_layout(fb)["rows"] as Array).size(), 1, "%d：照旧一行" % v)
	st._worth = 888888
	st._roman = false
	t.eq((st.tablet_layout(fb)["rows"] as Array).size(), 1, "阿拉伯写法不分行")
	t.eq(RecordsStele.overline_stack(50, 0), 0.0, "不画线不占高")
	t.eq(RecordsStele.overline_stack(50, 2), 5.0 + 2 * 3.0 + 2.5, "两道：缝 5 + 两道 3 粗 + 道间 2.5")
	st.free()
	var gs := GameSettings.new()
	t.check(gs.stele_roman, "设置默认罗马")
	gs.stele_roman = false
	t.check(not GameSettings.from_dict(gs.to_dict()).stele_roman, "存读一致")
	t.check(GameSettings.from_dict({"version": GameSettings.SAVE_VERSION}).stele_roman, "老设置文件没这项：罗马")


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
				st._worth = 888888     # 最长的那种（罗马 20 个字母；阿拉伯 888.88K）
				var font := UiPalette.cjk_font()
				var fb := UiPalette.cjk_font_bold()
				t.check(st.ledger_width(font, st.ledger_size()) <= st.BAND.size.x - 2.0 * st.BAND_PAD + 0.5 or st.ledger_size() == st.MIN_SIZE,
					"%s %s：碑脚一行放得进铭文带（%d 号）" % [lang, tier, st.ledger_size()])
				for roman in [true, false]:
					st._roman = roman
					var px: int = st.worth_size(fb)
					t.check(RecordsStele.worth_width(fb, st.parts(), px) <= st.WORTH_ROOM or px == st.MIN_SIZE, "%s %s %s：碑额一行（%d 号）放得进 330" % [lang, tier, "罗马" if roman else "阿拉伯", px])
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
