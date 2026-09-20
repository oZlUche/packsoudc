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

	t.check(StatMath.category_count() >= 1, "至少要有一个乘区")
	t.eq(StatMath.categories().size(), StatMath.category_count(), "枚举值数量应与计数一致")


static func run_formula(t: TestCase) -> void:
	t.begin("数值约定 · 结算公式")

	var B := StatMath.Buff

	# --- 只有基础值 ---
	var s := StatValue.new(StatMath.from_float(100.0))
	t.eq(s.total_int(), 100, "无任何加成时终值等于基础值")

	# --- 单个乘区 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(B.SHARP, 50)
	t.eq(s.total_int(), 150, "100 × (1+50%) = 150")

	# --- 同一乘区内相加 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(B.SHARP, 30)
	s.add_percent(B.SHARP, 20)
	t.eq(s.total_int(), 150, "同区 +30% 与 +20% 相加为 +50%，得 150")

	# --- 不同乘区相乘，而不是相加 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(B.SHARP, 50)
	s.add_percent(B.FIRE, 50)
	t.eq(s.total_int(), 225, "跨区 50% 与 50% 相乘：100 × 1.5 × 1.5 = 225，不是 200")

	# --- 固定加值在所有乘法之后 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(B.SHARP, 100)
	s.add_flat(StatMath.from_float(10.0))
	t.eq(s.total_int(), 210, "固定加值不吃乘区放大：100 × 2 + 10 = 210，不是 220")

	# --- 固定加值任意来源相加 ---
	s = StatValue.new(StatMath.from_float(50.0))
	s.add_flat(StatMath.from_float(5.0))
	s.add_flat(StatMath.from_float(3.0))
	t.eq(s.total_int(), 58, "多个固定来源相加")

	# --- 完整公式 ---
	s = StatValue.new(StatMath.from_float(20.0))
	s.add_percent(B.EMPOWER, 25)
	s.add_percent(B.EMPOWER, 25)   # 同区共 +50%
	s.add_percent(B.SHARP, 20)
	s.add_flat(StatMath.from_float(4.0))
	# 20 × 1.5 × 1.2 + 4 = 36 + 4 = 40
	t.eq(s.total_int(), 40, "20 × (1+50%) × (1+20%) + 4 = 40")

	# --- 加成来源的先后顺序不影响结果 ---
	var a := StatValue.new(StatMath.from_float(77.0))
	a.add_percent(B.FIRE, 13)
	a.add_percent(B.SHARP, 41)
	a.add_flat(StatMath.from_float(6.0))
	var b := StatValue.new(StatMath.from_float(77.0))
	b.add_flat(StatMath.from_float(6.0))
	b.add_percent(B.SHARP, 41)
	b.add_percent(B.FIRE, 13)
	t.eq(a.total(), b.total(), "加成的调用顺序不得影响终值")

	# --- 未使用的乘区因子为 1，不影响结果 ---
	var only_base := StatValue.new(StatMath.from_float(123.0))
	t.eq(only_base.total(), StatMath.from_float(123.0),
		"所有乘区为 0 时，逐个乘 1.0 后应逐位等于基础值")

	# --- 减益 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(B.SHARP, -25)
	t.eq(s.total_int(), 75, "单区 -25% 得 75")

	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(B.SHARP, -60)
	s.add_percent(B.FIRE, -50)
	t.eq(s.total_int(), 20, "跨区减益相乘：100 × 0.4 × 0.5 = 20")

	# --- 减益超过 -100% 时钳到 0，绝不翻正 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(B.SHARP, -150)
	t.eq(s.total_int(), 0, "单区减益超过 -100% 应钳为 0")

	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(B.SHARP, -150)
	s.add_percent(B.FIRE, -150)
	t.eq(s.total_int(), 0, "两个超限减区不得相乘成正数")

	# 钳零后固定加值仍然生效 —— flat 不参与乘法
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(B.SHARP, -200)
	s.add_flat(StatMath.from_float(7.0))
	t.eq(s.total_int(), 7, "乘法部分归零后，固定加值照常相加")

	# --- 中途不取整 ---
	s = StatValue.new(StatMath.from_float(100.0))
	s.add_percent(B.SHARP, 5)
	s.add_percent(B.SHARP, 5)
	var combined := StatValue.new(StatMath.from_float(100.0))
	combined.add_percent(B.SHARP, 10)
	t.eq(s.total(), combined.total(), "两个 +5% 必须等于一个 +10%")

	# --- 越界保护 ---
	var guard := StatValue.new(StatMath.from_float(10.0))
	t.eq(guard.mult_of(-1), 0, "越界乘区读取返回 0")
	t.eq(guard.mult_of(9999), 0, "越界乘区读取返回 0")

	# --- 克隆互不影响 ---
	var src := StatValue.new(StatMath.from_float(10.0))
	src.add_percent(B.SHARP, 50)
	var copy := src.clone()
	copy.add_percent(B.SHARP, 50)
	t.eq(src.total_int(), 15, "克隆后改副本不应影响原件")
	t.eq(copy.total_int(), 20, "副本自身的加成生效")
