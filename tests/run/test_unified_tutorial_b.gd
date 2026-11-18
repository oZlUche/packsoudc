## 统一教程 B 批（方案 docs/plans/2026-11-18-unified-tutorial-and-base-return.md §9 / §12.1）：
## 三段教程的固定奖励走同一本账 —— 跳过补未领的、正常撤离领自己那段；重复点、读档都不重复发；放不下的记着不丢；老档不追发
extends RefCounted

const Support := preload("res://tests/run/flow_support.gd")
const ResultScreenScript := preload("res://ui/game/result_screen.gd")
const PREFIX := "unified_b"


static func _flow(c: TestSupport.Content, p_profile: StringName = &"") -> GameFlow:
	var f := Support.flow(c, PREFIX, 0.0, c.meta_rules)
	f.profile = p_profile
	f.chapters = GameFlow.load_chapters(p_profile)
	return f


static func _count(m: MetaState, id: StringName) -> int:
	var n := 0
	for inst in m.warehouse.items():
		if (inst as ItemInstance).def.id == id:
			n += 1
	return n


static func _owed_ids(f: GameFlow) -> Array:
	var ids: Array = []
	for c in f.tutorial_chapters():
		ids.append_array(Array(c.tutorial_items))
	return ids


static func run_table(t: TestCase) -> void:
	t.begin("统一教程 B · 奖励表：三段 100 / 150 / 200 金币，道具都在道具库里；两档同一张表")
	var c := TestSupport.load_content("free_mode", ["loadouts", "meta_rules"])
	for p in [&"", SliceProfile.SLICE]:
		var f := _flow(c, p)
		var tuts := f.tutorial_chapters()
		t.eq(tuts.map(func(ch: ChapterDef) -> int: return ch.tutorial_funds), [100, 150, 200], "%s：三段金币" % p)
		for ch in tuts:
			for id in ch.tutorial_items:
				t.not_null(c.items.get_def(id), "%s 的奖励 %s 在道具库里" % [ch.id, id])
		t.check(tuts[2].tutorial_items_carried and not tuts[0].tutorial_items_carried, "只有第三段的信物按带回来的抵")


static func run_skip_fresh(t: TestCase) -> void:
	t.begin("统一教程 B · 新档跳过：开局那套 + 三段 450 金币 + 七件道具；再跳一次、读档再跳都不重复发")
	var c := TestSupport.load_content("free_mode", ["loadouts", "meta_rules"])
	var f := _flow(c)
	var pre := f.skip_preview()
	t.eq(int(pre["funds"]), 450, "清单：补 450 金币")
	t.eq((pre["items"] as Array).size(), _owed_ids(f).size(), "清单：三段的道具都在")
	t.check(f.skip_prologue(), "跳过并存了盘")
	t.eq(f.meta.funds, 450, "金币进了余额")
	for id in [&"knife", &"whetstone", &"charm_brute", &"charm_sun"]:
		t.check(_count(f.meta, id) >= 1, "仓库里有 %s" % id)
	for ch in f.tutorial_chapters():
		t.eq(TutorialRewards.state_of(f.meta, ch.id), TutorialRewards.SKIPPED, "%s 记成跳过" % ch.id)
	t.check(TutorialRewards.claimed(f.meta, TutorialRewards.START), "开局那套也记了账")
	var held := f.meta.warehouse.item_count()
	f.skip_prologue()
	t.eq(f.meta.funds, 450, "再跳一次：金币不变")
	t.eq(f.meta.warehouse.item_count(), held, "再跳一次：道具不变")
	t.eq(int(f.skip_preview()["funds"]), 0, "清单空了")
	# 花掉、卖掉之后也不补
	f.meta.spend_funds(400)
	var charm := -1
	for inst in f.meta.warehouse.items():
		if (inst as ItemInstance).def.id == &"charm_sun":
			charm = (inst as ItemInstance).uid
	f.meta.sell_item(charm)
	var back := MetaSave.read(c.items, f.meta_path, c.meta_rules, f.tech_defs)
	t.not_null(back, "读得回来")
	if back != null:
		for ch in f.tutorial_chapters():
			t.check(TutorialRewards.claimed(back, ch.id), "读档：%s 还记着领过" % ch.id)
		var g := _flow(c)
		g.meta = back
		var funds := back.funds
		var n := back.warehouse.item_count()
		g.skip_prologue()
		t.eq(back.funds, funds, "读档后再跳：不补金币")
		t.eq(back.warehouse.item_count(), n, "读档后再跳：不补道具")
	var again := _flow(c)
	again.meta = f.meta
	again.skip_prologue()
	t.eq(_count(f.meta, &"charm_sun"), 0, "卖掉的信物不补第二次")
	Support.cleanup(PREFIX)


static func run_partial(t: TestCase) -> void:
	t.begin("统一教程 B · 第一段打通后跳过：只补第二、三段的 350 金币和它们的道具；第三段带回的信物抵名额")
	var c := TestSupport.load_content("free_mode", ["loadouts", "meta_rules"])
	var f := _flow(c)
	var tuts := f.tutorial_chapters()
	var got := TutorialRewards.claim(f.meta, tuts[0], c.items, TutorialRewards.COMPLETED)
	t.eq(int(got["funds"]), 100, "第一段正常领 100")
	t.eq(TutorialRewards.claim(f.meta, tuts[0], c.items, TutorialRewards.COMPLETED), {}, "同一段再领：什么也不发")
	var pre := f.skip_preview()
	t.eq(int(pre["funds"]), 350, "清单：只剩 350")
	t.check((pre["claimed"] as Array).size() == 1 and (pre["claimed"] as Array).has(&"prologue"), "清单：第一段标已领")
	f.skip_prologue()
	t.eq(f.meta.funds, 450, "合计 450（100 + 350）")
	t.eq(TutorialRewards.state_of(f.meta, &"prologue"), TutorialRewards.COMPLETED, "第一段还是正常完成，没被改成跳过")
	# 第三段：带回来一枚蛮神信物 —— 只补日神那枚
	var h := _flow(c)
	var brute := ItemInstance.create(c.items.get_def(&"charm_brute"), 0)
	var res := TutorialRewards.claim(h.meta, h.tutorial_chapters()[2], c.items, TutorialRewards.COMPLETED, [brute])
	t.eq(res["items"], ["charm_sun"], "带回了蛮神的：只补日神的")
	t.eq(int(res["funds"]), 200, "金币照发")
	Support.cleanup(PREFIX)


static func run_started_then_skip(t: TestCase) -> void:
	t.begin("统一教程 B · 第三段打到一半跳过：账本从「进行中」变成跳过，奖励全补（局里拿的没带回来）")
	var c := TestSupport.load_content("free_mode", ["loadouts", "meta_rules"])
	var f := _flow(c)
	var tuts := f.tutorial_chapters()
	TutorialRewards.mark(f.meta, tuts[0].id, TutorialRewards.COMPLETED)
	TutorialRewards.mark(f.meta, tuts[1].id, TutorialRewards.COMPLETED)
	TutorialRewards.mark(f.meta, tuts[2].id, TutorialRewards.STARTED)
	t.check(not TutorialRewards.claimed(f.meta, tuts[2].id), "进行中不算领过")
	f.skip_prologue()
	t.eq(TutorialRewards.state_of(f.meta, tuts[2].id), TutorialRewards.SKIPPED, "记成跳过")
	t.check(_count(f.meta, &"charm_brute") == 1 and _count(f.meta, &"charm_sun") == 1, "两枚信物都补了")
	t.eq(f.meta.funds, 200, "只补第三段的 200")
	Support.cleanup(PREFIX)


static func run_first_kit_once(t: TestCase) -> void:
	t.begin("统一教程 B · 开局那套按账本只发一次：仓库卖空了也不再发")
	var c := TestSupport.load_content("free_mode", ["loadouts", "meta_rules"])
	var f := _flow(c)
	var n := f.grant_first_kit()
	t.check(n > 0, "新档发了 %d 件" % n)
	var uids: Array = f.meta.warehouse.items().map(func(i: ItemInstance) -> int: return i.uid)
	for u in uids:
		f.meta.sell_item(int(u))
	t.eq(f.meta.warehouse.item_count(), 0, "卖空了")
	t.eq(f.grant_first_kit(), 0, "不再发第二套")


static func run_legacy(t: TestCase) -> void:
	t.begin("统一教程 B · 老档：打通过的段记成老档领过、不追发；出过远征的开局那套也算领过；没打的段照常能领")
	var c := TestSupport.load_content("free_mode", ["loadouts", "meta_rules"])
	var f := _flow(c)
	f.meta.runs = 3
	f.meta.grant_unlock(&"prologue_done")
	f._migrate_tutorial_ledger()
	t.eq(TutorialRewards.state_of(f.meta, &"prologue"), TutorialRewards.LEGACY, "第一段：老档领过")
	t.eq(TutorialRewards.state_of(f.meta, &"prologue_2"), "", "第二段：还没开始")
	t.eq(f.grant_first_kit(), 0, "开局那套不补")
	t.eq(int(f.skip_preview()["funds"]), 350, "跳过只补没打的两段")


static func run_lossless(t: TestCase) -> void:
	t.begin("统一教程 B · 放不下的奖励不丢不折钱：记成待入库、存档带着、腾出地方再放进去")
	var c := TestSupport.load_content("free_mode", ["loadouts", "meta_rules"])
	var rules := MetaRules.new()
	rules.warehouse_size = Vector2i(1, 1)
	var m := MetaState.new(rules)
	var got := m.grant_lossless([c.items.get_def(&"shortsword"), c.items.get_def(&"bandage")])
	t.eq(int(got["stored"]), 1, "一格的纱布进了仓库")
	t.eq(int(got["pending"]), 1, "三格的短剑放不下：待入库")
	t.eq(m.funds, 0, "不折钱")
	var uid := m.reward_pending[0].uid
	var back := MetaState.from_dict(m.to_dict(), c.items, rules)
	t.check(back != null and back.reward_pending.size() == 1 and back.reward_pending[0].uid == uid, "存档带着待入库那件（uid 不变）")
	t.eq(m.store_pending(), 0, "还是放不下：留着")
	t.eq(m.reward_pending.size(), 1, "没丢")
	var roomy := MetaState.new(c.meta_rules)
	roomy.reward_pending.append(m.reward_pending[0])
	t.eq(roomy.store_pending(), 1, "地方够了：放进去")
	t.check(roomy.reward_pending.is_empty() and roomy.warehouse.has_item(uid), "进了仓库")


static func run_result_panel(t: TestCase) -> void:
	t.begin("统一教程 B · 结算屏的教程奖励小纸：发了才摆（金币 + 道具图），没发不摆")
	var c := TestSupport.load_content("free_mode", ["loadouts", "meta_rules"])
	t.is_null(ResultScreenScript.tutorial_reward_panel({}, c.items), "没发：不摆")
	var box := ResultScreenScript.tutorial_reward_panel({"funds": 100, "items": ["knife", "bandage"], "pending": 0}, c.items)
	t.not_null(box, "发了：摆一张")
	if box != null:
		var coins := 0
		var pics := 0
		for n in box.find_children("*", "", true, false):
			if n is CoinLabel:
				coins += 1
			elif n is TextureRect and n.get_parent() is HFlowContainer:
				pics += 1
		t.eq(coins, 1, "一枚金币")
		t.eq(pics, 2, "两张道具图")
		box.free()
