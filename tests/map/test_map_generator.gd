## 生成器抽象、通用校验与换种子重试（架构文档 5.3，M3-2）。
##
## 这一层不认识任何一种地图形态，所以测试也不能用某种形态来测。
## 下面的假生成器造的图刻意不像同心环 —— 一条链、一个孤岛、一个断开的点，
## 都是[b]用来踩某一条通用规则[/b]的最小例子。
extends RefCounted


#region 假生成器
## 照着脚本演：第 i 次尝试造第 i 张图。用来驱动重试逻辑。
class ScriptedGen:
	extends MapGenerator

	## Array[Callable]：每次尝试调一个，返回 MapGraph 或 null。
	## 用完之后一直用最后一个 —— 「一直失败」的用例不必写 32 份。
	var steps: Array = []
	var calls: int = 0
	var seeds: Array[int] = []

	func build(_cfg: Resource, rng: RandomNumberGenerator) -> MapGraph:
		seeds.append(rng.seed)
		var i := mini(calls, steps.size() - 1)
		calls += 1
		return (steps[i] as Callable).call()


## 一条链：1 — 2 — 3，出生点 1，终点 3。通用校验下的一张好图。
static func _chain() -> MapGraph:
	var g := MapGraph.new()
	for i in [1, 2, 3]:
		var n := MapNode.new()
		n.id = i
		n.type = &"battle"
		g.add_node(n)
	g.connect_nodes(1, 2)
	g.connect_nodes(2, 3)
	g.entry_ids = [1] as Array[int]
	g.goal_ids = [3] as Array[int]
	return g


static func _gen(steps: Array) -> ScriptedGen:
	var gen := ScriptedGen.new()
	gen.steps = steps
	return gen


static func _good() -> Callable:
	return func() -> MapGraph: return _chain()


static func _validate(g: MapGraph) -> MapValidation:
	var v := MapValidation.new()
	_gen([_good()]).validate(g, v)
	return v
#endregion


static func run(t: TestCase) -> void:
	t.begin("地图生成器 · 通用校验")

	t.check(_validate(_chain()).ok(), "一条链是好图：连得上、有出生点、有终点")

	# --- 空图 ---
	var empty := MapGraph.new()
	t.check(_validate(empty).rules().has(&"nodes"), "一个节点都没有")

	# --- 没出生点 / 没终点 ---
	var g := _chain()
	g.entry_ids = [] as Array[int]
	t.check(_validate(g).rules().has(&"entries"), "没有出生点")

	g = _chain()
	g.goal_ids = [] as Array[int]
	t.check(_validate(g).rules().has(&"goals"), "没有终点")

	g = _chain()
	g.entry_ids = [99] as Array[int]
	t.check(_validate(g).rules().has(&"entries"), "出生点指向一个不存在的节点")

	# --- 没类型 ---
	g = _chain()
	g.get_node(2).type = &""
	t.check(_validate(g).rules().has(&"typed"), "节点没有类型")

	# --- 孤立节点：一条边都不挨着 ---
	g = _chain()
	var lonely := MapNode.new()
	lonely.id = 9
	lonely.type = &"battle"
	g.add_node(lonely)
	var v := _validate(g)
	t.check(v.rules().has(&"isolated"), "有个节点一条边都不挨着")
	t.check(v.rules().has(&"reachable"), "它同时也走不到 —— 两条规则各报各的")

	# --- 走不到：连着但连成了两片 ---
	g = _chain()
	for i in [7, 8]:
		var n := MapNode.new()
		n.id = i
		n.type = &"battle"
		g.add_node(n)
	g.connect_nodes(7, 8)
	v = _validate(g)
	t.check(v.rules().has(&"reachable"), "另一片从出生点走不到")
	t.check(not v.rules().has(&"isolated"), "但那两个点彼此挨着，不算孤立")

	# --- 终点走不到，单独报 ---
	g = _chain()
	g.goal_ids = [3] as Array[int]
	g.remove_edge(g.edge_between(2, 3))
	v = _validate(g)
	t.check(v.rules().has(&"goal_reachable"), "终点走不到要单独说 —— 那是最要紧的一条")

	# --- 死胡同是合法的 ---
	# 玩家可以走回头路，所以「只连一条边」不是问题。这条最容易被顺手加成校验
	g = _chain()
	var dead_end := MapNode.new()
	dead_end.id = 4
	dead_end.type = &"search"
	g.add_node(dead_end)
	g.connect_nodes(2, 4)
	t.check(_validate(g).ok(), "**死胡同是好图** —— 可以走回头路，死路不是问题")

	# --- 单向边：顺着走得到就算数 ---
	g = _chain()
	var far := MapNode.new()
	far.id = 5
	far.type = &"battle"
	g.add_node(far)
	var one := MapEdge.new()
	one.from_id = 3
	one.to_id = 5
	one.directed = true
	g.add_edge(one)
	t.check(_validate(g).ok(), "顺着单向边走得到，算连通")

	g = _chain()
	far = MapNode.new()
	far.id = 5
	far.type = &"battle"
	g.add_node(far)
	one = MapEdge.new()
	one.from_id = 5
	one.to_id = 3
	one.directed = true
	g.add_edge(one)
	t.check(_validate(g).rules().has(&"reachable"), "只能从那边过来，就到不了它")


static func run_retry(t: TestCase) -> void:
	t.begin("地图生成器 · 换种子重试")

	var bad := func() -> MapGraph:
		var g := _chain()
		g.entry_ids = [] as Array[int]     # 故意坏掉
		return g

	# --- 一次就成 ---
	var gen := _gen([_good()])
	t.not_null(gen.generate(null, 1), "第一次就通过")
	t.eq(gen.calls, 1, "只造了一次")
	t.eq(gen.attempts_used, 1, "记着用了一次")
	t.check(gen.failure_tally.is_empty(), "没失败过，账上是空的")

	# --- 坏两次，第三次成 ---
	gen = _gen([bad, bad, _good()])
	t.not_null(gen.generate(null, 1), "第三次通过")
	t.eq(gen.attempts_used, 3, "用了三次")
	t.eq(gen.failure_tally.get(&"entries", 0), 2, "账上记着「没有出生点」失败两次")

	# --- 一直坏：用尽上限，返回 null ---
	gen = _gen([bad])
	t.is_null(gen.generate(null, 1, 5), "用尽上限返回 null —— **绝不降级产出坏图**")
	t.eq(gen.calls, 5, "老老实实试满五次")
	t.eq(gen.attempts_used, 5, "记着用了五次")
	t.eq(gen.failure_tally.get(&"entries", 0), 5, "**按规则聚合**：五次都是同一条规则，这正是要看的")

	# --- build 造不出来也算一次失败 ---
	gen = _gen([func() -> MapGraph: return null])
	t.is_null(gen.generate(null, 1, 3), "build 一直返回 null 也会用尽")
	t.eq(gen.failure_tally.get(&"build", 0), 3, "记成 build 失败，和校验失败分得开")

	# --- 上限至少试一次 ---
	gen = _gen([_good()])
	t.not_null(gen.generate(null, 1, 0), "上限传 0 也至少试一次，不会一次都不试就失败")


static func run_determinism(t: TestCase) -> void:
	t.begin("地图生成器 · 同种子同一张图")

	# 每次尝试的种子只由 base_seed 与第几次决定
	var a := _gen([_good()])
	var b := _gen([_good()])
	a.generate(null, 12345)
	b.generate(null, 12345)
	t.eq(a.seeds, b.seeds, "同一个 base_seed，两次跑出来的种子序列相同")

	var c := _gen([_good()])
	c.generate(null, 54321)
	t.ne(c.seeds[0], a.seeds[0], "换个 base_seed，种子也换")

	t.ne(MapGenerator.derive_seed(7, 0), MapGenerator.derive_seed(7, 1),
		"相邻两次尝试的种子不同 —— 否则重试等于原地打转")
	t.eq(MapGenerator.derive_seed(-99, 3), MapGenerator.derive_seed(-99, 3),
		"负种子也稳定")

	# 失败重试：每次的种子都不同，且**每一个都由 derive_seed 单独算得出来** ——
	# 「种子 12345 的第 7 次尝试」因此可以直接复现，不必把前六次重放一遍
	var bad := func() -> MapGraph: return null
	var d := _gen([bad])
	d.generate(null, 12345, 6)
	t.eq(d.seeds.size(), 6, "记下了六次的种子")
	var uniq := {}
	for i in d.seeds.size():
		uniq[d.seeds[i]] = true
		t.eq(d.seeds[i], MapGenerator.derive_seed(12345, i),
			"第 %d 次用的就是 derive_seed(12345, %d)" % [i, i])
	t.eq(uniq.size(), 6, "六次尝试六个不同的种子")


static func run_registry(t: TestCase) -> void:
	t.begin("地图生成器 · 注册表")

	# --- 登记的每一条都得能用 ---
	# 表现在还是空的（ring 在 M3-3 登记，grid_script 在 M3-3b）。
	# 这条断言现在是空转，等表里有了东西它就开始干活 —— 路径打错要在这里红，
	# 而不是等某一章跑不起来
	for id in MapGeneratorRegistry.ids():
		var path: String = MapGeneratorRegistry.GENERATORS[id]
		t.check(ResourceLoader.exists(path), "'%s' 登记的脚本存在：%s" % [id, path])
		var inst := MapGeneratorRegistry.create(id)
		t.not_null(inst, "'%s' 造得出实例" % id)
		t.check(inst is MapGenerator, "'%s' 造出来的是 MapGenerator" % id)

	# --- ids 与表对得上，不写死 ---
	t.eq(MapGeneratorRegistry.ids().size(), MapGeneratorRegistry.GENERATORS.size(),
		"ids() 列的就是表里的全部")
	for id in MapGeneratorRegistry.ids():
		t.check(MapGeneratorRegistry.has(id), "has() 与表一致：%s" % id)

	var sorted := MapGeneratorRegistry.ids().duplicate()
	sorted.sort()
	t.eq(MapGeneratorRegistry.ids(), sorted, "ids() 升序 —— 遍历顺序不该取决于写表的顺序")

	# --- 没登记过的 ---
	t.check(not MapGeneratorRegistry.has(&"nope"), "没登记过的 has() 为假")
	t.is_null(MapGeneratorRegistry.create(&"nope"), "没登记过的造不出来，返回 null")
