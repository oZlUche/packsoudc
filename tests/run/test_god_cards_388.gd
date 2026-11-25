## 388 第 0 批：质变牌框架 —— 开局一次 + 6 / 12 / … 级质变位；奉神时质变位只出这位神的质变牌，普通选牌通用 + 神的基础牌一个池子、保底一张神的；
## 四种出牌条件（拿过某张才出、互斥、满足条件才入池、升级版）；无信者 / 没写牌的神质变位改为多选一张通用牌；万神院五档开局多一张；
## 神恩区按拿的先后列质变牌、神的牌写层数；顶端栏徽记旁的小图标超过 9 个写「+N」。
## 牌是测试里临时塞进规矩的几张（真牌在第 1~3 批）
extends RefCounted

const L := preload("res://tests/run/test_level_372.gd")
const FX := preload("res://tests/battle/test_effect_system.gd")

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
	t.begin("388 第 1 批 · 蛮神的牌：32 张进牌池（11 质变 + 10 升级 + 11 基础，396 改）、拿了几张就把数填进怒气；死斗编进不屈；神罚按牌给次数、升级后精英耗 2 次")
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
	t.eq(quals, 21, "质变 11 张 + 升级 10 张（396：怒意延绵没有升级）")
	t.eq(bases, 11, "基础牌 11 张（396：怒气磅礴删掉、加献祭）")
	t.check(lv.card_text(&"god_brute_break").contains("2%"), "牌面按数写：%s" % lv.card_text(&"god_brute_break"))
	var perk := BruteRagePerk.new()
	var bare := perk.effect_for(lv)
	t.eq(bare.cap, 0, "396：核心不封顶")
	t.check(is_equal_approx(bare.damage_per, 0.0), "396：怒气本身不加伤害")
	lv.taken["god_brute_damage"] = 2
	lv.taken["god_brute_regen"] = 1
	lv.taken["god_brute_break"] = 1
	lv.taken["god_brute_break_up"] = 1
	lv.taken["god_brute_pain"] = 1
	lv.taken["god_brute_duration"] = 2
	var e := perk.effect_for(lv)
	t.check(is_equal_approx(e.damage_per, 3.0), "急躁两张 0.5×2 + 破甲升级每层 2%% = 每层 3%%（%s）" % e.damage_per)
	t.check(is_equal_approx(e.armor_per, 4.0), "破甲升级：对护甲增效 4%")
	t.check(is_equal_approx(e.duration_sec, 5.0), "记仇两张：4 + 0.5×2 = 5 秒")
	t.check(is_equal_approx(e.regen_per, 0.1), "不灭：每 10 层 1 点 = 每层 0.1")
	var regen_card := LevelModule.god_card_of(lv.card_def(&"god_brute_regen"))
	t.check(regen_card != null and regen_card.values.has("step") and float(regen_card.values["step"]) == 0.0, "不灭的开关 step 默认关（按层平摊）")
	if regen_card != null:
		regen_card.values["step"] = 1
		var stepped := perk.effect_for(lv)
		t.check(stepped.regen_step == 10 and is_equal_approx(stepped.regen_step_amount, 1.0) and stepped.regen_per == 0.0, "开：每满 10 层才 +1")
		regen_card.values["step"] = 0
	var hate_up := LevelModule.god_card_of(lv.card_def(&"god_brute_hate_up"))
	t.check(hate_up != null and float(hate_up.values.get("halving", -1)) == 0.0, "恨意升级的开关 halving 默认关")
	lv.taken["god_brute_cornered"] = 1
	t.check(is_equal_approx(perk.effect_for(lv).cornered_per, 0.5), "困兽：每失去 1% 生命 +0.5%")
	lv.taken["god_brute_cornered_more"] = 2
	t.check(is_equal_approx(perk.effect_for(lv).cornered_per, 0.75), "困兽犹斗两张（加算 +25%×2）：0.75%")
	lv.taken["god_brute_cornered_up"] = 1
	t.check(is_equal_approx(perk.effect_for(lv).cornered_per, 1.5), "困兽升级 1% × 1.5 = 1.5%")
	lv.taken["god_brute_persist"] = 1
	var p := perk.effect_for(lv)
	t.check(is_equal_approx(p.duration_sec, 2.5) and p.refresh_on_hit, "怒意延绵：5 秒减半 2.5 秒，受伤重置")
	t.eq(lv.rules().card(&"god_brute_cap"), {}, "怒气磅礴删掉了")
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
	var flesh := ItemInstance.create(run.items.get_def(&"eel_cut"))
	t.check(run.board.try_add(flesh), "背包里放一段鳗段（带【血肉】）")
	t.check(not BruteRagePerk.can_eat(run, flesh), "没拿啖肉吮血：不能吃（只是普通兽材）")
	var hp0 := float(run.effective_baseline().base_stats.get(&"max_hp", 0.0))
	var st0 := float(run.effective_baseline().base_stats.get(&"max_stamina", 0.0))
	lv.taken["god_brute_eat"] = 1
	t.check(BruteRagePerk.can_eat(run, flesh), "拿了：能吃")
	var ate := BruteRagePerk.eat(run, flesh)
	t.check(is_equal_approx(float(ate.get("hp", 0.0)), 32.0), "鳗段（稀有度 1、2 格）：8 × 2 × 2 = 32（%s）" % str(ate))
	t.eq(run.board.get_item(flesh.uid), null, "吃掉了：背包里没了")
	t.check(is_equal_approx(float(run.effective_baseline().base_stats.get(&"max_hp", 0.0)), hp0 + 32.0), "生命上限 +32")
	t.check(is_equal_approx(float(run.effective_baseline().base_stats.get(&"max_stamina", 0.0)), st0), "没升级：耐力上限不变")
	var row := CharacterCard.stat_row(run, &"max_hp")
	t.check(is_equal_approx(float(row.get("raw", 0.0)), float(run.effective_baseline().base_stats.get(&"max_hp", 0.0))), "状态界面的生命上限也算上血肉（%s）" % str(row.get("raw", 0.0)))
	lv.taken["god_brute_eat_up"] = 1
	t.check(is_equal_approx(float(run.effective_baseline().base_stats.get(&"max_stamina", 0.0)), st0 + 16.0), "升级：以前吃的补一半耐力上限 +16")
	var scrap := ItemInstance.create(run.items.get_def(&"toad_leg"))
	run.board.try_add(scrap)
	var ate2 := BruteRagePerk.eat(run, scrap)
	t.check(is_equal_approx(float(ate2.get("hp", 0.0)), 8.0) and is_equal_approx(float(ate2.get("stamina", 0.0)), 4.0), "蟾腿：生命 +8、耐力 +4")
	var back := LevelModule.new()
	back.restore(lv.to_dict())
	t.check(is_equal_approx(float(back.god_state.get(BruteRagePerk.FLESH_KEY, 0.0)), 40.0), "吃下的进存档")
	run.dispose()


static func run_brute_sacrifice(t: TestCase) -> void:
	t.begin("396 · 蛮神【献祭】：剩余体力大于 2 且还有质变牌可选才进池；拿了扣 2 点体力、紧接着多一次质变选牌（不占 6 / 12 级的质变位）；可以反复拿")
	var run := _start(43, &"brute")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"brute" or run.vitality == null:
		t.check(false, "开局奉蛮神")
		return
	var id := BruteRagePerk.SACRIFICE
	run.vitality.set_max(10, &"test")
	run.vitality.current = 2
	t.check(not lv.eligible(id), "体力 2：不进池")
	run.vitality.current = 5
	t.check(lv.eligible(id), "体力 5、质变牌还有：进池")
	var before := lv.pending()
	var quals_before := lv.qual_done
	lv.taken[String(id)] = 1
	lv._apply_now(id)
	t.eq(run.vitality.current, 3, "扣 2 点体力")
	t.eq(lv.sacrifice_due(), 1, "欠一次质变")
	t.eq(lv.pending(), before + 1, "多欠一次选牌")
	var cur := lv.current_pick()
	t.check(bool(cur.get("qual", false)) and int(cur.get("level", 0)) == lv.level(), "下一张就是质变，写当前等级（%s）" % str(cur))
	var offer := lv.offer()
	t.check(not offer.is_empty() and lv.rules().is_qual(offer[0]), "摆出来的是质变牌")
	lv.pick(0)
	t.eq(lv.sacrifice_due(), 0, "选完：不欠了")
	t.eq(lv.qual_done, quals_before, "不占原来的质变位")
	t.check(lv.eligible(id), "体力 3、还能再拿")
	var back := LevelModule.new()
	back.restore(lv.to_dict())
	t.eq(back.god_state.get(LevelModule.SACRIFICE_DUE, 0), 0, "进存档")
	t.check(lv.card_text(id).contains("2"), "牌面：%s" % lv.card_text(id))
	run.dispose()


static func run_convert_faith(t: TestCase) -> void:
	t.begin("396 第五节 · 改信：拿掉旧神的质变（升级版也还一次，作者 11-26 选 A；献祭欠的也算）和基础牌，清掉旧神的整局累积；按原张数重选，质变先、基础牌后，基础牌只出新神的；等级、通用牌不动")
	var run := _start(47, &"brute")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"brute":
		t.check(false, "开局奉蛮神")
		return
	lv.gain(float(lv.rules().total_for(4)), LevelModule.SRC_BATTLE)
	while lv.pending() > 0:
		lv.offer()
		lv.pick(0)
	var lvl := lv.level()
	lv.taken.clear()
	lv.taken["god_brute_break"] = 1
	lv.taken["god_brute_break_up"] = 1
	lv.taken["god_brute_cornered"] = 1
	lv.taken["god_brute_damage"] = 2
	lv.taken["god_brute_regen"] = 1
	lv.taken["card_rest"] = 1
	lv.god_state[BruteRagePerk.FLESH_KEY] = 40.0
	lv.god_state[LevelModule.SACRIFICE_DUE] = 1
	t.eq(lv.pending(), 1, "献祭欠着一次质变")
	run.selected_faith = &"sun"
	for id in run.items.ids():
		var d := run.items.get_def(id)
		if d.is_anchor() and FaithTags.id_of_tag(d.faith_tag()) == &"sun":
			TestSupport.put(run.board, d)
			break
	lv.convert_faith(&"brute", &"sun")
	t.eq(lv.count_of(&"god_brute_break") + lv.count_of(&"god_brute_damage") + lv.count_of(&"god_brute_regen"), 0, "旧神的牌都拿掉了")
	t.eq(lv.count_of(&"card_rest"), 1, "通用牌留着")
	t.eq(lv.god_state.get(BruteRagePerk.FLESH_KEY, 0.0), 0.0, "吃血肉攒的清掉")
	t.eq(lv.level(), lvl, "等级不变")
	t.eq(lv.pending(), 7, "重选 4 次质变（破甲 1、它的升级 1、困兽 1、献祭欠的 1）+ 3 次基础牌")
	if run.active_faith_id() != &"sun":
		t.check(false, "换成日神（%s）" % run.active_faith_id())
		run.dispose()
		return
	var quals := 0
	var bases := 0
	var order_ok := true
	var seen_base := false
	while lv.pending() > 0:
		var cur := lv.current_pick()
		t.check(bool(cur.get("convert", false)), "重选那几次带 convert")
		var cards := lv.offer()
		var qual := bool(cur.get("qual", false))
		if qual:
			quals += 1
			order_ok = order_ok and not seen_base
		else:
			bases += 1
			seen_base = true
			t.check(cards.all(func(c: StringName) -> bool: return lv.rules().god_of(c) == &"sun" and not lv.rules().is_qual(c)), "基础牌只出日神的：%s" % str(cards))
		if qual:
			t.check(cards.all(func(c: StringName) -> bool: return lv.rules().god_of(c) == &"sun" and lv.rules().is_qual(c)), "质变出日神的：%s" % str(cards))
		lv.pick(0)
	t.eq([quals, bases], [4, 3], "质变 4 次、基础牌 3 次")
	t.check(order_ok, "质变先选完再选基础牌")
	var back := LevelModule.new()
	back.restore(lv.to_dict())
	t.eq(back.repicks_left(), 0, "进存档：不欠了")
	run.dispose()


static func run_skill_cards(t: TestCase) -> void:
	t.begin("396 第 B 批 · 技巧之神的牌：31 张进牌池（11 质变 + 11 升级 + 9 基础），拿了几张就把数填进连击；背包里没武器有【拳头】；一气呵成留层数到下一场；万神院先不开放")
	var run := _start(53, &"skill")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"skill":
		t.check(false, "开局奉技巧之神")
		return
	var r := lv.rules()
	var quals := 0
	var bases := 0
	for cid in r.card_ids():
		if r.god_of(cid) == &"skill":
			if r.is_qual(cid):
				quals += 1
			else:
				bases += 1
	t.eq(quals, 22, "质变 11 张 + 升级 11 张")
	t.eq(bases, 9, "基础牌 9 张")
	t.check(lv.has_qual_pool(), "开局质变位出技巧之神的牌")
	t.check(Pantheon.temple_ready(&"skill"), "万神院：技巧之神的神殿可以解锁")
	t.check(Pantheon.temple_ready(&"brute"), "蛮神照常")
	var perk := SkillMomentumPerk.new()
	t.check(is_equal_approx(perk.effect_for(lv).haste_per, 1.0), "核心每层急速 1%")
	lv.taken["god_skill_ready"] = 2
	lv.taken["god_skill_steady"] = 1
	lv.taken["god_skill_gap"] = 1
	lv.taken["god_skill_gap_up"] = 1
	lv.taken["god_skill_edge"] = 1
	lv.taken["god_skill_edge_up"] = 1
	lv.taken["god_skill_poise"] = 2
	var e := perk.effect_for(lv)
	t.eq([e.opening, e.keep_on_reset, e.gap_every], [6, 2, 4], "预备两张 6 层、稳手留 2 层、寻隙升级每 4 层")
	t.check(is_equal_approx(e.gap_pct, 50.0) and is_equal_approx(e.edge_crit, 0.7) and is_equal_approx(e.edge_crit_damage, 1.0), "寻隙升级 +50%、锋芒升级暴击率 0.7% 暴击伤害 1%")
	t.check(is_equal_approx(e.poise_sec, 3.0) and is_equal_approx(e.poise_pct, 10.0), "蓄势两张：每 3 秒 +10%")
	t.check(lv.card_text(&"god_skill_press").contains("15"), "牌面按数写：%s" % lv.card_text(&"god_skill_press"))
	# 徒手大师：背包里没有武器才有拳头
	lv.taken["god_skill_fist"] = 1
	for raw in run.board.items():
		var inst := raw as ItemInstance
		if inst.def.has_tag(&"weapon"):
			run.board.remove(inst.uid)
	var bare := run.compile_player()
	var fists := bare.items.filter(func(it: CompiledItem) -> bool: return it.def_id == SkillMomentumPerk.FIST_ID)
	t.eq(fists.size(), 1, "没武器：有一只拳头")
	if fists.size() == 1:
		t.check(is_equal_approx(StatMath.to_float(bare.stats_of((fists[0] as CompiledItem).source_uid).total_of(BattleStats.DAMAGE)), 5.0), "拳头伤害 5")
		var fight := BattleSim.run(bare, FX._spec(5000.0, []), RandomNumberGenerator.new(), 5.0)
		var punches := 0
		for raw in fight.log:
			var ev := raw as BattleEvent
			if ev.name == BattleEvent.ITEM_FIRED and ev.side == 0 and ev.get_int(&"uid") == (fists[0] as CompiledItem).source_uid:
				punches += 1
		t.check(punches >= 3, "拳头每秒打一下（5 秒 %d 下）" % punches)
	t.check(TestSupport.put(run.board, run.items.get_def(&"knife")) != null, "放一把小刀")
	t.eq(run.compile_player().items.filter(func(it: CompiledItem) -> bool: return it.def_id == SkillMomentumPerk.FIST_ID).size(), 0, "放回一件武器：拳头没了")
	# 一气呵成：打完记下最后几层的 33%
	lv.taken["god_skill_carry"] = 1
	var res := BattleResult.new()
	res.log = [BattleEvent.make(BattleEvent.STATUS_STACKED, 100, 0, {"buff": "skill_momentum", "stacks": 30, "delta": 1})]
	SkillMomentumPerk.after_battle(lv, res)
	t.eq(lv.god_state.get(SkillMomentumPerk.CARRY_KEY, 0), 9, "30 层留 33%：9 层")
	t.eq(perk.effect_for(lv).carry_in, 9, "下一场开战给 9 层")
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
	lv.taken["god_sun_rise"] = 1
	var risen := perk.effect_for(lv)
	t.check(is_equal_approx(risen.sunrise, 90.0) and is_equal_approx(risen.sunrise_stamina, 50.0), "日出当作：生命 90、耐力 50（报告 390 的倍数）")
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


static func run_nature_cards(t: TestCase) -> void:
	t.begin("388 第 3 批 A · 自然之神战斗里的牌：进牌池、按牌填进枯萎 / 新生；战后生长、丰饶升级攒进整局生命上限；食补按格子加上限")
	var run := _start(61, &"nature")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"nature":
		t.check(false, "开局奉自然之神")
		return
	var r := lv.rules()
	var quals := 0
	var bases := 0
	var hidden := 0
	for cid in r.card_ids():
		if r.god_of(cid) == &"nature":
			if bool(r.card(cid).get("hidden", false)):
				hidden += 1
			elif r.is_qual(cid):
				quals += 1
			else:
				bases += 1
	t.eq(quals, 23, "12 张质变 + 11 张升级（初种没有升级，靠新生进化）")
	t.eq(bases, 10, "基础牌 10 张")
	t.eq(hidden, 5, "不进池的 5 张：幼芽、新蕊、硕果、继续培育、采摘")
	var perk := NatureCyclePerk.new()
	t.eq(perk.effect_for(lv).decay_percent, 0.0, "没拿凋零")
	lv.taken["god_nature_decay"] = 1
	lv.taken["god_nature_reap"] = 1
	lv.taken["god_nature_poison"] = 2
	var e := perk.effect_for(lv)
	t.check(is_equal_approx(e.decay_percent, 33.0), "凋零 33%")
	t.check(is_equal_approx(e.harvest_at, 10.0) and is_equal_approx(e.harvest_percent, 50.0), "收割：第 10 秒、50%（作者定 10 秒）")
	t.eq(e.poison, 2, "毒气两张：每次 2 层")
	# 战后：生长按新生、丰饶升级按丰饶
	lv.taken["god_nature_grow"] = 1
	lv.taken["god_nature_bounty"] = 1
	lv.taken["god_nature_bounty_up"] = 1
	var res := BattleResult.new()
	res.final = {"sides": [{"buffs": {String(NatureCycle.RENEWAL): 100, String(NatureCycle.BOUNTY): 40}}, {"buffs": {}}]}
	var hp0 := float(run.effective_baseline().base_stats.get(&"max_hp", 0.0))
	t.check(is_equal_approx(NatureCyclePerk.settle(lv, res), 30.0), "新生 100 × 10% + 丰饶 40 × 50% = 30")
	t.check(is_equal_approx(float(run.effective_baseline().base_stats.get(&"max_hp", 0.0)), hp0 + 30.0), "整局生命上限 +30")
	# 食补：棋盘上每格食物 / 食材
	lv.taken["god_nature_food"] = 1
	var cells := NatureCyclePerk.cells_of(run.board, [&"food", &"ingredient"])
	var input := CompileInput.of(run.effective_baseline())
	perk.compile_into(input, run.board, run)
	var add := 0.0
	for m in input.baseline_mods:
		if (m as StatModifier).stat == BattleStats.MAX_HP:
			add += (m as StatModifier).amount
	t.check(is_equal_approx(add, 3.5 * cells), "食补：%d 格 × 3.5 = %.1f" % [cells, add])
	t.check(lv.card_text(&"god_nature_strong").contains("4"), "强壮：负重 +4（%s）" % lv.card_text(&"god_nature_strong"))
	run.dispose()


static func _renewal_log(n: int) -> BattleResult:
	var res := BattleResult.new()
	res.final = {"sides": [{"buffs": {}}, {"buffs": {}}]}
	res.log.append(BattleEvent.make(BattleEvent.STATUS_STACKED, 0, 0, {"buff": NatureCycle.RENEWAL, "delta": n}))
	return res


static func run_nature_run(t: TestCase) -> void:
	t.begin("388 第 3 批 B · 自然之神局内的牌：枯荣攒标准轴、亲近自然、坚韧、药材 / 食材感知、培育、收获、初种进化与采摘、育种、药补算药材")
	var run := _start(62, &"nature")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"nature":
		t.check(false, "开局奉自然之神")
		return
	var perk := NatureCyclePerk.new()
	# 枯荣：敌人 400 层枯萎 × 10% = 40 点，每 20 点一层 → 2 层
	lv.taken["god_nature_wane"] = 1
	var res := BattleResult.new()
	res.final = {"sides": [{"buffs": {}}, {"buffs": {String(NatureCycle.WITHER): 400}}]}
	NatureCyclePerk.settle(lv, res)
	var axes: Dictionary = lv.god_state.get(NatureCyclePerk.AXES_KEY, {})
	var total := 0
	for k in axes:
		total += absi(int(axes[k]))
		t.check(int(axes[k]) * int(NatureCyclePerk.BENEFIT[StringName(k)]) > 0, "%s 是对自己有利的方向" % k)
	t.eq(total, 2, "枯荣：400 × 10% ÷ 20 = 2 层")
	res.final = {"sides": [{"buffs": {}}, {"buffs": {String(NatureCycle.WITHER): 30}}]}
	NatureCyclePerk.settle(lv, res)
	total = 0
	for k in lv.god_state[NatureCyclePerk.AXES_KEY]:
		total += absi(int(lv.god_state[NatureCyclePerk.AXES_KEY][k]))
	t.eq(total, 3, "不足 20 点也给 1 层")
	var input := CompileInput.of(run.effective_baseline())
	perk.compile_into(input, run.board, run)
	var shifted := 0
	for k in input.axes:
		shifted += absi(int(input.axes[k]))
	t.check(shifted >= 3, "开战就带着这几层（%d）" % shifted)
	# 亲近自然：第一次进非战斗的点，下一场 +35，打完清掉
	lv.taken["god_nature_near"] = 1
	var shop := MapNode.new()
	shop.type = &"shop"
	t.check(perk.on_node_entered(run, shop, true) != "", "进商店：记一笔")
	t.eq(perk.on_node_entered(run, shop, false), "", "再进一次不算")
	var fight := MapNode.new()
	fight.type = &"battle"
	t.eq(perk.on_node_entered(run, fight, true), "", "战斗点不算")
	t.check(is_equal_approx(float(lv.god_state.get(NatureCyclePerk.NEAR_KEY, 0.0)), 35.0), "临时生命上限 35（按报告 390 放大）")
	res.final = {"sides": [{"buffs": {}}, {"buffs": {}}]}
	lv.god_state[NatureCyclePerk.NEAR_KEY] = 35.0
	NatureCyclePerk.settle(lv, res)
	t.check(not lv.god_state.has(NatureCyclePerk.NEAR_KEY), "打完一场：用掉了")
	# 坚韧：没满回 1 点，满了上限 +1
	if run.vitality != null:
		run.vitality.set_max(run.vitality.maximum, &"t", true)
		var m0 := run.vitality.maximum
		lv.taken["god_nature_tough"] = 1
		NatureCyclePerk.on_pick(lv, &"god_nature_tough")
		t.eq(run.vitality.maximum, m0 + 1, "满了：上限 +1")
		t.check(run.vitality.is_full(), "加的那一格是满的")
		run.vitality.spend(2, &"t")
		var c0 := run.vitality.current
		NatureCyclePerk.on_pick(lv, &"god_nature_tough")
		t.eq(run.vitality.current, c0 + 1, "没满：回 1 点")
	# 药材感知 / 食材感知 / 培育：给一件，放进背包或地上
	var herbs := NatureGifts.pool(run, &"herb")
	t.check(not herbs.is_empty() and herbs.all(func(d: ItemDef) -> bool: return NatureGifts.is_herb(d)), "药材池 = 草药素材（%d 件）" % herbs.size())
	lv.taken["god_nature_herb_sense"] = 1
	NatureCyclePerk.on_pick(lv, &"god_nature_herb_sense")
	var got := run.items.get_def(StringName(String(lv.god_state.get("sense_last", ""))))
	t.check(NatureGifts.is_herb(got), "药材感知：给了一件药材（%s）" % String(lv.god_state.get("sense_last", "")))
	lv.taken["god_nature_herb_sense"] = 3
	var w := NatureCyclePerk.sense_weights(lv, &"god_nature_herb_sense")
	t.check(w[3] / w[0] > 5.0 / 50.0, "拿过几次：史诗的权重相对变大")
	lv.taken["god_nature_food_sense"] = 1
	NatureCyclePerk.on_pick(lv, &"god_nature_food_sense")
	got = run.items.get_def(StringName(String(lv.god_state.get("sense_last", ""))))
	t.check(got != null and got.has_tag(&"ingredient"), "食材感知：给了一件食材")
	lv.taken["god_nature_sow"] = 1
	NatureCyclePerk.on_pick(lv, &"god_nature_sow")
	got = run.items.get_def(StringName(String(lv.god_state.get("sow_last", ""))))
	t.check(got != null and got.has_tag(&"seed") and got.growth != null, "培育：给了一颗会长的种子")
	# 抽稀有度：那一档没有就往下取（药材），种子只在有的几档里分
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var only_epic: Array[float] = [0.0, 0.0, 0.0, 1.0, 0.0]
	var d2 := NatureGifts.roll(herbs, only_epic, rng)
	t.check(d2 != null and d2.rarity <= 3, "药材抽到史诗档、没有就往下（%s）" % (String(d2.id) if d2 != null else "无"))
	var only_common: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0]
	var seeds := NatureGifts.pool(run, &"seed")
	t.eq(seeds.size(), 3, "种子三件")
	t.check(NatureGifts.roll(seeds, only_common, rng, 0, true) != null, "种子：普通档没有也照样给")
	# 收获：每 40 层新生掉一件在地上
	lv.taken["god_nature_harvest"] = 1
	var ground0 := run.storage.item_count()
	res.final = {"sides": [{"buffs": {String(NatureCycle.RENEWAL): 85}}, {"buffs": {}}]}
	NatureCyclePerk.settle(lv, res)
	t.eq(run.storage.item_count(), ground0 + 2, "85 层：地上 2 件")
	# 初种：攒到 100 进幼芽，选「采摘」得稀有，放回池子
	lv.taken["god_nature_seed"] = 1
	t.eq(NatureCyclePerk.seed_stage(lv), 0, "初种")
	NatureCyclePerk.settle(lv, _renewal_log(60))
	t.eq(NatureCyclePerk.seed_stage(lv), 0, "60 点：还没长")
	NatureCyclePerk.settle(lv, _renewal_log(50))
	t.eq(NatureCyclePerk.seed_stage(lv), 1, "跨两场攒到 110：幼芽")
	t.check(NatureCyclePerk.choice_due(lv), "等着选")
	var before := lv.pending()
	var offer := lv.offer()
	t.eq(offer, [NatureCyclePerk.SEED_KEEP, NatureCyclePerk.SEED_PICK] as Array[StringName], "选牌窗摆的是继续培育 / 采摘")
	t.check(not lv.reroll(), "这一次不能刷新")
	t.eq(lv.quals().filter(func(q: Dictionary) -> bool: return q["id"] == NatureCyclePerk.SEED)[0]["shown"], &"god_nature_seed_2", "神恩区显示幼芽")
	lv.pick(0)
	t.eq(lv.pending(), before - 1, "选完少欠一次")
	t.eq(NatureCyclePerk.seed_stage(lv), 1, "继续培育：还在幼芽")
	NatureCyclePerk.settle(lv, _renewal_log(210))
	t.eq(NatureCyclePerk.seed_stage(lv), 2, "再攒 200：新蕊")
	lv.offer()
	lv.pick(1)
	got = run.items.get_def(StringName(String(lv.god_state.get("seed_last", ""))))
	t.check(got != null and got.has_tag(&"nature") and got.rarity == 3, "采摘新蕊：一件史诗自然道具（%s）" % (String(got.id) if got != null else "无"))
	t.eq(lv.count_of(NatureCyclePerk.SEED), 0, "初种放回池子")
	t.check(lv.eligible(NatureCyclePerk.SEED), "又能抽到了")
	t.check(not lv.eligible(&"god_nature_seed_2") and not lv.eligible(NatureCyclePerk.SEED_PICK), "后几阶和选项不进池")
	# 育种：种子长得快一倍；升级：长过一阶的出手快 50%
	var seed_def := run.items.get_def(&"thorn_seed")
	var sprout := ItemInstance.create(seed_def)
	t.eq(NatureCyclePerk.seed_speed(run, sprout), 1, "没拿育种：一步一步")
	lv.taken["god_nature_breed"] = 1
	t.eq(NatureCyclePerk.seed_speed(run, sprout), 2, "育种：一步算两步")
	t.eq(r_requires(lv), "seed", "育种要棋盘上有种子才进池")
	# 药补：药品和药材都算
	var herb_def := run.items.get_def(&"dried_herbs")
	t.check(NatureGifts.is_herb(herb_def), "干草药束是药材")
	var cells0 := NatureCyclePerk.cells_of(run.board, [&"remedy"], true)
	TestSupport.put(run.board, herb_def)
	t.eq(NatureCyclePerk.cells_of(run.board, [&"remedy"], true), cells0 + herb_def.cell_count(), "放一束干草药：药补多算它的格子")
	run.dispose()


static func r_requires(lv: LevelModule) -> String:
	return String(lv.rules().card(&"god_nature_breed").get("requires", ""))
