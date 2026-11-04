## 277 第 3 条（作者选 B）：点不相邻的点 = 沿走过的点连走过去，终点可以是新点；每步照常走，弹出事就停
extends RefCounted

const GF := preload("res://tests/run/test_game_flow.gd")
const Support := preload("res://tests/run/flow_support.gd")
const GAME := "res://ui/game/game.tscn"
const PREFIX := "walk277"


static func frame_walk_through_visited(t: TestCase, root: Window) -> void:
	t.begin("277 · 连走：中间只穿走过的点，终点可以是新点；隔壁照常一步；走完扣步数")
	var c := GF._content()
	var kit := GF._loadout(c, &"standard")
	var p := Support.paths(PREFIX)
	Support.cleanup(PREFIX)
	var game = load(GAME).instantiate()
	game.save_path = p["run"]
	game.meta_path = p["meta"]
	game.settings_path = p["settings"]
	root.add_child(game)
	var flow: GameFlow = game.flow
	flow.settings.ui_fades = false
	flow.begin(c.chapter, kit, 7, [] as Array[int], null)
	var map = game.base()
	var run: RunState = flow.run
	map.pick_spawn(run.map.entry_ids[0])
	var start: int = run.travel.current_id
	# 找一条 start → a → b（b 不挨着 start）的路
	var a := -1
	var b := -1
	for n1 in MapNavigator.available_moves(run.map, start):
		for n2 in MapNavigator.available_moves(run.map, n1):
			if n2 != start and not MapNavigator.available_moves(run.map, start).has(n2):
				a = n1
				b = n2
				break
		if b >= 0:
			break
	t.check(b >= 0, "找到两步远的点")
	if b < 0:
		game.queue_free()
		Support.cleanup(PREFIX)
		return
	t.eq(map.walk_path(a), [] as Array[int], "隔壁：不连走（照常一步）")
	t.eq(map.walk_path(b), [] as Array[int], "中间那点没走过：不连走")
	run.map.get_node(a).state = MapNode.State.VISITED
	var path: Array[int] = map.walk_path(b)
	t.eq(path, [a, b] as Array[int], "中间走过了：两步，终点是新点")
	var clock := run.travel.clock.total
	t.check(map.walk_to(b), "动身了")
	t.check(run.travel.current_id == b or flow.screen != GameFlow.Screen.MAP, "走到了，或路上弹出事停下")
	t.check(run.travel.clock.total > clock, "步数照扣")
	t.check(not map.walking(), "走完不再连走")
	game.queue_free()
	Support.cleanup(PREFIX)
