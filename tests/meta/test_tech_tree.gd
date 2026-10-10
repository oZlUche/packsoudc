## 118（作者定）：局外科技树 —— 前置（至少 1 级）、列手写深度按前置算、多级一个节点；
## 两种新构件（每级换一条局外 buff、保险箱扩格），开局一局读到科技加成；读档由进度表推算 tech_buffs 与 safe_bonus（120 起不入档）；
## 导入器拦前置不存在 / 成环、撞位只警告；首批三列十个节点；科技页左树右板、上交只给选中的节点
extends RefCounted

const META := "user://test_118_meta.json"
const SETTINGS := "user://test_118_settings.json"
const TECH_PANEL := "res://ui/game/tech_panel.gd"


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _meta() -> MetaState:
	return MetaState.new(GameFlow.load_meta_rules())


static func _tech(id: String, requires: Array = [], column: int = 0) -> TechDef:
	var def := TechDef.new()
	def.id = StringName(id)
	def.display_name = id
	def.column = column
	for r in requires:
		def.requires.append(StringName(String(r)))
	var tier := TechTier.new()
	tier.funds = 10
	def.tiers = [tier] as Array[TechTier]
	return def


static func _add(meta: MetaState, db: ItemDatabase, id: StringName) -> ItemInstance:
	var inst := ItemInstance.create(db.get_def(id), meta.allocate_uid())
	return inst if meta.warehouse.try_add(inst, true) else null


static func run_depth_and_prereqs(t: TestCase) -> void:
	t.begin("118 · 树：深度按前置算（根 0、最深前置 + 1）；前置每项至少 1 级才 ready；还缺哪几个前置；成环认得出")
	var a := _tech("a")
	var b := _tech("b", ["a"])
	var c := _tech("c", ["a"], 1)
	var d := _tech("d", ["b", "c"])
	var defs := [a, b, c, d]
	t.eq(TechService.depth_of(a, defs), 0, "根：0")
	t.eq(TechService.depth_of(b, defs), 1, "b：1")
	t.eq(TechService.depth_of(d, defs), 2, "d：最深前置 + 1 = 2")
	t.eq(TechService.layout(defs)[&"c"], Vector2i(1, 1), "c 在第 1 列、深度 1")
	var m := _meta()
	m.funds = 1000
	t.check(TechService.ready(m, a), "根节点：钱够就能点")
	t.check(not TechService.ready(m, b), "前置没点：不能点")
	t.eq(TechService.missing_prereqs(m, d, defs).size(), 2, "d 缺两个前置")
	t.check(TechService.upgrade(m, a), "点亮 a")
	t.check(TechService.ready(m, b), "a 到 1 级：b 能点了")
	t.eq(TechService.missing_prereqs(m, d, defs).size(), 2, "d 还缺 b、c")
	TechService.upgrade(m, b)
	TechService.upgrade(m, c)
	t.check(TechService.prereqs_met(m, d), "b、c 都点了：d 的前置满足")
	var x := _tech("x", ["y"])
	var y := _tech("y", ["x"])
	t.eq(TechService.depth_of(x, [x, y]), -1, "成环：深度 −1")
	t.eq(TechService.cycle_members([a, x, y]).size(), 2, "认出环上的两个")


static func run_run_buff_effect(t: TestCase) -> void:
	t.begin("118 · tech_run_buff：第 k 级给第 k 条局外 buff、替换上一级那条；读档只留当前级那条；面板那句是 buff 的 summary")
	var defs := GameFlow.load_techs()
	var buffs := RunBuffs.load_all()
	var pack := TechService.find(defs, &"pack")
	t.not_null(pack, "行囊在")
	if pack == null:
		return
	var eff := pack.effect as TechRunBuff
	t.not_null(eff, "行囊是 tech_run_buff")
	var m := _meta()
	m.funds = 100000
	m.tech_levels["warehouse"] = 1
	m.tech_levels["safe_box"] = 1
	t.check(TechService.upgrade(m, pack), "升 1 级")
	t.eq(m.tech_buffs, [eff.buffs[0]] as Array[StringName], "tech_buffs = 第一条")
	TechService.upgrade(m, pack)
	t.eq(m.tech_buffs, [eff.buffs[1]] as Array[StringName], "升 2 级：换成第二条（不叠）")
	t.check(not m.active_buffs.has(eff.buffs[1]), "开发开关那一栏不动")
	m.tech_buffs.append(eff.buffs[0])
	m.tech_buffs.append(&"tech_gone_1")
	TechService.derive(m, defs)
	t.eq(m.tech_buffs, [eff.buffs[1]] as Array[StringName], "推算：只留当前级那条、不属于科技的清掉")
	var text := eff.describe_level(2, buffs)
	t.eq(text, (buffs[eff.buffs[1]] as RunBuffDef).summary(), "面板那句：%s" % text)
	# 存档来回
	var back := MetaState.from_dict(m.to_dict(), _db(), GameFlow.load_meta_rules(), defs)
	t.eq(back.tech_buffs, m.tech_buffs, "120：tech_buffs 不入档，读档由进度表推算回来")
	t.eq(int(m.to_dict()["version"]), MetaState.SAVE_VERSION, "不升存档版本")


static func run_safe_size_effect(t: TestCase) -> void:
	t.begin("118 · tech_safe_size：每级加列 / 行进 safe_bonus；开局保险箱尺寸加上；读档按级数重算；旧档没有这项 = 零")
	var defs := GameFlow.load_techs()
	var safe := TechService.find(defs, &"safe_box")
	t.not_null(safe, "保险箱扩格在")
	if safe == null:
		return
	var eff := safe.effect as TechSafeSize
	t.not_null(eff, "是 tech_safe_size")
	var m := _meta()
	m.funds = 100000
	m.tech_levels["warehouse"] = 1
	TechService.upgrade(m, safe)
	t.eq(m.safe_bonus, Vector2i(eff.cols, eff.rows), "1 级：加一份")
	var f := GameFlow.new(_db(), EnemyDatabase.new(), SetDatabase.new(), m)
	var base := m.rules.safe_size if m.rules != null else Vector2i(3, 3)
	t.eq(f.safe_size(), base + Vector2i(eff.cols, eff.rows), "开局保险箱尺寸 = 规则 + 科技")
	m.safe_bonus = Vector2i.ZERO
	TechService.derive(m, defs)
	t.eq(m.safe_bonus, Vector2i(eff.cols, eff.rows), "推算按级数重算")
	var back := MetaState.from_dict(m.to_dict(), _db(), GameFlow.load_meta_rules(), defs)
	t.eq(back.safe_bonus, m.safe_bonus, "120：safe_bonus 不入档，读档由进度表推算回来")
	var bare := MetaState.from_dict(m.to_dict(), _db(), GameFlow.load_meta_rules())
	t.check(bare != null and bare.safe_bonus == Vector2i.ZERO and bare.tech_buffs.is_empty(), "没给科技定义：派生值留给调用方推算（默认值）")


static func run_run_reads_tech(t: TestCase) -> void:
	t.begin("118 · 开局：科技给的 buff 和开发开关的一起传进一局，RunContext 读得到（开局钱、体力上限）")
	var m := _meta()
	m.tech_buffs = [&"tech_pack_2", &"tech_endurance_1"] as Array[StringName]
	m.active_buffs = [&"tech_endurance_1"] as Array[StringName]
	var f := GameFlow.new(_db(), EnemyDatabase.new(), SetDatabase.new(), m)
	t.eq(f.meta_buffs(), [&"tech_endurance_1", &"tech_pack_2"] as Array[StringName], "合并去重，开关的在前")
	var buffs := RunBuffs.load_all()
	var chapter: ChapterDef = load(ContentPaths.asset_file("chapters", "free_mode"))
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var sets := SetDatabase.new()
	sets.load_dir()
	var s: RunState = null
	for seed in range(1, 40):
		s = RunState.start(chapter, seed, f.items, enemies, sets, [] as Array[StringName], buffs, f.meta_buffs())
		if s != null:
			break
	t.not_null(s, "开得了局")
	if s == null:
		return
	var ctx := s.buff_context()
	var pack: RunBuffDef = buffs[&"tech_pack_2"]
	var funds_eff := pack.effects[0] as Effect
	t.eq(ctx.starting_funds_mult, int(funds_eff.get("percent")), "开局钱的百分比读到了（行囊 2 级，149）")
	t.check(ctx.vitality_max_mult >= 1, "体力上限的百分比读到了（耐久 1 级，149）")


static func run_import_checks(t: TestCase) -> void:
	t.begin("118 · 导入：前置不存在、成环报错；撞位只警告；tech_run_buff 的条数要等于级数、buff 得存在且是局外的")
	var ctx := ContentImporter.Context.new()
	var buffs := RunBuffs.load_all()
	for id in buffs:
		ctx.register_run_buff(buffs[id])
	var r := ImportReport.new()
	ContentImporter.import_tech({"id": "a", "display_name": "甲", "effect": {"type": "warehouse_rows"}, "tiers": [{"funds": 1}]}, ctx, r)
	ContentImporter.import_tech({"id": "b", "display_name": "乙", "requires": ["a"], "effect": {"type": "warehouse_rows"}, "tiers": [{"funds": 1}]}, ctx, r)
	ContentImporter.import_tech({"id": "b2", "display_name": "乙二", "requires": ["a"], "effect": {"type": "warehouse_rows"}, "tiers": [{"funds": 1}]}, ctx, r)
	var r1 := ImportReport.new()
	ContentImporter.validate_techs(ctx, r1)
	t.check(r1.ok(), "好的树不报错：%s" % r1.to_text())
	t.check(r1.to_text().contains("撞位"), "b、b2 同列同深度：警告撞位")
	ContentImporter.import_tech({"id": "c", "display_name": "丙", "requires": ["nope"], "effect": {"type": "warehouse_rows"}, "tiers": [{"funds": 1}]}, ctx, ImportReport.new())
	var r2 := ImportReport.new()
	ContentImporter.validate_techs(ctx, r2)
	t.check(not r2.ok() and r2.to_text().contains("nope"), "前置不存在：报错并点名")
	var ctx2 := ContentImporter.Context.new()
	ContentImporter.import_tech({"id": "x", "display_name": "x", "requires": ["y"], "effect": {"type": "warehouse_rows"}, "tiers": [{"funds": 1}]}, ctx2, ImportReport.new())
	ContentImporter.import_tech({"id": "y", "display_name": "y", "requires": ["x"], "effect": {"type": "warehouse_rows"}, "tiers": [{"funds": 1}]}, ctx2, ImportReport.new())
	var r3 := ImportReport.new()
	ContentImporter.validate_techs(ctx2, r3)
	t.check(not r3.ok() and r3.to_text().contains("成环"), "成环：报错")
	var r4 := ImportReport.new()
	ContentImporter.import_tech({"id": "p", "display_name": "p", "effect": {"type": "tech_run_buff", "buffs": ["tech_pack_1", "weakened"]},
		"tiers": [{"funds": 1}]}, ctx, r4)
	var txt := r4.to_text()
	t.check(txt.contains("每一级给一条"), "条数不等于级数：报错")
	t.check(txt.contains("不是局外的"), "地图 buff 不能给：报错")


static func run_first_tree(t: TestCase) -> void:
	t.begin("118 · 首批树：三列十个节点（数值占位）；仓库扩建在第 0 列根上；侦察要幸运和讨价；每个 tech_run_buff 的 buff 都在且是局外的")
	var defs := GameFlow.load_techs()
	var buffs := RunBuffs.load_all()
	t.eq(defs.size(), 11, "十一个节点（129 加了扛重）")
	var cols := {}
	for def in defs:
		cols[def.column] = true
		if def.effect is TechRunBuff:
			var rb := def.effect as TechRunBuff
			t.eq(rb.buffs.size(), def.max_level(), "%s：每级一条 buff" % def.id)
			for id in rb.buffs:
				t.check(buffs.has(id) and (buffs[id] as RunBuffDef).is_meta(), "%s 在且是局外的" % id)
	t.eq(cols.size(), 3, "三列")
	var lay := TechService.layout(defs)
	t.eq(lay[&"warehouse"], Vector2i(0, 0), "仓库扩建：第 0 列根")
	t.eq(lay[&"pack"], Vector2i(0, 2), "行囊：第 0 列深度 2")
	t.eq(lay[&"scouting"], Vector2i(2, 2), "侦察：第 2 列深度 2")
	t.eq(TechService.find(defs, &"scouting").requires.size(), 2, "侦察要两个前置")
	t.check(TechService.cycle_members(defs).is_empty(), "没有环")


static func frame_tree_panel(t: TestCase, root: Window) -> void:
	t.begin("118 · 科技页：左树（深度 0 在下、锁住 / 可点亮 / 已点亮）右板（名称 / 效果 / 费用）；上交只记给选中的节点；锁住的按钮灰、写要先点亮谁")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var m := _meta()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), m)
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	f.buff_defs = RunBuffs.load_all()
	var panel = load(TECH_PANEL).new()
	root.add_child(panel)
	panel.setup(f, UiPalette.cjk_font())
	var tree: TechTreeView = panel.tree()
	t.not_null(tree.node_button(&"warehouse"), "树上有仓库扩建")
	t.check(tree.node_rect(&"safe_box").position.y < tree.node_rect(&"warehouse").position.y, "保险箱扩格（深度 1）画在仓库扩建（深度 0）上面")
	t.eq(tree.state_of(&"warehouse"), TechTreeView.State.AVAILABLE, "根节点：可点亮")
	t.eq(tree.state_of(&"safe_box"), TechTreeView.State.LOCKED, "前置没点：锁住")
	t.eq(TechTreeView.level_text(m, f.tech_of(&"undaunted")), "未点亮", "单级写未点亮")
	t.eq(TechTreeView.level_text(m, f.tech_of(&"warehouse")), "Lv 0 / 6", "多级写 Lv")

	# 选中锁住的节点：费用区写要先点亮谁、按钮灰
	t.check(panel.select(&"safe_box"), "选保险箱扩格")
	var texts: Dictionary = panel.panel_texts()
	t.check(String(texts["name"]).contains(Names.of(f.tech_of(&"safe_box"))), "名称区：%s" % texts["name"])
	t.check(String(texts["effect"]).contains("下一级："), "效果区有下一级：%s" % texts["effect"])
	t.check(String(texts["cost"]).contains("需要先点亮") and String(texts["cost"]).contains(Names.of(f.tech_of(&"warehouse"))), "费用区写要先点亮仓库扩建")
	m.funds = 100000
	m.changed.emit()
	t.check(panel.upgrade_button(&"safe_box").disabled, "钱够但锁着：灰")

	# 点亮仓库扩建：树上变色，保险箱扩格变可点亮
	t.check(panel.select(&"warehouse"), "选仓库扩建")
	t.eq(panel.upgrade_button(&"warehouse").text, "升级", "多级的按钮叫「升级」")
	panel.upgrade_button(&"warehouse").pressed.emit()
	t.eq(TechService.level(m, &"warehouse"), 1, "升到 1 级")
	t.eq(tree.state_of(&"warehouse"), TechTreeView.State.LIT, "已点亮")
	t.eq(tree.state_of(&"safe_box"), TechTreeView.State.AVAILABLE, "保险箱扩格可点亮了")
	t.check(String(panel.panel_texts()["effect"]).contains("现在："), "效果区有「现在」")

	# 上交只给选中的：选不屈（要建材、前置耐久没点）→ 交不进；点了耐久再交 → 记给不屈
	t.check(panel.select(&"undaunted"), "选不屈")
	t.eq(panel.upgrade_button(&"undaunted").text, "点亮", "单级的按钮叫「点亮」")
	var plank := _add(m, db, &"hardwood_plank")
	t.check(not panel.submit(plank.uid), "不屈锁着：交不进")
	t.check(panel.line_text().contains("锁着"), "提示：%s" % panel.line_text())
	TechService.upgrade(m, f.tech_of(&"endurance"))
	m.changed.emit()
	t.check(panel.submit(plank.uid), "耐久点了：硬木板交给不屈")
	t.eq(TechService.deposited(m, &"undaunted", &"hardwood_plank"), 1, "记在不屈名下")
	t.eq(TechService.deposited(m, &"luck", &"hardwood_plank"), 0, "没记给别的科技")
	var rivet := _add(m, db, &"rivet_box")
	t.check(not panel.submit(rivet.uid), "不屈不要铆钉盒")
	t.check(panel.line_text().contains("不是它下一级要的"), "提示：%s" % panel.line_text())
	var b := _add(m, db, &"steel_ingot")
	m.warehouse.remove(b.uid)
	t.check(panel.zone().place(b, Vector2i.ZERO, 0), "钢锭拖进上交区")
	t.eq(TechService.deposited(m, &"undaunted", &"steel_ingot"), 1, "记给选中的不屈")
	t.check(not panel._warehouse_box.visible, "仓库默认收起")
	panel.toggle_warehouse()
	t.check(panel._warehouse_box.visible, "点开仓库")
	panel.queue_free()
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func frame_owned_count_quick_submit(t: TestCase, root: Window) -> void:
	t.begin("138 · 科技页材料行：已交 / 需要 + 拥有 n；拥有且还差时【交 k】（k = 还差与拥有取小），按下逐件上交；锁住 / 没有 / 交齐不给按钮")
	ItemInstance.reset_uid_counter()
	var db := _db()
	var m := _meta()
	var f := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new(), m)
	f.meta_path = META
	f.settings_path = SETTINGS
	f.tech_defs = GameFlow.load_techs()
	f.buff_defs = RunBuffs.load_all()
	var panel = load(TECH_PANEL).new()
	root.add_child(panel)
	panel.setup(f, UiPalette.cjk_font())
	for i in 5:
		_add(m, db, &"steel_ingot")
	_add(m, db, &"hardwood_plank")
	m.changed.emit()

	# 不屈：前置耐久没点 → 拥有照写，但不给按钮
	t.check(panel.select(&"undaunted"), "选不屈")
	t.check(String(panel.panel_texts()["cost"]).contains("拥有 5"), "锁着也写拥有：%s" % panel.panel_texts()["cost"])
	t.is_null(panel.submit_button(&"steel_ingot"), "前置没点：没有【交】")
	m.funds = 100000
	t.check(TechService.upgrade(m, f.tech_of(&"endurance")), "点亮耐久")
	m.changed.emit()

	# 钢锭：要 2、已交 0、拥有 5 → 【交 2】
	var steel: Button = panel.submit_button(&"steel_ingot")
	t.not_null(steel, "钢锭有按钮")
	t.eq(steel.text if steel != null else "", "交 2", "k = min(还差 2, 拥有 5)")
	steel.pressed.emit()
	t.eq(TechService.deposited(m, &"undaunted", &"steel_ingot"), 2, "交齐两块")
	t.eq(panel._owned_counts().get("steel_ingot", 0), 3, "仓库剩三块")
	t.is_null(panel.submit_button(&"steel_ingot"), "交齐：按钮没了")
	t.check(String(panel.panel_texts()["cost"]).contains("已交 2 / 需要 2　✓"), "行打 ✓")
	t.check(panel.line_text().contains("交了 2 件"), "提示：%s" % panel.line_text())
	t.eq(MetaSave.read(db, META, m.rules, f.tech_defs).tech_deposits.get("undaunted", {}).get("steel_ingot", 0), 2, "meta 存了")

	# 硬木板：要 2、拥有 1 → 【交 1】，交完拥有 0、还差一块、没按钮
	var plank: Button = panel.submit_button(&"hardwood_plank")
	t.eq(plank.text if plank != null else "", "交 1", "只有一块：交 1")
	plank.pressed.emit()
	t.eq(TechService.deposited(m, &"undaunted", &"hardwood_plank"), 1, "交了一块")
	t.check(String(panel.panel_texts()["cost"]).contains("拥有 0"), "拥有 0")
	t.is_null(panel.submit_button(&"hardwood_plank"), "拥有 0：没按钮")
	panel.queue_free()
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)
