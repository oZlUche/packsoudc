extends SceneTree
## 游戏测试 v7.30（PR #780，报告 360 第一批）：各难度档的掉落与搜索下限 —— 真开局、真触发普通战 / 精英战，
## 用游戏自己的秒杀路径（smite_pending_battle：不模拟战斗、按赢了走正式的掉落）收尾，数每场掉几件；搜索点按难度问下限
const Support := preload("res://tests/run/flow_support.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const RARITY := ["普", "优", "稀", "史", "传"]


func L(s: String) -> void:
	print("D360 " + s)


func _initialize() -> void:
	call_deferred("_run")


func _carried(content: Dictionary, items: ItemDatabase) -> Array:
	var o := []
	for e in content.get("items", []):
		var id := StringName(String(e.get("id", "")) if e is Dictionary else String(e))
		if DropResolver.is_droppable(items.get_def(id)): o.append(id)
	return o


func _run() -> void:
	var c := TestSupport.load_content("free_mode")
	var kit: LoadoutDef = NodeScreens._kit(c)
	var defs: Array = []
	for d in GameFlow.load_difficulties(): defs.append(d)
	if not defs.any(func(d): return d.level == 0): defs.append(null)
	defs.sort_custom(func(a, b): return (0 if a == null else a.level) < (0 if b == null else b.level))
	var nr: NodeRules = load(ContentPaths.asset_file("node_rules", "standard"))
	for d in defs:
		var lv: int = 0 if d == null else d.level
		var stats := {"battle": [0, 0, 0, 0], "elite": [0, 0, 0, 0]}     # 场数、持有、掉落、不够下限的场
		var elite_extra := {}
		var floors := {}
		var floor_pct := 0.0
		for seed_ in [3, 7, 11, 19, 23, 31]:
			var f := Support.flow(c, "d360")
			if d != null and d.requires_unlock != &"": f.meta.grant_unlock(d.requires_unlock)     # 测试辅助：解锁这一档
			var run := f.begin(c.chapter, kit, seed_, [] as Array[int], null, [], d)
			if run == null: L("A%d 种子 %d：开不了局" % [lv, seed_]); continue
			if run.phase == RunState.Phase.PICK_SPAWN: run.pick_spawn(run.map.entry_ids[0])
			var ctx: LootContext = run.events._loot_ctx()
			floor_pct = ctx.held_floor if ctx.held_floor >= 0 else float(run.events.drop_rule.held_floor_percent) / 100.0
			for id in run.map.node_ids():
				var node := run.map.get_node(id)
				var t := NodeEvents.effective_type(node)
				if t == &"search":
					floors[String(node.content.get("search_tier", "normal"))] = str(SearchSession.floor_for(node, nr.search, d))
				if not (t == &"battle" or t == &"elite") or node.is_visited(): continue
				run.events.pending = {}
				run.events.pending_battle = {}
				run.pending_loot = null
				run.travel.current_id = id
				run.events.handle(node)
				if run.events.pending_battle.is_empty(): continue
				var content: Dictionary = run.events.pending_battle.get("content", {})
				var left := _carried(content, c.items)
				var m := left.size()
				run.events.smite_pending_battle()
				var got := 0
				var rar := []
				if run.pending_loot != null:
					for it in run.pending_loot.items():
						var at := left.find((it as ItemInstance).def.id)
						if at >= 0: left.remove_at(at); got += 1
						rar.append(int((it as ItemInstance).def.rarity))
				var s: Array = stats[String(t)]
				s[0] += 1; s[1] += m; s[2] += got
				if t == &"battle" and got < ceili(float(m) * floor_pct - 0.000001): s[3] += 1
				if t == &"elite" and not rar.is_empty():
					var top: int = rar.max()
					elite_extra[RARITY[top]] = int(elite_extra.get(RARITY[top], 0)) + 1
				run.pending_loot = null
				if run.is_over(): break
			Support.cleanup("d360")
		var b: Array = stats["battle"]
		var e: Array = stats["elite"]
		L("A%d：持有物下限 %d%%；精英额外稀有度 %s；搜索下限 %s" % [lv, roundi(floor_pct * 100), str(d.elite_rarity if d != null else (load(ContentPaths.asset_file("drop_rules", "standard")) as DropRule).elite_rarity), str(floors)])
		L("　　普通战 %d 场：能随机掉的持有物 %d 件、其中掉了 %d 件（%.0f%%），不够下限的场 %d；精英战 %d 场：持有 %d、掉 %d，每场最好那件 %s" % [b[0], b[1], b[2], 100.0 * b[2] / maxf(1, b[1]), b[3], e[0], e[1], e[2], str(elite_extra)])
	quit(0)
