## 221 G（作者 219 G）跳过序章 —— 240（作者 10-22）入口从主菜单搬到开场一问：新存档序章一读完开场事件弹「要带你走一遍吗？」，
## 【不需要】补上三张序章留下的东西（三个解锁、望远镜、两枚信物），这一局悄悄收掉，落在开局屏；交代、自由模式教练照旧会来
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "skip_prologue_221"


static func run_ask_text(t: TestCase) -> void:
	t.begin("240 · 开场一问的字中英都有、不写阿拉伯数字；主菜单「跳过序章」的两个键删了")
	var digit := RegEx.create_from_string("[0-9]")
	for key in ["tut_ask.title", "tut_ask.body", "tut_ask.yes", "tut_ask.no"]:
		var entry: Dictionary = UiText.TEXT[key]
		for lang in ["zh", "en"]:
			var s := String(entry.get(lang, ""))
			t.check(s != "" and digit.search(s) == null, "%s.%s：%s" % [key, lang, s])
	for key in ["menu.skip_prologue", "menu.skip_prologue_confirm"]:
		t.check(not UiText.TEXT.has(key), "删了 %s" % key)


static func _open_game(root: Window) -> Node:
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	return game


## 开新档 → 序章一的开场事件 → 选「出发」；返回问了几次
static func _through_intro(t: TestCase, flow: GameFlow) -> int:
	var asked := [0]
	var count := func() -> void: asked[0] += 1
	flow.tutorial_ask.connect(count)
	flow.start_new_game()
	var tut := flow.tutorial_chapters()
	t.check(flow.run != null and not tut.is_empty() and flow.run.chapter == tut[0], "开新档：直接进序章一")
	t.eq(flow.screen, GameFlow.Screen.EVENT, "先是开场事件")
	t.eq(asked[0], 0, "开场事件还没选：不问")
	t.check(flow.choose_event(0), "点「出发」")
	flow.tutorial_ask.disconnect(count)
	return asked[0]


static func frame_decline(t: TestCase, root: Window) -> void:
	t.begin("240 · 开场一问选【不需要】：三个解锁 + 望远镜 + 两枚信物进仓库，这一局悄悄收掉（不记场次、局内存档删掉），落在开局屏；存盘重读还在")
	var game = _open_game(root)
	var flow: GameFlow = game.flow
	var menu = game.base()
	var texts: Array = menu.lines().map(func(b): return (b as Button).text)
	t.check(not texts.has("跳过序章") and not texts.has("Skip the prologue"), "主菜单没有「跳过序章」了（%s）" % [texts])
	t.eq(_through_intro(t, flow), 1, "书页合上回到地图：问一次")
	var map = game.base()
	t.check(flow.screen == GameFlow.Screen.MAP and map.has_method("tutorial_ask_open") and map.tutorial_ask_open(), "地图上弹着卡")
	var runs := flow.meta.runs
	map.decline_tutorial()
	_check_meta(t, flow, flow.meta, "选完")
	t.eq(flow.meta.flag(GameFlow.TUTORIAL_ASKED), 1, "记下问过了")
	t.is_null(flow.run, "这一局收掉了")
	t.check(not flow.has_save(), "局内存档删了（「继续」不会回到序章一）")
	t.eq(flow.meta.runs, runs, "不记场次")
	t.eq(flow.screen, GameFlow.Screen.SETUP, "落在开局屏")
	var ids: Array = flow.available_chapters().map(func(c): return String((c as ChapterDef).id))
	ids.sort()
	t.eq(ids, ["clockwork_hourglass", "free_mode"], "能选的恰是自由模式与机关沙漏")
	var back := MetaSave.read(flow.items, Support.paths(PREFIX)["meta"], flow.meta_rules, flow.tech_defs)
	t.not_null(back, "局外存了盘")
	if back != null:
		_check_meta(t, flow, back, "重读")
		t.eq(back.flag(GameFlow.TUTORIAL_ASKED), 1, "重读：问过")
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup(PREFIX)


static func frame_accept(t: TestCase, root: Window) -> void:
	t.begin("240 · 开场一问选【需要】：记下问过、局照走；同一份存档再开序章一不再问；开场事件没选完不问")
	var game = _open_game(root)
	var flow: GameFlow = game.flow
	t.eq(_through_intro(t, flow), 1, "问一次")
	var map = game.base()
	t.check(map.tutorial_ask_open(), "卡弹着")
	t.check(map.escape() and map.tutorial_ask_open(), "Esc 不替玩家选：卡还在")
	map.accept_tutorial()
	t.check(not map.tutorial_ask_open(), "卡收起")
	t.eq(flow.meta.flag(GameFlow.TUTORIAL_ASKED), 1, "记下问过了")
	t.check(flow.run != null and flow.screen == GameFlow.Screen.MAP, "局还在、在地图上")
	t.check(not flow.meta.has_unlock(&"prologue_done"), "序章没被跳过")
	flow.to_main_menu()
	t.eq(_through_intro(t, flow), 0, "同一份存档再开：不再问")
	flow.to_main_menu()
	game.queue_free()
	Support.cleanup(PREFIX)


static func _check_meta(t: TestCase, flow: GameFlow, m: MetaState, when: String) -> void:
	for u in [&"prologue_done", &"prologue2_done", &"prologue3_done"]:
		t.check(m.has_unlock(u), "%s：解锁 %s" % [when, u])
	t.check(m.has_keepsake(&"spyglass"), "%s：望远镜" % when)
	var charms := {}
	var kit := 0
	for inst in m.warehouse.items():
		var id := String((inst as ItemInstance).def.id)
		if id in ["charm_brute", "charm_sun"]:
			charms[id] = int(charms.get(id, 0)) + 1
		else:
			kit += 1
	t.eq(charms, {"charm_brute": 1, "charm_sun": 1}, "%s：仓库里恰好两枚信物" % when)
	t.check(kit > 0, "%s：开局那套也在仓库（%d 件）" % [when, kit])
	t.check(m.briefing_seen.is_empty(), "%s：交代没看过（第一次出发前照弹）" % when)
	t.check(not m.coach_seen.has("free_mode_map"), "%s：自由模式教练照旧会来" % when)
