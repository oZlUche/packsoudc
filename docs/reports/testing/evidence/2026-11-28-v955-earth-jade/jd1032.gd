extends SceneTree
## v9.55（PR #1032）大地之神【玉石俱焚】改版：开战消耗最高价的道具并造成价值的伤害；大地结晶一摞消耗一半（向上取整）
const G := preload("res://tests/run/test_god_cards_388.gd")
var bad := 0

func ok(c: bool, msg: String) -> void:
	print("JD1032 %s %s" % ["OK " if c else "BAD", msg])
	if not c: bad += 1

func _v(run: RunState, inst: ItemInstance) -> int:
	return ItemValue.of_in(inst, run.board)

func _jade(run: RunState) -> int:
	return EarthHeavenPerk.effect_for(LevelModule.of(run), run.board, run).jade

func _clear(run: RunState) -> void:
	for raw in run.board.items():
		var inst := raw as ItemInstance
		if not run.board.acts_as_bag(inst.def) and not inst.def.is_keepsake():
			run.board.remove(inst.uid)

func _init() -> void:
	var run := G._start(1032, &"earth")
	var lv := LevelModule.of(run)
	ok(run.active_faith_id() == &"earth", "开局奉大地之神")
	var start := []
	for raw in run.board.items():
		var i := raw as ItemInstance
		start.append("%s(值%d%s)" % [i.def.id, _v(run, i), "，包" if run.board.acts_as_bag(i.def) else ""])
	print("JD1032 开局棋盘：", ", ".join(start))
	ok(EarthHeavenPerk.jade_uid(run) == -1, "没拿牌：jade_uid = -1")
	lv.taken["god_earth_jade"] = 1
	_clear(run)
	ok(EarthHeavenPerk.jade_uid(run) == -1 and _jade(run) == 0, "只剩包和信物：不消耗、不出伤害")
	# 1 挑最贵
	var ss := TestSupport.put(run.board, run.items.get_def(&"shortsword"))
	var bs := TestSupport.put(run.board, run.items.get_def(&"dense_basalt"))
	var lg := TestSupport.put(run.board, run.items.get_def(&"flame_bonesteel_broadsword"))
	print("JD1032 值：短剑 %d、玄武岩 %d、传说骨钢大剑 %d" % [_v(run, ss), _v(run, bs), _v(run, lg)])
	ok(EarthHeavenPerk.jade_uid(run) == lg.uid, "挑最贵的那件（传说大剑）")
	ok(_jade(run) == _v(run, lg), "伤害 = 它的价值 %d" % _jade(run))
	# 2 锁住 / 不参战 / 基石跳过
	lg.set_locked(true)
	ok(EarthHeavenPerk.jade_uid(run) != lg.uid, "玩家上锁：跳过，改挑 %s" % run.board.get_item(EarthHeavenPerk.jade_uid(run)).def.id)
	lg.set_locked(false); lg.set_benched(true)
	ok(EarthHeavenPerk.jade_uid(run) != lg.uid, "标了不参战：跳过")
	lg.set_benched(false); lg.set_stone(true)
	ok(EarthHeavenPerk.jade_uid(run) != lg.uid, "成了基石：跳过")
	lg.set_stone(false)
	# 3 委托物 / 随身之物 / 信物：给它们 9999 的价值也跳过
	for id in [&"commission_letter", &"legion_phalera", &"spyglass"]:
		var d := run.items.get_def(id)
		if d == null: ok(false, "没有 %s" % id); continue
		var x := TestSupport.put(run.board, d)
		if x == null: ok(false, "%s 放不下" % id); continue
		x.state["value"] = 9999
		ok(EarthHeavenPerk.jade_uid(run) == lg.uid, "%s（委托 %s / 随身 %s / 信物 %s）值 9999 也跳过" % [id, d.is_commission(), d.is_signature(), d.is_keepsake()])
		run.board.remove(x.uid)
	# 4 一样贵取 uid 小的
	_clear(run)
	var a := TestSupport.put(run.board, run.items.get_def(&"shortsword"))
	var b := TestSupport.put(run.board, run.items.get_def(&"shortsword"))
	ok(a.uid < b.uid and EarthHeavenPerk.jade_uid(run) == a.uid, "两把一样的短剑：挑 uid 小的 %d（另一把 %d）" % [a.uid, b.uid])
	ok(EarthHeavenPerk.consume_jade(run) != "" and not run.board.has_item(a.uid) and run.board.has_item(b.uid), "普通道具整件消耗，另一把还在")
	# 5 大地结晶一摞
	_clear(run)
	for n in [5, 4, 3, 2, 1]:
		var c := TestSupport.put(run.board, run.items.get_def(&"earth_crystal"))
		c.set_stack(n)
		var dmg := _jade(run)
		var full := _v(run, c)
		EarthHeavenPerk.consume_jade(run)
		var left := c.stack_count() if run.board.has_item(c.uid) else 0
		ok(dmg == full and left == n - maxi(1, ceili(n / 2.0)), "结晶 %d 个：伤害 %d（整摞价值 %d），剩 %d 个" % [n, dmg, full, left])
		_clear(run)
	# 6 百宝囊的倍率算进伤害
	var sat := TestSupport.put(run.board, run.items.get_def(&"treasure_satchel"))
	if sat != null:
		var inbag := TestSupport.put_where(run.board, run.items.get_def(&"shortsword"), func(i): return _in_bag(run.board, i, sat))
		if inbag != null:
			ok(_jade(run) == _v(run, inbag) and _v(run, inbag) > ItemValue.of_instance(inbag), "百宝囊里的短剑：伤害 %d（本身 %d，×1.25）" % [_jade(run), ItemValue.of_instance(inbag)])
		else: print("JD1032 SKIP 短剑放不进百宝囊")
	_clear(run)
	# 7 真走 before_battle 钩子：先编进伤害、再消耗；下一场换下一件
	var w1 := TestSupport.put(run.board, run.items.get_def(&"flame_bonesteel_broadsword"))
	var w2 := TestSupport.put(run.board, run.items.get_def(&"shortsword"))
	var me := run.compile_player()
	var foe := CombatantSpec.new()
	run.hooks.before_battle(me, foe, &"battle")
	ok(not run.board.has_item(w1.uid) and run.board.has_item(w2.uid), "开打钩子：最贵的大剑消耗了，短剑还在")
	ok(_jade(run) == _v(run, w2), "下一场的伤害换成短剑的价值 %d" % _jade(run))
	run.dispose()
	print("JD1032 完 BAD %d" % bad)
	quit(0)

func _in_bag(board: GridInventory, inst: ItemInstance, bag: ItemInstance) -> bool:
	for c in inst.absolute_cells(inst.cells()):
		if board.bag_at(c) != bag.uid: return false
	return true
