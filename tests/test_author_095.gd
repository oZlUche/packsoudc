## 赐福（095，作者定）：信仰道具的功能三种生效方式（按阶 / 激活即 / 按信力）；普通道具按信仰的模板派生赐福版；赐福版从战利品 / 搜索替代、包内转化、神坛 / 事件来；
## 只有信物能激活信仰；自己神的赐福版献回来双倍
extends RefCounted

const SAVE := "user://test_095_run.json"
const META := "user://test_095_meta.json"
const SETTINGS := "user://test_095_settings.json"
const NodeScreens := preload("res://tests/test_node_screens.gd")


static func _cleanup() -> void:
	RunSave.remove(SAVE)
	MetaSave.remove(META)
	GameSettings.remove(SETTINGS)


static func _dmg(spec: CombatantSpec, uid: int) -> float:
	return StatMath.to_float(spec.stats_of(uid).total_of(BattleStats.DAMAGE))


static func run_variants_and_modes(t: TestCase) -> void:
	t.begin("095 · 赐福版派生（id_<神>、前缀、标签、稀有度 +1、blessed_of；不进生成池）；只有信物激活信仰；功能三种生效方式；自己神的赐福版献回来双倍")
	var db := ItemDatabase.new()
	db.load_dir()
	var faiths := FaithDef.load_all()
	var sb := db.get_def(&"shortsword_brute")
	t.check(sb != null, "短剑有蛮神赐福版（武器）")
	if sb != null:
		t.check(sb.display_name.begins_with("蛮神赐福的") and sb.has_faith() and sb.faith_tag() == &"faith:brute" and sb.is_blessed() and not sb.is_anchor(), "名字前缀、faith + faith:brute + blessed、不是信物")
		t.eq(sb.blessed_of, &"shortsword", "记着从哪件派生")
		t.eq(sb.rarity, db.get_def(&"shortsword").rarity + 1, "稀有度 +1")
		t.check(sb.tags.has(&"weapon") and sb.tags.has(&"metal") and sb.combat != null, "原来的标签与战斗定义都在")
		t.eq(sb.faith_bonuses.size(), 2, "带着模板的两条功能")
	t.check(db.get_def(&"shortsword_sun") != null, "短剑也有日神版（金属）")
	t.check(db.get_def(&"plate_cuirass_earth") != null and db.get_def(&"plate_cuirass_nature") != null, "板甲：大地（≥ 5 格）与自然（防具）")
	t.check(db.get_def(&"ration_brute") == null and db.get_def(&"charm_brute_sun") == null and db.get_def(&"bag_small_earth") == null, "口粮不是武器、护符本来就是信仰道具、包 —— 都不派生")
	var in_pool := false
	for id in db.ids():
		if db.get_def(id).is_blessed():
			in_pool = true
	t.check(not in_pool and db.all_ids().has(&"shortsword_brute"), "赐福版不进生成池（搜索 / 掉落 / 商店 / 敌人），但库里有")
	# 只有信物能激活
	var b := GridInventory.new(Vector2i(6, 4), 1, false)
	var sword := ItemInstance.create(sb)
	t.check(b.try_add(sword, true), "放上赐福短剑")
	t.eq(FaithState.active_id(b), &"", "赐福的武器不激活信仰")
	var charm := ItemInstance.create(db.get_def(&"charm_sun"))
	t.check(b.try_add(charm, true), "放上日神的护符")
	t.eq(FaithState.active_id(b), &"sun", "护符是信物：激活日神")
	t.check(FaithState.is_dormant(sb, FaithState.active_tag(b)), "蛮神赐福的短剑在日神下休眠（留通用效果）")
	var sigil := ItemInstance.create(db.get_def(&"strength_sigil"))
	t.check(b.try_add(sigil, true), "再放力量的符号")
	t.eq(FaithState.active_id(b), &"brute", "最后置入的信物说了算：蛮神")
	# 三种生效方式
	var fb := FaithBonus.new()
	fb.mode = "tier"
	fb.tier = 2
	t.check(fb.times_for(1, 999) == 0 and fb.times_for(2, 0) == 1, "tier：过了第 2 阶才生效")
	fb.mode = "active"
	t.eq(fb.times_for(0, 0), 1, "active：激活即一份")
	fb.mode = "scaled"
	fb.per_points = 50
	t.eq(fb.times_for(0, 120), 2, "scaled：120 信力 = 2 份")
	fb.max_stacks = 1
	t.eq(fb.times_for(0, 120), 1, "最多 1 份")
	t.check(fb.gate_text().contains("每 50 信力"), "说明文字：%s" % fb.gate_text())
	# 编译：激活即 +10%、每 50 信力 +1（最多 6）
	var base_dmg := float(db.get_def(&"shortsword").combat.base_stats.get("damage", 0.0))     # 原件的伤害；乘区先乘、平的后加
	var tag := &"faith:brute"
	var d0 := _dmg(BattleCompiler.compile(b, null, [] as Array[StatModifier], [] as Array[AbilityRule], {tag: 0}, {tag: 0}), sword.uid)
	t.check(absf(d0 - base_dmg * 1.1) < 0.01, "0 阶 0 点：激活即 +10%%（%.2f → %.2f）" % [base_dmg, d0])
	var d120 := _dmg(BattleCompiler.compile(b, null, [] as Array[StatModifier], [] as Array[AbilityRule], {tag: 1}, {tag: 120}), sword.uid)
	t.check(absf(d120 - (base_dmg * 1.1 + 2.0)) < 0.01, "120 点：再 +2 平的（%.2f）" % d120)
	var d999 := _dmg(BattleCompiler.compile(b, null, [] as Array[StatModifier], [] as Array[AbilityRule], {tag: 4}, {tag: 9999}), sword.uid)
	t.check(absf(d999 - (base_dmg * 1.1 + 6.0)) < 0.01, "9999 点：最多 6 份（%.2f）" % d999)
	# 献祭双倍
	var brute: FaithDef = faiths[&"brute"]
	t.eq(brute.offering_value(sb), 2 * roundi(pow(2.0, float(sb.rarity)) * 2.0), "蛮神赐福的短剑献给蛮神：(2^2 × 2) × 2 = 16")
	var sun: FaithDef = faiths[&"sun"]
	t.eq(sun.offering_value(sb), roundi(pow(2.0, float(sb.rarity)) * 5.0), "献给日神照普通算（金属）：2^2 × 5 = 20")


static func run_blessing_paths(t: TestCase) -> void:
	t.begin("095 · 赐福从哪来：战利品 / 搜索替代（激活只换那位神的、没激活随机一位）、包内每步转化（位置不动、发信号）、神坛「祈求赐福」花信力、事件后果赐福一件")
	var c = NodeScreens._content()
	var f: GameFlow = NodeScreens._flow(c)
	f.save_path = SAVE
	f.meta_path = META
	f.settings_path = SETTINGS
	f.faith_defs = FaithDef.load_all()
	var run := f.begin(c.chapter, NodeScreens._kit(c), 4)
	if run == null:
		t.check(false, "开局")
		return
	f.pick_spawn(run.map.entry_ids[0])
	var db := run.items
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# 替代：没激活
	var idle := Blessings.substitute([&"shortsword", &"battery"] as Array[StringName], db, &"", run.faith_defs.keys(), 1.0, 1.0, rng)
	t.check(String(idle[0]).begins_with("shortsword_") and db.get_def(idle[0]).is_blessed() and idle[1] == &"battery", "没激活、概率 1：短剑换成随机一位神的赐福版，封存的电池没人要")
	var none := Blessings.substitute([&"shortsword"] as Array[StringName], db, &"", run.faith_defs.keys(), 0.0, 1.0, rng)
	t.eq(none[0], &"shortsword", "概率 0：不换")
	# 激活蛮神
	var charm := ItemInstance.create(db.get_def(&"charm_brute"))
	run.storage.admit(charm)
	t.check(InventoryService.transfer_auto(run.storage, charm.uid, run.board) and run.active_faith_id() == &"brute", "护符上棋盘：蛮神")
	var active := run.bless_ids([&"shortsword", &"longbow"] as Array[StringName], 0.0, 1.0, rng)
	t.eq(active, [&"shortsword_brute", &"longbow_brute"] as Array[StringName], "激活了、概率 1：都换成蛮神的")
	t.check(run.events.bless_substitute.is_valid() and run.events.current_search == null, "掉落 / 搜索的替代接上了")
	# 包内转化：把蛮神的定义复制一份、转化概率 1
	var brute := (run.faith_defs[&"brute"] as FaithDef).duplicate() as FaithDef
	brute.convert_chance = 1.0
	brute.convert_per_tier = 0.0
	run.faith_defs[&"brute"] = brute
	var weapons: Array = []
	for inst in run.board.items():
		if (inst as ItemInstance).def.tags.has(&"weapon") and not (inst as ItemInstance).def.has_faith():
			weapons.append([inst, (inst as ItemInstance).def.id, (inst as ItemInstance).origin])
	t.check(not weapons.is_empty(), "棋盘上有普通武器")
	var blessed: Array = []
	run.item_blessed.connect(func(inst: ItemInstance, fid: StringName): blessed.append([inst, fid]))
	var moves := run.travel.available_moves()
	t.check(not moves.is_empty() and f.step_to(moves[0]), "走一步")
	NodeScreens._settle(f)
	for w in weapons:
		var inst: ItemInstance = w[0]
		t.check(inst.def.id == Blessings.variant_id(w[1], &"brute") and inst.origin == w[2] and run.board.has_item(inst.uid), "「%s」原地变成蛮神赐福版" % w[1])
	t.eq(blessed.size(), weapons.size(), "每件发了一次 item_blessed")
	t.check(run.compile_player() != null, "编译照常")
	# 神坛：祈求赐福
	brute.convert_chance = 0.0
	var ration := ItemInstance.create(db.get_def(&"leather_armor"))     # 自然的模板认防具，蛮神不认 → 用一把新短剑
	var fresh := ItemInstance.create(db.get_def(&"shortsword"))
	run.storage.admit(fresh)
	run.faith_power.add_points(&"brute", 60)
	var bless_perk := run.faith_perk(&"altar_bless")
	t.check(bless_perk != null, "1 级起神坛有「祈求赐福」")
	if bless_perk != null:
		run.altar_node = run.travel.current_id
		t.eq(bless_perk.altar_available(run, run.current_node()), "", "信力够、包里有能赐福的（暂存区那把短剑）")
		var p0 := run.faith_power.points_of(&"brute")
		# 赐福的是最值钱的那件（棋盘优先、其次暂存区）：走的那一步可能捡到了比短剑更值钱的
		var target := Blessings.best_candidate(run.board, db, &"brute")
		if target == null:
			target = Blessings.best_candidate(run.storage, db, &"brute")
		var target_id: StringName = target.def.id if target != null else &""
		var line := run.altar_special(bless_perk, run.current_node())
		t.check(line.contains("成了"), "做了：%s" % line)
		t.eq(run.faith_power.points_of(&"brute"), p0 - 40, "花了 40 信力")
		if target == fresh:
			t.eq(fresh.def.id, &"shortsword_brute", "暂存区那把短剑受了赐福")
		else:
			t.eq(target.def.id, Blessings.variant_id(target_id, &"brute"), "最值钱的那件（%s）受了赐福" % target_id)
		run.faith_power.spend_points(&"brute", run.faith_power.points_of(&"brute"))
		t.check(bless_perk.altar_available(run, run.current_node()) != "", "信力不够就做不了")
	# 事件后果
	var ctx := run.events._event_ctx(run.current_node())
	var another := ItemInstance.create(db.get_def(&"longsword"))
	run.storage.admit(another)
	var o := BlessItem.new()
	o.apply(ctx)
	t.check(another.def.id == &"longsword_brute" and not ctx.log.is_empty(), "事件「赐福一件」：暂存区里那把长剑成了蛮神赐福版（%s）" % (ctx.log[0] if not ctx.log.is_empty() else ""))
	_cleanup()


## 图鉴：赐福版并进原件那一格，叠影 + 角标，点开弹异体列表
static func frame_codex_variants(t: TestCase, root: Window) -> void:
	t.begin("095 · 图鉴：赐福版并进原件那一格（不单列）、格子记着异体与各自点亮、点开弹出「原件 / 蛮神版 / 日神版…」、关得掉；点亮的计数含赐福版")
	var c = NodeScreens._content()
	_cleanup()
	var f: GameFlow = NodeScreens._flow(c)
	f.save_path = SAVE
	f.meta_path = META
	f.settings_path = SETTINGS
	f.faith_defs = FaithDef.load_all()
	f.meta.codex["shortsword_brute"] = 1     # 假装带出过一把蛮神赐福的短剑
	var screen = load("res://ui/game/meta_screen.gd").new()
	screen.flow = f
	screen.font = UiPalette.cjk_font()
	screen.screen = GameFlow.Screen.META
	root.add_child(screen)
	screen.open({})
	screen.show_tab("codex")
	var sword_tile: CodexTile = null
	var listed_blessed := false
	for tile in screen.codex_tiles():
		if tile.def.id == &"shortsword":
			sword_tile = tile
		if tile.def.is_blessed():
			listed_blessed = true
	t.check(not listed_blessed, "赐福版不单独占格")
	t.check(sword_tile != null, "短剑有一格")
	if sword_tile == null:
		screen.queue_free()
		return
	t.check(sword_tile.variants.size() >= 3 and sword_tile.variants[0].id == &"shortsword", "异体：原件 + 蛮神版 + 日神版…（%d）" % sword_tile.variants.size())
	t.check(sword_tile.lit and sword_tile.variants_lit() == 1, "只有蛮神版带出过：格子亮、角标 1/%d" % sword_tile.variants.size())
	t.check(not screen.variants_open(), "还没点开")
	screen.show_variants(sword_tile)
	t.check(screen.variants_open() and screen.variant_tiles().size() == sword_tile.variants.size(), "点开：一个异体一小格")
	var lit_ids: Array = []
	for vt in screen.variant_tiles():
		if vt.lit:
			lit_ids.append(vt.def.id)
	t.eq(lit_ids, [&"shortsword_brute"], "只有蛮神版那一小格亮")
	screen.close_variants()
	t.check(not screen.variants_open(), "关掉了")
	var plain: CodexTile = null
	for tile in screen.codex_tiles():
		if tile.def.id == &"charm_brute":
			plain = tile
	t.check(plain != null and plain.variant_count() == 0, "护符本来就是信仰道具、没有异体：普通一格")
	screen.queue_free()
	_cleanup()
