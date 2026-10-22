## 236 ④：不要了的一局放得掉 —— 局与模块、系统、hook 表互相抓着（[RunModule] 的 `_run`、骨架接在节点事件 / 旅程上的 lambda），
## 引用计数放不掉成环的东西；[method RunState.dispose] 解环，[GameFlow] 换局后下一帧调
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["characters", "hunter_defs", "difficulties", "loadouts", "faiths", "recipes", "buffs", "events"])


## 机制最多的那档难度（猎手、侵蚀都装上）
static func _hardest(c: TestSupport.Content) -> DifficultyDef:
	var best: DifficultyDef = null
	for d in c.difficulties:
		if best == null or d.mechanics.size() > best.mechanics.size():
			best = d
	return best


static func run_dispose_frees(t: TestCase) -> void:
	t.begin("236 · 放旧局：dispose 之后没人拿着就放掉（模块、系统、hook、lambda 不再成环）；不 dispose 放不掉")
	var c := _content()
	var diff := _hardest(c)
	var s := CS._start(c, CS._character(c, &"marcus"), diff, c.hunter_defs)
	if s == null:
		t.check(false, "开不了局")
		return
	s.step_to(s.travel.available_moves()[0])
	t.check(not s.modules.is_empty() and s.hooks.has(&"player_spec"), "局里装着模块、骨架接了 hook")
	t.check(s.hunters != null and s.travel.erosion != null, "难度 %s 装了猎手与侵蚀" % diff.id)
	var held: WeakRef = weakref(s)
	var mods: Array = s.modules.values()
	s.dispose()
	t.check(s.modules.is_empty() and not s.hooks.has(&"player_spec"), "dispose：模块表空、hook 全撤")
	t.check(mods.all(func(m: RunModule) -> bool: return m._run == null), "每个模块都放掉了局")
	t.check(s.hunters.run == null and s.travel.erosion.run == null and s.skills.run == null and s.faith_power.run == null, "猎手 / 侵蚀 / 技能 / 信力放掉了局")
	mods.clear()
	s = null
	t.check(held.get_ref() == null, "没人拿着之后整局放掉了")
	var leak := CS._start(c, CS._character(c, &"marcus"), diff, c.hunter_defs)
	var leaked: WeakRef = weakref(leak)
	leak = null
	t.check(leaked.get_ref() != null, "对照：不 dispose 的局放不掉（成环）")
	(leaked.get_ref() as RunState).dispose()     # 收拾掉对照组
	t.check(leaked.get_ref() == null, "对照组 dispose 之后也放掉了")


static func run_flow_defers(t: TestCase) -> void:
	t.begin("236 · 放旧局：开新局时旧局这一帧还完好（结算屏、result 还在读），dispose 留到下一帧")
	var c := _content()
	var f := Support.flow(c, "dispose236")
	var lo: LoadoutDef = c.loadouts[0] if not c.loadouts.is_empty() else null
	var first := f.begin(c.chapter, lo, 11)
	if first == null:
		t.check(false, "开不了局")
		return
	f.begin(c.chapter, lo, 12)
	t.check(f.run != first, "换了新局")
	t.check(not first.modules.is_empty() and first.hooks.has(&"player_spec"), "旧局这一帧还没拆")
	f._adopt(f.run)
	t.check(not f.run.modules.is_empty(), "同一局再接一次不会拆自己")
	f.to_main_menu()
	t.check(f.run == null, "回主菜单：局没了（下一帧拆）")
	Support.cleanup("dispose236")
