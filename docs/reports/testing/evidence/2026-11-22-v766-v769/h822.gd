extends SceneTree
## 游戏测试 v7.69（PR #822）：新精英处刑人、雷羽鹫调强 —— 无头：定义、图、在哪种点出现、带什么；
## 真开局在 A0 / A4 / A8 各 40 个种子上，把每个战斗 / 精英点触发出来，记处刑人和雷羽鹫的点类型、所在区、生命、带的东西
const Support := preload("res://tests/run/flow_support.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const IDS := ["executioner", "thunder_vulture"]
const RARITY := ["普", "优", "稀", "史", "传"]


func L(s: String) -> void:
	print("H822 " + s)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var c := TestSupport.load_content("free_mode")
	for id in IDS:
		var d: EnemyDef = c.enemies.enemy(StringName(id))
		if d == null: L("%s 不在敌人库" % id); continue
		var face := "res://assets/portraits/enemies/%s.png" % id
		var rel := "res://assets/portraits/enemies/relief/%s.png" % id
		L("%s「%s」：魔兽 %s；强度 %d；生命 %s；耐力回复 %s；招牌 %s；头像底 %s、浮雕 %s；名字 铜「%s」金「%s」" % [id, Names.of(d), str(d.is_wild()), d.strength, str(d.base_stats.get("max_hp", "-")), str(d.base_stats.get("regen_stamina", "-")), str(d.signature), str(ResourceLoader.exists(face)), str(ResourceLoader.exists(rel)), EnemyRank.prefix(d, 0) + Names.of(d), EnemyRank.prefix(d, 2) + Names.of(d)])
	var axe := c.items.get_def(&"executioner_axe")
	L("刽子手巨斧：%s" % ("不在" if axe == null else "%s、%s、%d 格" % [Names.of(axe), RARITY[clampi(axe.rarity, 0, 4)], axe.shape_cells().size() if axe.has_method("shape_cells") else -1]))
	var defs := {}
	for d in GameFlow.load_difficulties(): defs[(d as DifficultyDef).level] = d
	var kit: LoadoutDef = NodeScreens._kit(c)
	for lv in [0, 4, 8]:
		var d: DifficultyDef = defs.get(lv, null)
		var where := {}
		var hp := {}
		var items := {}
		var rar := {}
		var fights := 0
		for seed_ in range(1, 41):
			var f := Support.flow(c, "h822")
			if d != null and d.requires_unlock != &"": f.meta.grant_unlock(d.requires_unlock)
			var run := f.begin(c.chapter, kit, seed_ * 13 + 5, [] as Array[int], null, [], d)
			if run == null: continue
			if run.phase == RunState.Phase.PICK_SPAWN: run.pick_spawn(run.map.entry_ids[0])
			for id in run.map.node_ids():
				var node := run.map.get_node(id)
				var t := NodeEvents.effective_type(node)
				if not (t == &"battle" or t == &"elite") or node.is_visited(): continue
				run.events.pending = {}; run.events.pending_battle = {}
				run.travel.current_id = id
				run.events.handle(node)
				var content: Dictionary = run.events.pending_battle.get("content", {})
				run.events.pending_battle = {}; run.events.pending = {}
				if content.is_empty(): continue
				fights += 1
				var eid := String(content.get("enemy", ""))
				if not eid in IDS: continue
				var k: String = "%s/%s/区%d" % [eid, String(t), node.zone]
				where[k] = int(where.get(k, 0)) + 1
				var h: String = str(content.get("max_hp", content.get("hp", "?")))
				hp[eid + ":" + h] = int(hp.get(eid + ":" + h, 0)) + 1
				for e in content.get("items", []):
					var iid := String(e.get("id", "")) if e is Dictionary else String(e)
					items[eid + ":" + iid] = int(items.get(eid + ":" + iid, 0)) + 1
					var idf := c.items.get_def(StringName(iid))
					if idf != null:
						var rk: String = eid + ":" + RARITY[clampi(idf.rarity, 0, 4)]
						rar[rk] = int(rar.get(rk, 0)) + 1
			Support.cleanup("h822")
		L("A%d：%d 场；出现 %s" % [lv, fights, str(where)])
		L("　　生命 %s" % str(hp))
		L("　　带的东西 %s" % str(items))
		L("　　稀有度 %s" % str(rar))
	quit(0)
