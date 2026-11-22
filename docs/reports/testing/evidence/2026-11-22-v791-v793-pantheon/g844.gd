extends SceneTree
## 游戏测试 v7.91（PR #844，报告 366）：守卫联动道具 3 件 + 失效版 3 件 ——
## 逐件查定义、稀有度、价值、说明空、图、格子、标签、战斗规则；不在随机池（ItemDatabase 随机候选）；
## 真开局 A0 / A4 / A8 / A12 各 20 个种子，把战斗 / 精英 / 核心 / 商店 / 搜索点内容整份扫一遍，看这 6 件有没有出现（应该都没有：守卫携带和掉失效版还没接）
const Support := preload("res://tests/run/flow_support.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const RARITY := ["普", "优", "稀", "史", "传"]
const IDS := ["spare_mainspring", "spare_mainspring_spent", "rally_horn", "rally_horn_spent", "beast_king_pact", "beast_king_pact_spent"]


func L(s: String) -> void:
	print("G844 " + s)


func _initialize() -> void:
	call_deferred("_run")


func _scan(v: Variant, hits: Dictionary, where: String) -> void:
	if v is Dictionary:
		for k in v: _scan(v[k], hits, where)
	elif v is Array:
		for e in v: _scan(e, hits, where)
	elif v is String or v is StringName:
		if String(v) in IDS: hits[String(v) + "@" + where] = int(hits.get(String(v) + "@" + where, 0)) + 1


func _run() -> void:
	var c := TestSupport.load_content("free_mode")
	for id in IDS:
		var d: ItemDef = c.items.get_def(StringName(id))
		if d == null: L("%s 不在道具库" % id); continue
		var cells: Array = d.cells_rotated(0)
		L("%s「%s」/「%s」：%s；%d 格；价值 %d；材质 %s；说明「%s|%s」；图 %s；标签 %s；不进随机来源 %s；战斗规则 %s" % [id, d.display_name, String(d.display_names.get("en", "")), RARITY[clampi(d.rarity, 0, 4)], cells.size(), ItemValue.of(d), str(d.get("material")), d.description, String(d.descriptions.get("en", "")), "有" if ResourceLoader.exists("res://assets/items/%s.png" % id) else "无（占位）", str(d.tags), str(d.is_no_random_source()), "无" if d.combat == null or d.combat.rules.is_empty() else str(d.combat.rules.size())])
	var pool := []
	for iid in c.items.ids(): pool.append(String(iid))
	var pool_all := []
	for iid in c.items.ids(true): pool_all.append(String(iid))
	L("图鉴（ids(true)）里有没有：%s" % str(IDS.filter(func(x): return x in pool_all)))
	L("随机候选 ids() 里有没有：%s" % str(IDS.filter(func(x): return x in pool)))
	var defs := {}
	for d in GameFlow.load_difficulties(): defs[(d as DifficultyDef).level] = d
	var kit: LoadoutDef = NodeScreens._kit(c)
	for lv in ([] if OS.get_environment("G844_QUICK") != "" else [0, 4, 8, 12]):
		var d: DifficultyDef = defs.get(lv, null)
		var hits := {}
		var fights := 0
		var nodes := 0
		for seed_ in range(1, 21):
			var f := Support.flow(c, "g844")
			if d != null and d.requires_unlock != &"": f.meta.grant_unlock(d.requires_unlock)
			var run := f.begin(c.chapter, kit, seed_ * 11 + 3, [] as Array[int], null, [], d)
			if run == null: continue
			if run.phase == RunState.Phase.PICK_SPAWN: run.pick_spawn(run.map.entry_ids[0])
			for id in run.map.node_ids():
				var node := run.map.get_node(id)
				var t := NodeEvents.effective_type(node)
				nodes += 1
				_scan(node.content, hits, String(t))
				if (t == &"battle" or t == &"elite") and not node.is_visited():
					run.events.pending = {}; run.events.pending_battle = {}
					run.travel.current_id = id
					run.events.handle(node)
					var content: Dictionary = run.events.pending_battle.get("content", {})
					run.events.pending_battle = {}; run.events.pending = {}
					if not content.is_empty(): fights += 1
					_scan(content, hits, String(t) + "战")
			Support.cleanup("g844")
		L("A%d（%s）：%d 个点、%d 场战斗；6 件出现 %s" % [lv, "有定义" if d != null else "无定义", nodes, fights, str(hits)])
	quit(0)
