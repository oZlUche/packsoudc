## 大地之神（作者牌表 11-26）在局里的那一半：牌进牌池（神殿先不开）、进一个新节点的苦劳 / 锻炼 / 修行（升级版满级化作一次质变）、
## 进旧节点的西西弗斯、万象的经验与金钱加成、磐石让大地加重、编译时的天地规则与随机增益
extends RefCounted

const G := preload("res://tests/run/test_god_cards_388.gd")


static func _node(run: RunState, type: StringName) -> MapNode:
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		if n.type == type:
			return n
	return null


static func run_pool(t: TestCase) -> void:
	t.begin("大地之神 · 牌池：质变 + 升级、基础牌、专属牌（只拿一次）都进牌表；神殿还没落成；有质变牌池")
	var run := G._start(71, &"earth")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"earth":
		t.check(false, "开局奉大地之神")
		return
	var r := lv.rules()
	var quals := 0
	var once := 0
	var bases := 0
	for cid in r.card_ids():
		if r.god_of(cid) != &"earth":
			continue
		if r.is_qual(cid):
			quals += 1
		elif bool(r.card(cid).get("once", false)):
			once += 1
		else:
			bases += 1
	t.check(quals >= 16 and quals % 2 == 0, "质变和升级版成对（%d 张）" % quals)
	t.check(bases >= 3, "基础牌（%d 张）" % bases)
	t.check(once >= 8, "专属牌只拿一次（%d 张）" % once)
	t.check(lv.has_qual_pool(), "开局质变位出大地之神的牌")
	t.check(not Pantheon.temple_ready(&"earth"), "万神院：大地之神的神殿还没落成（牌没写齐）")
	t.check(lv.card_text(&"god_earth_rock").contains("8"), "牌面按数写：%s" % lv.card_text(&"god_earth_rock"))
	var spec := run.compile_player()
	var found := spec.set_rules.any(func(rr: AbilityRule) -> bool: return not rr.effects.is_empty() and rr.effects[0] is EarthHeaven)
	t.check(found, "编译出天地的那条规则")
	run.dispose()


static func run_nodes(t: TestCase) -> void:
	t.begin("大地之神 · 进点：苦劳给负重那么多钱、锻炼按大地件数涨上限、修行给负重盈余的经验；进旧节点西西弗斯攒所有属性")
	var run := G._start(72, &"earth")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"earth":
		t.check(false, "开局奉大地之神")
		return
	var perk := EarthHeavenPerk.new()
	var node := _node(run, &"battle")
	lv.taken["god_earth_toil"] = 1
	var before := run.wallet.balance
	perk.on_node_entered(run, node, true)
	t.eq(run.wallet.balance - before, run.carry_weight(), "苦劳：多了负重 %d 那么多钱" % run.carry_weight())
	lv.taken["god_earth_toil_up"] = 1
	before = run.wallet.balance
	perk.on_node_entered(run, node, true)
	t.eq(run.wallet.balance - before, run.carry_weight() * 2, "苦劳升级：两倍")
	lv.taken.erase("god_earth_toil")
	lv.taken.erase("god_earth_toil_up")
	var grounds := EarthHeaven.count_of(EarthHeaven.roles(run.board), EarthHeaven.GROUND)
	lv.taken["god_earth_train"] = 1
	perk.on_node_entered(run, node, true)
	var gained := float(lv.god_state.get(EarthHeavenPerk.TRAIN_HP, 0.0)) + float(lv.god_state.get(EarthHeavenPerk.TRAIN_STAMINA, 0.0))
	t.check(is_equal_approx(gained, grounds * 0.5), "锻炼：上限涨大地件数的一半（%d 件 → %s）" % [grounds, gained])
	lv.taken.erase("god_earth_train")
	lv.taken["god_earth_practice"] = 1
	var xp0 := lv.xp
	perk.on_node_entered(run, node, true)
	var spare := maxi(0, run.carry_capacity() - run.carry_weight())
	t.check(is_equal_approx(lv.xp - xp0, spare * lv.mult()), "修行：负重盈余 %d 点经验（乘难度系数）" % spare)
	perk.on_node_entered(run, node, false)
	t.eq(lv.xp, xp0 + spare * lv.mult(), "进旧节点不给修行")
	# 修行升级：满级时化作一次质变选牌（只一次）
	lv.taken["god_earth_practice_up"] = 1
	lv.xp = lv.rules().total_for(lv.rules().level_cap) + 1.0
	var due := lv.sacrifice_due()
	perk.on_node_entered(run, node, true)
	perk.on_node_entered(run, node, true)
	t.eq(lv.sacrifice_due(), due + 1, "修行升级满级：多一次质变选牌，只给一次")
	# 西西弗斯
	lv.taken["god_earth_sisyphus"] = 1
	perk.on_node_entered(run, node, false)
	perk.on_node_entered(run, node, false)
	t.eq(int(lv.god_state.get(EarthHeavenPerk.OLD_KEY, 0)), 2, "西西弗斯：进了两次旧节点")
	var input := CompileInput.new()
	perk.compile_into(input, run.board, run)
	var dmg := input.mods.filter(func(m: StatModifier) -> bool: return m.stat == BattleStats.DAMAGE)
	t.check(dmg.size() == 1 and is_equal_approx((dmg[0] as StatModifier).amount, 2.0), "所有属性 +2%（伤害那一项）")
	t.check(input.baseline_mods.any(func(m: StatModifier) -> bool: return m.stat == BattleStats.MAX_HP), "生命上限也算")
	run.dispose()


static func run_myriad_and_rock(t: TestCase) -> void:
	t.begin("大地之神 · 万象：每进过一种节点经验与金钱各 +10%（卖东西不算）；磐石：大地的重量多算一半")
	var run := G._start(73, &"earth")
	var lv := LevelModule.of(run)
	if lv == null or run.active_faith_id() != &"earth":
		t.check(false, "开局奉大地之神")
		return
	var perk := EarthHeavenPerk.new()
	lv.god_state.erase(EarthHeavenPerk.TYPES_KEY)
	perk.on_node_entered(run, _node(run, &"battle"), true)
	perk.on_node_entered(run, _node(run, &"battle"), false)
	perk.on_node_entered(run, _node(run, &"rest"), true)
	t.eq(EarthHeavenPerk.xp_pct(lv), 0.0, "没拿：不加")
	var m0 := lv.mult()
	lv.taken["god_earth_myriad"] = 1
	t.check(is_equal_approx(EarthHeavenPerk.xp_pct(lv), 20.0), "两种节点：经验 +20%")
	t.check(is_equal_approx(lv.mult(), m0 * 1.2), "经验值系数跟着乘")
	var before := run.wallet.balance
	run.wallet.earn(100, &"battle")
	t.eq(run.wallet.balance - before, 120, "打赢的钱 +20%")
	before = run.wallet.balance
	run.wallet.earn(100, &"shop_sell")
	t.eq(run.wallet.balance - before, 100, "卖东西不加")
	lv.taken["god_earth_myriad_up"] = 1
	t.check(is_equal_approx(EarthHeavenPerk.gold_pct(lv), 40.0), "升级翻倍")
	lv.xp = lv.rules().total_for(lv.rules().level_cap) + 1.0
	t.check(is_equal_approx(EarthHeavenPerk.xp_pct(lv), 20.0) and is_equal_approx(EarthHeavenPerk.gold_pct(lv), 60.0), "满级：经验加成的一半挪给金钱")
	# 磐石
	var w0 := run.carry_weight()
	lv.taken["god_earth_rock"] = 1
	var extra := 0.0
	var got := EarthHeaven.roles(run.board)
	for uid in EarthHeaven.uids_of(got, EarthHeaven.GROUND):
		extra += ItemWeight.of_in(run.board.get_item(uid), run.board) * 0.5
	t.eq(run.carry_weight(), w0 + roundi(extra), "磐石：大地加重一半（+%d）" % roundi(extra))
	run.dispose()
