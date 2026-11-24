## 388 第 0 批：质变牌框架 —— 开局一次 + 6 / 12 / … 级质变位；奉神时质变位只出这位神的质变牌，普通选牌通用 + 神的基础牌一个池子、保底一张神的；
## 四种出牌条件（拿过某张才出、互斥、满足条件才入池、升级版）；无信者 / 没写牌的神质变位改为多选一张通用牌；万神院五档开局多一张；
## 神恩区按拿的先后列质变牌、神的牌写层数；顶端栏徽记旁的小图标超过 9 个写「+N」。
## 牌是测试里临时塞进规矩的几张（真牌在第 1~3 批）
extends RefCounted

const L := preload("res://tests/run/test_level_372.gd")

const FIXTURE := {
	"t_q_a": {"kind": "god", "god": "brute", "qual": true},
	"t_q_a_up": {"kind": "god", "god": "brute", "upgrade_of": "t_q_a"},
	"t_q_b": {"kind": "god", "god": "brute", "qual": true, "excludes": ["t_q_c"]},
	"t_q_c": {"kind": "god", "god": "brute", "qual": true, "excludes": ["t_q_b"]},
	"t_q_w": {"kind": "god", "god": "brute", "qual": true, "when": "t_cond"},
	"t_b_1": {"kind": "god", "god": "brute"},
	"t_b_2": {"kind": "god", "god": "brute", "after": "t_q_a"},
	"t_sun": {"kind": "god", "god": "sun"},
}


## 换上带测试牌的规矩（返回原来的，测完换回去）
static func _swap_rules() -> LevelRules:
	var keep := LevelRules.load_rules()
	var r := keep.duplicate(true) as LevelRules
	for k in r.cards.keys():
		if String((r.cards[k] as Dictionary).get("kind", "")) == "god":
			r.cards.erase(k)     # 真牌拿掉，只看测试牌
	for k in FIXTURE:
		r.cards[k] = (FIXTURE[k] as Dictionary).duplicate(true)
	LevelRules._rules = r
	return keep


## 开一局；[param god] 给了就奉这位神（信物放上棋盘），测试牌的 buff 塞进这一局
static func _start(seed_from: int, god: StringName = &"") -> RunState:
	var run := L._start(seed_from)
	if run == null:
		return null
	for k in FIXTURE:
		var def := RunBuffDef.new()
		def.id = StringName(k)
		def.display_name = k
		run.buff_defs[StringName(k)] = def
	if god != &"":
		run.selected_faith = god
		for id in run.items.ids():
			var d := run.items.get_def(id)
			if d.is_anchor() and FaithTags.id_of_tag(d.faith_tag()) == god:
				TestSupport.put(run.board, d)
				break
	return run


static func run_slots(t: TestCase) -> void:
	t.begin("388 · 质变位：开局一次，6 / 12 / 18 / 24 / 30 级各一次；奉神时只出这位神能出的质变牌（升级版、条件不满足的不出）")
	var keep := _swap_rules()
	var run := _start(5, &"brute")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"brute":
		t.check(false, "开局奉蛮神")
		LevelRules._rules = keep
		return
	var r := lv.rules()
	t.eq(r.qual_slots_at(1), 1, "1 级：开局那一位")
	t.eq(r.qual_slots_at(30), 6, "30 级：一共 6 位")
	t.eq(lv.pending(), 1, "开局欠一次")
	var cur := lv.current_pick()
	t.check(bool(cur["qual"]) and not bool(cur["generic"]) and int(cur["level"]) == 1, "是开局的质变位，蛮神有质变牌（%s）" % cur)
	var offer: Array = lv.offer().map(func(c: StringName) -> String: return String(c))
	offer.sort()
	t.eq(offer, ["t_q_a", "t_q_b", "t_q_c"], "只出蛮神能出的质变牌：升级版、条件没满足的不出")
	# 满足条件才入池
	lv.register_when(&"t_cond", func(_run: RunState) -> bool: return true)
	t.check(lv.eligible(&"t_q_w"), "登记的条件满足：入池")
	# 互斥：拿 b，c 不再出
	var at := lv.offer().find(&"t_q_b")
	lv.pick(at)
	t.eq(lv.qual_done, 1, "用掉一个质变位")
	t.check(not lv.eligible(&"t_q_c") and not lv.eligible(&"t_q_b"), "互斥：拿了 b，c 不出；质变牌拿过不再出")
	# 升级版：拿过原牌才出
	t.check(not lv.eligible(&"t_q_a_up"), "没拿原牌：升级版不出")
	lv.taken["t_q_a"] = 1
	t.check(lv.eligible(&"t_q_a_up") and lv.eligible(&"t_b_2"), "拿了原牌：升级版进池；「拿过某张才出」的基础牌进池")
	# 6 级：普通牌在前，质变位在后
	lv.gain(float(r.total_for(6)), LevelModule.SRC_BATTLE)
	t.eq(lv.pending(), 5 + 1, "2→6 级五次普通 + 6 级的质变位")
	# 神恩区读的
	lv.taken["t_q_a_up"] = 1
	var qs := lv.quals()
	t.eq(qs.map(func(q: Dictionary) -> StringName: return q["shown"]), [&"t_q_b", &"t_q_a_up"], "按拿的先后；升级了显示升级版")
	t.check(bool(qs[1]["upgraded"]) and not bool(qs[0]["upgraded"]), "升级过的标出来")
	run.dispose()
	LevelRules._rules = keep


static func run_pool(t: TestCase) -> void:
	t.begin("388 · 普通选牌：奉神时通用牌 + 这位神的基础牌一个池子，每一批至少一张神的；别的神的牌、质变牌都不出；无信者全是通用牌")
	var keep := _swap_rules()
	var run := _start(9, &"brute")
	var lv := LevelModule.of(run)
	if lv == null:
		t.check(false, "开局")
		LevelRules._rules = keep
		return
	var r := lv.rules()
	lv.qual_done = 1     # 开局那一次不看
	lv.gain(float(r.total_for(30)), LevelModule.SRC_BATTLE)
	var all_ok := true
	var no_other := true
	var batches := 0
	while lv.pending() > 0 and batches < 40:
		var cur := lv.current_pick()
		var offer := lv.offer()
		if not bool(cur["qual"]):
			batches += 1
			if not offer.any(func(c: StringName) -> bool: return r.god_of(c) == &"brute" and not r.is_qual(c)):
				all_ok = false
			if offer.any(func(c: StringName) -> bool: return r.god_of(c) == &"sun" or r.is_qual(c)):
				no_other = false
		lv.pick(0)
	t.check(batches >= 20, "看了 %d 批普通选牌" % batches)
	t.check(all_ok, "每一批至少一张蛮神的基础牌")
	t.check(no_other, "日神的牌、质变牌不进普通选牌")
	t.check(not lv.god_cards().is_empty(), "拿到的神的基础牌记下来（神恩区列）")
	run.dispose()
	# 无信者
	var plain := _start(9)
	var pl := LevelModule.of(plain)
	pl.gain(float(r.total_for(12)), LevelModule.SRC_BATTLE)
	var godly := false
	var generic_quals := 0
	while pl.pending() > 0:
		var cur := pl.current_pick()
		if bool(cur["qual"]) and bool(cur["generic"]):
			generic_quals += 1
		for c in pl.offer():
			if r.god_of(c) != &"":
				godly = true
		pl.pick(0)
	t.check(not godly, "无信者一张神的牌都不出")
	t.eq(generic_quals, 3, "开局、6、12 级三个质变位都改为多选一张通用牌")
	plain.dispose()
	LevelRules._rules = keep


static func run_opening_extra(t: TestCase) -> void:
	t.begin("388 · 万神院五档：开局那次质变选牌多一张（四选一，初值）；只在开局那一次；开关跟着信仰开关进局、进存档")
	var keep := _swap_rules()
	var run := _start(21, &"brute")
	var lv := LevelModule.of(run)
	run.opening_extra_choice = true
	lv.register_when(&"t_cond", func(_run: RunState) -> bool: return true)
	t.eq(lv.offer().size(), 4, "开局四张")
	lv.pick(0)
	t.check(run.to_dict()["faith_access"].get("opening_extra", false), "存档里有这个开关")
	lv.gain(float(lv.rules().total_for(6)), LevelModule.SRC_BATTLE)
	while lv.pending() > 0 and not bool(lv.current_pick()["qual"]):
		lv.offer()
		lv.pick(0)
	t.eq(lv.offer().size(), 3, "6 级的质变位照旧三张")
	run.dispose()
	LevelRules._rules = keep
	t.eq(Pantheon.full_access().get("opening_extra", true), false, "不受限制的开关：没有多一张")


static func frame_favor(t: TestCase, root: Window) -> void:
	t.begin("388 · 神恩区：奉神时状态界面加一栏、窗跟着加宽；质变牌按先后、升级的标「+」、神的牌写层数；无信者不出现。顶端栏小图标超过 9 个写 +N")
	var keep := _swap_rules()
	var run := _start(23, &"brute")
	var lv := LevelModule.of(run)
	lv.taken["t_q_a"] = 1
	lv.taken["t_q_a_up"] = 1
	lv.taken["t_q_b"] = 1
	lv.taken["t_b_1"] = 3
	var host := Control.new()
	host.size = Vector2(1600, 1000)
	root.add_child(host)
	var win := BagWindow.new()
	host.add_child(win)
	win.setup_bag(run, UiPalette.cjk_font(), func(): pass)
	t.check(win.favor.visible, "奉神：有神恩栏")
	t.eq(win.favor.slot_ids(), [&"t_q_a_up", &"t_q_b", &"t_b_1"] as Array[StringName], "质变两张（升级的显示升级版）+ 神的牌一张")
	t.check(win.favor.tip_text(2).contains("×3"), "神的牌悬浮窗写层数：%s" % win.favor.tip_text(2))
	var wide := win.window_size().x
	t.check(win.favor.position.x > win.card.position.x + win.card.size.x and win.favor.position.x + FavorPanel.W <= wide, "神恩栏在角色卡右边、在窗里")
	t.check(win.close_button.position.x + win.close_button.size.x <= wide, "收起键跟着挪到加宽后的右上")
	host.queue_free()
	run.dispose()
	var plain := _start(23)
	var host2 := Control.new()
	host2.size = Vector2(1600, 1000)
	root.add_child(host2)
	var win2 := BagWindow.new()
	host2.add_child(win2)
	win2.setup_bag(plain, UiPalette.cjk_font(), func(): pass)
	t.check(not win2.favor.visible, "无信者：没有神恩栏")
	t.check(win2.window_size().x < wide, "窗不加宽（%.0f < %.0f）" % [win2.window_size().x, wide])
	host2.queue_free()
	plain.dispose()
	# 顶端栏
	var run3 := _start(25, &"brute")
	var lv3 := LevelModule.of(run3)
	for i in 11:
		var id := "t_fill_%d" % i
		lv3.rules().cards[id] = {"kind": "god", "god": "brute", "qual": true}
		lv3.taken[id] = 1
	var w: HudWidget = HudWidgets.create(&"faith")
	root.add_child(w)
	w.setup(run3, null)
	t.eq((w.call("favor_ids") as Array).size(), 11, "十一张质变牌")
	t.eq(w.call("favor_more_text"), "+2", "画 9 个，最后写 +2")
	w.queue_free()
	run3.dispose()
	LevelRules._rules = keep


static func run_vitality_card_empty(t: TestCase) -> void:
	t.begin("388 / 作者 11-24 · 通用牌【耐行】加的是一个空的体力容器：上限 +1，当前体力不跟着涨")
	var run := L._start(31)
	var lv := LevelModule.of(run)
	if lv == null or run.vitality == null or not lv.rules().cards.has("card_vitality"):
		t.check(false, "开局、有体力、有耐行")
		return
	var cur := run.vitality.current
	var mx := run.vitality.maximum
	lv.qual_done = lv.rules().qual_slots_at(1)
	lv.gain(float(lv.rules().total_for(2)), LevelModule.SRC_BATTLE)
	lv.offer_ids = ["card_vitality"] as Array[String]
	lv.offer_qual = false
	lv.pick(0)
	t.eq(run.vitality.maximum, mx + 1, "上限 +1")
	t.eq(run.vitality.current, cur, "当前体力没涨")
	run.dispose()


static func run_tutorial_no_opening(t: TestCase) -> void:
	t.begin("388 · 教程章节关掉开局那次质变选牌（章节开关，架构设计初值）；6 级的质变位照旧")
	var run := L._start(33)
	var lv := LevelModule.of(run)
	if lv == null or run.chapter == null:
		t.check(false, "开局")
		return
	t.eq(lv.pending(), 1, "平常的章节：开局欠一次")
	var ch := run.chapter.duplicate() as ChapterDef
	ch.opening_qual_pick = false
	run.chapter = ch
	t.eq(lv.pending(), 0, "关掉开局选牌：开局不欠")
	lv.gain(float(lv.rules().total_for(6)), LevelModule.SRC_BATTLE)
	t.eq(lv.pending(), 5 + 1, "到 6 级：五次普通 + 6 级的质变位")
	var seen_qual := 0
	while lv.pending() > 0:
		if bool(lv.current_pick()["qual"]):
			seen_qual += 1
			t.eq(int(lv.current_pick()["level"]), 6, "质变位是 6 级的")
		lv.offer()
		lv.pick(0)
	t.eq(seen_qual, 1, "只有 6 级那一次质变")
	for id in [&"prologue", &"prologue_2"]:
		var path := ContentPaths.asset_file("chapters", String(id))
		var c := load(path) as ChapterDef if ResourceLoader.exists(path) else null
		t.check(c != null and not c.opening_qual_pick, "%s 关了开局选牌" % id)
	run.dispose()


static func run_brute_cards(t: TestCase) -> void:
	t.begin("388 第 1 批 · 蛮神的牌：31 张进牌池（10 质变 + 10 升级 + 11 基础）、拿了几张就把数填进怒气；死斗编进不屈；神罚按牌给次数、升级后精英耗 2 次")
	var run := _start(41, &"brute")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"brute":
		t.check(false, "开局奉蛮神")
		return
	var r := lv.rules()
	var quals := 0
	var bases := 0
	for cid in r.card_ids():
		if r.god_of(cid) == &"brute":
			if r.is_qual(cid):
				quals += 1
			else:
				bases += 1
	t.eq(quals, 20, "质变 10 张 + 升级 10 张（啖肉吮血第 1 批补）")
	t.eq(bases, 11, "基础牌 11 张")
	t.check(lv.card_text(&"god_brute_break").contains("2%"), "牌面按数写：%s" % lv.card_text(&"god_brute_break"))
	var perk := BruteRagePerk.new()
	var bare := perk.effect_for(lv)
	t.eq(bare.cap, 30, "没拿牌：30 层")
	lv.taken["god_brute_cap"] = 2
	lv.taken["god_brute_damage"] = 2
	lv.taken["god_brute_regen"] = 1
	lv.taken["god_brute_break"] = 1
	lv.taken["god_brute_break_up"] = 1
	lv.taken["god_brute_pain"] = 1
	var e := perk.effect_for(lv)
	t.eq(e.cap, 50, "怒气磅礴两张：50 层")
	t.check(is_equal_approx(e.damage_per, 3.0), "气血上涌两张：每层 3%")
	t.check(is_equal_approx(e.regen_per, 0.2), "不灭：每 5 层 1 点 = 每层 0.2")
	var regen_card := LevelModule.god_card_of(lv.card_def(&"god_brute_regen"))
	t.check(regen_card != null and regen_card.values.has("step") and float(regen_card.values["step"]) == 0.0, "不灭的开关 step 默认关（按层平摊）")
	if regen_card != null:
		regen_card.values["step"] = 1
		var stepped := perk.effect_for(lv)
		t.check(stepped.regen_step == 5 and is_equal_approx(stepped.regen_step_amount, 1.0) and stepped.regen_per == 0.0, "开：每满 5 层才 +1")
		regen_card.values["step"] = 0
	for pair in [["god_brute_break_up", "block"], ["god_brute_hate_up", "halving"]]:
		var c := LevelModule.god_card_of(lv.card_def(StringName(pair[0])))
		t.check(c != null and float(c.values.get(pair[1], -1)) == 0.0, "%s 的开关 %s 默认关" % pair)
	t.check(is_equal_approx(e.armor_per, 3.0) and is_equal_approx(e.ignore_per, 2.0), "破甲拿了升级：3% 且无视 2%")
	t.eq(e.defer_percent, 50, "痛觉残留 50%")
	t.eq(BruteRagePerk.undying_sec(lv), 0.0, "没拿死斗：不屈 0 秒")
	lv.taken["god_brute_deathfight"] = 1
	lv.taken["god_brute_undying"] = 2
	t.check(is_equal_approx(BruteRagePerk.undying_sec(lv), 4.0), "死斗 3 + 不屈 0.5×2 = 4 秒")
	# 神罚
	var smite := SmitePerk.new()
	smite.card = &"god_brute_smite"
	smite.up_card = &"god_brute_smite_up"
	smite.more_card = &"god_brute_smite_more"
	t.eq(smite.prebattle_actions(run, &"battle").size(), 0, "没拿神罚：战前没有按钮")
	lv.taken["god_brute_smite"] = 1
	t.eq(smite.uses_total(run), 2, "神罚一局 2 次")
	t.eq(smite.prebattle_actions(run, &"battle").size(), 1, "普通敌人有按钮")
	t.eq(smite.prebattle_actions(run, &"elite").size(), 0, "没升级：精英没有")
	lv.taken["god_brute_smite_up"] = 1
	lv.taken["god_brute_smite_more"] = 1
	t.eq(smite.uses_total(run), 5, "升级 +2、再现 +1：5 次")
	t.eq(smite.cost_for(run, &"elite"), 2, "升级后精英耗 2 次")
	t.eq(smite.cost_for(run, &"boss"), 0, "首领不行")
	lv.god_state[SmitePerk.USED_KEY] = 4
	t.eq(String(smite.prebattle_actions(run, &"elite")[0]["why"]) != "", true, "只剩 1 次：精英灰着")
	t.eq(lv.to_dict()["god_state"].get(SmitePerk.USED_KEY, 0), 4, "用掉几次进存档")
	# 啖肉吮血：【血肉】吃下去，按稀有度和格子给整局生命上限；升级再给一半的耐力上限（以前吃的也补）
	var flesh := ItemInstance.create(run.items.get_def(&"blood_flesh"))
	t.check(run.board.try_add(flesh), "背包里放一块血肉")
	t.check(not BruteRagePerk.can_eat(run, flesh), "没拿啖肉吮血：不能吃（只是普通兽材）")
	var hp0 := float(run.effective_baseline().base_stats.get(&"max_hp", 0.0))
	var st0 := float(run.effective_baseline().base_stats.get(&"max_stamina", 0.0))
	lv.taken["god_brute_eat"] = 1
	t.check(BruteRagePerk.can_eat(run, flesh), "拿了：能吃")
	var ate := BruteRagePerk.eat(run, flesh)
	t.check(is_equal_approx(float(ate.get("hp", 0.0)), 20.0), "血肉（稀有度 1、2 格）：5 × 2 × 2 = 20（%s）" % str(ate))
	t.eq(run.board.get_item(flesh.uid), null, "吃掉了：背包里没了")
	t.check(is_equal_approx(float(run.effective_baseline().base_stats.get(&"max_hp", 0.0)), hp0 + 20.0), "生命上限 +20")
	t.check(is_equal_approx(float(run.effective_baseline().base_stats.get(&"max_stamina", 0.0)), st0), "没升级：耐力上限不变")
	lv.taken["god_brute_eat_up"] = 1
	t.check(is_equal_approx(float(run.effective_baseline().base_stats.get(&"max_stamina", 0.0)), st0 + 10.0), "升级：以前吃的补一半耐力上限 +10")
	var scrap := ItemInstance.create(run.items.get_def(&"blood_flesh_scrap"))
	run.board.try_add(scrap)
	var ate2 := BruteRagePerk.eat(run, scrap)
	t.check(is_equal_approx(float(ate2.get("hp", 0.0)), 5.0) and is_equal_approx(float(ate2.get("stamina", 0.0)), 2.5), "碎血肉：生命 +5、耐力 +2.5")
	var back := LevelModule.new()
	back.restore(lv.to_dict())
	t.check(is_equal_approx(float(back.god_state.get(BruteRagePerk.FLESH_KEY, 0.0)), 25.0), "吃下的进存档")
	run.dispose()


static func run_sun_cards(t: TestCase) -> void:
	t.begin("388 第 2 批 · 日神的牌：39 张进牌池；日长夜短 / 长夜促昼每张挪基础时长 20%、第五张把一边减到 0 才出永恒；永恒拿了下一张质变必是升级、拿掉日长夜短；升级独占；按牌填进日月")
	var run := _start(51, &"sun")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"sun":
		t.check(false, "开局奉日神")
		return
	var r := lv.rules()
	var quals := 0
	var bases := 0
	for cid in r.card_ids():
		if r.god_of(cid) == &"sun":
			if r.is_qual(cid):
				quals += 1
			else:
				bases += 1
	t.eq(quals, 28, "质变 14 张 + 升级 14 张")
	t.eq(bases, 11, "基础牌 11 张")
	var perk := SunCyclePerk.new()
	t.eq(SunCyclePerk.durations(lv, perk), Vector2(6.0, 6.0), "没拿牌：各 6 秒")
	lv.taken["god_sun_longday"] = 2
	t.check(SunCyclePerk.durations(lv, perk).is_equal_approx(Vector2(8.4, 3.6)), "日长夜短两张：白昼 8.4、黑夜 3.6（%s）" % SunCyclePerk.durations(lv, perk))
	t.check(not lv.eligible(&"god_sun_eternal_day"), "黑夜还没到 0：永日不出")
	lv.taken["god_sun_longday"] = 5
	t.eq(SunCyclePerk.durations(lv, perk).y, 0.0, "第五张：黑夜 0 秒")
	t.check(GodWhen.met(&"sun_night_zero", lv), "条件满足")
	lv.taken["god_sun_faster"] = 1
	t.check(is_equal_approx(SunCyclePerk.durations(lv, perk).x, 9.6), "更迭：白昼 12 × 0.8 = 9.6，黑夜照旧 0")
	lv.taken.erase("god_sun_faster")
	lv.taken["god_sun_eternal_day"] = 1
	t.eq(lv.forced_next(), &"god_sun_eternal_day_up", "永日：下一张质变必是它的升级")
	t.check(not lv.eligible(&"god_sun_longday"), "永日拿掉日长夜短")
	var e := perk.effect_for(lv)
	t.check(is_equal_approx(e.eternal_day, 100.0) and e.eternal_day_scorch == 5, "永日的数填进去")
	lv.taken["god_sun_sunbath"] = 1
	t.eq(perk.effect_for(lv).sun_light, 1, "日光浴：每秒 1 层")
	lv.taken["god_sun_eternal_day_up"] = 1
	t.eq(lv.solo_card(), &"god_sun_eternal_day_up", "永日升级独占")
	t.check(not lv.has_card(&"god_sun_sunbath") and lv.has_card(&"god_sun_eternal_day"), "独占：别的质变不再生效，永日本身照算")
	t.eq(perk.effect_for(lv).sun_light, 0, "日光浴不填了")
	t.check(not lv.eligible(&"god_sun_dusk"), "独占：别的质变不再出")
	lv.taken["god_sun_veil"] = 2
	t.check(is_equal_approx(perk.effect_for(lv).veil, (1.0 - 0.92 * 0.92) * 100.0), "夜幕两张：连乘")
	t.check(lv.card_text(&"god_sun_veil").contains("8"), "牌面按数写：%s" % lv.card_text(&"god_sun_veil"))
	run.dispose()


static func run_miracle(t: TestCase) -> void:
	t.begin("388 第 2 批 · 奇迹：拿到那一刻，背包里随机一件材料换成同类、高一档稀有度的")
	var run := _start(53, &"sun")
	var lv := LevelModule.of(run)
	if lv == null:
		t.check(false, "开局")
		return
	var pick: ItemDef = null
	for id in run.items.ids():
		var d := run.items.get_def(id)
		if Miracle._ok(d) and d.rarity == 0 and d.cell_count() <= 2:
			pick = d
			break
	if pick == null:
		t.check(false, "找得到一件 0 档材料")
		run.dispose()
		return
	var keep := run.board.items().size()
	t.check(run.board.try_add(ItemInstance.create(pick)), "放一件 %s" % pick.id)
	var got := Miracle.apply(run)
	t.check(not got.is_empty(), "换了一件：%s" % str(got))
	if not got.is_empty():
		var from := run.items.get_def(StringName(got["from"]))
		var to := run.items.get_def(StringName(got["to"]))
		t.eq(to.rarity, from.rarity + 1, "稀有度 +1")
		t.eq(Miracle.class_of(to), Miracle.class_of(from), "同类")
		t.eq(run.board.items().size(), keep + 1, "件数不变")
		t.check(run.board.items().any(func(x): return (x as ItemInstance).def.id == to.id), "新的一件在背包里")
	run.dispose()
