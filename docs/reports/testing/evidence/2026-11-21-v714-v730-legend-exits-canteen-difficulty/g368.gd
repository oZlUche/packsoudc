extends SceneTree
## 游戏测试 报告 368（PR #774）：魔晶石退出配方 —— 数据核对（不进游戏界面）
func L(s: String) -> void:
	print("G368 " + s)


var _game: Node


func _initialize() -> void:
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	var flow: GameFlow = _game.flow
	var items: ItemDatabase = flow.items
	var glands := [&"fire_gland", &"frost_gland", &"shock_sac"]
	for g in glands:
		var d := items.get_def(g)
		L("%s：%s；稀有度 %s；标签 %s；值 %d" % [g, Names.of(d) if d != null else "（没有这件）", str(d.rarity) if d != null else "-", str(d.tags) if d != null else "-", ItemValue.of(d) if d != null else -1])
	var crystals := []
	for id in items.ids(true):
		var d := items.get_def(id)
		if d != null and d.tags.has(&"crystal") and String(id).contains("crystal") and not String(id).begins_with("crystal_shards"): crystals.append(id)
	L("魔晶石类（id 带 crystal、有 crystal 标签）%d 种：%s" % [crystals.size(), str(crystals.slice(0, 12))])
	var n := 0
	for r in flow.smith_recipes:
		var rr := r as SmithRecipeDef
		var o := String(rr.output)
		if not (String(rr.id).begins_with("forge_flame") or String(rr.id).begins_with("forge_frost") or String(rr.id).begins_with("forge_thunder") or rr.id == &"smith_mithril_sword"): continue
		n += 1
		var bad := []
		for k in rr.inputs:
			if crystals.has(StringName(k)): bad.append(String(k))
		var fits := []
		for s in rr.slots():
			if String(s["material"]).begins_with("crystal"): bad.append("格 " + String(s["material"]))
			for c in crystals:
				if SmithRecipeDef.slot_fits(s, items.get_def(c)): fits.append("%s 放得进 %s" % [c, s["material"]])
		var costs := []
		for k in rr.inputs: costs.append("%s=%d" % [k, Alchemy.line_cost(rr, String(k), items)])
		for i in rr.slots().size(): costs.append("slot:%d(%s≥%d)=%d" % [i, rr.slots()[i]["material"], int(rr.slots()[i]["min"]), Alchemy.line_cost(rr, Smithy.SLOT_KEY % i, items)])
		L("%s → %s：料 %s；格 %s；魔晶石 %s；魔晶石放得进 %s；尘价 %s" % [rr.id, o, str(rr.inputs), str(rr.slots().map(func(s): return "%s≥%d×%d" % [s["material"], int(s["min"]), int(s["count"])])), str(bad) if not bad.is_empty() else "无", str(fits) if not fits.is_empty() else "无", ", ".join(costs)])
	L("金武 + 秘银剑共 %d 张" % n)
	var left := []
	for r in flow.smith_recipes:
		var rr := r as SmithRecipeDef
		for k in rr.inputs: if crystals.has(StringName(k)): left.append("%s 料 %s" % [rr.id, k])
		for s in rr.slots(): if String(s["material"]).begins_with("crystal"): left.append("%s 格 %s" % [rr.id, s["material"]])
	for f in DirAccess.get_files_at("res://data/recipes"):
		if not f.ends_with(".tres"): continue
		var fr = load("res://data/recipes/" + f)
		for k in fr.inputs: if crystals.has(StringName(k)): left.append("拼合 %s 料 %s" % [fr.id, k])
	L("全部 %d 张铁匠配方 + 拼合配方里还用魔晶石的：%s" % [flow.smith_recipes.size(), str(left) if not left.is_empty() else "没有"])
	for rid in [&"fuse_flame_fang", &"fuse_frost_fang", &"fuse_thunder_heavy_crossbow"]:
		var fr = load("res://data/recipes/%s.tres" % rid)
		L("拼合 %s：%s → %s" % [rid, str(fr.inputs), fr.output])
	for e in DirAccess.get_files_at("res://data/authoring/enemies"):
		var t := FileAccess.get_file_as_string("res://data/authoring/enemies/" + e)
		for g in glands:
			if t.contains("\"%s\"" % g): L("敌人 %s 带 %s" % [e.get_basename(), g])
	var rules := Market.load_rules()
	for st in Market.stalls():
		for lv in [1, 2, 3]:
			var cat := Market.catalogue(rules, items, st, lv)
			var hit := glands.filter(func(g): return cat.has(g))
			if not hit.is_empty() or lv == 3: L("集市摊 %s %d 级：货单 %d 种；腺体 %s；价 %s" % [st.id, lv, cat.size(), str(hit), str(hit.map(func(g): return Market.price_of(rules, items.get_def(g))))])
	var cd := Commissions.def(&"society_identify_ore")
	L("协会鉴定委托 society_identify_ore：%s" % (str(cd.get("steps")) if cd != null else "（没有）"))
	quit(0)
