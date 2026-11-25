## 336（阵营与委托 W0，报告 335）：定义表能导、能查；声望节点（389：只看声望、跨过的节点进通知）；接取规则（两个位、档位、前置、互斥、要选配方）；
## 记账去重与分步；一局并进局外时现场交付失败也算、带回的只在撤离或托付成功时算；存读往返；老档没有委托
extends RefCounted

const T110 := preload("res://tests/meta/test_tech.gd")
const W1 := preload("res://tests/run/test_commissions_w1_336.gd")


static func _meta() -> MetaState:
	return T110._meta()


## 测试用的委托：一份三步（现场 / 带回可托付 / 营地）
static func _def(id: StringName, faction: StringName, tier: StringName, wheres: Array = [CommissionStage.FIELD]) -> CommissionDef:
	var d := CommissionDef.new()
	d.id = id
	d.faction = faction
	d.tier = tier
	for w in wheres:
		var s := CommissionStage.new()
		s.goal = &"inspect_extracts"
		s.where = w
		s.entrust_ok = w == CommissionStage.CARRY
		d.stages.append(s)
	return d


static func run_content(t: TestCase) -> void:
	t.begin("336 W0：五方按顺序（军团 / 协会 / 灰灯 / 使团 / 猎盟），首版只列前三方；三张原型单导得进来、前置与阵营查得过")
	var fs := Commissions.factions()
	t.eq(fs.map(func(f: FactionDef) -> String: return String(f.id)), ["legion", "society", "greylamp", "cartographers", "envoy", "growers", "hunters", "pantheon"], "八方、顺序对（342 B3 加地图协会、垦户社；377 加万神院）")
	Commissions.active = CommissionBook.new()
	t.eq(Commissions.listed_factions().map(func(f: FactionDef) -> String: return String(f.id)), ["legion", "society", "greylamp"], "只列三方（地图协会第一次正式探索结算后才来）")
	t.check(fs.all(func(f: FactionDef) -> bool: return f.id == &"pantheon" or (Commissions.effect_rep(f, Commissions.EFFECT_INQUIRY) == 10 and Commissions.effect_rep(f, Commissions.EFFECT_FINALE) == 25)), "389：万神院以外每方都有 10 调查、25 结案两个节点")
	t.eq(Commissions.effect_rep(Commissions.faction(&"pantheon"), Commissions.EFFECT_REGULAR), 25, "396：万神院不走调查 / 结案，25 直接开日常委托")
	t.check(fs.all(func(f: FactionDef) -> bool: return Names.of(f, "en") != f.display_name), "都有英文名")
	var ids := Commissions.defs().map(func(d: CommissionDef) -> String: return String(d.id))
	for id in ["legion_two_routes", "society_copy_recipe", "greylamp_unsigned_letter"]:
		t.check(ids.has(id), "有原型单 " + id)
	t.eq(Commissions.validate_all(Commissions.defs(), Commissions.factions()), [] as Array[String], "前置、阵营都查得过")
	var two := Commissions.def(&"legion_two_routes")
	t.eq(two.quote, "去的时候路都好走。替我看看，回来还能走哪条。", "方案的原话原样用")
	t.eq([two.faction, Commissions.reputation_of(two), Commissions.required_rep(two)], [&"cartographers", 5, 10], "两条回路：342 B3 改给地图协会，+5，要 10 声望")
	t.eq(Commissions.required_rep(Commissions.def(&"society_copy_recipe")), 10, "342 B2：配方实验成了协会的基础剧情，10 声望可接")
	t.check(Commissions.needs_pick(Commissions.def(&"society_copy_recipe")), "配方实验要先选配方")


static func run_import_checks(t: TestCase) -> void:
	t.begin("336 W0：导入校验 —— 认不得的目标、目标不许的完成地点、非带回步骤写托付、门槛不对、阵营找不到都报错")
	var ctx := ContentImporter.Context.new()
	var r0 := ImportReport.new()
	ContentImporter.import_faction({"id": "f1", "display_name": "甲", "nodes": [{"id": "a", "rep": 5, "kind": "open", "effect": "fly"}, {"id": "a", "rep": -1, "kind": "gift", "effect": "inquiry"}]}, ctx, r0)
	var t0 := r0.to_text()
	t.check(t0.contains("不认识的效果") and t0.contains("不重复") and t0.contains("负数") and t0.contains("种类只认"), "389：节点的效果、id、声望、种类写错都报错（赠礼不是节点）")
	var r00 := ImportReport.new()
	ContentImporter.import_faction({"id": "f0", "display_name": "乙", "nodes": [{"id": "p", "rep": 40, "kind": "open", "effect": "", "placeholder": true}]}, ctx, r00)
	t.check(not r00.to_text().contains("不认识的效果"), "占位节点可以不写效果")
	var r1 := ImportReport.new()
	ContentImporter.import_commission({"id": "c1", "faction": "f1", "tier": "intro", "stages": [{"goal": "fly", "where": "field"}]}, ctx, r1)
	t.check(r1.to_text().contains("不认识的目标"), "认不得的目标报错")
	var r2 := ImportReport.new()
	ContentImporter.import_commission({"id": "c2", "faction": "f1", "tier": "intro", "stages": [{"goal": "smith_forge", "where": "field"}]}, ctx, r2)
	t.check(r2.to_text().contains("只能在"), "打造只能在营地")
	var r3 := ImportReport.new()
	ContentImporter.import_commission({"id": "c3", "faction": "f1", "tier": "intro", "stages": [{"goal": "inspect_extracts", "where": "field", "entrust_ok": true}]}, ctx, r3)
	t.check(r3.to_text().contains("托付"), "现场步骤写托付报错")
	var r4 := ImportReport.new()
	ContentImporter.import_commission({"id": "c4", "faction": "nobody", "tier": "intro", "stages": [{"goal": "inspect_extracts", "where": "field"}]}, ctx, r4)
	t.check(r4.to_text().contains("找不到阵营"), "阵营找不到报错")
	var r5 := ImportReport.new()
	ContentImporter.import_commission({"id": "c5", "faction": "f1", "tier": "boss", "stages": []}, ctx, r5)
	t.check(r5.to_text().contains("档位") and r5.to_text().contains("至少一步"), "档位不认得、没有步骤报错")
	var a := _def(&"a", &"legion", CommissionDef.INTRO)
	var b := _def(&"b", &"legion", CommissionDef.INQUIRY)
	a.requires = [&"b"] as Array[StringName]
	b.requires = [&"a"] as Array[StringName]
	var c := _def(&"c", &"society", CommissionDef.INTRO)
	c.requires = [&"a"] as Array[StringName]
	var probs := Commissions.validate_all([a, b, c], Commissions.factions())
	t.check(probs.any(func(p: String) -> bool: return p.contains("成环")), "前置成环报错")
	t.check(probs.any(func(p: String) -> bool: return p.contains("不是同一方")), "跨方前置报错")


static func run_tiers(t: TestCase) -> void:
	t.begin("389：声望节点 —— 到了那个数就算到（不再要求先做完结案）；下一个节点还差几点；跨过的节点；占位的到了也不算")
	var book := CommissionBook.new()
	var f := Commissions.faction(&"legion")
	var at := func(r: int) -> Array:
		book.rep["legion"] = r
		return [Commissions.has_effect(book, f, Commissions.EFFECT_INQUIRY), Commissions.has_effect(book, f, Commissions.EFFECT_FINALE)]
	t.eq([at.call(0), at.call(9), at.call(10), at.call(24), at.call(25), at.call(120)], [[false, false], [false, false], [true, false], [true, false], [true, true], [true, true]], "10 调查、25 结案")
	book.rep["legion"] = 18
	t.eq(Commissions.rep_to_next(book, f), 7, "18 到 25 还差 7")
	book.rep["legion"] = 30
	t.eq(Commissions.rep_to_next(book, f), 0, "后勤部队过了最后一个节点：0（389 第 2 条：之后照涨，不给东西）")
	t.eq(Commissions.crossed(f, 5, 30).map(func(n: Dictionary) -> String: return String(n["id"])), ["inquiry", "finale"], "从 5 涨到 30 跨过两个")
	var p := FactionDef.new()     # 396 起数据里没有占位节点了：拿一份现搭的查
	p.id = &"t_ph"
	var ph := {"id": "ph", "rep": 40, "kind": "open", "effect": "", "placeholder": true}
	p.nodes = [ph] as Array[Dictionary]
	book.rep["t_ph"] = 100
	t.check(not Commissions.reached(book, p, ph), "占位在 40：到了也不算")
	t.check(Commissions.crossed(p, 0, 100).is_empty(), "跨过的不含占位")
	t.eq(Commissions.node_text(ph), UiText.t("node.unknown"), "占位显示？？？？")


static func run_node_news(t: TestCase) -> void:
	t.begin("389：办成委托涨声望跨过节点 —— 记进通知（营地一条一条放），存档带着；占位的不通知")
	var m := _meta()
	var d := _def(&"t_news", &"pantheon", CommissionDef.INTRO)
	d.reputation = 30
	Commissions._complete(m, d, null)
	t.eq(m.commissions.node_news.map(func(r: Dictionary) -> String: return String(r["node"])), ["regular", "temple_rite_25"], "396：0 → 30：日常委托、25 的引导委托两条")
	var back := CommissionBook.from_dict(m.commissions.to_dict())
	t.eq(back.node_news, m.commissions.node_news, "存档带着")
	m.commissions.node_news.clear()
	d.reputation = 30
	Commissions._complete(m, d, null)
	t.eq(m.commissions.node_news.map(func(r: Dictionary) -> String: return String(r["node"])), ["reroll", "temple_rite_50", "convert", "skip"], "30 → 60：重选、50 的引导委托、改信、跳过")


static func run_gifts(t: TestCase) -> void:
	t.begin("389 第七节：【赠礼】—— 声望每攒 gift_every（各方 25，可改）多一份、一直累积；点【领取】一次领一份、随机给一样；领过的进存档；老档从 0 算起补发")
	var m := _meta()
	var f := Commissions.faction(&"legion")
	t.eq(Commissions.gift_every(f), 25, "后勤部队每 25 一份")
	t.check(Commissions.factions().all(func(x: FactionDef) -> bool: return x.gift_every == 25), "各方都写 25")
	t.eq(Commissions.gifts_due(m, f), 0, "0 声望：没有")
	m.commissions.rep["legion"] = 60
	t.eq(Commissions.gifts_due(m, f), 2, "60：两份")
	t.eq(Commissions.rep_to_next_gift(m, f), 15, "下一份还差 15")
	var funds := m.funds
	var got := Commissions.claim_gift(m, f)
	t.check(bool(got["ok"]) and Commissions.gifts_due(m, f) == 1, "领一份，剩一份")
	t.eq(m.funds - funds, int(got["funds"]), "给的钱进了账")
	Commissions.claim_gift(m, f)
	t.check(not bool(Commissions.claim_gift(m, f)["ok"]) and Commissions.gifts_due(m, f) == 0, "领完了再点不给")
	m.commissions.rep["legion"] = 75
	t.eq(Commissions.gifts_due(m, f), 1, "再攒到 75：又一份（领过的照算）")
	var back := CommissionBook.from_dict(m.commissions.to_dict())
	t.eq(int(back.gifts_claimed.get("legion", 0)), 2, "领过几份进存档")
	var d := m.commissions.to_dict()
	d.erase("gifts_claimed")
	var m2 := _meta()
	m2.commissions = CommissionBook.from_dict(d)
	t.eq(Commissions.gifts_due(m2, f), 3, "老档没有这一键：75 声望从 0 补发三份")
	var pf := FactionDef.new()
	pf.id = &"t_pool"
	pf.gift_every = 10
	pf.gift_pool.assign([{"funds": 7}, {"funds": 9}])
	var m3 := _meta()
	m3.commissions.rep["t_pool"] = 40
	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for _i in 4:
		seen[int(Commissions.claim_gift(m3, pf, null, rng)["funds"])] = true
	t.check(seen.keys().all(func(k: int) -> bool: return k == 7 or k == 9), "每份从那一小组里随机给一样（%s）" % str(seen.keys()))
	var nogift := FactionDef.new()
	nogift.id = &"t_none"
	m3.commissions.rep["t_none"] = 100
	t.eq(Commissions.gifts_due(m3, nogift), 0, "gift_every = 0：这一方没有赠礼")


static func run_take_rules(t: TestCase) -> void:
	t.begin("336 W0 / 342 B2：接取 —— 常规（模板）同时三份（342 B2：手头 3）；档位不够、前置没做、互斥组被结、做完的具名单、没选配方都不能接；暂缓不占位，放弃清进度")
	var book := CommissionBook.new()
	var a := _def(&"t_a", &"legion", CommissionDef.TEMPLATE)
	var b := _def(&"t_b", &"society", CommissionDef.TEMPLATE)
	var c := _def(&"t_c", &"greylamp", CommissionDef.TEMPLATE)
	var deep := _def(&"t_deep", &"legion", CommissionDef.INQUIRY)
	var hidden := _def(&"t_hidden", &"envoy", CommissionDef.INTRO)
	t.eq(Commissions.why_not(book, hidden), Commissions.WHY_HIDDEN, "没列出来的阵营不能接")
	t.eq(Commissions.why_not(book, deep), Commissions.WHY_REP, "调查要 10 声望")
	var z := _def(&"t_z", &"legion", CommissionDef.TEMPLATE)
	t.check(Commissions.take(book, z) and Commissions.take(book, a) and Commissions.take(book, b), "接三份")
	t.eq(Commissions.why_not(book, c), Commissions.WHY_SLOTS, "第四份没位")
	t.eq(Commissions.why_not(book, a), Commissions.WHY_TAKEN, "接着的不能再接")
	t.check(Commissions.pause(book, &"t_b"), "暂缓一份")
	t.eq(book.taken(), [&"t_z", &"t_a"] as Array[StringName], "暂缓的不占位")
	t.check(Commissions.take(book, c), "空出的位接第四份")
	t.eq(Commissions.why_not(book, b), Commissions.WHY_SLOTS, "位满了，暂缓的也接不回来")
	t.check(Commissions.abandon(book, &"t_c"), "放弃一份")
	t.eq(book.state_of(&"t_c"), "", "放弃的没留下进度")
	t.check(Commissions.take(book, b), "暂缓的接回来")
	var story := _def(&"t_story", &"legion", CommissionDef.INTRO)
	t.eq(Commissions.why_not(book, story), "", "342 B2：剧情不占位（常规满了照样接）")
	Commissions.take(book, story)
	Commissions.defs().append(story)     # pause / abandon 按 id 查定义
	t.check(not Commissions.pause(book, &"t_story") and not Commissions.abandon(book, &"t_story"), "342 B2：剧情不暂缓、不放弃")
	Commissions.defs().erase(story)
	var after := _def(&"t_after", &"legion", CommissionDef.INTRO)
	after.requires = [&"t_x"] as Array[StringName]
	t.eq(Commissions.why_not(CommissionBook.new(), after), Commissions.WHY_REQUIRES, "前置没做不能接")
	var m1 := _def(&"t_m1", &"legion", CommissionDef.INTRO)
	m1.mutex = &"roll"
	var b2 := CommissionBook.new()
	b2.mutex["roll"] = "t_m0"
	t.eq(Commissions.why_not(b2, m1), Commissions.WHY_MUTEX, "互斥组被别人结了")
	var copy := Commissions.def(&"society_copy_recipe")
	var b0 := CommissionBook.new()     # 342 B2：前面那份开放单办完、熟面
	b0.entries["society_first_survey"] = {"state": CommissionBook.DONE, "stage": 0, "progress": 0, "keys": [], "times": 1, "pick": "", "seq": 0}
	b0.rep["society"] = 10
	t.eq(Commissions.why_not(b0, copy, &"", [&"iron_sword"]), Commissions.WHY_PICK, "没选配方不能接")
	t.eq(Commissions.why_not(b0, copy, &"bogus", [&"iron_sword"]), Commissions.WHY_PICK, "选的不在可选里不能接")
	var b3 := CommissionBook.from_dict(b0.to_dict())
	t.check(Commissions.take(b3, copy, &"iron_sword", [&"iron_sword"]), "选了能做的配方就能接")
	t.eq(String(b3.entry(copy.id)["pick"]), "iron_sword", "记下选的配方")


static func run_credit(t: TestCase) -> void:
	t.begin("336 W0：记账 —— 同一处只记一次；做够了进下一步；最后一步结案给声望、酬金、回执；具名单做完不能再接；模板最多推到信赖")
	var m := _meta()
	var d := _def(&"t_two", &"legion", CommissionDef.INQUIRY)
	d.min_rep = 0
	d.stages[0].count = 2
	d.funds = 60
	t.check(Commissions.take(m.commissions, d), "接下")
	var funds0 := m.funds
	t.check(bool(Commissions.credit(m, d, 0, "node:4")["ok"]), "第一处记上")
	t.check(not bool(Commissions.credit(m, d, 0, "node:4")["ok"]), "同一处再记不算")
	t.check(not bool(Commissions.credit(m, d, 1, "node:5")["ok"]), "不是当前这一步不算")
	var r := Commissions.credit(m, d, 0, "node:9")
	t.check(bool(r["ready"]) and not bool(r["done"]), "第二处：办成了，先不结案（作者 2026-11-21：点【完成】才算）")
	t.eq([m.commissions.state_of(&"t_two"), m.commissions.rep_of(&"legion"), m.funds - funds0], [CommissionBook.READY, 0, 0], "还没点完成：留在手上、没给声望和酬金")
	t.eq(m.commissions.receipts[0]["kind"], "ready", "回执：办成了")
	t.eq(Commissions.why_not(m.commissions, d), Commissions.WHY_TAKEN, "办成没点完成：不能再接")
	t.check(bool(Commissions.claim(m, d)["done"]), "点【完成】：结案")
	t.check(not bool(Commissions.claim(m, d)["ok"]), "再点不算")
	t.eq([m.commissions.rep_of(&"legion"), m.funds - funds0], [2, 60], "声望 +2（没写就按档位默认）、酬金 60")
	t.eq(m.commissions.receipts[0]["kind"], "done", "回执：结案")
	t.eq(Commissions.why_not(m.commissions, d), Commissions.WHY_DONE, "具名单做完不能再接")
	var tpl := _def(&"t_tpl", &"society", CommissionDef.TEMPLATE)
	tpl.reputation = 4
	m.commissions.rep["society"] = 40     # 391：模板不再封顶在 50
	for i in 4:
		t.check(Commissions.take(m.commissions, tpl), "模板第 %d 次能接" % (i + 1))
		Commissions.credit(m, tpl, 0, "k%d" % i)
		Commissions.claim(m, tpl)
	t.eq(m.commissions.rep_of(&"society"), 56, "模板做四次，声望 40 + 16，过了 50 照涨")
	t.eq(int(m.commissions.entry(&"t_tpl")["times"]), 4, "完成次数照记")
	var fin := _def(&"t_fin", &"greylamp", CommissionDef.FINALE)
	fin.min_rep = 0
	fin.mutex = &"roll"
	Commissions.take(m.commissions, fin)
	Commissions.credit(m, fin, 0, "x")
	Commissions.claim(m, fin)
	t.check(m.commissions.signed.has("greylamp"), "结案署名")
	t.eq(m.commissions.mutex.get("roll", ""), "t_fin", "互斥组记下归属")


static func run_merge_run(t: TestCase) -> void:
	t.begin("336 W0：一局并进局外 —— 现场交付失败也算；带回的只在撤离（或写明托付算时托付成功）算，否则写「重做」；同一条并两次不重复")
	var d := _def(&"t_mix", &"legion", CommissionDef.INTRO, [CommissionStage.FIELD, CommissionStage.CARRY])
	# merge_run 按 id 查定义：测试的定义临时塞进表里，查完拿掉
	Commissions.defs().append(d)
	var m := _meta()
	Commissions.take(m.commissions, d)
	var rows := [{"id": "t_mix", "stage": 0, "key": "node:3"}]
	t.eq(Commissions.merge_run(m, rows, false, false)["credited"], 1, "现场交付：败退也算")
	t.eq(Commissions.current_stage(m.commissions, &"t_mix"), 1, "进到带回那一步")
	t.eq(Commissions.merge_run(m, rows, false, false)["credited"], 0, "同一条再并不算")
	var carry := [{"id": "t_mix", "stage": 1, "key": "uid:7", "via": "self"}]
	t.eq(Commissions.merge_run(m, carry, false, false)["redo"], 1, "带回的：败退没带回 = 重做")
	t.eq(Commissions.current_stage(m.commissions, &"t_mix"), 1, "还停在带回那一步")
	t.eq(m.commissions.receipts[0]["kind"], "redo", "回执：重做")
	var via := [{"id": "t_mix", "stage": 1, "key": "uid:8", "via": "entrust"}]
	t.eq(Commissions.merge_run(m, via, false, false)["credited"], 0, "托付没成不算")
	t.eq(Commissions.merge_run(m, via, false, true)["credited"], 1, "托付成功且写明托付算：算")
	t.check(Commissions.is_ready(m.commissions, &"t_mix"), "办成了，等点【完成】")
	Commissions.claim(m, d)
	t.check(m.commissions.is_done(&"t_mix"), "结案")
	var m2 := _meta()
	Commissions.take(m2.commissions, d)
	Commissions.merge_run(m2, rows, false, false)
	t.eq(Commissions.merge_run(m2, carry, true, false)["credited"], 1, "本人撤离：带回算")
	Commissions.defs().erase(d)


static func run_save(t: TestCase) -> void:
	t.begin("336 W0：委托跟局外存档往返逐字节相同；老档（v4 样本迁上来）没有委托 = 全空、图鉴与原有进度不变")
	var db := T110._db()
	var m := _meta()
	var d := Commissions.def(&"legion_two_routes")
	W1.unlock(m.commissions)     # 342 B3：排在地图协会首单后
	t.check(Commissions.take(m.commissions, d), "接上《两条回路》")
	Commissions.credit(m, d, 0, "node:2")
	m.commissions.rep["greylamp"] = 1
	var text := MetaSave.to_text(m)
	var back := MetaState.from_dict(m.to_dict(), db, GameFlow.load_meta_rules())
	t.not_null(back, "读得回来")
	if back == null:
		return
	t.eq(JSON.stringify(back.commissions.to_dict()), JSON.stringify(m.commissions.to_dict()), "委托往返相同")
	t.eq(int(back.commissions.entry(&"legion_two_routes")["progress"]), 1, "进度照旧")
	t.check(text != "", "存得出")
	var raw := FileAccess.get_file_as_string("res://tests/fixtures/meta_v4.json")
	var old := MetaSave.from_text(raw, db, GameFlow.load_meta_rules(), GameFlow.load_techs())
	t.not_null(old, "老档读得回来")
	if old == null:
		return
	t.check(old.commissions.entries.is_empty() and old.commissions.rep.is_empty(), "老档没有委托")
	t.check(not old.commissions.gated, "342 B2：老档不受设施门控")
	var src: Dictionary = JSON.parse_string(raw)
	t.eq(old.codex.size(), (src.get("codex", {}) as Dictionary).size(), "图鉴条目数不变")
