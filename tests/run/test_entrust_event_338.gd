## 报告 337 第一节：真玩时撤离点走的是 extract_default 事件，地图上那个带【托付】的确认框只有测试打开 —— 玩家点不到托付。
## 修：撤离点事件多一项「托付」（只在能托时显示），选了开托付屏，这个点不算用过；关了站着点节点就再弹撤离
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Safe := preload("res://tests/run/test_safe.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "entrust_event_338"


static func _entrust_index(def: EventDef) -> int:
	for i in def.options.size():
		if (def.options[i] as EventOption).outcomes.any(func(o) -> bool: return o is OpenSafe):
			return i
	return -1


## 从旁边一个点真的走上 [param node]（到了弹点上的事件）
static func _walk_onto(f: GameFlow, run: RunState, node: MapNode) -> bool:
	var near := run.map.neighbors(node.id)
	if near.is_empty():
		return false
	Safe.stand_on(run, run.map.get_node(near[0]))
	run.events.pending = {}
	return f.step_to(node.id)


static func run_entrust_from_event(t: TestCase) -> void:
	t.begin("报告 337 §1 · 真玩撤离：免费撤离点的事件里有「托付」，选了开托付屏；关了站着点节点再弹撤离、能撤；付费出口没有")
	var ev := load("res://data/events/extract_default.tres") as EventDef
	t.not_null(ev, "撤离点事件")
	if ev == null:
		return
	var at := _entrust_index(ev)
	t.check(at >= 0 and ev.options[at].hide_when_locked, "有「托付」，托不了就不显示")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, PREFIX)
	var run := f.begin(c.chapter, kit, 1)
	t.not_null(run, "开局")
	if run == null:
		Support.cleanup(PREFIX)
		return
	f.pick_spawn(run.map.entry_ids[0])
	var free := Safe.extract_node(run, true)
	t.check(free != null, "有免费撤离点")
	if free == null:
		Support.cleanup(PREFIX)
		return
	t.check(_walk_onto(f, run, free), "走上免费撤离点")
	var pe := run.events.pending_event()
	t.check(pe != null and pe.id == &"extract_default", "弹撤离点事件")
	t.eq(f.screen, GameFlow.Screen.EVENT, "看的是事件")
	t.check(f.choose_event(at), "选「托付」")
	t.eq(f.screen, GameFlow.Screen.SAFE, "开了托付屏")
	t.check(not free.is_visited(), "这个点不算用过")
	f.close_safe()
	t.eq(f.screen, GameFlow.Screen.MAP, "关了回地图")
	t.check(f.can_reopen() and f.reopen_node(), "站着点节点")
	pe = run.events.pending_event()
	t.check(pe != null and pe.id == &"extract_default", "撤离又弹出来了")
	var paid := Safe.extract_node(run, false)
	if paid != null:
		var ctx := EventContext.new()
		ctx.node = paid
		ctx.hooks = run.hooks
		t.check(ev.options[at].locked_reason(ctx) != "", "付费出口：托付不显示")
	t.check(f.choose_event(0), "撤离")
	t.check(run.is_over(), "这一局结束了")
	Support.cleanup(PREFIX)
