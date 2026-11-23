extends SceneTree
## 游戏测试 v7.99（PR #852，报告 360 第四批）：A12 守卫核心 —— 真开局（GameFlow.begin）A11 / A12 各 40 个种子：
## 有没有守卫、是谁、在哪种点、带哪件联动道具、绕不绕得开、首领有没有增援、浮窗写什么；挑一局走 NodeEvents 打赢守卫的结算（_guard_won）看掉失效版、增援撤掉；存档往返
const Support := preload("res://tests/run/flow_support.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")


func L(s: String) -> void:
	print("Q852 " + s)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var c := TestSupport.load_content("free_mode")
	var defs := {}
	for d in GameFlow.load_difficulties(): defs[(d as DifficultyDef).level] = d
	var d12: DifficultyDef = defs.get(12, null)
	L("A12 定义：%s" % ("无" if d12 == null else "%s；要解锁 %s；精英额外稀有度 %d；说明「%s」；挑战「%s」" % [String(d12.id), String(d12.requires_unlock), d12.elite_rarity, d12.description, d12.challenge]))
	var kit: LoadoutDef = NodeScreens._kit(c)
	var shown := false
	for lv in [11, 12]:
		var d: DifficultyDef = defs.get(lv, null)
		var stat := {"有守卫": 0, "多于一名": 0, "绕得开": 0, "首领带增援": 0, "没守卫但首领带增援": 0}
		var who := {}
		var links := {}
		for seed_ in range(1, 41):
			var f := Support.flow(c, "q852")
			if d.requires_unlock != &"": f.meta.grant_unlock(d.requires_unlock)
			var run := f.begin(c.chapter, kit, seed_ * 17 + 9, [] as Array[int], null, [], d)
			if run == null: continue
			var guards := []
			var cores: Array[int] = []
			for id in run.map.node_ids():
				var n := run.map.get_node(id)
				if bool(n.content.get(DifficultyMap.GUARD_KEY, false)): guards.append(id)
				if n.type == &"core": cores.append(id)
			var reinf := false
			for cid in cores: reinf = reinf or DifficultyMap.reinforced(run.map, run.map.get_node(cid).content)
			if guards.is_empty():
				if reinf: stat["没守卫但首领带增援"] += 1
				Support.cleanup("q852"); continue
			stat["有守卫"] += 1
			if guards.size() > 1: stat["多于一名"] += 1
			if reinf: stat["首领带增援"] += 1
			var g: MapNode = run.map.get_node(guards[0])
			if DifficultyMap.bypassable(run.map, g.id, cores): stat["绕得开"] += 1
			var k := "%s/%s" % [String(g.content.get("enemy", "?")), String(g.type)]
			who[k] = int(who.get(k, 0)) + 1
			var lk := String(g.content.get(DifficultyMap.LINK_KEY, "?"))
			links[lk] = int(links.get(lk, 0)) + 1
			if not shown and lv == 12:
				shown = true
				var core := run.map.get_node(cores[0])
				L("种子 %d：守卫点 %d「%s」带 %s；守卫浮窗「%s」" % [seed_ * 17 + 9, g.id, String(g.content.get("enemy", "")), lk, NodeTooltip.text_for(run, run.chapter, g).replace("\n", " / ")])
				L("　　首领浮窗「%s」；首领增援 %s" % [NodeTooltip.text_for(run, run.chapter, core).replace("\n", " / "), str(core.content.get(EnemyKit.REINFORCE_KEY, null))])
				var rolled := {"dropped": [] as Array[StringName], "treasure": [] as Array[StringName]}
				run.events._guard_won(g, g.content, rolled)
				L("　　打赢守卫（_guard_won）：掉 %s；首领增援还在 %s；首领浮窗「%s」" % [str(rolled["treasure"]), str(core.content.has(EnemyKit.REINFORCE_KEY)), NodeTooltip.text_for(run, run.chapter, core).replace("\n", " / ")])
			Support.cleanup("q852")
		L("A%d：40 局里 %s；守卫是 %s；带 %s" % [lv, str(stat), str(who), str(links)])
	quit(0)
