## 231 补充二（游戏测试 20:25，作者卡片甲）：顶栏别剧透 —— 一按「开战」结算就同步算完了，顶栏的金币 / 信力 / 红心等回放看完才变。
## 读数层按住时信号照响、组件只记下不刷；放开刷一次（两次放开不重复）；动效开着时金币从旧数滚到新数
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "hud_hold_231"


static func frame_hold(t: TestCase, root: Window) -> void:
	t.begin("231 补充二 · 读数层按住：信号响了不刷；放开刷一次、内容对；再放开不重复；没按住照常立刻刷")
	var c := CS._content()
	var run := CS._start(c, CS._character(c, &"marcus"))
	if run == null:
		t.check(false, "开不了局")
		return
	var host := HudHost.new()
	host.size = Vector2(1200, 700)
	root.add_child(host)
	host.setup(run, null, HudLayout.default_for("map"))
	var wallet := host.widget(&"wallet")
	var vit := host.widget(&"vitality")
	var before := wallet.text()
	var hearts: Vector2i = vit.hearts()
	run.wallet.earn(25)
	t.eq(wallet.text(), "%d" % run.wallet.balance, "没按住：一变就刷")
	before = wallet.text()
	host.hold()
	t.check(HudHost.hosts_in(root.get_tree()).has(host), "场上找得到读数层")
	run.wallet.earn(10)
	run.vitality.change(-1)
	host.refresh()
	t.eq(wallet.text(), before, "按住：金币不变")
	t.eq(vit.hearts(), hearts, "按住：红心不变")
	host.release()
	t.eq(wallet.text(), "%d" % run.wallet.balance, "放开：金币是新数")
	t.eq(vit.hearts(), Vector2i(run.vitality.maximum, run.vitality.current), "放开：红心是新的")
	var txt := wallet.text()
	host.release()
	t.eq(wallet.text(), txt, "再放开：什么也不做")
	t.check(not host.held, "已经放开")
	# 动效开着：从旧数滚到新数
	GameDirector.fades_allowed = true
	host.hold()
	var old := run.wallet.balance
	run.wallet.earn(40)
	host.release()
	t.eq(wallet.text(), "%d" % old, "动效开着：放开那一刻还是旧数（往上滚）")
	t.eq(wallet._shown_value, run.wallet.balance, "记着要滚到的数")
	t.check(wallet._roll_tween != null and wallet._roll_tween.is_valid(), "在滚")
	wallet._roll_tween.custom_step(HudWidget.ROLL_SEC + 0.1)
	t.eq(wallet.text(), "%d" % run.wallet.balance, "滚完：新数")
	GameDirector.fades_allowed = false
	host.free()     # 立刻出组：下一条用例找场上的读数层不能找到它


static func frame_battle_holds_hud(t: TestCase, root: Window) -> void:
	t.begin("231 补充二 · 开战到看完：战斗屏开着、回放没看完时顶栏金币还是战前的数；看完（跳到底）才变；回到地图一定放开")
	var c := GF._content()
	var kit := GF._loadout(c, &"standard")
	var found := GF._seed_with(c, &"battle", kit.items)
	if found.is_empty():
		t.check(false, "找不到出生点旁边就是战斗点的种子")
		return
	var ch := c.chapter.duplicate() as ChapterDef
	ch.coaches = {}
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [ch] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	flow.begin(ch, kit, int(found["seed"]), [] as Array[int], null)
	var map = game.base()
	map.pick_spawn(int(found["entry"]))
	map.step(int(found["next"]))
	var pre = game.overlay()
	t.check(pre != null and pre.screen == GameFlow.Screen.PREBATTLE, "到了战前准备")
	if pre == null or pre.screen != GameFlow.Screen.PREBATTLE:
		_done(game)
		return
	var host: HudHost = map._hud_host
	t.check(HudHost.hosts_in(root.get_tree()).has(host), "地图屏的读数层在场上")
	var wallet := host.widget(&"wallet")
	var shown := wallet.text()
	var funds := flow.run.wallet.balance
	t.check(pre.start_battle(), "开战")
	var screen = game.overlay()
	t.check(screen != null and screen.screen == GameFlow.Screen.BATTLE, "到了回放屏")
	if screen == null or screen.screen != GameFlow.Screen.BATTLE:
		_done(game)
		return
	t.check(host.held, "按住了")
	t.check(flow.run.wallet.balance != funds, "这一仗进了钱（%d → %d）" % [funds, flow.run.wallet.balance])
	t.eq(wallet.text(), shown, "回放没看完：顶栏还是战前的 %s" % shown)
	screen.view().skip_to_end()
	t.check(not host.held, "跳到底：放开")
	t.eq(wallet.text(), "%d" % flow.run.wallet.balance, "顶栏是战后的数（战前 %d，显示 %s）" % [funds, shown])
	host.hold()
	screen.proceed()
	t.check(not host.held, "离开战斗屏：兜底放开")
	_done(game)


static func _done(game: Node) -> void:
	game.flow.to_main_menu()
	game.queue_free()
	Support.cleanup(PREFIX)
