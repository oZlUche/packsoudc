## 105 第十节 10.5（耐力消耗连乘轴）：因子算法、落到道具终值上、和乘区相乘、净化与显示，外加轴表自检。
##
## 期望值从表与公式推（步长 97 写在 `StatAxes.TABLE`，不在这里写死）：
## 断言里出现的 0.97^5 ≈ 85.87% 是**作者给的曲线**，定点实现只许差末位一个单位。
extends RefCounted

const AXIS := StatAxes.STAMINA_COST


## 一个只有一件道具的假人：那件道具的耐力消耗 = [param cost]（点数），可选一条 EMPOWER 乘区
static func _dummy(cost: float, empower_percent: int = 0) -> CombatantRuntime:
	var item := CompiledItem.new()
	item.source_uid = 7
	item.def_id = &"dummy_weapon"
	item.stats = StatSet.new()
	var v := item.stats.ensure(BattleStats.STAMINA_COST)
	v.base = StatMath.from_float(cost)
	if empower_percent != 0:
		v.add_percent(StatMath.Buff.EMPOWER, empower_percent)
	var spec := CombatantSpec.new()
	spec.baseline = StatSet.new()
	spec.add(item)
	return CombatantRuntime.from_spec(spec, 0)


static func run_compound_factor(t: TestCase) -> void:
	t.begin("105 10.5 · 连乘轴的因子：0.97^层数，负层是反过来除，0 层是 1")
	t.eq(StatAxes.mode_of(AXIS), StatAxes.Mode.COMPOUND, "耐力消耗轴是连乘模式")
	t.check(StatAxes.is_factor(AXIS), "连乘轴也是「乘一个因子」型，和百分比轴走同一条结算路")
	t.check(not StatAxes.is_percent(AXIS), "但它不是百分比轴（层数之间不是加算）")

	var per := StatAxes.step_of(AXIS) / 100.0
	t.eq(StatAxes.factor(AXIS, 0), StatMath.ONE, "0 层 = ×1，什么都不乘")
	for n in [1, 2, 3, 5, 8]:
		var want := StatMath.from_float(pow(per, float(n)))
		var got := StatAxes.factor(AXIS, n)
		t.check(absi(got - want) <= 1, "%d 层 = ×%.4f^%d（期望 %d，实得 %d，定点只许差 1）" % [n, per, n, want, got])

	# 负层（笨拙）是反过来除：1 / 0.97²
	var neg2 := StatAxes.factor(AXIS, -2)
	t.check(absi(neg2 - StatMath.from_float(1.0 / pow(per, 2.0))) <= 2,
		"−2 层 = ×1/%.4f² = %.4f（实得 %.4f）" % [per, 1.0 / pow(per, 2.0), StatMath.to_float(neg2)])
	t.check(neg2 > StatMath.ONE, "负层是减益：耐力消耗变大")

	# 正负相抵：+5 −2 和直接 +3 是同一个因子（层数先相抵再算，不是两个因子相乘）
	t.eq(StatAxes.factor(AXIS, 5 - 2), StatAxes.factor(AXIS, 3), "+5 层灵巧 −2 层笨拙 = +3 层")


static func run_cost_on_item(t: TestCase) -> void:
	t.begin("105 10.5 · 落到每件道具的耐力消耗终值上：10 点 × 5 层 = 8.59，另有 −20% 乘区时 6.87")
	var want5 := StatMath.to_float(StatAxes.factor(AXIS, 5))

	var rt := _dummy(10.0)
	t.eq(rt.item_stat(7, BattleStats.STAMINA_COST), StatMath.from_float(10.0), "没层数时就是面板的 10 点")
	rt.shift_axis(AXIS, 5, true)
	var cost := rt.item_stat(7, BattleStats.STAMINA_COST)
	t.check(absf(StatMath.to_float(cost) - 10.0 * want5) < 0.001,
		"5 层灵巧：出手扣 %.2f（期望 10 × %.4f = %.2f）" % [StatMath.to_float(cost), want5, 10.0 * want5])
	t.check(absf(StatMath.to_float(cost) - 8.59) < 0.01, "即作者给的 ≈8.59（实得 %.3f）" % StatMath.to_float(cost))

	# 轴在乘区之后：两者相乘，不是二选一
	var rt2 := _dummy(10.0, -20)
	t.eq(rt2.item_stat(7, BattleStats.STAMINA_COST), StatMath.from_float(8.0), "只有 −20% EMPOWER 乘区时是 8 点")
	rt2.shift_axis(AXIS, 5, true)
	var both := rt2.item_stat(7, BattleStats.STAMINA_COST)
	t.check(absf(StatMath.to_float(both) - 8.0 * want5) < 0.001,
		"−20%% 乘区 + 5 层灵巧 = %.2f（期望 0.8 × %.4f × 10 = %.2f）" % [StatMath.to_float(both), want5, 8.0 * want5])
	t.check(absf(StatMath.to_float(both) - 6.87) < 0.01, "即作者给的 ≈6.87（实得 %.3f）" % StatMath.to_float(both))


static func run_compiled_axes(t: TestCase) -> void:
	t.begin("105 10.5 · 编译期带来的层数记在系统层：净化洗不掉，显示「灵巧 ×n」")
	var item := CompiledItem.new()
	item.source_uid = 7
	item.def_id = &"dummy_weapon"
	item.stats = StatSet.new()
	item.stats.ensure(BattleStats.STAMINA_COST).base = StatMath.from_float(10.0)
	var spec := CombatantSpec.new()
	spec.baseline = StatSet.new()
	spec.add(item)
	spec.axes = {AXIS: 5}
	var rt := CombatantRuntime.from_spec(spec, 0)
	t.eq(rt.axis_system(AXIS), 5, "spec.axes 的 5 层种进系统层")
	t.eq(rt.axis_stacks(AXIS), 0, "内容层是空的")

	rt.clear_axis(AXIS)
	t.eq(rt.axis_total(AXIS), 5, "对手净化只动内容层，系统层的 5 层灵巧不动")

	# 被人加了 2 层笨拙：层数相抵，显示成「灵巧 ×3」
	rt.shift_axis(AXIS, -2)
	t.eq(rt.axis_total(AXIS), 3, "5 − 2 = 3 层")
	t.eq("%s ×%d" % [StatAxes.name_of(AXIS, rt.axis_total(AXIS)), absi(rt.axis_total(AXIS))], "灵巧 ×3",
		"buff 栏按合计层数显示（和 battle_view 同一个写法）")
	t.eq(StatAxes.name_of(AXIS, -1), "笨拙", "负层用负名")
	t.eq(rt.axis_factor(AXIS), StatAxes.factor(AXIS, 3), "单位的当前因子按合计层数算")


static func run_describe(t: TestCase) -> void:
	t.begin("105 10.4 · 悬浮窗的一句从表与层数算，不写死")
	var line := StatAxes.describe(AXIS, 5)
	t.check(line.contains("耐力消耗") and line.contains("×97%"), "第一行说清每层乘多少：%s" % line)
	t.check(line.contains("灵巧") and line.contains("笨拙"), "正名负名都在：%s" % line)
	t.check(line.contains("85.9%"), "第二行是当前的合计因子 ×85.9%%：%s" % line)
	var sys := StatAxes.describe(AXIS, 0, 5)
	t.check(sys.contains("不可解除"), "系统层要标明不可解除：%s" % sys)
	t.check(sys.contains("85.9%"), "系统层也算进合计：%s" % sys)


static func run_table_selfcheck(t: TestCase) -> void:
	t.begin("105 10.4 · 轴表自检：连乘轴的步长必须在 (0, 100) 开区间，否则因子不收敛")
	var compound := 0
	for axis in StatAxes.ORDER:
		t.check(StatAxes.has(axis), "ORDER 里的 %s 在表里" % axis)
		if not StatAxes.is_compound(axis):
			continue
		compound += 1
		var step := StatAxes.step_of(axis)
		t.check(step > 0.0 and step < 100.0, "%s 的步长 %s 在 (0, 100) 之间" % [axis, step])
		t.ne(StatAxes.stat_of(axis), &"", "连乘轴必须落在某项属性上（没有「由管线直接读」的连乘轴）")
	t.eq(compound, 1, "目前只有耐力消耗一条连乘轴")
	t.eq(StatAxes.ORDER.size(), StatAxes.TABLE.size(), "表里每条轴都在显示顺序里")
