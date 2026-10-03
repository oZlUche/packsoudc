## 109（作者定）：离开点不再弹暂存区提示（断言在 test_node_storage）；战斗倍速记进设置、跨局继承；
## 仓库「整理」（先大后小、原子生效）；局外仓库面板与开局屏的双击快速置入。
extends RefCounted

const META := "user://test_109_meta.json"
const SETTINGS := "user://test_109_settings.json"
const BATTLE := "res://ui/game/battle_screen.gd"
const WAREHOUSE_PANEL := "res://ui/game/warehouse_panel.gd"


static func _def(id: String, rows: Array, rarity: int = 0) -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.display_name = id
	d.rarity = rarity
	d.shape = ItemShape.from_ascii(rows)
	return d


static func _cells_of(g: GridInventory) -> Dictionary:
	var out := {}
	for y in g.size.y:
		for x in g.size.x:
			var uid := g.cell_uid(Vector2i(x, y))
			if uid != GridInventory.EMPTY_UID:
				out[Vector2i(x, y)] = uid
	return out


## 最后一个有东西的行
static func _last_row(g: GridInventory) -> int:
	var last := -1
	for c in _cells_of(g):
		last = maxi(last, (c as Vector2i).y)
	return last


#region 整理
static func run_tidy(t: TestCase) -> void:
	t.begin("仓库整理 · 先大后小、占用聚到左上、东西一件不少、两次一样")

	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(6, 5), 100, false)
	var placed_at := [
		[_def("pebble", ["#"]), Vector2i(5, 4)],
		[_def("gem", ["#"], 3), Vector2i(0, 4)],
		[_def("stick", ["##"]), Vector2i(2, 3)],
		[_def("ell", ["#.", "##"], 1), Vector2i(3, 1)],
		[_def("crate", ["##", "##"]), Vector2i(0, 1)],
		[_def("coin", ["#"]), Vector2i(5, 0)],
	]
	var seqs := {}
	for row in placed_at:
		var inst := ItemInstance.create(row[0])
		t.check(g.place(inst, row[1], 0), "摆 %s" % inst.def.id)
		seqs[inst.uid] = inst.placed_seq
	var uids_before := {}
	for inst in g.items():
		uids_before[(inst as ItemInstance).uid] = true
	var last_before := _last_row(g)
	var fired := [0]
	var arrivals := [0]
	g.changed.connect(func(): fired[0] += 1)
	g.placed.connect(func(_i): arrivals[0] += 1)

	t.check(GridTidy.tidy(g), "整理成功")
	t.eq(fired[0], 1, "只发一次 changed")
	t.eq(arrivals[0], 0, "同容器内挪位不算置入：不发 placed")
	var uids_after := {}
	for inst in g.items():
		var item := inst as ItemInstance
		uids_after[item.uid] = true
		t.eq(item.placed_seq, seqs[item.uid], "%s 的置入序号不变" % item.def.id)
	t.eq(uids_after, uids_before, "件数、uid 一个不少")
	t.check(_last_row(g) <= last_before, "占用的最后一行不比整理前靠下（%d → %d）" % [last_before, _last_row(g)])
	t.eq(g.get_item(_uid_of(g, &"crate")).origin, Vector2i.ZERO, "最大的（2×2）排在最左上")
	t.eq(_last_row(g), 1, "6 件 12 格在 6 宽的仓库里塞进两行")
	var once := _cells_of(g)
	t.check(GridTidy.tidy(g), "再整理一次")
	t.eq(_cells_of(g), once, "两次结果逐格相同（确定性）")


static func _uid_of(g: GridInventory, id: StringName) -> int:
	for inst in g.items():
		if (inst as ItemInstance).def.id == id:
			return (inst as ItemInstance).uid
	return 0


static func run_tidy_rollback(t: TestCase) -> void:
	t.begin("仓库整理 · 排不开就原样放回；棋盘与空仓库不整理")

	ItemInstance.reset_uid_counter()
	# 4×2 里两件 L 形咬合拼满。按排序 a_hook 先放、落在 (0,0)，剩下的四格不连成 L —— b_hook 放不进，必须整批回滚
	var g := GridInventory.new(Vector2i(4, 2), 100, false)
	var b_hook := ItemInstance.create(_def("b_hook", ["###", "#.."]))
	var a_hook := ItemInstance.create(_def("a_hook", ["..#", "###"]))
	t.check(g.place(b_hook, Vector2i.ZERO, 0) and g.place(a_hook, Vector2i(1, 0), 0), "两件 L 形咬合摆满")
	var before := _cells_of(g)
	var fired := [0]
	g.changed.connect(func(): fired[0] += 1)
	t.check(not GridTidy.tidy(g), "排不开：返回 false")
	t.eq(_cells_of(g), before, "逐格回到原样")
	t.eq([b_hook.origin, a_hook.origin], [Vector2i.ZERO, Vector2i(1, 0)], "两件都在原位")
	t.eq(g.item_count(), 2, "一件不少")
	t.eq(fired[0], 1, "回滚也只发一次 changed")

	var board := GridInventory.new(Vector2i(3, 3), 1, true)
	t.check(not GridTidy.tidy(board), "棋盘（要求包）不整理 —— 那是玩家摆的阵")
	t.check(not GridTidy.tidy(GridInventory.new(Vector2i(3, 3), 100, false)), "空的不整理")
#endregion


#region 倍速
static func _flow(meta: MetaState = null) -> GameFlow:
	var c_items := ItemDatabase.new()
	c_items.load_dir()
	var f := GameFlow.new(c_items, EnemyDatabase.new(), SetDatabase.new(), meta if meta != null else MetaState.new())
	f.meta_path = META
	f.settings_path = SETTINGS
	f.settings = GameSettings.load_from(SETTINGS)
	return f


static func frame_battle_speed(t: TestCase, root: Window) -> void:
	t.begin("战斗倍速 · 切一次记进设置，下一场（重开游戏）照这个速度开场")

	GameSettings.remove(SETTINGS)
	var f := _flow()
	t.eq(f.settings.battle_speed, 1.0, "第一次：1×")
	var screen = load(BATTLE).new()
	screen.flow = f
	root.add_child(screen)
	screen.open({})
	t.eq(screen._view.speed(), 1.0, "回放 1× 开场")
	screen._view.cycle_speed()
	t.eq(screen._view.speed(), 2.0, "切到 2×")
	t.eq(f.settings.battle_speed, 2.0, "写回了设置")
	screen.queue_free()

	var f2 := _flow()     # 新的一局 / 重开游戏：从同一份 settings.json 读
	t.eq(f2.settings.battle_speed, 2.0, "读回来是 2×")
	var screen2 = load(BATTLE).new()
	screen2.flow = f2
	root.add_child(screen2)
	screen2.open({})
	t.eq(screen2._view.speed(), 2.0, "下一场起手 2×")
	screen2._view.cycle_speed()
	screen2._view.cycle_speed()
	t.eq(GameSettings.load_from(SETTINGS).battle_speed, 1.0, "转回 1× 也存了")
	screen2.queue_free()

	var view := BattleView.new()
	view.set_speed(3.0)
	t.eq(view.speed(), 1.0, "不在表里的倍速按 1×")
	view.set_speed(4.0)
	t.eq(view.speed(), 4.0, "4× 认得")
	view.free()
	GameSettings.remove(SETTINGS)
#endregion


#region 双击
static func frame_warehouse_double_click(t: TestCase, root: Window) -> void:
	t.begin("仓库面板 · 双击快速置入（带回来的背包 ⇄ 仓库）与整理按钮")

	ItemInstance.reset_uid_counter()
	var meta := MetaState.new()
	var f := _flow(meta)
	meta.board = GridInventory.new(Vector2i(4, 2), MetaState.BOARD_ID, false)
	var rock := ItemInstance.create(_def("rock", ["#"]))
	var rod := ItemInstance.create(_def("rod", ["##"]))
	t.check(meta.board.place(rock, Vector2i.ZERO, 0) and meta.board.place(rod, Vector2i(1, 0), 0), "带回来两件")
	var panel = load(WAREHOUSE_PANEL).new()
	root.add_child(panel)
	panel.setup(f, UiPalette.cjk_font())
	var emitted := [0]
	panel.changed.connect(func(): emitted[0] += 1)

	t.check(panel.quick_move(panel._board_view, rock.uid), "双击带回来的一件")
	t.check(meta.warehouse.has_item(rock.uid) and not meta.board.has_item(rock.uid), "进了仓库")
	t.eq(emitted[0], 1, "面板发了 changed")
	t.check(panel.quick_move(panel._warehouse_view, rock.uid), "双击仓库里的那件")
	t.check(meta.board.has_item(rock.uid), "回到带回来的背包（还有它就能放）")

	# 仓库塞满：双击原地不动、提示行有字
	var w := meta.warehouse
	var fillers := 0
	while w.try_add(ItemInstance.create(_def("filler", ["#"]))):
		fillers += 1
	t.check(fillers > 0, "仓库塞满了（%d 件）" % fillers)
	t.check(not panel.quick_move(panel._board_view, rod.uid), "仓库满了：双击不动")
	t.check(meta.board.has_item(rod.uid), "东西还在带回来的背包里")
	t.check(panel._line.text.contains("放不下"), "提示一句：%s" % panel._line.text)

	t.check(not panel._tidy_btn.disabled, "仓库多于一件：整理可按")
	t.check(panel.tidy(), "整理")
	panel.queue_free()

	# 局外平时没有带回来的背包：双击仓库什么都不做
	var meta2 := MetaState.new()
	var f2 := _flow(meta2)
	var lone := ItemInstance.create(_def("lone", ["#"]))
	meta2.warehouse.try_add(lone)
	var panel2 = load(WAREHOUSE_PANEL).new()
	root.add_child(panel2)
	panel2.setup(f2, UiPalette.cjk_font())
	t.check(not panel2.quick_move(panel2._warehouse_view, lone.uid), "没有带回来的背包：双击不做事")
	t.check(meta2.warehouse.has_item(lone.uid), "还在仓库")
	t.check(panel2._tidy_btn.disabled, "只有一件：整理灰掉")
	panel2.queue_free()
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
#endregion


static func frame_setup_double_click(t: TestCase, root: Window) -> void:
	t.begin("开局屏 · 双击快速置入：仓库 → 初始包、棋盘 → 仓库；初始包本体不动")

	var save := "user://test_109_run.json"
	RunSave.remove(save)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
	var game = load("res://ui/game/game.tscn").instantiate()
	game.save_path = save
	game.meta_path = META
	game.settings_path = SETTINGS
	root.add_child(game)
	var flow: GameFlow = game.flow
	# 序章不过开局屏；把章节许诺的解锁都给上，再挑第一章（同 test_node_storage）
	for gch in flow.chapters:
		if gch.grants_unlock != &"":
			flow.meta.grant_unlock(gch.grants_unlock)
	flow.new_run()
	var setup = game.base()
	for gi in setup._chapters.size():
		if setup._chapters[gi].id == &"free_mode":
			setup.choose_chapter(gi)
	t.not_null(setup.board, "开局屏有初始包的棋盘")
	var w := flow.meta.warehouse
	var pick := -1
	for inst in w.items():
		var item := inst as ItemInstance
		if item.def.shape != null and item.def.shape.cell_count() == 1:
			pick = item.uid
			break
	t.check(pick > 0, "仓库里有一件 1 格的东西")
	if pick > 0 and setup.board != null:
		t.check(setup.quick_move(setup._warehouse_view, pick), "双击仓库里的")
		t.check(setup.board.has_item(pick) and not w.has_item(pick), "进了初始包")
		t.check(setup.quick_move(setup._board_view, pick), "双击棋盘上的")
		t.check(w.has_item(pick) and not setup.board.has_item(pick), "回了仓库")
		var bag_uid := -1
		for inst in setup.board.items():
			if (inst as ItemInstance).def.is_bag:
				bag_uid = (inst as ItemInstance).uid
		t.check(bag_uid > 0, "棋盘上有初始包")
		t.check(not setup.quick_move(setup._board_view, bag_uid), "双击初始包本体：不动")
		t.check(setup.board.has_item(bag_uid), "初始包还在棋盘上")
		t.check(setup._status.text.contains("初始包"), "状态行说了一句：%s" % setup._status.text)
	flow.to_main_menu()
	game.queue_free()
	RunSave.remove(save)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
