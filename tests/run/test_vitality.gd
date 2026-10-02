## 体力（架构文档 7.1）。
##
## 这一组守的核心是：**本类不知道任何游戏数值**。扣多少、回多少全由调用方给，
## 所以下面一个「普通战斗 −1」都不会出现 —— 那是内容，改它不该让测试变红。
## 要守的是边界行为：截断、实际变化量、归零信号。
extends RefCounted


## 收信号用的小信箱。lambda 按值捕获局部变量，写不出去，所以用字典。
static func _watch(v: Vitality) -> Dictionary:
	var log := {"changed": [], "depleted": []}
	v.changed.connect(
		func(cur: int, mx: int, delta: int, reason: StringName) -> void:
			(log["changed"] as Array).append([cur, mx, delta, String(reason)])
	)
	v.depleted.connect(
		func(reason: StringName) -> void: (log["depleted"] as Array).append(String(reason))
	)
	return log


static func run(t: TestCase) -> void:
	t.begin("体力 · 扣与回")

	var v := Vitality.new(5)
	t.eq(v.current, 5, "不给当前值就是满的")
	t.eq(v.maximum, 5, "上限就是传进来的那个")
	t.check(v.is_full() and not v.is_depleted(), "满着，没空")

	var log := _watch(v)

	# --- 扣多少由调用方说了算，本类不认识任何一场战斗 ---
	t.eq(v.spend(1, &"battle_lost"), 1, "扣 1 就是 1")
	t.eq(v.current, 4, "剩 4")
	t.eq(v.spend(2, &"elite_lost"), 2, "扣 2 就是 2")
	t.eq(v.current, 2, "剩 2")
	t.eq((log["changed"] as Array).size(), 2, "两次变动两条信号")
	t.eq((log["changed"] as Array)[1], [2, 5, -2, "elite_lost"],
		"信号带着当前值、上限、实际变化量与原因")

	# --- 回多少同样由调用方说了算 ---
	t.eq(v.restore(1, &"rest"), 1, "回 1 就是 1")
	t.eq(v.current, 3, "剩 3")

	# --- 负数参数不该反向生效 ---
	t.eq(v.spend(-2, &"oops"), 2, "spend 传负数仍按扣算")
	t.eq(v.current, 1, "扣掉了")
	t.eq(v.restore(-1, &"oops"), 1, "restore 传负数仍按回算")
	t.eq(v.current, 2, "回来了")


static func run_clamping(t: TestCase) -> void:
	t.begin("体力 · 截断与实际变化量")

	var v := Vitality.new(3)
	var log := _watch(v)

	# --- 回不过上限 ---
	t.eq(v.restore(10, &"rest"), 0, "已经满了，实际回复 0")
	t.eq((log["changed"] as Array).size(), 0, "**没变就不发信号** —— 界面不该为一次无事发生闪一下")

	v.spend(1, &"x")
	t.eq(v.restore(10, &"rest"), 1, "只差 1 格，实际只回 1 —— 请求量与实际量是两回事")
	t.check(v.is_full(), "回满了")

	# --- 扣不破 0 ---
	t.eq(v.spend(99, &"boss"), 3, "只剩 3，实际只扣 3")
	t.eq(v.current, 0, "到 0 为止，不会变成负数")
	t.eq((log["depleted"] as Array), ["boss"], "归零发一次 depleted，带着原因")

	t.eq(v.spend(1, &"again"), 0, "已经 0 了，再扣不动")
	t.eq((log["depleted"] as Array).size(), 1, "也不会再发一次 depleted")

	# --- 上限为 0 的退化情形 ---
	var zero := Vitality.new(0)
	t.eq(zero.spend(1, &"x"), 0, "上限 0 时扣不动")
	t.eq(zero.restore(1, &"x"), 0, "也回不了")
	t.eq(zero.ratio(), 0.0, "ratio 不除零")


static func run_set_max(t: TestCase) -> void:
	t.begin("体力 · 调整上限")

	var v := Vitality.new(5)
	v.spend(3, &"x")
	t.eq(v.current, 2, "剩 2")

	# --- 涨上限，当前值同量涨 ---
	v.set_max(7)
	t.eq(v.maximum, 7, "上限涨到 7")
	t.eq(v.current, 4, "**当前值同量增加** —— 多出来的体力立刻能用，与 ResourcePool 一致")

	# --- 降上限，当前值截断 ---
	v.set_max(3)
	t.eq(v.maximum, 3, "上限降到 3")
	t.eq(v.current, 3, "当前值按新上限截断")

	# --- 降到 0 也算归零 ---
	var log := _watch(v)
	v.set_max(0, &"cursed")
	t.check(v.is_depleted(), "上限归零，人也就没了")
	t.eq((log["depleted"] as Array), ["cursed"], "同样发 depleted，原因是调用方给的")

	# --- 没变就不动 ---
	var still := Vitality.new(4)
	var log2 := _watch(still)
	still.set_max(4)
	t.eq((log2["changed"] as Array).size(), 0, "上限没变，不发信号")


static func run_round_trip(t: TestCase) -> void:
	t.begin("体力 · 存取")

	var v := Vitality.new(6)
	v.spend(2, &"x")
	var d := v.to_dict()
	var back := Vitality.from_dict(d)
	t.eq(back.current, 4, "当前值存得住")
	t.eq(back.maximum, 6, "上限存得住")
	t.eq(back.to_dict(), d, "来回一趟不丢字")

	# 过一遍 JSON：整数会变浮点
	var from_json := Vitality.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.eq(from_json.to_dict(), d, "过一遍 JSON 也一样")


static func run_placeholder(t: TestCase) -> void:
	t.begin("体力 · 角色系统的占位")

	# 上限有个默认值，但那是占位 —— 断言它存在且合理，不断言它等于几。
	# 角色系统落地后这个数由角色给，改它不该让测试变红。
	var v := Vitality.new()
	t.check(v.maximum > 0, "不给上限时有一份占位默认值，游戏跑得起来")
	t.eq(v.maximum, Vitality.PLACEHOLDER_MAX, "用的就是那个占位常量，没有第二处写死")
	t.check(v.is_full(), "开局满的")

	# 调用方给什么就是什么 —— 角色系统将来就从这里接进去
	for mx in [1, 3, 12]:
		t.eq(Vitality.new(mx).maximum, mx, "上限由调用方给（角色系统的接入点）")
