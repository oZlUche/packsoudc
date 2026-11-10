## 平衡检测方案（2026-11-10）§8.1～§8.3：观看记录的记账（暂停、教程停住、失焦分开扣）、决定性窗口手算、配对对照、
## 体验报告五节（有没有观看记录都写得出来，缺的进未知项）、人工验证场景可复现、问题清单不暗示答案
extends RefCounted

const DIR := "user://test_battle_experience"
const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "viewing_record"


static func _near(t: TestCase, got: Variant, want: float, what: String, tol: float = 0.0005) -> void:
	t.check(got != null and absf(float(got) - want) <= tol, "%s：%s ≈ %s" % [what, str(got), str(want)])


static func run_viewing_session(t: TestCase) -> void:
	t.begin("§8.1 观看记录：实际观看 = 到揭晓的墙上时间扣掉暂停、教程停住、失焦；揭晓只记第一次；提示记停留；离开后不再记")
	var idle := ViewingSession.new()
	idle.note(ViewingSession.PAUSE, 1.0, 500)
	t.eq(idle.events.size(), 0, "没开始：不记")
	var v := ViewingSession.new()
	v.start("run:7", 6.0, 1.0, 1000, true, {"coins": 10})
	v.note(ViewingSession.PAUSE, 2.0, 3000)          # 放了 2 秒
	v.note(ViewingSession.PLAY, 2.0, 4000)           # 停了 1 秒
	v.note(ViewingSession.FOCUS_OUT, 3.0, 5000)      # 放了 1 秒
	v.note(ViewingSession.FOCUS_IN, 3.0, 7000)       # 失焦 2 秒
	v.note(ViewingSession.HOLD, 3.5, 7500)           # 放了 0.5 秒
	v.note(ViewingSession.HINT, 3.5, 7500, {"id": "coach"})
	v.note(ViewingSession.RELEASE, 3.5, 8000)        # 教程停住 0.5 秒
	v.note(ViewingSession.HINT_END, 3.5, 9000)       # 提示停留 1.5 秒
	v.note(ViewingSession.SPEED, 4.0, 9000, {"speed": 2.0})
	v.note(ViewingSession.SEEK, 4.5, 9200)
	v.note(ViewingSession.SKIP, 5.0, 10000)
	v.note(ViewingSession.REVEAL, 6.0, 10000)        # 到这儿一共放了 2 + 1 + 0.5 + 2 = 5.5 秒
	v.note(ViewingSession.REVEAL, 6.0, 11000)        # 拖时间轴拖到头又「看完」一次：不算
	v.note(ViewingSession.LEAVE, 6.0, 13000)
	v.note(ViewingSession.PLAY, 6.0, 14000)          # 走了以后：不记
	var d := v.to_dict()
	_near(t, d["presentation_elapsed"], 5.5, "实际观看（扣掉暂停、停住、失焦）")
	_near(t, d["wall_to_reveal"], 9.0, "开始到揭晓的墙上时间")
	_near(t, d["linger_after_reveal"], 3.0, "揭晓后又待了 3 秒")
	_near(t, d["wall_total"], 12.0, "一共 12 秒")
	_near(t, d["paused_sec"], 1.0, "暂停 1 秒")
	_near(t, d["held_sec"], 0.5, "教程停住 0.5 秒")
	_near(t, d["unfocused_sec"], 2.0, "失焦 2 秒")
	t.check(bool(d["skipped"]) and float(d["skip_at_sim"]) == 5.0, "跳过：在模拟 5 秒处")
	t.eq(d["seeks"], 1, "拖过一次时间轴")
	t.eq((d["speeds"] as Array).size(), 2, "倍速：开场一条 + 切过一次")
	t.eq(float((d["speeds"] as Array)[1]["speed"]), 2.0, "切到 2 倍")
	t.eq((d["hints"] as Array).size(), 1, "一条提示")
	_near(t, (d["hints"] as Array)[0]["dwell"], 1.5, "提示停留 1.5 秒")
	t.eq((d["events"] as Array).filter(func(e: Dictionary) -> bool: return e["kind"] == ViewingSession.REVEAL).size(), 1, "揭晓只有一条")
	t.check(bool(d["revealed"]) and bool(d["left"]) and d["before"] == {"coins": 10}, "揭晓了、离开了、战前状态原样带着")
	var early := ViewingSession.new()
	early.start("run:8", 6.0, 1.0, 0)
	early.note(ViewingSession.LEAVE, 1.0, 2000)
	var ed := early.to_dict()
	t.check(ed["presentation_elapsed"] == null and ed["wall_to_reveal"] == null and not bool(ed["revealed"]), "没看到揭晓就走：实际观看是 null（不按模拟时长推算）")
	_near(t, ed["wall_total"], 2.0, "墙上一共 2 秒照记")


static func _hit(at: float, side: int, amount: float, extra: Dictionary = {}) -> BattleEvent:
	var p := {"amount": -StatMath.from_float(amount), "source_side": 1 - side, "uid": 1, "direct": true}
	p.merge(extra)
	return BattleEvent.make(BattleEvent.DAMAGE, StatMath.from_float(at), side, p)


static func run_decisive_window(t: TestCase) -> void:
	t.begin("§8.2 决定性窗口：落败一方挨的伤害里装得下一半的最短时间窗，手算；窗在屏上放了多久按倍速和跳过算")
	var r := BattleResult.new()
	r.winner = 0
	r.duration = StatMath.from_float(10.0)
	r.log.append(_hit(1.0, 1, 10.0))
	r.log.append(_hit(2.0, 1, 50.0, {"cancelled": true}))     # 被取消的不算
	r.log.append(_hit(5.0, 1, 30.0))
	r.log.append(_hit(5.5, 1, 30.0))
	r.log.append(_hit(9.0, 1, 30.0))
	r.log.append(_hit(3.0, 0, 99.0))                          # 胜方挨的不算
	var w := BattleExperience.decisive_window(r)
	t.eq(int(w["side"]), 1, "落败一方是对方")
	_near(t, w["total"], 100.0, "落败一方一共挨了 100")
	_near(t, w["start"], 5.0, "窗从 5 秒开始")
	_near(t, w["end"], 5.5, "到 5.5 秒")
	_near(t, w["share"], 0.6, "装了六成")
	var viewing := {"speeds": [{"sim": 0.0, "speed": 1.0}, {"sim": 4.0, "speed": 2.0}], "skip_at_sim": null}
	var shown: Dictionary = BattleExperience._shown(w, viewing)
	t.check(not bool(shown["skipped"]) and float(shown["speed"]) == 2.0, "没跳过，当时 2 倍速")
	_near(t, shown["display_sec"], 0.25, "0.5 秒的窗在屏上放了 0.25 秒")
	viewing["skip_at_sim"] = 5.2
	shown = BattleExperience._shown(w, viewing)
	t.check(bool(shown["skipped"]), "窗里跳过：记跳过")
	_near(t, shown["display_sec"], 0.1, "跳过之前放了 0.1 秒")
	viewing["skip_at_sim"] = 3.0
	shown = BattleExperience._shown(w, viewing)
	t.check(bool(shown["skipped"]) and float(shown["display_sec"]) == 0.0, "窗还没到就跳过：屏上 0 秒")
	t.is_null(BattleExperience._shown(w, {}), "没有观看记录：不知道（null）")
	var draw := BattleResult.new()
	draw.winner = -1
	t.eq(BattleExperience.decisive_window(draw), {}, "没有胜方：不算窗")


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func run_battle_factor(t: TestCase) -> void:
	t.begin("§8.2 准备有效性：同一份配装配对重打差 0；编译后拿掉一件列出连带变化；从棋盘编译的两份只差声明的那几种")
	var db := _items()
	var me := FeelScenarios.player(["longsword", "shortsword"], 100.0, db)
	var foe := FeelScenarios.player(["knife", "salve"], 120.0, db)
	t.not_null(me, "我方编得出来")
	t.is_null(FeelScenarios.player(["no_such_item"], 100.0, db), "没有的道具：编不出来（null）")
	var seeds := BattleFactor.seeds_from(5, 6)
	t.eq(seeds.size(), 6, "六个种子")
	t.eq(seeds, BattleFactor.seeds_from(5, 6), "种子只看基准和序号")
	var same := BattleFactor.paired(me, me, foe, seeds)
	t.eq(int(same["n"]), 6, "六对")
	_near(t, same["win_diff"]["diff"], 0.0, "同一份配装：胜率差 0")
	_near(t, same["hp_diff"]["diff"], 0.0, "余血差 0")
	_near(t, same["duration_diff"]["diff"], 0.0, "时长差 0")
	var uid := me.items[0].source_uid
	var cut := BattleFactor.without_item(me, uid)
	t.not_null(cut["spec"], "拿掉一件：还编得回来")
	if cut["spec"] != null:
		var left := (cut["spec"] as CombatantSpec).items.filter(func(it: CompiledItem) -> bool: return it.source_uid == uid)
		t.eq(left.size(), 0, "那一件没了")
		t.eq(String(cut["removed"]), String(me.items[0].def_id), "记下拿掉的是哪件")
		t.check((cut["collateral"] as Array).any(func(s: String) -> bool: return s.contains("相邻")), "连带变化：相邻 / 包内加成没有重算")
	t.is_null(BattleFactor.without_item(me, 999999)["spec"], "没有这个 uid：null")
	var again := FeelScenarios.player(["longsword", "shortsword"], 100.0, db)
	t.eq(BattleFactor.collateral(me, again, []), [] as Array[String], "同一张棋盘编两次：没有连带变化")
	var swapped := FeelScenarios.player(["longsword", "round_shield"], 100.0, db)
	var undeclared := BattleFactor.collateral(me, swapped, [])
	t.check(undeclared.any(func(s: String) -> bool: return s.begins_with("shortsword")), "不声明：短剑件数的变化列出来（%s）" % str(undeclared))
	var declared := BattleFactor.collateral(me, swapped, [&"shortsword", &"round_shield"] as Array[StringName])
	t.check(not declared.any(func(s: String) -> bool: return s.begins_with("shortsword") or s.begins_with("round_shield")), "声明了的两种不算连带（%s）" % str(declared))


static func _brief(vit: int, coins: int, items: int, steps: int) -> Dictionary:
	return {"vitality": vit, "coins": coins, "items": items, "steps": steps}


static func run_experience_report(t: TestCase) -> void:
	t.begin("§8.2 体验报告：没有观看记录照样写五节，缺的进未知项；有观看记录时节奏和得失用它；复现对不上整份只作参考")
	var db := _items()
	var me := FeelScenarios.player(["longsword", "shortsword"], 100.0, db)
	var foe := FeelScenarios.player(["knife", "salve"], 120.0, db)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var result := BattleSim.run(me, foe, rng, 30.0, null)
	var bare := BattleExperience.analyze(result, [me, foe], 30.0)
	for k in ["cause", "preparation", "rhythm", "consequence", "unknowns"]:
		t.check(bare.has(k), "有「%s」一节" % k)
	var unknown_text := "\n".join(bare["unknowns"])
	t.check(unknown_text.contains("没有观看记录"), "没有观看记录：写进未知项")
	t.check(unknown_text.contains("没有和原始结果比对过"), "没比对过：写进未知项")
	t.check(unknown_text.contains("没有做准备有效性"), "没做配对：写进未知项")
	t.is_null(bare["rhythm"]["presentation_elapsed"], "没有观看记录：实际观看是 null，不拿模拟时长顶")
	t.check(bare["consequence"]["run_delta"].values().all(func(x: Variant) -> bool: return x == null), "没有战前战后：得失全是 null")
	t.eq((bare["rhythm"]["hp_line"][0] as Array).size(), BattleExperience.HP_SAMPLES + 1, "血线等距取点")
	t.eq(float(bare["rhythm"]["hp_line"][0][0]), 1.0, "开场满血")
	var md := BattleExperience.markdown(bare)
	for h in ["## 一 原因可见性", "## 二 准备有效性", "## 三 过程节奏", "## 四 后果差异", "## 五 未知项"]:
		t.check(md.contains(h), "Markdown 有「%s」" % h)
	t.check(md.begins_with("# 战斗体验诊断\n"), "没有战斗标识：标题后面不留空")
	var v := ViewingSession.new()
	v.start("run:42", result.duration_sec(), 1.0, 0, true, _brief(10, 20, 5, 3))
	v.note(ViewingSession.REVEAL, result.duration_sec(), 4000)
	v.after = _brief(9, 35, 6, 3)
	v.note(ViewingSession.LEAVE, result.duration_sec(), 5000)
	var factors := BattleExperience.factor_rows(me, foe, 30.0, null, 21, 4)
	t.eq(factors.size(), 2, "两件各拿掉一次")
	var full := BattleExperience.analyze(result, [me, foe], 30.0, v.to_dict(), factors, true)
	t.eq(full["battle_id"], "run:42", "战斗标识取自观看记录")
	_near(t, full["rhythm"]["presentation_elapsed"], 4.0, "实际观看取自观看记录")
	t.eq(full["consequence"]["run_delta"], {"vitality": -1.0, "coins": 15.0, "items": 1.0, "steps": 0.0}, "整局得失 = 战后 − 战前")
	var full_unknown := "\n".join(full["unknowns"])
	t.check(not full_unknown.contains("没有观看记录") and not full_unknown.contains("比对过") and not full_unknown.contains("没有做准备"), "有了的不再列为未知")
	t.check(full_unknown.contains("耐力") and full_unknown.contains("屏上显示"), "量不到的照样列：耐力停火原因、屏上显示")
	var fmd := BattleExperience.markdown(full)
	t.check(fmd.contains("| %s |" % factors[0]["removed"]), "准备有效性表：每件一行")
	t.check(fmd.contains("钱 +15"), "得失写进后果一节")
	var off := BattleExperience.analyze(result, [me, foe], 30.0, {}, [], false)
	t.check("\n".join(off["unknowns"]).contains("只作参考"), "复现对不上：整份只作参考")


static func run_feel_scenarios(t: TestCase) -> void:
	t.begin("§8.3 人工验证场景：同一个种子打两遍事实一样，包重跑和预期对得上；问题清单只露代号，不露场景名")
	var db := _items()
	var me := FeelScenarios.player(["longsword", "shortsword", "salve"], 120.0, db)
	var foe := FeelScenarios.player(["knife"], 60.0, db)
	var any := func(_m: Dictionary) -> bool: return true
	var a := FeelScenarios._try(me, foe, 77, any)
	var b := FeelScenarios._try(me, foe, 77, any)
	t.eq(JSON.stringify(a["facts"]), JSON.stringify(b["facts"]), "同一个种子：预期事实一样")
	var pack: BattleDiagPack = a["pack"]
	t.eq(BattleDiagPack.compare(pack.expected, BattleDiagPack.summary(pack.rerun())), {}, "包重跑：和预期对得上")
	t.eq(pack.meta.get("source", ""), ExperimentManifest.SYNTHETIC, "场景包记成合成数据")
	t.eq(FeelScenarios._try(me, foe, 77, func(_m: Dictionary) -> bool: return false), {}, "条件不满足：返回空（不放宽）")
	var ids: Array[String] = []
	for row in FeelScenarios.catalog():
		ids.append(String(row[0]))
	t.check(ids.size() >= 6 and ids.has("crush_win") and ids.has("clear_loss") and ids.has("stamina_short") and ids.has("counter_a"), "目录里有方案要的几类（%s）" % str(ids))
	var rows := [{"id": "crush_win", "found": true, "code": "S1", "replay": "x.replay.json"}, {"id": "clear_loss", "found": false},
		{"id": "swap_b", "found": true, "code": "S2"}]
	var q := FeelScenarios.questions(rows)
	t.check(q.contains("| 1 | S1 | x.replay.json |") and q.contains("| 2 | S2 | — |"), "按代号排，没找到的不进表")
	t.check(not q.contains("crush_win") and not q.contains("swap_b") and not q.contains("大胜"), "不露场景名和说明")
	t.check(q.contains("答完再看"), "提醒先答再看")


static func frame_viewing_record(t: TestCase, root: Window) -> void:
	t.begin("§8.1 回放屏：诊断开着就记一份观看记录（跳过、揭晓、离开），离开时落盘；诊断关着不记")
	_cleanup(DIR)
	var was: Variant = BattleDiagnostics.enabled
	var was_dir := BattleDiagnostics.viewing_dir
	BattleDiagnostics.enabled = true
	BattleDiagnostics.viewing_dir = DIR
	var f := Support.flow(GF._content(), PREFIX)
	var r := BattleResult.new()
	r.winner = 0
	r.duration = 3 * StatMath.ONE
	r.log.append(BattleEvent.make(BattleEvent.BATTLE_START, 0, -1))
	r.log.append(BattleEvent.make(BattleEvent.DAMAGE, StatMath.ONE, 1, {"amount": -StatMath.ONE, "type": "physical"}))
	var screen = load("res://ui/game/battle_screen.gd").new()
	screen.screen = GameFlow.Screen.BATTLE
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	root.add_child(screen)
	screen.open({"result": r, "won": true, "battle_id": "run9:123", "before": {"coins": 4}})
	screen.view().skip_to_end()
	screen._close_viewing()
	var files := BattleDiagnostics.list(DIR, BattleDiagnostics.VIEWING_EXT)
	t.eq(files.size(), 1, "落了一份 .viewing.json")
	if files.size() == 1:
		t.check(files[0].contains("run9_123"), "文件名带战斗标识（%s）" % files[0])
		var rec = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(files[0])))
		t.check(rec is Dictionary, "读得回来")
		if rec is Dictionary:
			t.eq(rec["battle_id"], "run9:123", "战斗标识")
			t.check(bool(rec["skipped"]) and bool(rec["revealed"]) and bool(rec["left"]), "跳过、揭晓、离开都记了")
			_near(t, rec["simulation_duration"], 3.0, "模拟时长另记")
			_near(t, (rec["before"] as Dictionary).get("coins"), 4.0, "战前状态原样带着")
			t.check(rec.has("source"), "盖了数据来源")
	screen.queue_free()
	BattleDiagnostics.enabled = false
	var quiet = load("res://ui/game/battle_screen.gd").new()
	quiet.screen = GameFlow.Screen.BATTLE
	quiet.flow = f
	quiet.font = UiPalette.cjk_font()
	root.add_child(quiet)
	quiet.open({"result": r, "won": true, "battle_id": "run9:124"})
	quiet.view().skip_to_end()
	quiet._close_viewing()
	t.eq(BattleDiagnostics.list(DIR, BattleDiagnostics.VIEWING_EXT).size(), 1, "诊断关着：不记")
	quiet.queue_free()
	BattleDiagnostics.enabled = was
	BattleDiagnostics.viewing_dir = was_dir
	_cleanup(DIR)
	Support.cleanup(PREFIX)


static func _cleanup(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
