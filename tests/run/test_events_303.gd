## 报告 303 第 4 步：第一批八个常规事件（事件方案 2026-11-11 §5）、地图专属事件池与每张图一次（§8.1）、旧事件修补（§7）。
## 期望从数据推：价钱、耗时、体力都读事件定义里的字段
extends RefCounted

const NEW_COMMON: Array[StringName] = [&"event_supply_bundle", &"event_herbalist", &"event_stuck_cart", &"event_field_stretcher", &"event_refugee_weaver"]
const RUINS_ONLY: Array[StringName] = [&"event_cracked_foundry", &"event_ward_recess"]
const HOURGLASS_ONLY: Array[StringName] = [&"event_clock_oiler"]


static func _content(chapter: String = "free_mode") -> TestSupport.Content:
	return TestSupport.load_content(chapter, ["events", "node_rules"])


## 出生点旁边的事件点挂上事件 [param eid]
static func _run_with(c: TestSupport.Content, eid: StringName) -> Dictionary:
	for seed_ in range(1, 80):
		var s := RunState.start(c.chapter, seed_, c.items, c.enemies, c.sets, [&"bag_leather", &"shortsword", &"knife"] as Array[StringName])
		if s == null:
			continue
		for entry in s.map.entry_ids:
			for nid in s.map.neighbors(entry):
				if s.map.get_node(nid).type == &"event":
					s.event_defs = c.events.duplicate()
					s.pick_spawn(entry)
					s.map.get_node(nid).content["event"] = String(eid)
					return {"run": s, "next": nid}
	return {}


static func _give(s: RunState, c: TestSupport.Content, id: StringName, n: int = 1) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for i in n:
		var inst := ItemInstance.create(c.items.get_def(id), 0)
		s.storage.admit(inst)
		out.append(inst)
	return out


static func run_content(t: TestCase) -> void:
	t.begin("303 · 八个新事件都导进来了：中英文标题、正文、每个选项的英文；有不带条件的离开；池奖励的选项都有可抽的池")
	var c := _content()
	for eid in NEW_COMMON + RUINS_ONLY + HOURGLASS_ONLY:
		var def: EventDef = c.events.get(eid, null)
		t.check(def != null, "%s 在" % eid)
		if def == null:
			continue
		t.check(def.title != "" and def.titles.has("en") and def.text != "" and def.texts.has("en"), "%s 中英文标题与正文" % eid)
		var free := false
		for opt in def.options:
			t.check((opt as EventOption).labels.has("en"), "%s「%s」有英文" % [eid, opt.label])
			free = free or (opt as EventOption).requires.is_empty()
		t.check(free, "%s 有不带条件的选项" % eid)
	var pools := RewardPool.load_all()
	for eid in c.events:
		for opt in (c.events[eid] as EventDef).options:
			for o in (opt as EventOption).outcomes:
				if o is GivePoolItem:
					t.check(pools.has((o as GivePoolItem).pool), "%s 引用的池 %s 在" % [eid, (o as GivePoolItem).pool])


static func run_distribution(t: TestCase) -> void:
	t.begin("303 · 分布：两张图各 40 个种子 —— 有上限的新事件一张图最多一处；废墟专属的不出现在沙漏、沙漏专属的不出现在废墟；信仰事件照旧每张图都有")
	var seeds: Array = []
	for i in 40:
		seeds.append(i + 1)
	for pair in [["free_mode", HOURGLASS_ONLY, RUINS_ONLY], ["clockwork_hourglass", RUINS_ONLY, HOURGLASS_ONLY]]:
		var c := _content(pair[0])
		var r := EventDistribution.survey(c.chapter, c.items, c.enemies, seeds)
		var rules: NodeRules = c.node_rules
		t.eq(int(r["failed"]), 0, "%s 40 张图都开得出" % pair[0])
		for eid in r["events"]:
			var cap := int(rules.event_max_per_map.get(String(eid), -1))
			if cap >= 0:
				t.check(int(r["events"][eid]["max"]) <= cap, "%s：%s 一张图最多 %d 处（上限 %d）" % [pair[0], eid, r["events"][eid]["max"], cap])
		for eid in pair[1]:
			t.check(not (r["events"] as Dictionary).has(String(eid)), "%s 不出 %s" % [pair[0], eid])
		for eid in pair[2] + NEW_COMMON:
			t.check((r["events"] as Dictionary).has(String(eid)), "%s 出过 %s" % [pair[0], eid])
		t.eq(int(r["faith_maps"]), int(r["maps"]), "%s 每张图都有信仰事件" % pair[0])


static func run_cap_on_reveal(t: TestCase) -> void:
	t.begin("303 · 每张图一次也管随机点揭开 / 踩上去现配：图上已有的到了上限，同一张表里换别的抽")
	var c := _content()
	var rules := c.node_rules.with_chapter_events(c.chapter.chapter_events)
	var g := MapGraph.new()
	for i in 30:
		var n := MapNode.new()
		n.id = i
		n.type = &"event"
		n.content_seed = 1000 + i
		g.add_node(n)
	EventPlacer.fill(g, rules)
	var used := EventPlacer.used_counts(g)
	for eid in rules.event_max_per_map:
		t.check(int(used.get(String(eid), 0)) <= int(rules.event_max_per_map[eid]), "铺图后 %s 没超上限" % eid)
	var extra := MapNode.new()
	extra.id = 99
	extra.content_seed = 4242
	for k in 40:
		extra.content_seed = 4242 + k
		var eid := EventPlacer.pick_for(extra, &"event", rules, g)
		var cap := int(rules.event_max_per_map.get(String(eid), -1))
		if cap >= 0:
			t.check(int(used.get(String(eid), 0)) < cap, "现配的 %s 还没到上限" % eid)
	t.check(c.chapter.chapter_events.has("event"), "废墟另加了事件")
	t.check(not (c.node_rules.events_by_type["event"] as Dictionary).has("event_cracked_foundry"), "共用的 standard 没被改（并的是副本）")


static func run_stretcher(t: TestCase) -> void:
	t.begin("303 · E04 担架：满体力时两个恢复选项灰掉写原因；坐下耗时 2 回 1；付钱扣定义里的钱回 1、不耗时；钱不够灰掉")
	var c := _content()
	var def: EventDef = c.events[&"event_field_stretcher"]
	var pay := -int((def.options[1].outcomes[0] as ChangeMoney).amount)
	var f := _run_with(c, &"event_field_stretcher")
	if f.is_empty():
		return
	var s: RunState = f["run"]
	s.step_to(int(f["next"]))
	t.eq(String(s.events.option_state(0)["why"]), UiText.t("cond.vitality_full"), "满体力：坐下灰掉")
	t.eq(String(s.events.option_state(1)["why"]), UiText.t("cond.vitality_full"), "满体力：付钱也灰掉")
	s.vitality.spend(2, &"test")
	t.check(not bool(s.events.option_state(1)["ok"]), "没钱：付钱灰掉")
	s.wallet.earn(pay + 5, &"test")
	t.check(bool(s.events.option_state(1)["ok"]), "钱够了")
	var v := s.vitality.current
	var clock := s.travel.clock.total
	s.events.choose(1)
	t.eq(s.wallet.balance, 5, "扣了 %d" % pay)
	t.eq(s.vitality.current, v + 1, "回 1")
	t.eq(s.travel.clock.total, clock, "不耗时")
	t.check(not s.events.choose(0), "选过了：再选不了（不重复结算）")
	var f2 := _run_with(c, &"event_field_stretcher")
	var s2: RunState = f2["run"]
	s2.step_to(int(f2["next"]))
	s2.vitality.spend(1, &"test")
	var c0 := s2.travel.clock.total
	s2.events.choose(0)
	t.eq(s2.travel.clock.total, c0 + int((def.options[0].outcomes[0] as PassTime).actions), "坐下耗了定义里的时间")


static func run_weaver(t: TestCase) -> void:
	t.begin("303 · E07 补衣人：没有皮革灰掉；锁着的皮革不算；交出皮革得定义里的钱、皮革没了；一次成交关掉")
	var c := _content()
	var def: EventDef = c.events[&"event_refugee_weaver"]
	var gain := int((def.options[0].outcomes[1] as ChangeMoney).amount)
	var f := _run_with(c, &"event_refugee_weaver")
	if f.is_empty():
		return
	var s: RunState = f["run"]
	var n := int(f["next"])
	s.step_to(n)
	t.check(not bool(s.events.option_state(0)["ok"]), "没有皮革")
	var hide := _give(s, c, &"tanned_leather")
	hide[0].set_locked(true)
	t.check(not bool(s.events.option_state(0)["ok"]), "锁着的不算")
	hide[0].set_locked(false)
	var m := s.wallet.balance
	t.check(s.events.choose(0), "能交")
	t.eq(s.wallet.balance, m + gain, "得了 %d" % gain)
	t.eq(s.events._event_ctx(s.map.get_node(n)).count_item(&"tanned_leather"), 0, "皮革交掉了")
	t.check(not s.events.choose(1), "成交后事件关了")


static func run_pool_events(t: TestCase) -> void:
	t.begin("303 · 池奖励事件：E01 拆内层耗时、给冻结的那件、结果那句写出它；E03 体力不到 2 灰掉；读档后奖励不变")
	var c := _content()
	var f := _run_with(c, &"event_supply_bundle")
	if f.is_empty():
		return
	var s: RunState = f["run"]
	var n := int(f["next"])
	s.step_to(n)
	var want := EventRewards.frozen(s.map.get_node(n), &"food_supply")
	t.eq(want.size(), 1, "挂起时冻结了一件食物")
	var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.eq(EventRewards.frozen(back.map.get_node(n), &"food_supply"), want, "读档后还是它")
	var got: Array = []
	s.events.event_resolved.connect(func(_n: MapNode, _o: StringName, d: Dictionary): got.append(d))
	var clock := s.travel.clock.total
	s.events.choose(0)
	t.eq(s.travel.clock.total, clock + 1, "耗了 1")
	t.eq((got[0] as Dictionary).get("items", []), [String(want[0])] if not want.is_empty() else [], "给的是冻结的那件")
	t.check(String(((got[0] as Dictionary).get("log", [""]) as Array)[0]).contains("{item:%s}" % want[0]) if not want.is_empty() else false, "结果那句写出了它")
	var f3 := _run_with(c, &"event_stuck_cart")
	var s3: RunState = f3["run"]
	s3.step_to(int(f3["next"]))
	s3.vitality.spend(s3.vitality.current - 1, &"test")
	t.check(not bool(s3.events.option_state(0)["ok"]), "体力 1：抬轮轴灰掉")
	t.check(bool(s3.events.option_state(1)["ok"]), "收杂物照样能选")


static func run_old_fixes(t: TestCase) -> void:
	t.begin("303 · 旧事件修补：祭坛的 {lose_name} 就是会被拿走的那件、锁着的最值钱的跳过；裂隙挑不到落点时灰掉、不扣体力")
	var c := _content()
	var f := _run_with(c, &"event_altar")
	if f.is_empty():
		return
	var s: RunState = f["run"]
	var n := int(f["next"])
	s.step_to(n)
	var top: ItemInstance = null
	for inst in s.board.items():
		var ii := inst as ItemInstance
		if not ii.def.is_bag and (top == null or ItemValue.of(ii.def) > ItemValue.of(top.def)):
			top = ii
	t.not_null(top, "棋盘上有东西")
	if top == null:
		return
	top.set_locked(true)
	var p := s.events.option_params(0)
	t.check(not String(p.get("lose_name", "")).contains(Names.of(top.def)) or s.board.items().filter(func(x): return (x as ItemInstance).def.id == top.def.id).size() > 1, "锁着的最值钱的不在预告里")
	var lost: Array = []
	s.events.event_resolved.connect(func(_n: MapNode, _o: StringName, d: Dictionary): lost.append(d))
	s.events.choose(0)
	t.check(s.board.items().has(top), "锁着的那件还在")
	if not lost.is_empty() and String(p.get("lose_name", "")) != "":
		var names: Array = (lost[0] as Dictionary).get("items_lost", [])
		t.check(not names.is_empty() and String(p["lose_name"]).contains(String(names[0])), "预告的就是拿走的：%s" % [names])
	# 裂隙：挑不到落点
	var ctx := EventContext.new()
	ctx.graph = s.map
	ctx.node = s.map.get_node(n)
	var tp := Teleport.new()
	tp.min_steps = 999
	t.eq(tp.blocked_reason(ctx), UiText.t("cond.no_landing"), "没有落点：灰掉写原因")
	tp.min_steps = 1
	t.eq(tp.blocked_reason(ctx), "", "有落点：能选")
