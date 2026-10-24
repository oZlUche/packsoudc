## 159（作者定）：离开时没拿的战利品落到这个点的地上，不再消失（所有地图）；开着的搜索只落亮过的；BOSS 战利品屏的「收起」仍是不要了
extends RefCounted

const RunStateTests := preload("res://tests/run/test_run_state.gd")


static func _box(c: TestSupport.Content, ids: Array[StringName]) -> GridInventory:
	var box := GridInventory.new(Vector2i(6, 4), 0, false)
	for id in ids:
		box.try_add(ItemInstance.create(c.items.get_def(id), 0), true)
	return box


static func run(t: TestCase) -> void:
	t.begin("159 · 走开时待拾取倒到地上：件数一件不少、地上的东西跟着这个点走（存进这个点）")
	var c := TestSupport.load_content()
	var s := RunStateTests._start_with_battle_next(c)
	if s == null:
		t.check(false, "开不了局")
		return
	var here := s.travel.current_id
	var before := s.storage.item_count()
	s._offer_loot(_box(c, [&"ration", &"bandage", &"salve"] as Array[StringName]))
	var n := s.pending_loot.item_count()
	t.eq(n, 3, "三件待拾取")
	var target := -1
	for id in s.travel.available_moves():
		target = id
		break
	t.check(target >= 0, "有路可走")
	var nsm := NodeStorageModule.of(s)
	s.step_to(target)
	t.check(s.pending_loot == null or s.travel.current_id == target, "走开之后原来那份待拾取没了")
	var left: Array = nsm.stored_at(here) if nsm != null else []
	t.eq(left.size(), before + n, "原来那个点的地上：原有 %d + 落下 %d" % [before, n])

	t.begin("159 · 包也落地（先倒内容、再放空包）；关会话之前记下的「没亮过」不落")
	var s2 := RunStateTests._start(c, 7)
	var loot := _box(c, [&"ration", &"bandage"] as Array[StringName])
	s2._offer_loot(loot)
	var skip := {}
	var first := (s2.pending_loot.items()[0] as ItemInstance).uid
	skip[first] = true
	var g0 := s2.storage.item_count()
	s2._drop_pending_loot(skip)
	t.eq(s2.storage.item_count(), g0 + 1, "跳过的那件不落，另一件落地")
	t.check(not s2.storage.has_item(first), "没亮过的不在地上")

	t.begin("159 · 开着的搜索走开：搜索屏里亮过的落地，没亮过的算没搜到")
	var s3 := RunStateTests._start(c, 11)
	var session := SearchSession.new(null, s3.node_rules.search, c.items, RandomNumberGenerator.new())
	session.haul_box.try_add(ItemInstance.create(c.items.get_def(&"ration"), 0), true)
	session.haul_box.try_add(ItemInstance.create(c.items.get_def(&"bandage"), 0), true)
	var seen_uid := (session.haul_box.items()[0] as ItemInstance).uid
	var hidden_uid := (session.haul_box.items()[1] as ItemInstance).uid
	s3.events.current_search = session
	s3.loot_seen = func(uid: int) -> bool: return uid == seen_uid
	t.eq(s3._unseen_search_haul().keys(), [hidden_uid], "记下没亮过的那一件")
	s3.loot_seen = Callable()
	t.eq(s3._unseen_search_haul(), {}, "没接（纯核心）：都算亮过")
	s3.events.current_search = null

	t.begin("159 · 拿完 / 全拿 / BOSS 收起这几条照旧：拿完的空容器、明确不要的不往地上倒")
	var s4 := RunStateTests._start(c, 13)
	s4._offer_loot(_box(c, [&"ration"] as Array[StringName]))
	var g4 := s4.storage.item_count()
	s4.discard_loot()
	t.check(s4.pending_loot == null and s4.storage.item_count() == g4, "discard_loot（BOSS 收起 = 不要了）：不落地")
