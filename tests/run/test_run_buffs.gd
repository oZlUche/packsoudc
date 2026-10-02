## buff 骨架（059，报告 062）：局外 buff 与地图 buff 同一套构件；效果树多了 RUN 分支；各生效点真的读了它；
## 标记给事件条件查；时限按步数；跟着存档；局外屏开关。期望从数据推：作者文件里写了 +1 就该 +1。
extends RefCounted

const SAVE := "user://test_run_buffs_run.json"
const META := "user://test_run_buffs_meta.json"


class Content:
	extends RefCounted
	var items: ItemDatabase
	var enemies: EnemyDatabase
	var sets: SetDatabase
	var chapter: ChapterDef
	var loadouts: Array[LoadoutDef]
	var buffs: Dictionary


static func _content() -> Content:
	var c := Content.new()
	c.items = ItemDatabase.new()
	c.items.load_dir()
	c.enemies = EnemyDatabase.new()
	c.enemies.load_all()
	c.sets = SetDatabase.new()
	c.sets.load_dir()
	c.chapter = load(ContentPaths.asset_file("chapters", "chapter_01"))
	c.loadouts = GameFlow.load_loadouts()
	c.buffs = GameFlow.load_run_buffs()
	return c


static func _kit(c: Content) -> LoadoutDef:
	for l in c.loadouts:
		if l.id == &"standard":
			return l
	return c.loadouts[0]


## 一条 RunEffect 加的数（从定义里读，不写死）
static func _run_amount(def: RunBuffDef, prop: String) -> int:
	var ctx := RunBuffs.context([def])
	return int(ctx.get(prop))


static func run_pipeline(t: TestCase) -> void:
	t.begin("buff · 走管线：往返、战斗效果不许放 effects、作者文件、资产、load_all")

	var def := RunBuffDef.new()
	def.id = &"t_buff"
	def.display_name = "测试"
	def.scope = RunBuffDef.Scope.MAP
	def.duration_steps = 3
	def.tags = [&"x"] as Array[StringName]
	var eff := VitalityMaxBonus.new()
	eff.amount = 2
	def.effects = [eff] as Array[Effect]
	var text := ContentExporter.to_json(ContentExporter.export_run_buff(def))
	var report := ImportReport.new()
	var back := ContentImporter.import_run_buff(JSON.parse_string(text), ContentImporter.Context.new(), report)
	t.check(report.ok(), "导得回来：%s" % report.to_text())
	t.check(back.is_map() and back.duration_steps == 3 and back.tags == def.tags, "作用域、时限、标记原样")
	t.check(back.effects.size() == 1 and back.effects[0] is VitalityMaxBonus and (back.effects[0] as VitalityMaxBonus).amount == 2, "RunEffect 按注册表造回来了")
	t.eq(ContentExporter.to_json(ContentExporter.export_run_buff(back)), text, "再导出逐字节相同")

	var bad := ImportReport.new()
	ContentImporter.import_run_buff({"id": "x", "scope": "META", "effects": [{"type": "deal_damage", "amount": 3}]}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok() and bad.to_text().contains("rules"), "战斗效果放 effects 里不行，提示写进 rules")
	bad = ImportReport.new()
	ContentImporter.import_run_buff({"id": "x", "duration_steps": -1}, ContentImporter.Context.new(), bad)
	t.check(not bad.ok(), "时限不能为负")
	var warn := ImportReport.new()
	ContentImporter.import_run_buff({"id": "x"}, ContentImporter.Context.new(), warn)
	t.check(warn.ok() and not warn.warnings.is_empty(), "什么都不改也没标记：告警")

	var dir: String = ContentPaths.KINDS["run_buffs"][0]
	var d := DirAccess.open(dir)
	t.not_null(d, "有 %s" % dir)
	var files := 0
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".json"):
				continue
			files += 1
			var raw := FileAccess.get_file_as_string(dir + "/" + f)
			var rep := ImportReport.new()
			var res := ContentImporter.import_run_buff(JSON.parse_string(raw), ContentImporter.Context.new(), rep)
			t.check(rep.ok(), "%s 导得进：%s" % [f, rep.to_text()])
			t.eq(ContentExporter.to_json(ContentExporter.export_run_buff(res)), raw, "%s 是往返不动点" % f)
			t.check(ResourceLoader.exists(ContentPaths.asset_file("run_buffs", f.get_basename())), "%s 的资产在" % f)
	t.check(files >= 4, "至少四个测试用的 buff（实际 %d）" % files)
	var c := _content()
	t.eq(c.buffs.size(), files, "load_all 装回全部 %d 个" % files)
	t.check(c.buffs.has(&"hardy") and c.buffs.has(&"lucky") and c.buffs.has(&"marked") and c.buffs.has(&"weakened"), "四个都在")
	t.check((c.buffs[&"hardy"] as RunBuffDef).is_meta() and (c.buffs[&"marked"] as RunBuffDef).is_map(), "作用域按文件")


static func run_context_and_start(t: TestCase) -> void:
	t.begin("buff · 开局按局外 buff 改体力上限与钱；幸运进掉落；地图 buff 给 / 到期 / 标记；战斗属性并进编译；跟着存档")

	var c := _content()
	var kit := _kit(c)
	var hardy: RunBuffDef = c.buffs[&"hardy"]
	var lucky: RunBuffDef = c.buffs[&"lucky"]
	var weakened: RunBuffDef = c.buffs[&"weakened"]
	var ctx := RunBuffs.context([hardy, lucky])
	t.eq(ctx.vitality_max_bonus, _run_amount(hardy, "vitality_max_bonus"), "坚韧：体力上限的加成从定义里来")
	t.eq(ctx.luck_bonus, _run_amount(lucky, "luck_bonus"), "幸运：幸运的加成从定义里来")
	t.check(ctx.vitality_max_bonus > 0 and ctx.luck_bonus > 0, "两个都是正的（作者文件写的）")

	var plain := RunState.start(c.chapter, 41, c.items, c.enemies, c.sets, kit.items)
	var buffed := RunState.start(c.chapter, 41, c.items, c.enemies, c.sets, kit.items, c.buffs, [&"hardy", &"lucky"] as Array[StringName])
	t.eq(buffed.vitality.maximum, plain.vitality.maximum + ctx.vitality_max_bonus, "开局体力上限多了 buff 给的")
	t.eq(buffed.wallet.balance, plain.wallet.balance + ctx.starting_funds_bonus, "开局钱按 buff（这两个不给钱就一样）")
	t.eq(buffed.meta_buffs.size(), 2, "局外 buff 记在这一局里")
	var no_such := RunState.start(c.chapter, 41, c.items, c.enemies, c.sets, kit.items, c.buffs, [&"nope", &"marked"] as Array[StringName])
	t.eq(no_such.meta_buffs.size(), 0, "不认识的、地图作用域的不算局外 buff")

	# 幸运进掉落：同一件东西的掉落率高了 luck × luck_bonus
	var lc_plain: LootContext = plain.hooks.loot_context()
	var lc_buffed: LootContext = buffed.hooks.loot_context()
	t.eq(lc_buffed.luck, ctx.luck_bonus, "掉落上下文里的幸运 = buff 给的")
	if buffed.drop_rule != null:
		var some := c.items.get_def(&"pistol")
		var p0 := DropResolver.owned_chance(buffed.drop_rule, lc_plain, some)
		var p1 := DropResolver.owned_chance(buffed.drop_rule, lc_buffed, some)
		t.check(absf((p1 - p0) - float(ctx.luck_bonus) * buffed.drop_rule.luck_bonus) < 1e-6 or p1 >= 1.0,
			"掉落率多了 幸运 × luck_bonus（%.3f → %.3f）" % [p0, p1])

	# 地图 buff：给、标记、时限、到期
	buffed.pick_spawn(buffed.map.entry_ids[0])
	var changes: Array = []
	var bm := BuffModule.of(buffed)     # 101：一局里拿到的 buff 在模块里
	t.not_null(bm, "默认清单里有 buff 模块")
	bm.buffs_changed.connect(func(): changes.append(true))
	t.check(not bm.grant(&"hardy"), "局外的 buff 不能当地图 buff 给")
	t.check(not bm.grant(&"nope"), "不认识的给不了")
	t.check(bm.grant(&"marked"), "给一个标记")
	t.check(bm.has(&"marked") and buffed.has_buff_tag(&"marked"), "有了，标记查得到")
	t.check(not buffed.has_buff_tag(&"nope"), "没有的标记查不到")
	t.check(bm.grant(&"weakened"), "给一个有时限的")
	var left0 := -1
	for entry in bm.entries:
		if String(entry["id"]) == "weakened":
			left0 = int(entry["left"])
	t.eq(left0, weakened.duration_steps, "时限从定义里来（%d 步）" % weakened.duration_steps)
	t.check(changes.size() >= 2, "发了 buffs_changed")

	# 战斗属性并进编译：虚弱的 mods 让预估 DPS 变低
	var dps_weak := buffed.compile_player().rough_dps()
	bm.remove(&"weakened")
	var dps_norm := buffed.compile_player().rough_dps()
	t.check(dps_weak < dps_norm, "虚弱时预估 DPS 更低（%.2f < %.2f）" % [dps_weak, dps_norm])
	bm.grant(&"weakened")

	# 存档：id 跟着走，读回来给了定义表就一样
	var saved := buffed.to_dict()
	var back := RunState.from_dict(saved, c.chapter, c.items, c.enemies, c.sets)
	back.buff_defs = c.buffs
	t.eq(back.meta_buffs, buffed.meta_buffs, "局外 buff 跟着存档")
	var bm_back := BuffModule.of(back)
	t.check(bm_back.has(&"marked") and bm_back.has(&"weakened"), "一局里拿到的 buff 跟着存档（modules.buff）")
	t.eq(back.buff_context().vitality_max_bonus, ctx.vitality_max_bonus, "读回来上下文一样")

	# 走几步到期：整局的不走
	for i in weakened.duration_steps:
		bm.tick()
	t.check(not bm.has(&"weakened"), "走满 %d 步虚弱没了" % weakened.duration_steps)
	t.check(bm.has(&"marked"), "整局的标记还在")
	t.check(bm.grant(&"weakened") and bm.grant(&"weakened"), "再给一次只是刷新时限")
	var n := 0
	for entry in bm.entries:
		if String(entry["id"]) == "weakened":
			n += 1
	t.eq(n, 1, "不重复")


static func run_sessions(t: TestCase) -> void:
	t.begin("buff · 搜索点多搜几次、商店打折：会话真的读了上下文")

	var c := _content()
	var rules := SearchRules.new()
	rules.max_searches = 1
	rules.encounter_curve = [0.0, 0.0, 0.0] as Array[float]
	rules.items_per_search = Vector2i(1, 1)
	var node := MapNode.new()
	node.id = 3
	node.type = &"search"
	node.content_seed = 9
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var s := SearchSession.new(node, rules, c.items, rng, 0.2)
	s.extra_searches = 1
	t.eq(s.max_total(), 2, "上限 1 + 多搜 1 = 2")
	t.eq(s.searches_left(), 2, "还能搜 2 次")
	s.search()
	t.check(s.active and s.can_search(), "搜了一次还能搜")
	s.search()
	t.check(not s.can_search() and s.active, "搜满两次不能再搜，会话还开着（084）")
	s.leave()
	t.check(not s.active, "离开才结束")

	var econ: EconomyRules = load(ContentPaths.asset_file("economy_rules", String(c.chapter.economy_rules)))
	var shop_node := MapNode.new()
	shop_node.id = 4
	shop_node.type = &"shop"
	shop_node.content_seed = 5
	var full := ShopSession.new(shop_node, econ, c.items, Wallet.new(1000), 0.3)
	var half := ShopSession.new(shop_node, econ, c.items, Wallet.new(1000), 0.3, 0.5)
	t.eq(full.stock.size(), half.stock.size(), "同一个点货架一样长")
	var cheaper := 0
	for i in full.stock.size():
		if int(half.stock[i]["price"]) <= int(full.stock[i]["price"]) and String(half.stock[i]["id"]) == String(full.stock[i]["id"]):
			cheaper += 1
	t.eq(cheaper, full.stock.size(), "打五折之后每一格都更便宜、货不变")

	# 走进真的节点：NodeEvents 把上下文交给会话
	var kit := _kit(c)
	for seed in range(1, 60):
		var run := RunState.start(c.chapter, seed, c.items, c.enemies, c.sets, kit.items, c.buffs, [&"hardy"] as Array[StringName])
		var found := -1
		for entry in run.map.entry_ids:
			for nid in run.map.neighbors(entry):
				if run.map.get_node(nid).type == &"search":
					found = nid
					run.pick_spawn(entry)
					break
			if found >= 0:
				break
		if found < 0:
			continue
		var extra := ExtraSearches.new()
		extra.amount = 2
		var more := RunBuffDef.new()
		more.id = &"t_more"
		more.scope = RunBuffDef.Scope.MAP
		more.effects = [extra] as Array[Effect]
		run.buff_defs[&"t_more"] = more
		BuffModule.of(run).grant(&"t_more")
		run.step_to(found)
		var session := run.events.current_search
		if session != null:
			t.eq(session.max_total(), session.rules.max_searches + 2, "踩上搜索点，会话拿到了 buff 给的多搜 2 次")
			session.leave()
		break


static func run_flow_toggle(t: TestCase) -> void:
	t.begin("场景流 · 局外屏的开关：开了就存、下一局生效；关了下一局没有")

	var c := _content()
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	var f := GameFlow.new(c.items, c.enemies, c.sets, MetaState.new())
	f.buff_defs = c.buffs
	f.chapters = [c.chapter] as Array[ChapterDef]
	f.loadouts = c.loadouts
	f.save_path = SAVE
	f.meta_path = META
	var kit := _kit(c)
	t.check(f.toggle_meta_buff(&"hardy"), "开坚韧")
	t.check(MetaSave.read(c.items, META).active_buffs.has(&"hardy"), "存了")
	var run := f.begin(c.chapter, kit, 51)
	var bonus := _run_amount(c.buffs[&"hardy"], "vitality_max_bonus")
	t.eq(run.vitality.maximum, Vitality.PLACEHOLDER_MAX + bonus, "这一局体力上限多了 %d" % bonus)
	t.check(f.save(), "存这一局")
	f.to_main_menu()
	t.check(f.continue_run(), "继续")
	t.check(f.run.buff_defs == c.buffs and f.run.meta_buffs.has(&"hardy"), "读档回来定义表补上了、buff 还在")
	f.to_main_menu()
	t.check(not f.toggle_meta_buff(&"hardy"), "关坚韧")
	var run2 := f.begin(c.chapter, kit, 52)
	t.eq(run2.vitality.maximum, Vitality.PLACEHOLDER_MAX, "关了下一局没有")
	RunSave.remove(SAVE)
	MetaSave.remove(META)
