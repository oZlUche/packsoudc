## 236 ③：盖死底屏的叠层（铸炉、营地、宝箱，自带整屏底图）完全显出来之后，导演把底下的地图藏起来、停掉；
## 撤掉叠层时恢复。透出地图的叠层（铜面板、事件书、帐篷……）不停，只让地图隔帧重绘
extends RefCounted

const Forge := preload("res://tests/run/test_forge_175.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func frame_covers_base(t: TestCase, root: Window) -> void:
	t.begin("236 · 盖死即停：开铸炉（整屏底图）→ 地图藏起来、不跑 _process；回地图恢复；透出地图的叠层不停、地图隔帧重绘；淡入时还透着地图")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	Support.cleanup("covers236")
	var game = (load(Forge.GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("covers236")["run"])
	game.meta_path = String(Support.paths("covers236")["meta"])
	game.settings_path = String(Support.paths("covers236")["settings"])
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.chapters = [c.chapter] as Array[ChapterDef]
	flow.player_baseline = CombatantBaseline.with_hp(10000.0)
	var node := Forge._rest_next_to_spawn(flow, c, kit)
	t.check(node != null and flow.step_to(node.id), "走上休息点")
	var base: GameScreen = game.base()
	t.check(base != null and base.screen == GameFlow.Screen.MAP, "底屏是地图")
	var camp: GameScreen = game.overlay()
	t.check(camp != null and camp.covers_base(), "休息点开的是营地夜景（盖死底屏）")
	t.check(not base.visible and base.process_mode == Node.PROCESS_MODE_DISABLED, "地图藏起来、停掉了")
	t.check(flow.open_forge(node), "开铸炉")
	var forge: GameScreen = game.overlay()
	t.check(forge != null and forge.covers_base() and not base.visible, "铸炉也盖死：地图还藏着")
	t.check(forge.escape(), "铸炉返回")
	t.check(not base.visible, "回到营地：地图还藏着")
	game._drop_overlay(true)
	t.check(base.visible and base.process_mode == Node.PROCESS_MODE_INHERIT, "撤掉叠层：地图回来、接着跑")
	var view: MapView = base.find_children("*", "MapView", true, false)[0]
	t.check(not view.throttled, "没叠层：每帧重绘")
	# 透出地图的叠层（基类 covers_base 是 false）
	var glass := GameScreen.new()
	game.add_child(glass)
	game._overlay = glass
	game._sync_base()
	t.check(base.visible and base.process_mode == Node.PROCESS_MODE_INHERIT, "透出地图的叠层：地图照跑")
	t.check(view.throttled, "地图隔帧重绘")
	game._drop_overlay(true)
	t.check(not view.throttled and game.overlay() == null, "撤掉：回到每帧重绘")
	# 淡入时还透着地图：叠层没显全不藏底屏
	t.check(flow.open_forge(node), "再开铸炉")
	forge = game.overlay()
	t.check(not base.visible, "叠层显全：藏着")
	forge.modulate.a = 0.5
	game._sync_base()
	t.check(base.visible, "淡入一半：地图还在")
	forge.modulate.a = 1.0
	game._sync_base()
	t.check(not base.visible, "淡入完：藏起来")
	game._drop_overlay(true)
	game.queue_free()
	Support.cleanup("covers236")
