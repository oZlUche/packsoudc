## 作者 2026-10-22：序章撤离点第一次选「再整理一下」，走开再回来就不再弹撤离 —— 卡死。
## 撤离点的「先不撤」一律是「先回地图，回来再弹」（revisit_later），这个点不算用过；站着点节点 / 放大镜也能再弹
extends RefCounted

const Prologue := preload("res://tests/run/test_prologue.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "extract_revisit_1022"


static func run_extract_events_revisit(t: TestCase) -> void:
	t.begin("作者 10-22 · 四张图的撤离事件：「先不撤」那一项回来再弹")
	for id in ["extract_default", "tut_extract", "tut2_extract", "tut3_extract"]:
		var def := load("res://data/events/%s.tres" % id) as EventDef
		t.not_null(def, id)
		if def == null:
			continue
		var stay := def.options[1] as EventOption
		t.check(stay.outcomes.any(func(o) -> bool: return o is RevisitLater), "%s「%s」：回来再弹" % [id, stay.label])


static func run_prologue_extract_again(t: TestCase) -> void:
	t.begin("作者 10-22 · 序章撤离点：选「再整理一下」→ 走回上一个点 → 再回来，撤离照样弹、能撤")
	var c := Prologue._content()
	var s := Prologue._start(c)
	t.not_null(s, "开局")
	if s == null:
		return
	s.events.pending = {}     # 开场事件不管
	var path := Prologue._path(s.map)
	var extract := path[path.size() - 1]
	t.eq(String(extract.type), "extract", "最后一个点是撤离点")
	for i in range(1, path.size() - 1):
		s.travel.mark_visited(path[i].id)     # 中间的点都当打完了，只穿行
	for i in range(1, path.size()):
		t.check(s.step_to(path[i].id), "走到 %d" % path[i].id)
	var ev := s.events.pending_event()
	t.check(ev != null and ev.id == &"tut_extract", "到了撤离点：弹撤离")
	t.check(s.events.choose(1), "选「再整理一下」")
	t.check(not extract.is_visited(), "这个点不算用过")
	t.check(s.step_to(path[path.size() - 2].id), "走回上一个点捡东西")
	t.check(s.step_to(extract.id), "再回撤离点")
	ev = s.events.pending_event()
	t.check(ev != null and ev.id == &"tut_extract", "撤离又弹出来了")
	t.check(s.events.choose(0), "撤离")
	t.check(s.is_over(), "这一局结束了")


static func run_reopen_on_the_spot(t: TestCase) -> void:
	t.begin("作者 10-22 · 撤离点选「再整理一下」：站着点节点 / 放大镜就再弹撤离（不用走开）")
	var c := Prologue._content()
	var f := Support.flow(c, PREFIX)
	f.chapters = [c.prologue] as Array[ChapterDef]
	var s := f.begin_direct(c.prologue, 7)
	t.not_null(s, "开局")
	if s == null:
		return
	s.events.pending = {}
	var path := Prologue._path(s.map)
	var extract := path[path.size() - 1]
	for i in range(1, path.size() - 1):
		s.travel.mark_visited(path[i].id)
	for i in range(1, path.size()):
		f.step_to(path[i].id)
	t.check(s.events.pending_event() != null and s.events.pending_event().id == &"tut_extract", "到了撤离点：弹撤离")
	t.check(f.choose_event(1), "选「再整理一下」")
	t.eq(f.screen, GameFlow.Screen.MAP, "回地图")
	t.check(f.can_reopen(), "放大镜亮着：有可开的")
	t.check(f.reopen_node(), "点节点 / 放大镜")
	t.eq(f.screen, GameFlow.Screen.EVENT, "撤离又弹出来了")
	t.check(s.events.pending_event() != null and s.events.pending_event().id == &"tut_extract", "是撤离事件")
	t.check(f.choose_event(0), "撤离")
	t.check(s.is_over(), "这一局结束了")
	Support.cleanup(PREFIX)
