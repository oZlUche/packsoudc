## 221 G（作者 219 G）：主菜单「新的游戏」下面一行「跳过序章」—— 点两次才开（这份存档不再有序章）；
## 开的是一份新存档，补上三张序章留下的东西（三个解锁、望远镜、两枚信物），落在开局屏；交代、自由模式教练照旧会来
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "skip_prologue_221"


static func run_menu_text(t: TestCase) -> void:
	t.begin("221 G · 菜单两行中英都有、不写阿拉伯数字")
	var digit := RegEx.create_from_string("[0-9]")
	for key in ["menu.skip_prologue", "menu.skip_prologue_confirm"]:
		var entry: Dictionary = UiText.TEXT[key]
		for lang in ["zh", "en"]:
			var s := String(entry.get(lang, ""))
			t.check(s != "" and digit.search(s) == null, "%s.%s：%s" % [key, lang, s])


static func frame_skip_prologue(t: TestCase, root: Window) -> void:
	t.begin("221 G · 跳过序章：点一次只换字、两次才开；三个解锁 + 望远镜 + 两枚信物进仓库，落在开局屏；存盘重读还在")
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	var menu = game.base()
	var btn: Button = menu.skip_button()
	t.not_null(btn, "主菜单有「跳过序章」")
	if btn == null:
		game.queue_free()
		Support.cleanup(PREFIX)
		return
	var lines: Array = menu.lines().map(func(b): return (b as Button).text)
	t.eq(lines.find(btn.text), lines.find(UiText.t("menu.new_run")) + 1, "就在「新的游戏」下面（%s）" % [lines])
	t.check(not menu.skip_prologue(), "第一次点：不开")
	t.eq(btn.text, UiText.t("menu.skip_prologue_confirm"), "字换成确认句")
	t.check(not flow.tutorials_done() and flow.screen == GameFlow.Screen.MAIN_MENU, "还在主菜单、序章没动")
	menu.disarm_skip()
	t.eq(btn.text, UiText.t("menu.skip_prologue"), "几秒没再点：换回来")
	t.check(not menu.skip_prologue(), "重新武装")
	t.check(menu.skip_prologue(), "第二次点：开了")
	_check_meta(t, flow, flow.meta, "开完")
	t.eq(flow.screen, GameFlow.Screen.SETUP, "落在开局屏")
	var ids: Array = flow.available_chapters().map(func(c): return String((c as ChapterDef).id))
	ids.sort()
	t.eq(ids, ["clockwork_hourglass", "free_mode"], "能选的恰是自由模式与机关沙漏")
	var back := MetaSave.read(flow.items, p["meta"], flow.meta_rules, flow.tech_defs)
	t.not_null(back, "局外存了盘")
	if back != null:
		_check_meta(t, flow, back, "重读")
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
