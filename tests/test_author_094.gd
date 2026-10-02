## 094（作者定）：带入预算 —— 从仓库带进一局的道具总价值有预算（规模档 > 章节），超出的部分换倒计时（每超 carry_over_cost 价值 −1）；预设与角色初始包不算
extends RefCounted

const SAVE := "user://test_094_run.json"
const META := "user://test_094_meta.json"
const SETTINGS := "user://test_094_settings.json"
const NodeScreens := preload("res://tests/test_node_screens.gd")


static func _cleanup() -> void:
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func run_carry_budget(t: TestCase) -> void:
	t.begin("094 · 带入预算：小 600 / 中 900 / 大 1200（章节兜底 600）；超出每 50 价值倒计时 −1，至少留 1；关闭的撤离点按罚后的一半；存档带着带入价值；开局屏的读数一行；序章没有预算")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	t.eq(RunState.carry_budget_for(c.chapter, &"small"), 600, "小图预算 600")
	t.eq(RunState.carry_budget_for(c.chapter, &"medium"), 900, "中图 900")
	t.eq(RunState.carry_budget_for(c.chapter, &"large"), 1200, "大图 1200")
	t.eq(RunState.carry_budget_for(c.chapter, &""), RunState.carry_budget_for(c.chapter, RunState.scale_profile_of(c.chapter, &"").id), "默认规模 = 章节配置里默认那一档")
	t.eq(RunState.carry_budget_for(c.prologue, &""), 0, "序章没有预算")
	t.eq(RunState.carry_over_for(c.chapter, &"small", 420), 0, "420 没超")
	t.eq(RunState.carry_over_for(c.chapter, &"small", 750), 150, "750 超 150")
	t.eq(RunState.carry_penalty_for(c.chapter, &"small", 750), 3, "超 150 → −3 步")
	t.eq(RunState.carry_penalty_for(c.chapter, &"small", 649), 0, "超 49 不够一档：不罚")
	t.eq(RunState.countdown_limit_for(c.chapter, &"small", 750), 33, "小图 36 − 3 = 33")
	t.eq(RunState.countdown_limit_for(c.chapter, &"small", 600 + 50 * 100), 1, "罚到底至少留 1")
	t.eq(RunState.countdown_limit_for(c.prologue, &"", 99999), 0, "序章没倒计时：还是 0")
	# 一局：带入价值进开局，倒计时与关闭的撤离点按罚后的算
	var s := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, kit.items, {}, [] as Array[StringName], null, [], null, {}, &"small", {}, 750)
	if s == null:
		t.check(true, "（这个种子生成不出小图，跳过）")
	else:
		t.eq(s.carry_in_value, 750, "记着带入 750")
		t.eq(s.carry_budget(), 600, "预算 600")
		t.eq(s.carry_penalty_steps(), 3, "罚 3 步")
		t.eq(s.countdown_limit(), 33, "倒计时 33")
		s.pick_spawn(s.map.entry_ids[0])
		t.eq(s.countdown_left(), 33, "开局剩 33")
		var closing := s.closing_extract_id()
		if closing >= 0:
			t.eq(PaidExtracts.closes_at(s.map.get_node(closing)), 16, "关闭的撤离点按 33 / 2 = 16")
		var back := RunState.from_dict(s.to_dict(), c.chapter, c.items, c.enemies, c.sets)
		t.check(back != null and back.carry_in_value == 750 and back.countdown_limit() == 33, "存档往返：带入价值与倒计时都在")
	var plain := RunState.start(c.chapter, 3, c.items, c.enemies, c.sets, kit.items, {}, [] as Array[StringName], null, [], null, {}, &"small")
	if plain != null:
		t.check(plain.carry_in_value == 0 and plain.countdown_limit() == 36, "不带：不罚")
	# GameFlow.begin：按 uid 从仓库带的自动算价值
	_cleanup()
	var f: GameFlow = NodeScreens._flow(c)
	f.save_path = SAVE
	f.meta_path = META
	f.settings_path = SETTINGS
	var defs_added: Array = []
	var total := 0
	for id in [&"plate_cuirass", &"longsword", &"rifle"]:
		var d: ItemDef = c.items.get_def(id)
		if d == null:
			continue
		var inst := ItemInstance.create(d)
		if f.meta.warehouse.try_add(inst, true):
			defs_added.append(inst.uid)
			total += ItemValue.of(d)
	var uids: Array[int] = []
	for u in defs_added:
		uids.append(int(u))
	var run := f.begin(c.chapter, kit, 5, uids, null, [], null, &"small")
	t.check(run != null, "开局")
	if run != null:
		t.eq(run.carry_in_value, total, "从仓库按 uid 带的：价值自动算（%d）" % total)
		t.eq(run.countdown_limit(), RunState.countdown_limit_for(c.chapter, &"small", total), "倒计时按它罚")
	# 开局屏那一行
	var SetupScript = load("res://ui/game/setup_screen.gd")
	t.check(String(SetupScript.carry_text(c.chapter, &"small", 420)).contains("已带 420") and not String(SetupScript.carry_text(c.chapter, &"small", 420)).contains("超出"), "没超：绿字「带入预算 600：已带 420」")
	var over_text: String = SetupScript.carry_text(c.chapter, &"small", 750)
	t.check(over_text.contains("超出 150") and over_text.contains("倒计时 −3") and over_text.contains("36 → 33"), "超了：说清超多少、扣几步（%s）" % over_text)
	t.eq(String(SetupScript.carry_text(c.prologue, &"", 999)), "", "序章没有预算：不显示")
	_cleanup()
