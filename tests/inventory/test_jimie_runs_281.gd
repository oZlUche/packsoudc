## 281 寂灭的路 ①：同一把法杖反复进出局 —— 10 次起变色，50 次全黑
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func run_counter(t: TestCase) -> void:
	t.begin("281 · 法杖记完整进出局：带进去 + 回基地（撤离 / 保险箱）= 1 次；不是法杖、红武本体不记；0 次不写键")
	var db := _db()
	var staff := ItemInstance.create(db.get_def(&"magic_staff"))
	t.check(staff.state.is_empty(), "新的：不写键")
	staff.close_run()
	t.eq(staff.runs(), 0, "没带进去过：回基地不算")
	staff.mark_run_in()
	t.eq(staff.runs(), 0, "带进去还没回来：不算")
	staff.close_run()
	t.eq(staff.runs(), 1, "回来了：1 次")
	t.check(not staff.state.has(ItemInstance.RUN_IN_KEY), "记号摘掉")
	var sword := ItemInstance.create(db.get_def(&"longsword"))
	sword.mark_run_in()
	t.check(sword.state.is_empty(), "长剑不记")
	var red := ItemInstance.create(db.get_def(&"jimie"))
	red.mark_run_in()
	t.check(red.state.is_empty(), "寂灭本体不记")
	var back := ItemInstance.from_dict(staff.to_dict(), db)
	t.eq(back.runs(), 1, "存档读回来还在")


static func run_flow(t: TestCase) -> void:
	t.begin("281 · 一局里：开局带进来的法杖记号，撤离回仓库 +1；49 次的再进出一次就全黑")
	var c := TestSupport.load_content("free_mode", ["buffs"])
	var layout := [{"id": "magic_staff", "origin": [0, 0], "rot": 0, "state": {ItemInstance.RUNS_KEY: 49}}]
	var run := RunState.start(c.chapter, 7, c.items, c.enemies, c.sets, [] as Array[StringName], c.buffs, [] as Array[StringName], null, layout)
	var staffs: Array = run._owned_now().filter(func(i: ItemInstance) -> bool: return i.def.id == &"magic_staff")
	t.eq(staffs.size(), 1, "法杖带进来了")
	if staffs.is_empty():
		return
	var staff: ItemInstance = staffs[0]
	t.check(staff.state.has(ItemInstance.RUN_IN_KEY), "开局记号")
	t.check(not staff.is_black_staff(), "49 次：还没全黑")
	var meta := MetaState.new()
	t.check(meta._adopt(staff), "回基地")
	t.eq(staff.runs(), 50, "50 次")
	t.check(staff.is_black_staff(), "全黑法杖")


static func run_tint(t: TestCase) -> void:
	t.begin("281 · 法杖的图：10 次以内原色，之后越来越暗，50 次全黑")
	var db := _db()
	var staff := ItemInstance.create(db.get_def(&"magic_staff"))
	t.eq(ItemPainter.runs_tint(staff), Color.WHITE, "0 次：原色")
	staff.state[ItemInstance.RUNS_KEY] = 10
	t.eq(ItemPainter.runs_tint(staff), Color.WHITE, "10 次：刚起")
	staff.state[ItemInstance.RUNS_KEY] = 30
	var mid := ItemPainter.runs_tint(staff)
	t.check(mid.r < 1.0 and mid.r > ItemPainter.RUNS_BLACK_TINT.r, "30 次：一半暗")
	staff.state[ItemInstance.RUNS_KEY] = 80
	t.check(ItemPainter.runs_tint(staff).is_equal_approx(ItemPainter.RUNS_BLACK_TINT), "50 次起：全黑")
	var sword := ItemInstance.create(db.get_def(&"longsword"))
	sword.state[ItemInstance.RUNS_KEY] = 80
	t.eq(ItemPainter.runs_tint(sword), Color.WHITE, "不是法杖：原色")
