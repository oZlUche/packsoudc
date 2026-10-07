## 105 的专项验收（报告 105 第八节 2～5）：按件随机挑选可复现、火焰轴、食物翻倍只动 base、基线补账消失。
##
## 第 1 条（搬家前后逐件相等）是金样，在 `test_compile_golden.gd`；第 8 条是内容往返与全套，跑器自己管。
extends RefCounted

const WEAPONS: Array[StringName] = [&"knife", &"shortsword", &"longsword", &"cleaver", &"scimitar"]


static func _items() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


## 一张只有武器的棋盘（不要包：这里不测空间，只测筛与挑）
static func _board(items: ItemDatabase, ids: Array[StringName]) -> GridInventory:
	return LootPacker.board_of(ids, Vector2i(8, 6), items)


static func _enchant(count: int) -> EnchantWeaponsPerk:
	var p := EnchantWeaponsPerk.new()
	p.count = count
	return p


## 挂了附火规则的那几件 uid
static func _enchanted(spec: CombatantSpec) -> Array[int]:
	var out: Array[int] = []
	for it in spec.items:
		for rule in (it as CompiledItem).rules:
			for e in (rule as AbilityRule).effects:
				if e is FireEnchant and not out.has((it as CompiledItem).source_uid):
					out.append((it as CompiledItem).source_uid)
	out.sort()
	return out


## 让这条 perk 自己往入参里放，再编译 —— 和开战时走的是同一条路
static func _compile(board: GridInventory, perk: FaithPerk, seed: int) -> CombatantSpec:
	var input := CompileInput.new()
	input.seed = seed
	perk.compile_into(input, board, null)
	return BattleCompiler.compile(board, input)


static func run_scoped_pick(t: TestCase) -> void:
	t.begin("105 第八节 2 · 按件随机挑选可复现：同 seed 两次挑同三把、换 seed 可能换、不够 3 把就全挑、没规则的不在候选里")
	var items := _items()
	var board := _board(items, WEAPONS)
	var all_uids: Array[int] = []
	for inst in board.items():
		all_uids.append((inst as ItemInstance).uid)
	all_uids.sort()
	t.eq(all_uids.size(), 5, "棋盘上 5 把武器")

	var a := _enchanted(_compile(board, _enchant(3), 12345))
	var b := _enchanted(_compile(board, _enchant(3), 12345))
	t.eq(a.size(), 3, "挑了 3 把")
	t.eq(a, b, "同一个 seed 两次编译挑的是同三把：%s" % str(a))
	# 换 seed：只要存在**一个**别的 seed 挑出不同的三把，就说明挑选真的跟着 seed 走
	var differs := false
	for s in range(1, 40):
		if _enchanted(_compile(board, _enchant(3), s * 7919)) != a:
			differs = true
			break
	t.check(differs, "换 seed 会挑出不同的三把（不是写死的）")
	for uid in a:
		t.check(all_uids.has(uid), "挑中的 uid %d 在棋盘上" % uid)

	# 候选不够就全挑
	var small := _board(items, [&"knife", &"shortsword"] as Array[StringName])
	t.eq(_enchanted(_compile(small, _enchant(3), 1)).size(), 2, "只有 2 把武器：全挑")
	t.eq(_enchanted(_compile(board, _enchant(0), 1)).size(), 5, "count = 0：全部武器")

	# require_active：没规则的道具不在候选里（棋盘上没有这种武器，直接查构件的筛法）
	var probe := CompileInput.new()
	_enchant(3).compile_into(probe, board, null)
	var scope := probe.scoped[0] as ScopedMod
	t.check(scope.require_active, "附魔这一条只要有规则的")
	t.check(not scope.matches(items.get_def(&"knife"), false), "同一件道具，没规则就不命中")
	t.check(scope.matches(items.get_def(&"knife"), true), "有规则就命中")
	t.check(not scope.matches(items.get_def(&"ration"), true), "口粮不带 weapon 标签：不命中")

	# 挑中的那件挂的规则只听自己（否则一件附魔会被全场出手触发）
	var spec := _compile(board, _enchant(3), 777)
	var bound := 0
	for it in spec.items:
		for rule in (it as CompiledItem).rules:
			var trig := (rule as AbilityRule).trigger as OnItemFired
			if trig == null:
				continue
			bound += 1
			t.eq(trig.source_uids, [(it as CompiledItem).source_uid] as Array[int], "附火规则只听自己（uid %d）" % (it as CompiledItem).source_uid)
			t.check(trig.include_self, "包括自己出手")
	t.eq(bound, 3, "三条规则都绑好了")


static func run_fire_axis(t: TestCase) -> void:
	t.begin("105 第八节 3 · 火焰轴：祈祷按斐波那契攒层、种在系统层（净化洗不掉）、放大所有火焰来源、物理不受影响")
	var pray := AltarPrayFirePerk.new()
	t.eq([pray.gain_at(1), pray.gain_at(2), pray.gain_at(3), pray.gain_at(4), pray.gain_at(5), pray.gain_at(6)],
		[1, 1, 2, 3, 5, 8], "斐波那契：每次给 1 / 1 / 2 / 3 / 5 / 8 层")
	var cumulative: Array[int] = []
	var sum := 0
	for n in range(1, 7):
		sum += pray.gain_at(n)
		cumulative.append(sum)
	t.eq(cumulative, [1, 2, 4, 7, 12, 20], "累计 1 / 2 / 4 / 7 / 12 / 20 层")
	t.eq(StatAxes.factor(StatAxes.FIRE_DAMAGE, 20), StatMath.from_float(1.6), "20 层 = ×1.6（每层 3%）")
	var tuned := AltarPrayFirePerk.new()
	tuned.gains = [3, 2, 2]
	t.eq([tuned.gain_at(1), tuned.gain_at(4)], [3, 2], "gains 填了就按表走；超出表长按最后一项（第 4 次给 2 层）")

	# 编译 → 运行时：层数在系统层
	var input := CompileInput.new()
	input.shift_axis(StatAxes.FIRE_DAMAGE, 20)
	var spec := BattleCompiler.compile(null, input)
	t.eq(int(spec.axes.get(StatAxes.FIRE_DAMAGE, 0)), 20, "编译结果带着 20 层")
	var me := CombatantRuntime.from_spec(spec, 0)
	t.eq(me.axis_system(StatAxes.FIRE_DAMAGE), 20, "开战时种在系统层")
	t.eq(me.axis_stacks(StatAxes.FIRE_DAMAGE), 0, "内容层是 0")

	# 伤害管线：攻方的因子乘在防御之前
	var foe := CombatantRuntime.from_spec(BattleCompiler.compile_board(null, CombatantBaseline.with_hp(1000.0)), 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ctx := BattleContext.create(me, foe, rng)
	var fire := DamageResolver.deal(ctx, foe, StatMath.from_float(10.0), DamageTypes.FIRE, 0, 0)
	t.eq(StatMath.to_int(fire), 16, "20 层下一下 10 点火焰打出 16（×1.6）")
	var phys := DamageResolver.deal(ctx, foe, StatMath.from_float(10.0), DamageTypes.PHYSICAL, 0, 0)
	t.eq(StatMath.to_int(phys), 10, "物理伤害不受火焰轴影响")
	# 「任何火焰来源」：不经附魔、随手造一包火焰（灼烧走的也是这条路）
	var tick := DamageResolver.resolve(ctx, DamagePacket.create(DamageTypes.FIRE, StatMath.from_float(5.0), foe, 0, 0))
	t.eq(StatMath.to_int(tick), 8, "灼烧这类火焰来源一样放大（5 → 8）")
	var no_source := DamageResolver.resolve(ctx, DamagePacket.create(DamageTypes.FIRE, StatMath.from_float(10.0), foe, -1, 0))
	t.eq(StatMath.to_int(no_source), 10, "没有攻方（环境 / 自伤）就不放大")


static func run_food_double(t: TestCase) -> void:
	t.begin("105 第八节 4 · 食物翻倍只动 base：食物的基础值 ×2、急速不动、它的 flat 与乘区不动；非食物不受影响")
	var items := _items()
	var board := _board(items, [&"ration", &"shortsword"] as Array[StringName])
	var ration_uid := -1
	var sword_uid := -1
	for inst in board.items():
		if (inst as ItemInstance).def.id == &"ration":
			ration_uid = (inst as ItemInstance).uid
		else:
			sword_uid = (inst as ItemInstance).uid
	# 同时给每件加一条乘算 + 一条加算，用来确认翻倍不碰它们（133：一条只做一件事，写两条）
	var extra := StatModifier.make(BattleStats.REGEN_STAMINA, StatModifier.Mode.MULT, 50.0)
	var extra_flat := StatModifier.make(BattleStats.REGEN_STAMINA, StatModifier.Mode.ADD, 1.0)

	var plain := CompileInput.new()
	plain.mods = [extra, extra_flat] as Array[StatModifier]
	var before := BattleCompiler.compile(board, plain)

	var doubled := CompileInput.new()
	doubled.mods = [extra, extra_flat] as Array[StatModifier]
	FoodDoublePerk.new().compile_into(doubled, board, null)
	var after := BattleCompiler.compile(board, doubled)

	var r0 := before.stats_of(ration_uid)
	var r1 := after.stats_of(ration_uid)
	t.eq(r1.ensure(BattleStats.REGEN_STAMINA).base, r0.ensure(BattleStats.REGEN_STAMINA).base * 2, "口粮回气的 base 翻倍")
	t.eq(r1.ensure(BattleStats.MAX_STAMINA).base, r0.ensure(BattleStats.MAX_STAMINA).base * 2, "耐力上限的 base 翻倍")
	t.eq(r1.ensure(BattleStats.HASTE).base, r0.ensure(BattleStats.HASTE).base, "急速的 base 不动（每件都是 1.0，翻倍就成了二倍速）")
	t.eq(r1.ensure(BattleStats.REGEN_STAMINA).flat, r0.ensure(BattleStats.REGEN_STAMINA).flat, "它的 flat 不动")
	t.eq(r1.ensure(BattleStats.REGEN_STAMINA).percent,
		r0.ensure(BattleStats.REGEN_STAMINA).percent, "它的乘算不动")
	t.eq(after.stats_of(sword_uid).ensure(BattleStats.DAMAGE).base,
		before.stats_of(sword_uid).ensure(BattleStats.DAMAGE).base, "不带 food 标签的短剑不受影响")


static func run_baseline_catchup(t: TestCase) -> void:
	t.begin("105 第八节 5 · 基线补账消失：生命上限最后算，改基线生命多多少 spec.max_hp 就多多少，不多不少")
	var items := _items()
	var board := _board(items, [&"shortsword", &"ration"] as Array[StringName])
	var base := CombatantBaseline.with_hp(100.0)
	var plain := BattleCompiler.compile(board, CompileInput.of(base))

	var perk := StatModPerk.new()
	perk.target = "baseline"
	var m := StatModifier.new()
	m.stat = BattleStats.MAX_HP
	m.amount = 10.0
	perk.mods = [m] as Array[StatModifier]
	var input := CompileInput.of(base)
	perk.compile_into(input, board, null)
	var bumped := BattleCompiler.compile(board, input)

	t.eq(bumped.max_hp, plain.max_hp + StatMath.from_float(10.0), "max_hp 多 10，不多不少")
	t.eq(bumped.baseline.total_of(BattleStats.MAX_HP), plain.baseline.total_of(BattleStats.MAX_HP) + StatMath.from_float(10.0), "基线也多 10")
	# 没有棋盘也成立（走的是 compile 里 board == null 的那条路）
	var empty := BattleCompiler.compile(null, CompileInput.of(base))
	var input2 := CompileInput.of(base)
	perk.compile_into(input2, null, null)
	t.eq(BattleCompiler.compile(null, input2).max_hp, empty.max_hp + StatMath.from_float(10.0), "空棋盘一样")


static func run_axis_passive_note(t: TestCase) -> void:
	t.begin("105 3.3 · 轴层数种在系统层就不发 AXIS_SHIFTED，来源靠 buff 栏的常驻格说清楚")
	var m := AltarModule.new()
	t.eq(m.shift_axis(StatAxes.FIRE_DAMAGE, 4), 4, "攒了 4 层")
	t.eq(m.shift_axis(StatAxes.FIRE_DAMAGE, 3), 7, "再攒 3 层 = 7")
	t.eq(int(m.axes().get(StatAxes.FIRE_DAMAGE, 0)), 7, "给编译器的是 7 层")
	var back := AltarModule.new()
	back.restore(m.to_dict())
	t.eq(int(back.axes().get(StatAxes.FIRE_DAMAGE, 0)), 7, "跟存档（modules.altar.axis_bonus）")
	t.check(StatAxes.describe(StatAxes.FIRE_DAMAGE, 0, 7).contains("不可解除"), "悬浮窗里写明系统层不可解除")
