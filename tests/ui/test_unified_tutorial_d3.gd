## 统一教程 D3（方案 docs/plans/2026-11-18-unified-tutorial-and-base-return.md §4 T8、§5 B2–B9）：
## 第一段首战后多一个休息点（讲体力、满体力可以不歇）；第一段打完回基地放一次基地导览 —— 带了东西回来先教入库，
## 再点仓库、后勤、书架、开始探索；收起不算看过，跳过教程的不放
extends RefCounted

const W178 := preload("res://tests/ui/test_base_warehouse_178.gd")


static func _flow(p_profile: StringName = &"") -> GameFlow:
	var f := W178._flow()
	f.profile = p_profile
	f.chapters = GameFlow.load_chapters(p_profile)
	f.loadouts = GameFlow.load_loadouts()
	return f


static func _first_done(f: GameFlow) -> void:
	f.meta.grant_unlock(&"prologue_done")
	TutorialRewards.mark(f.meta, &"prologue", TutorialRewards.COMPLETED)


static func run_rest_node(t: TestCase) -> void:
	t.begin("统一教程 D3 · 第一段：首战后、第二个搜索点前有一个休息点，配 tut_rest（歇一下 / 多歇一会 / 不用歇）")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/prologue.json"))
	var rest: Array = (d["nodes"] as Array).filter(func(n: Dictionary) -> bool: return n["type"] == "rest")
	t.eq(rest.size(), 1, "一个休息点")
	if rest.is_empty():
		return
	t.eq(String(rest[0]["content"]["event"]), "tut_rest", "配教程事件")
	var nb: Array = []
	for e in d["edges"]:
		if int(e["from"]) == int(rest[0]["id"]):
			nb.append(int(e["to"]))
		elif int(e["to"]) == int(rest[0]["id"]):
			nb.append(int(e["from"]))
	var type_of := {}
	for n in d["nodes"]:
		type_of[int(n["id"])] = String(n["type"])
	nb.sort()
	t.eq(nb.map(func(i: int) -> String: return type_of[i]), ["battle", "search"], "夹在首战和第二个搜索点中间")
	var ev: EventDef = load("res://data/events/tut_rest.tres")
	t.not_null(ev, "tut_rest 导入了")
	if ev == null:
		return
	t.eq(ev.options.size(), 3, "三个选项")
	t.eq((ev.options[2] as EventOption).outcomes.size(), 0, "「不用歇」什么也不动")
	t.check(ev.text.contains("{vitality}"), "写着现在几点体力")


static func frame_tour(t: TestCase, root: Window) -> void:
	t.begin("统一教程 D3 · 基地导览：第一段打完回基地才放；带了东西回来先教入库（真入库才往下走），再点科技（342 B1）、后勤、书架、开始探索；看完记下不再放")
	for p in [&"", SliceProfile.SLICE]:
		var f := _flow(p)
		var s: Control = W178._screen(f, root)
		t.check(not s.tour_due(), "%s：还没打完第一段：不放" % p)
		s.queue_free()
		_first_done(f)
		W178._with_board(f)
		s = W178._screen(f, root, {"result": true})
		t.check(s.tour_due(), "%s：第一段打完：该放" % p)
		t.check(s.show_tour(), "%s：放了" % p)
		var o: CoachOverlay = s.tour()
		t.eq(o.steps.size(), 6, "%s：入库 + 五处" % p)
		for st in o.steps:
			t.check(s.tour_rect(StringName(String(st["target"]))).size != Vector2.ZERO, "%s：%s 在屏上" % [p, st["target"]])
		t.eq(CoachOverlay.action_of(o.step()), GameFlow.ACTION_STORE, "%s：第一步要入库" % p)
		o.acknowledge()
		t.check(o.waiting(), "%s：点知道了：等你真放进去" % p)
		f.store_all()
		t.eq(o.index, 1, "%s：入库了：下一步" % p)
		for i in 5:
			o.acknowledge()
		t.is_null(s.tour(), "%s：看完收掉" % p)
		t.check(not s.tour_due(), "%s：记下看过了" % p)
		s.queue_free()
		W178._cleanup()


static func frame_tour_variants(t: TestCase, root: Window) -> void:
	t.begin("统一教程 D3 · 基地导览：没带东西回来不教入库；收起不算看过，下次进基地再放；跳过教程的不放")
	var f := _flow()
	_first_done(f)
	var s: Control = W178._screen(f, root)
	t.check(s.show_tour(), "放了")
	t.eq(s.tour().steps.size(), 5, "没带东西：五步")
	t.eq(String(s.tour().step()["target"]), "tab_warehouse", "从仓库页签讲起")
	s.tour().dismiss()
	t.is_null(s.tour(), "收起了")
	t.check(s.tour_due(), "收起不算看过")
	s.queue_free()
	W178._cleanup()
	var g := _flow()
	TutorialRewards.mark(g.meta, &"prologue", TutorialRewards.SKIPPED)
	var s2: Control = W178._screen(g, root)
	t.check(not s2.tour_due(), "跳过的不放")
	s2.queue_free()
	W178._cleanup()
