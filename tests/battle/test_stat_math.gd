## 数值约定的可执行定义（架构文档 4.3）。
##
## 这套断言就是约定本身 —— 想改公式，必须先改这里。
extends RefCounted

const ONE := StatMath.ONE


static func run(t: TestCase) -> void:
	t.begin("数值约定 · 定点数")

	t.eq(StatMath.from_percent(25), ONE / 4, "25% 应为 0.25")
	t.eq(StatMath.from_percent(100), ONE, "100% 应为 1.0")
	t.eq(StatMath.from_percent(0), 0, "0% 应为 0")
	t.eq(StatMath.from_percent(-50), -ONE / 2, "-50% 应为 -0.5")

	t.eq(StatMath.mul(ONE, ONE), ONE, "1.0 × 1.0 = 1.0")
	t.eq(StatMath.mul(StatMath.from_float(2.0), StatMath.from_float(3.0)),
		StatMath.from_float(6.0), "2 × 3 = 6")
	t.eq(StatMath.mul(StatMath.from_float(0.5), StatMath.from_float(0.5)),
		StatMath.from_float(0.25), "0.5 × 0.5 = 0.25")
	t.eq(StatMath.mul(0, ONE), 0, "0 乘任何数为 0")

	# 乘以 1.0 必须逐位不变 —— 这是「末尾追加空乘区不改变结果」的前提
	for v in [1, 7, 12345, ONE, ONE * 999 + 12345]:
		t.eq(StatMath.mul(v, ONE), v, "乘 1.0 应逐位不变（v=%d）" % v)

	# 取整对称
	t.eq(StatMath.to_int(StatMath.from_float(2.5)), 3, "2.5 取整为 3")
	t.eq(StatMath.to_int(StatMath.from_float(-2.5)), -3, "-2.5 取整为 -3（远离零）")
	t.eq(StatMath.to_int(StatMath.from_float(2.4)), 2, "2.4 取整为 2")



static func run_formula(t: TestCase) -> void:
	t.begin("数值约定 · 结算公式（133：一个乘区 —— 终值 = 基础 × max(0, 1 + Σ乘算) + Σ加算）")

	# --- 只有基础值 ---
	var s := StatValue.new(StatMath.from_float(100.0))
	t.eq(s.total_int(), 100, "无任何加成时终值等于基础值")

	# --- 一条乘算 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(50)
	t.eq(s.total_int(), 150, "100 × (1+50%) = 150")

	# --- 乘算之间相加而不是相乘（133）---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(50)
	s.add_percent(50)
	t.eq(s.total_int(), 200, "两条 +50% 相加为 +100%：100 × 2 = 200，不是 225")
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(20)
	s.add_percent(15)
	t.eq(s.total(), StatMath.from_float(135.0), "+20% 与 +15%（箭矢 + 力量的符号）：1.35，不再是跨区的 1.38")

	# --- 加算在乘法之后，不吃乘算 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(100)
	s.add_flat(StatMath.from_float(10.0))
	t.eq(s.total_int(), 210, "加算不吃乘算放大：100 × 2 + 10 = 210，不是 220")

	# --- 加算任意来源相加 ---
	s = StatValue.new(StatMath.from_float(50.0))
	s.add_flat(StatMath.from_float(5.0))
	s.add_flat(StatMath.from_float(3.0))
	t.eq(s.total_int(), 58, "多个加算相加")

	# --- 完整公式 ---
	s = StatValue.new(StatMath.from_float(20.0))
	s.add_percent(25)
	s.add_percent(25)
	s.add_percent(20)
	s.add_flat(StatMath.from_float(4.0))
	t.eq(s.total_int(), 38, "20 × (1 + 70%) + 4 = 38")

	# --- 加成来源的先后顺序不影响结果 ---
	var a := StatValue.new(StatMath.from_float(77.0))
	a.add_percent(13)
	a.add_percent(41)
	a.add_flat(StatMath.from_float(6.0))
	var b := StatValue.new(StatMath.from_float(77.0))
	b.add_flat(StatMath.from_float(6.0))
	b.add_percent(41)
	b.add_percent(13)
	t.eq(a.total(), b.total(), "加成的调用顺序不得影响终值")

	var only_base := StatValue.new(StatMath.from_float(123.0))
	t.eq(only_base.total(), StatMath.from_float(123.0), "没有乘算时逐位等于基础值")

	# --- 缩小 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(-25)
	t.eq(s.total_int(), 75, "−25% 得 75")
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(-60)
	s.add_percent(-50)
	t.eq(s.total_int(), 0, "−60% 与 −50% 相加为 −110%：钳到 0")

	# --- 乘算之和低于 −100% 钳 0，绝不翻正 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(-80)
	s.add_percent(-40)
	t.eq(s.total_int(), 0, "乘算之和 −120% 钳为 0")
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(-200)
	s.add_flat(StatMath.from_float(7.0))
	t.eq(s.total_int(), 7, "乘法部分归零后，加算照常相加")

	# --- 中途不取整 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(5)
	s.add_percent(5)
	var combined := StatValue.new(StatMath.from_float(100.0))
	combined.add_percent(10)
	t.eq(s.total(), combined.total(), "两个 +5% 必须等于一个 +10%")

	# --- 克隆互不影响 ---
	var src := StatValue.new(StatMath.from_float(10.0))
	src.add_percent(50)
	var copy := src.clone()
	copy.add_percent(50)
	t.eq(src.total_int(), 15, "克隆后改副本不应影响原件")
	t.eq(copy.total_int(), 20, "副本自身的加成生效")

	# --- StatModifier：一条只做一件事 ---
	var set := StatSet.new()
	set.set_base(BattleStats.DAMAGE, StatMath.from_float(10.0))
	StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.MULT, 50.0).apply_to(set, 2)
	StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.ADD, 3.0).apply_to(set, 1)
	t.eq(set.ensure(BattleStats.DAMAGE).total_int(), 23, "两份 +50% 乘算 + 3 加算：10 × 2 + 3 = 23")
	t.check(StatModifier.make(BattleStats.DAMAGE, StatModifier.Mode.MULT, 25.0).editor_hint().begins_with("乘算 · 扩大"), "提示：乘算 · 扩大")
	t.check(StatModifier.make(BattleStats.HASTE, StatModifier.Mode.MULT, -10.0).editor_hint().contains("缩小"), "提示：缩小")
	t.check(StatModifier.make(BattleStats.MAX_SHIELD, StatModifier.Mode.ADD, 8.0).editor_hint().contains("不吃百分比"), "提示：加算不吃百分比")
	t.check(StatModifier.make(BattleStats.CRIT_CHANCE, StatModifier.Mode.MULT, 5.0).editor_hint().contains("只收加算"), "提示：暴击只收加算")
