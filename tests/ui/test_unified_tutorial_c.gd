## 统一教程 C 批（方案 docs/plans/2026-11-18-unified-tutorial-and-base-return.md §3）：教学卡三个键、不误触；
## 动作步要真做成才算（看过 ≠ 做过）；几方同时停回放时，谁停的谁放，都放开了才接着放
extends RefCounted

const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const PREFIX := "unified_c"


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


static func _overlay(root: Window, steps: Array, flow: GameFlow = null) -> CoachOverlay:
	var o := CoachOverlay.new()
	o.flow = flow
	root.add_child(o)
	o.set_anchors_preset(Control.PRESET_TOP_LEFT)
	o.size = Vector2(1200, 700)
	o.start(steps)
	return o


static func frame_keys(t: TestCase, root: Window) -> void:
	t.begin("统一教程 C · 教学卡：回车 = 知道了、「上一步」退回、Esc = 收起（不记看完）；别的键不算")
	var o := _overlay(root, [{"target": "a", "text": "一"}, {"target": "a", "text": "二"}, {"target": "a", "text": "三"}])
	var got := {"finished": 0, "dismissed": 0, "closed": 0}
	o.finished.connect(func(): got["finished"] += 1)
	o.dismissed.connect(func(): got["dismissed"] += 1)
	o.closed.connect(func(): got["closed"] += 1)
	t.check(not o._back.visible and o._ok.visible and o._hide.visible, "第一步：没有「上一步」")
	o._input(_key(KEY_A))
	t.eq(o.index, 0, "别的键：不算")
	o._input(_key(KEY_ENTER))
	t.eq(o.index, 1, "回车：下一步")
	t.check(o._back.visible, "第二步：有「上一步」")
	o.back()
	t.eq(o.index, 0, "「上一步」：退回第一步")
	o._input(_key(KEY_ESCAPE))
	t.eq(got, {"finished": 0, "dismissed": 1, "closed": 1}, "Esc：收起（不发完成）")
	t.check(o.is_queued_for_deletion(), "收掉了")


static func frame_action_step(t: TestCase, root: Window) -> void:
	t.begin("统一教程 C · 动作步：「知道了」只算看过、放开操作等真做；做成了才下一步、记进局外；做过的下次直接跳过；没点也能先做")
	var f := GameFlow.new(null, null, null, MetaState.new())
	var steps := [{"target": "a", "text": "讲"}, {"target": "a", "text": "合一件", "action": "fuse"}, {"target": "a", "text": "完"}]
	var o := _overlay(root, steps, f)
	o.acknowledge()
	t.eq(o.index, 1, "到了动作步")
	o.acknowledge()
	t.check(o.waiting() and o.index == 1, "「知道了」：等着真做")
	t.eq(o.mouse_filter, Control.MOUSE_FILTER_IGNORE, "放开操作（点得到底下）")
	t.check(not o._ok.visible and o._hide.visible, "纸条留着当目标，只剩「收起」")
	o._input(_key(KEY_ENTER))
	t.eq(o.index, 1, "等着时回车不算")
	f.note_action(GameFlow.ACTION_STORE)
	t.eq(o.index, 1, "别的动作不算")
	t.check(not f.action_done(GameFlow.ACTION_FUSE), "还没做")
	f.note_action(GameFlow.ACTION_FUSE)
	t.check(o.index == 2 and not o.waiting(), "合成成了：下一步")
	t.check(f.meta.coach_done.has("fuse"), "记进了局外（做过）")
	o.next()
	var again := _overlay(root, steps, f)
	again.acknowledge()
	t.eq(again.index, 2, "做过的动作步：直接跳过")
	again.next()
	var g := GameFlow.new(null, null, null, MetaState.new())
	var early := _overlay(root, steps, g)
	early.acknowledge()
	g.note_action(GameFlow.ACTION_FUSE)
	t.eq(early.index, 2, "没点「知道了」先做了：也算")
	early.next()
	var back := MetaState.from_dict(f.meta.to_dict(), null)
	t.check(back != null and back.coach_done.has("fuse"), "存档带着做过的动作")


static func run_hold_owners(t: TestCase) -> void:
	t.begin("统一教程 C · 停回放：过场、教程、反应讲解各记各的；放开一方，别人压着就还停着")
	var view := BattleView.new()
	view.hold(BattleView.HOLD_INTRO)
	view.hold(BattleView.HOLD_COACH)
	t.eq(view.holders(), [BattleView.HOLD_INTRO, BattleView.HOLD_COACH] as Array[StringName], "两方压着")
	view.release(BattleView.HOLD_INTRO)
	t.check(view.is_held(), "过场放开：教程还压着，不动")
	view.release(BattleView.HOLD_REACTION)
	t.check(view.is_held(), "没压的一方放开：不算数")
	view.release(BattleView.HOLD_COACH)
	t.check(not view.is_held(), "都放开了：接着放")
	view.free()


static func run_actions_noted(t: TestCase) -> void:
	t.begin("统一教程 C · 真实成功事件记动作：一键置入 = 入库；合成模块报成 = 合成")
	var c := GF._content()
	var f := Support.flow(c, PREFIX)
	f.meta.board = GridInventory.new(RunState.BOARD_SIZE, MetaState.BOARD_ID, false)
	var inst := ItemInstance.create(c.items.get_def(&"bandage"), 0)
	inst.uid = f.meta.allocate_uid()
	t.check(f.meta.board.try_add(inst, true), "带回来一卷纱布")
	var heard: Array = []
	f.tutorial_action.connect(func(id: StringName): heard.append(id))
	f.store_all()
	t.check(f.action_done(GameFlow.ACTION_STORE) and heard.has(GameFlow.ACTION_STORE), "一键置入：记了入库")
	var empty := Support.flow(c, PREFIX)
	empty.store_all()
	t.check(not empty.action_done(GameFlow.ACTION_STORE), "什么也没放：不算")
	var run := f.begin(c.chapter, GF._loadout(c, &"standard"), 1, [] as Array[int], null)
	t.not_null(run, "开了一局")
	var crafting := CraftingModule.of(run) if run != null else null
	t.not_null(crafting, "有合成模块")
	if crafting != null:
		crafting.done.emit({"ok": true})
		t.check(f.action_done(GameFlow.ACTION_FUSE), "合成成了：记了合成")
	Support.cleanup(PREFIX)


static func frame_pause_replay(t: TestCase, root: Window) -> void:
	t.begin("统一教程 C · 地图暂停菜单「重看教程」：关掉暂停菜单、从头放地图教程，看过的也放")
	var c := GF._content()
	var ch := c.chapter.duplicate() as ChapterDef
	ch.coaches = {"map": "prologue_map"}
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load("res://ui/game/game.tscn").instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.settings.ui_fades = false
	flow.chapters = [ch] as Array[ChapterDef]
	flow.meta.coach_seen.append("prologue_map")
	flow.begin(ch, GF._loadout(c, &"standard"), 1, [] as Array[int], null)
	var map = game.base()
	map.toggle_pause()
	t.check(map.pause_open(), "暂停菜单开着")
	t.check(map.replay_map_coach(), "重看")
	t.check(not map.pause_open() and map.coach() != null, "暂停菜单关了、教程开了")
	if map.coach() != null:
		map.coach().dismiss()
	t.is_null(map.coach(), "收起：收掉")
	game.queue_free()
	Support.cleanup(PREFIX)
