## 303 第 2 / 3 步（材料方案 2026-11-11 §6、§4.1）：材料供给审计 —— 资格按 [method SmithRecipeDef.material_fits]，来源用生产函数，
## 可达性在配方上做不动点闭包（断路、自产的环、只靠解锁 / 科技的都分得出来）；三件首批材料真有来源、真被配方认
extends RefCounted


static func _items() -> ItemDatabase:
	var items := ItemDatabase.new()
	items.load_dir()
	return items


static func _def(id: String, rarity: int, tags: Array, mat: String = "", unlock: String = "") -> ItemDef:
	var d := ItemDef.new()
	d.id = StringName(id)
	d.rarity = rarity
	for t in tags:
		d.tags.append(StringName(t))
	d.material = StringName(mat)
	d.requires_unlock = StringName(unlock)
	d.shape = ItemShape.from_ascii(["1"])
	return d


static func _recipe(id: String, output: String, inputs: Dictionary, mats: Dictionary, tech: String = "") -> SmithRecipeDef:
	var r := SmithRecipeDef.new()
	r.id = StringName(id)
	r.output = StringName(output)
	r.inputs = inputs
	r.material_inputs = mats
	r.tech = StringName(tech)
	return r


static func run_fits(t: TestCase) -> void:
	t.begin("303 · 资格照生产规则：名字像骨的 flesh、没有 material 标签的不顶；蓝顶绿门槛；魔晶石认家族")
	var items := _items()
	var r := _recipe("t", "x", {}, {"bone": 1, "stone": 1, "crystal:fire": 2})
	var bone := MaterialSupplyAudit.fitting(r, "bone", items).map(func(d: ItemDef) -> String: return String(d.id))
	t.check(not bone.has("beast_tusk_root"), "巨兽獠牙根是 flesh：不顶骨")
	t.check(MaterialSupplyAudit.fitting(r, "bone", items).all(func(d: ItemDef) -> bool: return d.rarity >= 1 and d.tags.has(&"material")), "骨格的全是 ≥ 绿、带 material 标签")
	var statue := _def("t_statue", 2, ["valuable"], "stone")
	t.check(not r.material_fits("stone", statue), "没 material 标签的石雕：不顶石")
	t.check(r.material_fits("stone", _def("t_blue_stone", 2, ["material"], "stone")), "蓝石顶绿门槛")
	var crystals := MaterialSupplyAudit.fitting(r, "crystal:fire", items)
	t.check(not crystals.is_empty() and crystals.all(func(d: ItemDef) -> bool: return d.crystal_family == &"fire" and d.rarity >= 2), "火格只认火族够档的魔晶石")


static func run_closure(t: TestCase) -> void:
	t.begin("303 · 可达性闭包：外部来源 → 配方产出；自产的环、没来源、只靠解锁 / 科技的分得出")
	var items := ItemDatabase.new()
	for d in [_def("t_ore", 1, ["material"], "metal"), _def("t_ingot", 2, ["material"], "metal"), _def("t_loop", 2, ["material"], "metal"),
			_def("t_rare", 4, ["material"], "metal", "ach_t"), _def("t_sword", 1, ["weapon"]), _def("t_blade", 2, ["weapon"]), _def("t_relic", 3, ["weapon"])]:
		items.register(d)
	var recipes := [
		_recipe("smelt", "t_ingot", {"t_ore": 2}, {}),     # 外部矿 → 锭
		_recipe("loop", "t_loop", {"t_loop": 1}, {}),     # 只有自己产自己
		_recipe("up", "t_blade", {"t_sword": 1}, {"metal": 2}),     # 锭（蓝）顶蓝门槛
		_recipe("relic", "t_relic", {"t_blade": 1}, {"metal": 4}, "t_tech"),     # 要科技 + 锁着的料
		_recipe("broken", "t_relic", {"t_loop": 1}, {}),
	]
	var ext := {"t_ore": [{"kind": "search", "where": "c", "share": 0.1}], "t_sword": [{"kind": "shop", "where": "c", "share": -1.0}],
		"t_rare": [{"kind": "chest", "where": "c", "share": 0.01}]}
	var open := MaterialSupplyAudit.reachable(items, recipes, [], ext, true)
	var full := MaterialSupplyAudit.reachable(items, recipes, [], ext, false)
	t.check(open.has("t_ingot") and open.has("t_blade"), "矿 → 锭 → 升级：不要门槛就拿得到")
	t.check(not full.has("t_loop"), "自产的环：全开也拿不到")
	t.check(not open.has("t_relic") and full.has("t_relic"), "要科技 + 锁着的料：只有全开拿得到")
	var res := MaterialSupplyAudit.audit(items, null, recipes, [], ext)
	var by := {}
	for row in res["slots"]:
		by["%s/%s" % [row["recipe"], row["slot"]]] = row["status"]
	t.eq(by.get("loop/id:t_loop"), MaterialSupplyAudit.NO_SOURCE, "自产的环那一格：no_source")
	t.eq(by.get("relic/metal"), MaterialSupplyAudit.GATED, "锁着的料那一格：gated")
	t.eq(by.get("up/id:t_sword"), MaterialSupplyAudit.THIN, "只有商店一条渠道：thin")
	t.eq(by.get("smelt/id:t_ore"), MaterialSupplyAudit.THIN, "只有搜索一条：thin")
	var none := _recipe("none", "t_blade", {}, {"cloth": 1})
	var res2 := MaterialSupplyAudit.audit(items, null, [none], [], ext)
	t.eq(res2["slots"][0]["status"], MaterialSupplyAudit.NO_ITEM, "库里没有顶得上的：no_item")


static func run_new_materials(t: TestCase) -> void:
	t.begin("303 第 3 步 · 三件首批材料：绿、说明留空；梣木枝出在废墟林地、沙漏没有林地；风干木料出在遗骸和木材料池；玄武岩出在矿脉；改造 D 后暂时没有配方认")
	var items := _items()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var ext := MaterialSupplyAudit.external_sources(items, enemies, MaterialSupplyAudit.CHAPTERS, 2)
	var has := func(id: String, kind: String, where: String) -> bool:
		return (ext.get(id, []) as Array).any(func(e: Dictionary) -> bool: return e["kind"] == kind and e["where"] == where)
	for id in ["straight_ash_branch", "seasoned_timber", "dense_basalt"]:
		var d := items.get_def(StringName(id))
		t.check(d != null and d.rarity == 1 and d.tags.has(&"material") and d.description == "", "%s：绿、是材料、说明留空" % id)
	t.check(has.call("straight_ash_branch", "node:grove", "free_mode"), "梣木枝：废墟林地")
	t.check(not has.call("straight_ash_branch", "node:grove", "clockwork_hourglass"), "梣木枝：沙漏没有林地")
	t.check(has.call("seasoned_timber", "node:remains", "clockwork_hourglass") and has.call("seasoned_timber", "pool:worked_wood", "clockwork_hourglass"), "风干木料：沙漏的遗骸和木材料池")
	t.check(has.call("dense_basalt", "node:mine", "free_mode") and has.call("dense_basalt", "node:mine", "clockwork_hourglass"), "玄武岩：两图矿脉")
	var res := MaterialSupplyAudit.audit(items, enemies, [], [], ext)
	var used := {}
	for row in res["slots"]:
		for it in row["items"]:
			if it["open"]:
				used[it["id"]] = true
	for id in ["straight_ash_branch", "seasoned_timber", "dense_basalt"]:     # 改造 D：砧拆了，绿木 / 石没有打造格认了（报告 316 §四，等作者定）
		t.check(not used.has(id), "%s：砧拆了以后暂时没有配方认" % id)
	var c := MaterialSupplyAudit.counts(res)
	t.eq(int(c[MaterialSupplyAudit.NO_ITEM]), 0, "全库没有「库里没道具」的格（%s）" % c)
	var open_broken: Array = res["slots"].filter(func(row: Dictionary) -> bool:     # 只扫两张图时，敌人才背的锁定件可能没碰上；不要门槛的不该断
		return row["status"] == MaterialSupplyAudit.NO_SOURCE and (row["items"] as Array).any(func(i: Dictionary) -> bool: return i["gate"] == ""))
	t.check(open_broken.is_empty(), "不要门槛的道具没有断路的格（%s）" % [open_broken.map(func(row: Dictionary) -> String: return "%s/%s" % [row["recipe"], row["slot"]])])
