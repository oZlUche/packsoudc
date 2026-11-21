extends SceneTree
## 游戏测试 v7.31 / v7.36 / v7.38（PR #784、#789、#791）：18 件新史诗武器、8 件护甲和盾（加改小的板甲）、32 件食材 ——
## 逐件查：定义在、稀有度、中英说明都空、图能载入（有没有 @2x）、占几格 / 外框多大（护甲要放得进 3×3 包）、标签；
## 食材：粮铺常备哪几样、五种魔兽的掉落里有没有肉、局内商店卖不卖食材；再真开局在 A0 / A4 / A8 各 12 个种子上数敌人带新武器 / 新护甲的次数
const Support := preload("res://tests/run/flow_support.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const RARITY := ["普", "优", "稀", "史", "传"]
const WEAPONS := ["armor_piercer", "bloodsipper_scimitar", "bonecrusher_maul", "duelist_rapier", "flaying_hooks", "hierophant_staff", "hook_glaive", "monster_hunter_spear", "oathkeeper_sword", "quickcast_wand", "repeating_crossbow", "serpent_fang_bow", "silent_blade", "throat_cutter", "vanguard_greatsword", "veteran_twin_blades", "viper_twin_stingers", "warding_staff"]
const ARMORS := ["chain_mail", "studded_leather", "knight_plate", "dragonscale_armor", "plate_cuirass", "steel_round_shield", "kite_shield", "legion_tower_shield", "riposte_buckler", "condenser_tube", "arc_coil_core", "blood_tusk", "bonesplit_claw", "frigid_tear", "miasma_sac", "miasma_source", "molten_scale", "permafrost_marrow", "thunder_marrow", "thunder_plume", "unclotting_blood", "undying_ember", "viper_gland"]


func L(s: String) -> void:
	print("I784 " + s)


func _initialize() -> void:
	call_deferred("_run")


func _shape(d: ItemDef) -> String:
	var cells: Array = d.cells_rotated(0)
	var w := 0
	var h := 0
	for v in cells:
		w = maxi(w, (v as Vector2i).x + 1); h = maxi(h, (v as Vector2i).y + 1)
	return "%d 格 %d×%d" % [cells.size(), w, h]


func _line(d: ItemDef) -> String:
	var desc := "%s|%s" % [d.description, String(d.descriptions.get("en", ""))]
	var art := ResourceLoader.exists("res://assets/items/%s.png" % d.id)
	var hi := "有" if ResourceLoader.exists("res://assets/items/@2x/%s.png" % d.id) else "无"
	return "%s %s（%s）%s；%s；说明 %s；图 %s（@2x %s）；标签 %s" % [String(d.id), d.display_name, String(d.display_names.get("en", "")), RARITY[clampi(d.rarity, 0, 4)], _shape(d), "空" if desc == "|" else "「%s」" % desc, "有" if art else "无（占位）", hi, str(d.tags)]


func _run() -> void:
	var c := TestSupport.load_content("free_mode")
	L("== 18 件新史诗武器")
	for id in WEAPONS:
		var d := c.items.get_def(StringName(id))
		L(_line(d) if d != null else "%s 不在道具库" % id)
		if d != null: L("　　真实伤害 %s；元素 %s" % [str(EnemyPlacer.deals_true_damage(d)), str(d.tags.filter(func(t): return String(t) in ["fire", "ice", "lightning", "poison", "nature", "element"]))])
	L("== 护甲和盾")
	for id in ARMORS:
		var d := c.items.get_def(StringName(id))
		L(_line(d) if d != null else "%s 不在道具库" % id)
		if d != null and d.combat != null: L("　　护甲上限 %s、格挡 %s；扳机 %s" % [str(d.combat.base_stats.get("max_armor", 0)), str(d.combat.base_stats.get("block", 0)), str(d.combat.rules.map(func(r): return (r as AbilityRule).trigger.describe() if (r as AbilityRule).trigger != null else "-"))])
	var big := []
	for iid in c.items.all_ids():
		var d := c.items.get_def(StringName(iid))
		var dd := d as ItemDef
		if dd.combat != null and float(dd.combat.base_stats.get("max_armor", 0.0)) > 0.0 and not dd.tags.has(&"bag"):
			var sh := _shape(dd)
			var parts := sh.split(" ")
			var wh := parts[2].split("×")
			if int(wh[0]) > 3 or int(wh[1]) > 3 or int(parts[0]) > 9: big.append("%s %s" % [String(dd.id), sh])
	L("放不进 3×3 的护甲：%s" % str(big))
	L("== 32 件食材")
	var ing := []
	for iid in c.items.all_ids():
		var d := c.items.get_def(StringName(iid))
		if (d as ItemDef).tags.has(&"ingredient"): ing.append(d)
	L("食材 %d 件" % ing.size())
	for d in ing: L("　　" + _line(d))
	var stall := ContentPaths.asset_file("market_stalls", "food")
	L("粮铺定义 %s" % stall)
	if ResourceLoader.exists(stall):
		var s = load(stall)
		for p in s.get_property_list():
			var nm := String(p.name)
			if nm in ["extra_ids", "always", "stock", "staples"]: L("　　粮铺 %s = %s" % [nm, str(s.get(nm))])
	L("== 魔兽掉肉")
	for k in c.enemies._enemies:
		var ed := c.enemies._enemies[k] as EnemyDef
		if not ed.is_wild(): continue
		L("　　%s %s：替身肉 %s" % [String(ed.id), ed.display_name, str(ed.loot_filler)])
	L("== 敌人带新东西（真开局、触发战斗看内容）")
	var defs := {}
	for d in GameFlow.load_difficulties(): defs[(d as DifficultyDef).level] = d
	var kit: LoadoutDef = NodeScreens._kit(c)
	for lv in [0, 4, 8]:
		var d: DifficultyDef = defs.get(lv, null)
		var cnt := {}
		var fights := 0
		var ing_in_shop := 0
		for seed_ in range(1, 13):
			var f := Support.flow(c, "i784")
			if d != null and d.requires_unlock != &"": f.meta.grant_unlock(d.requires_unlock)
			var run := f.begin(c.chapter, kit, seed_ * 7 + 1, [] as Array[int], null, [], d)
			if run == null: continue
			if run.phase == RunState.Phase.PICK_SPAWN: run.pick_spawn(run.map.entry_ids[0])
			for id in run.map.node_ids():
				var node := run.map.get_node(id)
				var t := NodeEvents.effective_type(node)
				var content: Dictionary = {}
				if t == &"core" and EnemyKit.has_enemy(node.content): content = node.content
				elif (t == &"battle" or t == &"elite") and not node.is_visited():
					run.events.pending = {}; run.events.pending_battle = {}
					run.travel.current_id = id
					run.events.handle(node)
					content = run.events.pending_battle.get("content", {})
					run.events.pending_battle = {}; run.events.pending = {}
				elif t == &"shop":
					for e in node.content.get("stock", node.content.get("items", [])):
						var sid := String(e.get("id", "")) if e is Dictionary else String(e)
						var sd := c.items.get_def(StringName(sid))
						if sd != null and sd.tags.has(&"ingredient"): ing_in_shop += 1
				if content.is_empty(): continue
				fights += 1
				for e in content.get("items", []):
					var iid := String(e.get("id", "")) if e is Dictionary else String(e)
					if iid in WEAPONS or iid in ARMORS or c.items.get_def(StringName(iid)) != null and c.items.get_def(StringName(iid)).tags.has(&"ingredient"):
						cnt[iid] = int(cnt.get(iid, 0)) + 1
			Support.cleanup("i784")
		L("A%d：%d 场敌人；新武器 / 护甲 / 食材出现 %s；局内商店里的食材 %d 件" % [lv, fights, str(cnt), ing_in_shop])
	quit(0)
