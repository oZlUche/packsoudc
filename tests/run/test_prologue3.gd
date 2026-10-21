## 序章三「祭坛」（作者定，报告 113）：教信仰全套 —— 信物激活、信力怎么涨、神坛献祭、特殊操作二选一、换神与休眠。
## 一条线 9 个点；数值（献祭两件骨头过 1 阶、第二场打完过 2 阶）用真的战斗模拟走一遍验。
extends RefCounted

const SAVE := "user://test_p3_run.json"
const META := "user://test_p3_meta.json"


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("prologue_3", ["brutus", "events", "faiths"])


static func _start(c: TestSupport.Content, seed: int = 7) -> RunState:
	var s := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], c.brutus)
	if s == null:
		return null
	s.event_defs = c.events
	s.faith_defs = c.faiths
	s.pick_spawn(s.map.entry_ids[0])
	return s


static func _find(container, id: StringName) -> ItemInstance:
	for inst in container.items():
		if (inst as ItemInstance).def.id == id:
			return inst
	return null


## 123：背包里找，没有再看地上
static func _find_any(s: RunState, id: StringName) -> ItemInstance:
	var inst := _find(s.board, id)
	return inst if inst != null else _find(s.storage, id)


static func _option(def: EventDef, label: String) -> int:
	for i in def.options.size():
		if (def.options[i] as EventOption).label == label:
			return i
	return -1


static func run_data(t: TestCase) -> void:
	t.begin("序章三 · 数据：序章二通关才开、通关收起、解锁自由模式；序章二撤离直接进它；一条线 9 个点；两件骨头祭品没有战斗属性")
	var c := _content()
	t.not_null(c.chapter, "有序章三")
	if c.chapter == null:
		return
	t.eq(c.chapter.requires_unlock, c.prologue2.grants_unlock, "要序章二通关")
	t.eq(c.chapter.grants_unlock, c.chapter1.requires_unlock, "通关才开自由模式")
	t.eq(c.chapter.hidden_by_unlock, c.chapter.grants_unlock, "通关就收起")
	t.eq(c.prologue2.next_chapter, c.chapter.id, "序章二撤离直接进序章三")
	t.check(c.prologue2.order < c.chapter.order and c.chapter.order < c.chapter1.order, "顺序：序章二、序章三、自由模式")
	t.check(c.chapter.skip_setup and c.chapter.auto_spawn and c.chapter.intro_event == &"tut3_intro", "不走开局屏、先过 intro")
	t.eq(c.chapter.rules.size(), 3, "规则卡三条")
	var g := c.chapter.map_source.resolve(1)
	t.not_null(g, "预设图过了校验：%s" % c.chapter.map_source.last_error)
	if g == null:
		return
	t.eq(g.node_ids().size(), 9, "9 个点")
	var want := [&"spawn", &"event", &"battle", &"search", &"rest", &"event", &"battle", &"rest", &"extract"]
	for i in want.size():
		t.eq(g.get_node(i).type, want[i], "第 %d 个点是 %s" % [i, want[i]])
	for id in [&"bone_dice", &"bone_charm_bits"]:
		var d := c.items.get_def(id)
		t.check(d != null and d.tags.has(&"bone") and d.combat == null, "%s：骨头、没有战斗属性" % id)
	for id in ["tut3_intro", "tut3_faith_call", "tut3_battle_1", "tut3_search", "tut3_search_again_1", "tut3_search_again_2",
			"tut3_search_done", "tut3_rest_1", "tut3_faith_call_sun", "tut3_battle_2", "tut3_rest_2", "tut3_extract"]:
		var e := c.events.get(StringName(id), null) as EventDef
		t.not_null(e, "事件 %s 在" % id)
		if e != null:
			var shown := TextTemplate.plain(e.title + e.text, {"_items": c.items, "_faiths": c.faiths})
			t.check(not shown.contains("{"), "%s 的占位符都换得掉：%s" % [id, shown.left(40)])


static func run_walkthrough(t: TestCase) -> void:
	t.begin("序章三 · 走一遍：拿护符 → 不放包打不了 → 放包激活蛮神 → 打完有信力 → 搜三件 → 献祭过 1 阶、神坛关 → 拿日神护符换神、蛮神信力不丢 → 不切回打不了 → 切回打完过 2 阶 → 第二座神坛两个特殊操作、做一个就关 → 撤离")
	var c := _content()
	var s := _start(c)
	t.not_null(s, "按布鲁图斯开局")
	if s == null:
		return
	t.not_null(_find(s.board, &"shortsword"), "开局包里一把短剑")
	# 1 信仰事件
	t.check(s.step_to(1), "走到信仰事件")
	var ev := s.events.pending_event()
	t.check(ev != null and ev.id == &"tut3_faith_call", "蛮神的低语")
	t.eq(ev.options.size(), 1, "只有「接过护符」（教程不给跳过）")
	t.check(s.events.choose(0), "接过护符")
	var charm := _find(s.storage, &"charm_brute")
	t.not_null(charm, "护符到了地上")
	t.is_null(s.active_faith(), "还没放进包里：没信仰")
	# 2 战斗：门禁
	t.check(s.step_to(2), "走到战斗点（护符还在地上）")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut3_battle_1", "第一场的事件")
	var go := _option(ev, "进入战前准备")
	t.check(not bool(s.events.option_state(go)["ok"]), "没信仰：「进入战前准备」锁着")
	t.check((ev.options[go] as EventOption).hide_when_locked and (ev.options[go] as EventOption).hint_when_hidden != "", "锁着时藏起来、底下说一句为什么")
	t.check(s.events.choose(_option(ev, "先回地图")), "选「先回地图」（作者 2026-10-12：原来的「我先整理一下背包」只会重开这一屏，删了）")
	t.is_null(s.events.pending_event(), "事件关了，回到地图")
	t.check(s.events.pending_battle.is_empty(), "没开打")
	t.is_null(_find(s.storage, &"charm_brute"), "护符没跟过来：留在上一个点的地上（教程提示里说了回去拿）")
	t.check(s.step_to(1), "回上一个点")
	charm = _find(s.storage, &"charm_brute")
	t.not_null(charm, "护符还在那个点的地上")
	if charm == null:
		return
	s.equip(charm.uid)
	t.check(s.step_to(2), "再走回战斗点")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut3_battle_1", "战斗事件还在等着")
	t.check(s.board.has_item(charm.uid), "护符放进包里")
	t.check(s.active_faith() != null and s.active_faith().id == &"brute", "激活了蛮神")
	t.check(bool(s.events.option_state(go)["ok"]), "现在能进战前准备了")
	t.check(s.events.choose(go), "开打")
	var p1 := s.faith_power.points_of(&"brute")
	t.check(p1 > 0, "打完蛮神有信力了（%d）" % p1)
	if s.pending_loot != null:
		s.take_all_loot()
	# 3 搜索
	t.check(s.step_to(3), "走到搜索点")
	t.check(s.events.choose(0), "搜第一次")
	t.check(s.events.pause_search() and s.events.pending_event().id == &"tut3_search_again_1", "→ 骨骰子")
	t.check(s.events.choose(0), "搜第二次")
	t.check(s.events.pause_search() and s.events.pending_event().id == &"tut3_search_again_2", "→ 碎骨串")
	t.check(s.events.choose(0), "搜第三次")
	t.check(s.events.pause_search() and s.events.pending_event().id == &"tut3_search_done", "→ 胫骨大棒")
	t.check(s.events.choose(0), "继续")
	t.check(s.pending_loot == null, "作者 2026-10-16：不弹战利品屏，收获掉在地上")
	# 123：全部拾取先进背包，放不下的才到地上
	var dice := _find_any(s, &"bone_dice")
	var bits := _find_any(s, &"bone_charm_bits")
	var tibia := _find_any(s, &"tibia_violence")
	t.check(dice != null and bits != null and tibia != null, "骨骰子、碎骨串、胫骨大棒都拿到了（背包或地上）")
	if dice == null or bits == null or tibia == null:
		return
	s.equip(dice.uid)
	s.equip(bits.uid)
	s.equip(tibia.uid)
	t.check(s.board.has_item(tibia.uid), "胫骨大棒进包")
	t.eq(s.active_faith().id, &"brute", "胫骨大棒不是信物：还是蛮神")
	# 4 神坛 A：献祭
	t.check(s.step_to(4), "走到第一座神坛")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut3_rest_1", "教程版的休息点")
	var altar_i := _option(ev, "献祭或特殊操作，二选一")
	t.check(bool(s.events.option_state(altar_i)["ok"]), "信了神：神坛能开")
	t.check(s.events.choose(altar_i), "开神坛")
	var altar := AltarModule.of(s)
	t.check(altar.is_open(), "神坛开着")
	var tier0 := s.active_faith_tier()
	var got := altar.offer([dice, bits], s.current_node())
	s.board.remove(dice.uid)
	s.board.remove(bits.uid)
	t.check(int(got["points"]) > 0, "献祭得了 %d 信力" % int(got["points"]))
	var p2 := s.faith_power.points_of(&"brute")
	t.check(s.active_faith_tier() >= 1, "过了 1 阶（信力 %d，阈值 %d）" % [p2, c.faiths[&"brute"].thresholds[0]])
	t.check(p2 < c.faiths[&"brute"].thresholds[1], "但还没到 2 阶（%d < %d）—— 第二场才到" % [p2, c.faiths[&"brute"].thresholds[1]])
	t.check(tier0 < s.active_faith_tier(), "阶变了（%d → %d）" % [tier0, s.active_faith_tier()])
	t.check(not altar.is_open(), "献祭了：这座神坛关了（二选一）")
	t.not_null(altar.perk(&"low_hp_empower"), "1 阶效果「低血增伤」生效")
	# 5 日神：换神与休眠
	t.check(s.step_to(5), "走到日神的事件")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut3_faith_call_sun", "日神的低语")
	t.check(s.events.choose(0), "接过日神的护符")
	var sun := _find(s.storage, &"charm_sun")
	t.not_null(sun, "日神护符在地上")
	if sun == null:
		return
	s.equip(sun.uid)
	t.eq(s.active_faith().id, &"sun", "放进包里：换成日神")
	t.eq(s.faith_power.points_of(&"brute"), p2, "蛮神的信力还记着（%d）" % p2)
	# 6 战斗 2：门禁要蛮神
	t.check(s.step_to(6), "走到第二场")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut3_battle_2", "第二场的事件")
	go = _option(ev, "进入战前准备")
	t.check(not bool(s.events.option_state(go)["ok"]), "信的是日神：锁着")
	t.check(s.board.reseat(charm.uid), "右键蛮神护符（重新落下）")
	t.eq(s.active_faith().id, &"brute", "切回蛮神")
	t.check(bool(s.events.option_state(go)["ok"]), "现在能打")
	t.check(s.events.choose(go), "开打")
	var p3 := s.faith_power.points_of(&"brute")
	t.check(s.active_faith_tier() >= 2, "第二场打完过了 2 阶（信力 %d，阈值 %d）" % [p3, c.faiths[&"brute"].thresholds[1]])
	# 116：留余量，防下次改武器 / 数值又贴着线（曲线 102～118）
	t.check(p3 >= c.faiths[&"brute"].thresholds[1] + 2, "第二场打完离 2 阶还留着余量（%d ≥ %d + 2）" % [p3, c.faiths[&"brute"].thresholds[1]])
	if s.pending_loot != null:
		s.take_all_loot()
	# 7 神坛 B：特殊操作二选一
	t.check(s.step_to(7), "走到第二座神坛")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut3_rest_2", "第二座神坛")
	t.check(s.events.choose(_option(ev, "献祭或特殊操作，二选一")), "开神坛")
	var acts := altar.actions()
	var names: Array[StringName] = []
	for p in acts:
		names.append(ContentSchema.registry_name_of(p))
	t.check(names.has(&"altar_bless") and names.has(&"altar_sacrifice_hp"), "两个特殊操作都在：%s" % str(names))
	var line := altar.special(altar.perk(&"altar_sacrifice_hp"), s.current_node())
	t.check(line != "", "献祭生命上限：%s" % line)
	t.check(not altar.is_open(), "做了一个：神坛关了，另一个与献祭都不行")
	t.eq(altar.special(altar.perk(&"altar_bless"), s.current_node()), "", "祈求赐福做不了了")
	# 8 撤离
	t.check(s.step_to(8), "走到撤离点")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut3_extract", "撤离事件")
	t.check(s.events.choose(0), "撤离")
	t.eq(s.phase, RunState.Phase.EXTRACTED, "撤出来了")


static func run_gating(t: TestCase) -> void:
	t.begin("序章三 · 教程顺序 1 → 2 → 3 → 自由模式（114）：序章二通关只列序章三，序章三通关只剩自由模式、新的一局进开局屏")
	var c := _content()
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = GameFlow.load_chapters()
	f.characters = GameFlow.load_characters()
	f.event_defs = c.events
	f.save_path = SAVE
	f.meta_path = META
	var tuts := f.tutorial_chapters()
	t.eq(tuts.map(func(x: ChapterDef) -> StringName: return x.id), [&"prologue", &"prologue_2", &"prologue_3"], "三张教程按顺序")
	f.meta.grant_unlock(&"prologue_done")
	f.meta.grant_unlock(&"prologue2_done")
	var avail := f.available_chapters()
	t.check(avail.size() == 1 and avail[0].id == &"prologue_3", "序章二通关后只列序章三")
	var cont := f.continue_target()
	t.check(cont != null and cont.id == &"prologue_3", "「继续」指向序章三")
	t.check(not f.tutorials_done(), "教程还没全通")
	f.meta.grant_unlock(&"prologue3_done")
	avail = f.available_chapters()
	t.check(avail.size() == 2 and avail[0].id == &"free_mode" and avail[1].id == &"clockwork_hourglass", "序章三通关后只剩自由模式（210：后面跟着机关沙漏）")
	t.check(f.tutorials_done(), "教程全通")
	t.is_null(f.new_run_target(), "新的一局不直接开：进开局屏挑角色、规模")
	t.eq(Names.of(avail[0]), "魔法废墟", "显示名（180：自由模式改叫魔法废墟，id 不变）")
	t.eq(f.chapter_of(&"chapter_01"), avail[0], "老存档里的 chapter_01 认得出是自由模式（IdAliases）")
	var old := RunSave.load_chapter(&"chapter_01")
	t.check(old != null and old.id == &"free_mode", "读档按老 id 也载得到")
	RunSave.remove(SAVE)
	MetaSave.remove(META)


static func run_faith_placeholders(t: TestCase) -> void:
	t.begin("113 · 信仰占位符：{faith:id} 上色、阈值 / 行为 / 献祭 / 效果的数读定义；写错不换")
	var c := _content()
	var ctx := {"_faiths": c.faiths}
	var brute := c.faiths[&"brute"] as FaithDef
	t.eq(TextTemplate.render("{faith:brute}", ctx), "[color=@faith][b]%s[/b][/color]" % Names.of(brute), "{faith:}：信仰名、faith 色")
	t.eq(TextTemplate.plain("{faith_threshold:brute:2}", ctx), str(brute.thresholds[1]), "第二阶阈值")
	t.eq(TextTemplate.plain("{faith_deed:brute:damage:cap}", ctx), "30", "伤害行为的封顶")
	t.eq(TextTemplate.plain("{faith_deed:brute:damage:multiplier}", ctx), "0.2", "伤害行为的倍数")
	t.eq(TextTemplate.plain("{faith_deed:brute:vitality_lost:multiplier}", ctx), "50", "失去体力的倍数（默认值也读得到）")
	t.eq(TextTemplate.plain("{faith_offer:brute:bone:multiplier}", ctx), "5", "骨制品的献祭倍数")
	t.eq(TextTemplate.plain("{faith_perk:brute:altar_bless:cost}", ctx), "40", "祈求赐福花的信力")
	t.eq(TextTemplate.plain("{faith_threshold:brute:9}", ctx), "{faith_threshold:brute:9}", "没有这一阶：原样保留")
	t.eq(TextTemplate.plain("{faith:nobody}", ctx), "{faith:nobody}", "没有这位神：原样保留")
	t.eq(TextTemplate.refs("{faith:brute}{faith_perk:sun:x:y}").size(), 2, "refs 认信仰引用")
	var cond := FaithActive.new()
	cond.faith = &"brute"
	t.check(cond.describe().contains("蛮神"), "条件说明点名要哪位神")


static func run_departure_briefing_218(t: TestCase) -> void:
	t.begin("218 补充一 · 「军团的交代」挪到开局屏第一次按出发前：自由模式、机关沙漏同一个事件只弹一次；序章三撤离直接结算")
	var c := _content()
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.chapters = GameFlow.load_chapters()
	f.characters = GameFlow.load_characters()
	f.event_defs = EventPlacer.load_all()
	f.save_path = SAVE
	f.meta_path = META
	var run := f.begin_direct(c.chapter, 7)
	t.not_null(run, "开了序章三")
	if run != null:
		t.eq(c.chapter.departure_event, &"", "序章三不配交代")
		f.choose_event(0)
		run.travel.start_at(run.map.goal_ids[0])
		t.check(f.extract(), "撤离")
		t.eq(f.screen, GameFlow.Screen.RESULT, "撤离后直接结算（交代不再挂在这里）")
		f.finish_result()
	var free := f.chapter_of(&"free_mode")
	var hour := f.chapter_of(&"clockwork_hourglass")
	t.check(free != null and hour != null and free.departure_event == &"briefing_legion" and hour.departure_event == &"briefing_legion", "自由模式、机关沙漏都配「军团的交代」")
	var def := f.departure_briefing(free)
	t.check(def != null and def.id == &"briefing_legion", "第一次出发：要弹")
	if def == null:
		return
	t.eq(def.title, "军团的交代", "标题")
	var shown := TextTemplate.plain(def.text_for(), TextTemplate.context_for(null))
	t.check(shown != "" and not shown.contains("{") and not shown.contains("}"), "局还没开，占位符也换得掉")
	t.eq(TextLint.scan({"text": def.text}).size(), 0, "不写数字")
	for word in ["日晷", "免费出口", "保险箱", "主人", "百科"]:
		t.check(shown.contains(word), "讲到「%s」" % word)
	var went := [0]
	f.show_briefing(def, func(): went[0] += 1)
	t.eq(f.screen, GameFlow.Screen.EVENT, "叠一层事件屏")
	t.check(f.last_payload.get("def", null) == def and bool(f.last_payload.get("briefing", false)) and f.last_payload.get("node", null) == null, "带着交代、没有节点")
	t.eq(went[0], 0, "还没出发")
	f.close_briefing()
	t.eq(went[0], 1, "「知道了」：接着出发")
	t.check(f.meta.briefing_seen.has(&"briefing_legion"), "记看过")
	t.is_null(f.departure_briefing(free), "再出发：不弹")
	t.is_null(f.departure_briefing(hour), "换机关沙漏出发：同一个事件，也不弹")
	t.check(MetaState.from_dict(f.meta.to_dict(), c.items).briefing_seen.has(&"briefing_legion"), "跟存档")
	RunSave.remove(SAVE)
	MetaSave.remove(META)
