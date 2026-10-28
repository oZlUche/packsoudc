## 147（作者定）：腰带 —— 随身槽，默认 3 格、可扩。160 补一（作者定）：放的是**可堆叠的一次性技能**（[BeltSkillDef]），不是道具：
## 存「id → 几个」、一种一格、同种叠在一起、用一次少一个；不进道具库（仓库 / 图鉴 / 负重 / 敌人包 / 搜索 / 商店货架都没有它）、撤离时作废。
## 来路四条：事件 `grant_belt`、商店「随身」一排、科技 `tech_belt_grant`、角色能力 / 章节 `starting_belt`。
## 烟雾弹（战前准备屏：这一场不打，同「脱身」）、急救包（地图上：体力 +1，满了不能用）
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func run_not_items(t: TestCase) -> void:
	t.begin("160 补一 · 随身技能不是道具：道具库里没有烟雾弹与急救包；随身技能库里有；敌人、商店货架的候选里都没有")
	var c := CS._content()
	t.check(c.items.get_def(&"smoke_bomb") == null and c.items.get_def(&"aid_pack") == null, "道具库里没有")
	t.check(BeltSkillDef.ids().has(&"smoke_bomb") and BeltSkillDef.ids().has(&"aid_pack"), "随身技能库里有：%s" % [BeltSkillDef.ids()])
	var smoke := BeltSkillDef.find(&"smoke_bomb")
	t.check(smoke != null and smoke.on_prebattle() and not smoke.on_map(), "烟雾弹只在开战前用")
	var aid := BeltSkillDef.find(&"aid_pack")
	t.check(aid != null and aid.on_map() and aid.effects[0] is MendVitality, "急救包地图上用、回体力")
	var economy: EconomyRules = load(ContentPaths.asset_file("economy_rules", "standard"))
	for id in ShopSession.candidates(economy, c.items):
		t.check(c.items.get_def(id) != null, "货架候选都是道具（%s）" % id)
	t.check(not ShopSession.candidates(economy, c.items).has(&"smoke_bomb"), "货架候选里没有烟雾弹")


static func run_stacks(t: TestCase) -> void:
	t.begin("160 补一 · 腰带：一种一格、同种叠着不限个数；格数限种类；用一个少一个，到零那格空出来；不认识的不收")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var belt := BeltModule.of(s)
	t.not_null(belt, "默认装了腰带模块")
	t.eq(belt.slot_count(), belt.slots, "默认 %d 格" % belt.slots)
	t.eq(belt.ids().size(), 0, "自由模式开局是空的")
	var changes := [0]
	belt.changed.connect(func(): changes[0] += 1)
	t.eq(belt.add(&"smoke_bomb", 3), 3, "放三个烟雾弹")
	t.eq(belt.ids(), [&"smoke_bomb"] as Array[StringName], "占一格")
	t.eq(belt.count_of(&"smoke_bomb"), 3, "叠了三个")
	t.eq(belt.add(&"smoke_bomb", 20), 20, "同种不限个数")
	t.eq(belt.add(&"nope", 1), 0, "不认识的不收")
	t.check(changes[0] >= 2, "变了就发 changed")
	belt.slots = 1
	t.eq(belt.add(&"aid_pack", 1), 0, "只剩一格：第二种放不下")
	t.eq(belt.add(&"smoke_bomb", 1), 1, "已有的那种照样叠")
	belt.slots = 3
	t.eq(belt.add(&"aid_pack", 2), 2, "加回三格：急救包放进第二格")
	t.eq(belt.ids(), [&"smoke_bomb", &"aid_pack"] as Array[StringName], "先来的在前面")
	var ctx := RunContext.new()
	var bonus := BeltSlotsBonus.new()
	bonus.amount = 2
	bonus.modify(ctx)
	t.eq(ctx.belt_slots_bonus, 2, "BeltSlotsBonus 往上下文里加格数")
	s.vitality.current = s.vitality.maximum - 2
	t.eq(belt.use(&"aid_pack"), "", "用一个急救包")
	t.eq(belt.count_of(&"aid_pack"), 1, "剩一个")
	t.eq(belt.use(&"aid_pack"), "", "再用一个")
	t.check(not belt.ids().has(&"aid_pack"), "用到零：那格空出来")
	t.eq(belt.use(&"aid_pack"), "腰带里没有这个", "没有了")


static func run_belt_use(t: TestCase) -> void:
	t.begin("147 · 用：急救包地图上 +1、满了不能用、开战前用不了；烟雾弹只在开战前、核心点用不了、普通战这一场不打（同脱身）")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var belt := BeltModule.of(s)
	belt.add(&"aid_pack", 2)
	belt.add(&"smoke_bomb", 1)
	var mend := BeltSkillDef.find(&"aid_pack").effects[0] as MendVitality
	s.vitality.current = s.vitality.maximum
	t.eq(s.hooks.belt_use(&"aid_pack"), "体力是满的", "满的不让用")
	t.eq(belt.count_of(&"aid_pack"), 2, "没用掉")
	s.vitality.current = s.vitality.maximum - 2
	var used: Array = []
	belt.used.connect(func(id: StringName): used.append(id))
	t.eq(s.hooks.belt_use(&"aid_pack"), "", "地图上用了")
	t.eq(s.vitality.current, s.vitality.maximum - 2 + mend.amount, "体力 +%d" % mend.amount)
	t.eq(belt.count_of(&"aid_pack"), 1, "少了一个")
	t.eq(used, [&"aid_pack"], "发了 used")

	t.eq(s.hooks.belt_use(&"smoke_bomb"), "只能在开战前用", "烟雾弹：地图上用不了")
	var node := CS._battle_node(s)
	s.events.pending_battle = {"node": node.id, "type": "core", "content": node.content, "kind": "node"}
	t.eq(s.hooks.belt_use(&"smoke_bomb"), "核心的战斗躲不开", "核心点用不了")
	s.vitality.current = 1
	s.events.pending_battle = {"node": node.id, "type": "battle", "content": node.content, "kind": "node"}
	t.eq(s.hooks.belt_use(&"aid_pack"), "开战前用不了", "急救包开战前用不了")
	var v0 := s.vitality.current
	var m0 := s.wallet.balance
	t.eq(s.hooks.belt_use(&"smoke_bomb"), "", "普通战：烟雾弹用了")
	t.check(s.events.pending_battle.is_empty(), "等着开打的一场没了")
	t.check(node.is_visited(), "点算用过")
	t.eq(s.vitality.current, v0, "体力不变")
	t.eq(s.wallet.balance, m0, "没进账")
	t.check(s.pending_loot == null, "没有战利品")
	t.eq(belt.count_of(&"smoke_bomb"), 0, "烟雾弹用掉了")


static func run_belt_save(t: TestCase) -> void:
	t.begin("147 / 160 · 存档：腰带的「id → 几个」往返；147 的老档（腰带是格子）读出空腰带、不重发开局的；撤离时腰带里剩的作废")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var belt := BeltModule.of(s)
	belt.add(&"smoke_bomb", 2)
	belt.add(&"aid_pack", 1)
	var d := s.to_dict()
	t.eq((d["modules"] as Dictionary)["belt"], {"stacks": {"smoke_bomb": 2, "aid_pack": 1}}, "存的是 id → 几个")
	var back := RunState.from_dict(d, c.chapter, c.items, c.enemies, c.sets)
	t.not_null(back, "读得回来")
	if back == null:
		return
	var b2 := BeltModule.of(back)
	t.eq(b2.count_of(&"smoke_bomb"), 2, "烟雾弹两个")
	t.eq(b2.ids(), [&"smoke_bomb", &"aid_pack"] as Array[StringName], "顺序不变")
	var old := d.duplicate(true)
	(old["modules"] as Dictionary)["belt"] = {"belt": {"size": [3, 1], "items": []}}
	var back2 := RunState.from_dict(old, c.chapter, c.items, c.enemies, c.sets)
	t.eq(BeltModule.of(back2).total(), 0, "147 的老档：空腰带")
	# 撤离：腰带里的不带出去
	s.phase = RunState.Phase.EXTRACTED
	var r := RunResult.settle(s)
	for inst in r.carried:
		t.check((inst as ItemInstance).def != null, "带出去的都是道具")
	t.eq(r.carried.size(), s.board.item_count(), "带出去的只有棋盘上的")


static func run_sources(t: TestCase) -> void:
	t.begin("160 补一 · 来路：章节 starting_belt、角色能力 / 局外 buff 的 starting_belt、科技 tech_belt_grant（模块输入）、事件 grant_belt")
	var c := CS._content()
	var ch := c.chapter.duplicate() as ChapterDef
	ch.starting_belt = [&"smoke_bomb", &"smoke_bomb", &"aid_pack"] as Array[StringName]
	var hero: CharacterDef = (c.characters[0] as CharacterDef).duplicate()
	var passive := PassiveSkill.new()
	passive.id = &"probe_belt"
	var gift := StartingBelt.new()
	gift.skill = &"aid_pack"
	gift.count = 2
	passive.passive = [gift] as Array[Effect]
	hero.skills = hero.skills.duplicate()
	hero.skills.append(passive)
	var meta := MetaState.new()
	var tech := TechBeltGrant.new()
	tech.skill = &"smoke_bomb"
	tech.count = 1
	tech.derive(meta, 2)
	t.eq(meta.belt_grants, {&"smoke_bomb": 2}, "科技二级：每局开局两个烟雾弹")
	tech.derive(meta, 0)
	t.check(meta.belt_grants.is_empty(), "降到零级：不发")
	tech.derive(meta, 1)
	var s: RunState = null
	for seed in range(1, 60):
		s = RunState.start(ch, seed, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], hero, [], null, {}, &"",
			{BeltModule.ID: {"grants": meta.belt_grants.duplicate()}})
		if s != null:
			break
	t.not_null(s, "开得了局")
	if s == null:
		return
	var belt := BeltModule.of(s)
	t.eq(belt.count_of(&"smoke_bomb"), 3, "章节两个 + 科技一个")
	t.eq(belt.count_of(&"aid_pack"), 3, "章节一个 + 角色能力两个")
	t.eq(s.board.item_count(), s.board.bags().size(), "棋盘上没有多出道具")
	t.eq(s.storage.item_count(), 0, "地上也没有")
	t.check(gift.describe().contains("急救包"), "说明写着名字：%s" % gift.describe())
	# 事件：grant_belt
	var outcome := GrantBelt.new()
	outcome.skill = &"aid_pack"
	outcome.count = 1
	var ctx := EventContext.new()
	ctx.hooks = s.hooks
	outcome.apply(ctx)
	t.eq(belt.count_of(&"aid_pack"), 4, "事件给了一个")
	var said: Array = ctx.detail().get("belt", [])
	t.check(said.size() == 1 and String(said[0]) == "急救包 ×1", "结果页写着腰带里多了什么：%s" % [said])
	belt.slots = 2
	var full := GrantBelt.new()
	full.skill = &"nope"
	var ctx2 := EventContext.new()
	ctx2.hooks = s.hooks
	full.apply(ctx2)
	t.check(not ctx2.detail().has("belt") and ctx2.log.size() == 1, "不认识 / 放不下：没发、日志说一句")


static func run_shop(t: TestCase) -> void:
	t.begin("160 补一 · 商店「随身」一排：按权重抽、跟着货架刷新、同一次刷新可复现；买了直接进腰带不进棋盘；买过的那格「已售」存在点上")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	var economy: EconomyRules = load(ContentPaths.asset_file("economy_rules", "standard"))
	t.check(not economy.belt_stock.is_empty(), "标准经济有「随身」那一排")
	var node := MapNode.new()
	node.id = 99
	node.content_seed = 1234
	s.wallet.earn(500, &"test")
	var shop := ShopSession.new(node, economy, c.items, s.wallet)
	shop.belt_grant = s.hooks.belt_grant
	t.check(shop.belt_offers.size() >= 1 and shop.belt_offers.size() <= economy.belt_picks, "抽了 1 ～ %d 种（%d）" % [economy.belt_picks, shop.belt_offers.size()])
	var again := ShopSession.new(node, economy, c.items, s.wallet)
	t.eq(again.belt_offers, shop.belt_offers, "同一家店同一次刷新：一样")
	var sid := StringName(String(shop.belt_offers[0]["id"]))
	var price := int(shop.belt_offers[0]["price"])
	var money := s.wallet.balance
	var board_n := s.board.item_count()
	t.eq(shop.buy_belt(0), "", "买第一格")
	t.eq(BeltModule.of(s).count_of(sid), 1, "进了腰带")
	t.eq(s.wallet.balance, money - price, "扣了 %d" % price)
	t.eq(s.board.item_count(), board_n, "棋盘没变")
	t.eq(shop.buy_belt(0), "没有这一格", "买过的不能再买")
	var reopened := ShopSession.new(node, economy, c.items, s.wallet)
	t.check(reopened.belt_sold.has(0), "回到这家店：那格还是已售")
	var poor := ShopSession.new(node, economy, c.items, Wallet.new(0))
	poor.belt_grant = s.hooks.belt_grant
	if poor.belt_offers.size() > 1:
		t.eq(poor.can_buy_belt(1), "钱不够", "没钱买不了")
	t.check(ShopSession.new(node, economy, c.items, s.wallet).can_buy_belt(0) != "", "没接腰带的店：买不了")


static func run_belt_icons(t: TestCase) -> void:
	t.begin("随身技能图标定稿（作者 10-28 18:35「B+C」）：烟雾弹陶罐、急救包亚麻小包，60 × 60，按约定路径；图跟着 def 留一份，腰带每帧画不重读")
	for id in [&"smoke_bomb", &"aid_pack"]:
		var def := BeltSkillDef.find(id)
		t.not_null(def, "%s 有定义" % id)
		if def == null:
			continue
		var icon := def.icon()
		t.not_null(icon, "%s 有图标" % id)
		if icon != null:
			t.eq(icon.get_size(), Vector2(60, 60), "%s 60 × 60" % id)
			t.check(def.icon() == icon, "%s 第二次拿到同一张" % id)
