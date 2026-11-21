extends SceneTree
## 游戏测试 v7.41（PR #794，报告 360 第二批）：难度 A1 到 A10 换机制 —— 真开局（每档 6 个种子），数地图上的休息点、
## 撤离点（付费 / 会关闭），首领的生命倍数、加速、名牌、带的东西；触发普通战 / 精英战，看敌人武器最高稀有度、
## 件数、品质、低档真实伤害武器；再用猎手系统问输给猎手扣几点体力
const Support := preload("res://tests/run/flow_support.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const RARITY := ["普", "优", "稀", "史", "传"]


func L(s: String) -> void:
	print("D794 " + s)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var c := TestSupport.load_content("free_mode")
	var kit: LoadoutDef = NodeScreens._kit(c)
	var defs: Array = [null]
	for d in GameFlow.load_difficulties(): defs.append(d)
	defs.sort_custom(func(a, b): return (0 if a == null else a.level) < (0 if b == null else b.level))
	for d in defs:
		var lv: int = 0 if d == null else d.level
		if lv > 11: continue
		var rests := []
		var ext := []
		var boss := {}
		var gear := {"battle": {}, "elite": {}}     # 档位 → [场数, 件数和, 武器最高稀有度分布, 有品质的武器件数, 武器件数, 0 档真实伤害武器场数]
		var hunter_loss := "-"
		for seed_ in [3, 7, 11, 19, 23, 31]:
			var f := Support.flow(c, "d794")
			if d != null and d.requires_unlock != &"": f.meta.grant_unlock(d.requires_unlock)
			var run := f.begin(c.chapter, kit, seed_, [] as Array[int], null, [], d)
			if run == null: L("A%d 种子 %d：开不了局" % [lv, seed_]); continue
			if run.phase == RunState.Phase.PICK_SPAWN: run.pick_spawn(run.map.entry_ids[0])
			var nr := 0
			var ne := 0
			var paid := 0
			var closing := 0
			for id in run.map.node_ids():
				var n := run.map.get_node(id)
				if n.type == &"rest": nr += 1
				if n.type == &"extract":
					ne += 1
					if PaidExtracts.fee_of(n) > 0: paid += 1
					if n.content.has("closes_at"): closing += 1
				if n.type == &"core" and EnemyKit.has_enemy(n.content):
					var eid := String(n.content.get("enemy", ""))
					var t := EnemyKit.title_of(n.content, c.enemies.enemy(StringName(eid)))
					var ids := []
					for e in n.content.get("items", []): ids.append(String(e.get("id", "")) if e is Dictionary else String(e))
					var key := "%s「%s」生命×%.2f 加速×%.2f" % [eid, t, float(n.content.get(EnemyKit.HP_MULT, 1.0)), float(n.content.get(EnemyKit.SPEED_MULT, 1.0))]
					boss[key] = int(boss.get(key, 0)) + 1
					if seed_ == 3: L("A%d 首领 %s 带 %s" % [lv, key, str(ids)])
			rests.append(nr)
			ext.append("%d（付费 %d、会关 %d）" % [ne, paid, closing])
			for id in run.map.node_ids():
				var node := run.map.get_node(id)
				var t := NodeEvents.effective_type(node)
				if not (t == &"battle" or t == &"elite") or node.is_visited(): continue
				run.events.pending = {}
				run.events.pending_battle = {}
				run.pending_loot = null
				run.travel.current_id = id
				run.events.handle(node)
				if run.events.pending_battle.is_empty(): continue
				var content: Dictionary = run.events.pending_battle.get("content", {})
				var stg := int(content.get("strength", 0))
				var g: Dictionary = gear[String(t)]
				if not g.has(stg): g[stg] = [0, 0, {}, 0, 0, 0]
				var s: Array = g[stg]
				s[0] += 1
				var top := -1
				var tru := false
				for e in content.get("items", []):
					if not (e is Dictionary): continue
					if bool(e.get("carried", false)): continue
					var idef := c.items.get_def(StringName(String(e.get("id", ""))))
					if idef == null: continue
					s[1] += 1
					if idef.tags.has(&"weapon"):
						s[4] += 1
						top = maxi(top, int(idef.rarity))
						if int(e.get(ItemInstance.QUALITY_KEY, 0)) > 0: s[3] += 1
						if EnemyPlacer.deals_true_damage(idef): tru = true
				if top >= 0: s[2][RARITY[top]] = int(s[2].get(RARITY[top], 0)) + 1
				if tru: s[5] += 1
				run.events.pending_battle = {}
				run.events.pending = {}
			if seed_ == 3 and run.hunters != null:
				var hd: HunterDef = null
				for k in run.hunters.defs: hd = run.hunters.defs[k]; break
				hunter_loss = "%s（猎手定义 %s）" % [str(run.hunters.loss_cost_of(hd)), str(hd.loss_cost) if hd != null else "-"]
			Support.cleanup("d794")
		L("A%d：休息点 %s；撤离点 %s；输给猎手扣体力 %s" % [lv, str(rests), str(ext), hunter_loss])
		L("　　首领 %s" % str(boss))
		for t in ["battle", "elite"]:
			var g: Dictionary = gear[t]
			var ks := g.keys()
			ks.sort()
			for k in ks:
				var s: Array = g[k]
				L("　　%s 档 %d：%d 场，平均 %.1f 件；武器最高稀有度 %s；带品质的武器 %d / %d；带真实伤害武器的场 %d" % ["普通战" if t == "battle" else "精英战", k, s[0], float(s[1]) / maxf(1, s[0]), str(s[2]), s[3], s[4], s[5]])
	quit(0)
