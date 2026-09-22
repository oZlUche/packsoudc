## 同心环地图的配置（架构文档 5.4）。
##
## 标了「M3-3c 才用到」的字段属于**类型分配**（谁是战斗、谁是商店），
## 与拓扑无关；[RingMapGenerator] 这一步一个都不读。
class_name RingMapConfig
extends Resource

## 由外向内，下标 0 = 最外环。环数 = rings.size()
@export var rings: Array[RingSpec] = []

@export_group("规模")
## 新建的环（换规模 / 换环数时）从这份模板抄 quota 与 type_weights。
## 没有它，换一次规模之后每环的权重表是空的，非路线节点就只剩战斗
@export var ring_template: RingSpec = null
## 每环 节点/槽位 的上限，严格小于 1 —— 内环也不填满，环上总有空位
@export var fill_cap: float = 0.9
## 规模模板：每种规模的图最多能要几个出发点、几片高危区、多大的高危区。
## 按环数匹配；一个都不匹配（比如三环的测试图）= 不设上限、不要高危区
@export var scales: Array[MapScaleProfile] = []

@export_group("路线")
## 每条出生点→尽头的路线各有一种风格；出生点数 = entry_count，风格按本列表轮流分配
@export var routes: Array[RouteStyle] = []
@export var entry_count: int = 3
## 出生点之间在最外环上至少隔几个槽位（环形距离）。
## 放不下（出生点数 × 间隔 > 槽位数）是配置错误，生成器会直说
@export var entry_min_gap: int = 2
## 向内走时，下一环的候选槽位在当前次序比例的 ± 多少个槽位之内。
## 单位是【最外环的槽位】，到内环按环长等比缩小（至少 1）—— 和 entry_min_gap 同一把尺
@export var route_drift: int = 1
## 走过几环之后才允许路线合流。太早合流，风格就没意义了
@export var converge_after_ring: int = 2
## 换乘几次由规模模板定（MapScaleProfile.pivots），均分在路线上。
## 这里只管窗口：离安排的那一环几环之内，两条路线的点恰好相邻就直接连起来当换乘，
## 不必严格踩在那一环上；窗口里始终没碰上，才在那一环上拉一整段换乘弧兜底
@export var pivot_window: int = 1

@export_group("类型分配")
## 类型 → 风险分：走这一步期望损失多少体力。搜索点填的是【每搜一次】的值，
## 定档时乘 reference_searches —— 搜几次是玩家的旋钮，生成器只按基准定档（5.4.2）
@export var type_risk: Dictionary = {}
## 类型 → 收益分：走这一步期望拿到多少价值。搜索点同上
@export var type_reward: Dictionary = {}
## 给路线定档时假设玩家在每个搜索点搜几次。实际搜几次由玩家决定（5.4.2）
@export var reference_searches: int = 1
## 必须型：不靠权重碰运气、撤离点不许覆盖、被高危区吸收的路线节点不许当的那几种
@export var mandatory_types: Array[StringName] = [&"elite", &"shop", &"rest"]
@export var danger_risk_multiplier: Array[float] = [1.0, 1.3, 1.7]
@export var danger_reward_multiplier: Array[float] = [1.0, 1.4, 2.0]
@export var ev_tolerance: float = 0.2
## 类型 → 每个节点到最近该类型节点的步数上限。例：{"rest": 4, "shop": 6}
@export var coverage: Dictionary = {}
## danger 高于此值的区域里不放喘气的地方（= coverage 里列的那几种类型）
@export var no_haven_in_danger_above: int = 1
## 休息区与商店只在路径的这一段之后才出现（0～1，按环深算：最外环 0，核心前一环 1）
@export var haven_after_progress: float = 1.0 / 3.0
## 不许相邻的类型对
@export var no_adjacent: Array = []
@export var extract_every_rings: int = 2
## 撤离点两两之间的最短路至少几步。-1 = 用规模模板的值（MapScaleProfile.extract_gap）
@export var extract_min_distance: int = -1

@export_group("高危区")
## 高危区怎么【长出来】。null = 这张图不要高危区
@export var zone_spec: DangerZoneSpec = null
## 要几片。-1 = 在规模允许的范围里随机；给了数也会被夹进那个范围
@export var zone_count: int = -1
## 每片长到几个点就停。-1 = 用规模允许的最大值；给了数也会被夹进那个范围
@export var zone_soft_cap: int = -1
## 一片高危区长成什么样才算数（规模、出入口上限）。写进图的 layout_meta，校验从图上读
@export var zone_rules: ZoneRules = ZoneRules.new()

@export_group("边与槽位")
## 单条路径的长度上限：一条边两端最多差几环。生成器只连相邻环，所以 1 就是它会用到的最大值
@export var edge_max_ring_offset: int = 1
## 单条路径的长度上限：一条边两端最多差几个槽位。同环 = 相邻槽位；
## 跨环 = 把里面那个点按比例投到外面那环上（外环的槽位更细，拿它当尺子），正对着的那个 ± 这么多。
## 正对着空白区的点因此可以【没有】向内的边，它靠同环的弧连到别处
@export var edge_max_slot_offset: int = 1
## 同环挨着的两个点之间最多隔几个空槽还连弧（5.4.1 的 1----1）；
## 隔得更远就是空白区，环在那里断开。节点数少于槽位数时（规模模板要的），空槽散在点与点之间
@export var tangential_span_max: int = 3
## 同环相邻边被断开的概率。骨架边与换乘弧不受影响
@export var tangential_break_chance: float = 0.35
## 每个节点向内连接的邻近节点数范围
@export var radial_links: Vector2i = Vector2i(1, 2)
## 环越靠里越短：每个槽位对应的弧长。slots 为 0 的环用它按半径算槽位数。
##
## 它与 [member radius_step] [b]只有比值有意义[/b] —— 两个都不是渲染尺寸，
## 合在一起只回答一件事：第 r 环有几个槽位。
@export var arc_per_slot: float = 60.0
## 最内环至少几个槽位，免得算出来只有两三个
@export var min_slots: int = 6
## 只用来算每环槽位数，**不是渲染距离**。
## 渲染时环画多大、点之间隔多远，是布局策略的事（5.9）。
## 默认值配 arc_per_slot 得到「最内环 6 个槽位、第五环 16 个」这样的密度。
@export var radius_step: float = 30.0


func ring_count() -> int:
	return rings.size()


## 第 r 环（1 = 最内环）的配置。越界返回 null。
func spec_for_ring(r: int) -> RingSpec:
	var i := ring_count() - r
	return rings[i] if i >= 0 and i < rings.size() else null


## 第 r 环有几个角度槽位。
##
## spec.slots > 0 就用它；否则按半径算 —— 同心环越靠里周长越短，
## 槽位数随之减少，这样每个槽位的弧长大致相等，内环不会挤成一团、
## 外环也不会稀疏得连不上。
func slots_for_ring(r: int) -> int:
	var spec := spec_for_ring(r)
	if spec != null and spec.slots > 0:
		return spec.slots
	var by_radius := roundi(TAU * float(r) * radius_step / maxf(1.0, arc_per_slot))
	return maxi(maxi(1, min_slots), by_radius)


## 这张图属于哪种规模。没有匹配的返回 null。
func scale() -> MapScaleProfile:
	for p in scales:
		if p != null and p.covers(ring_count()):
			return p
	return null


func style_by_id(id: StringName) -> RouteStyle:
	for s in routes:
		if s != null and s.id == id:
			return s
	return null


func scale_by_id(id: StringName) -> MapScaleProfile:
	for p in scales:
		if p != null and p.id == id:
			return p
	return null


## 实际用几个出发点：配置值夹进规模允许的范围。
func effective_entry_count() -> int:
	var p := scale()
	return clampi(entry_count, p.entries.x, p.entries.y) if p != null else entry_count


## 高危区数量的范围 [必须有的, 至多]。没有规模或没配 zone_spec 就是 0。
func zone_count_range() -> Vector2i:
	var p := scale()
	if p == null or zone_spec == null:
		return Vector2i.ZERO
	if zone_count < 0:
		return p.zones
	var fixed := clampi(zone_count, p.zones.x, p.zones.y)
	return Vector2i(mini(p.zones.x, fixed), fixed)


func effective_extract_gap() -> int:
	if extract_min_distance >= 0:
		return extract_min_distance
	var p := scale()
	return p.extract_gap if p != null else 0


func effective_zone_soft_cap() -> int:
	var p := scale()
	if p == null:
		return 0
	return p.zone_size.y if zone_soft_cap < 0 else clampi(zone_soft_cap, p.zone_size.x, p.zone_size.y)


## 换一种规模 / 环数：重建 rings，并把几个可选项夹进新规模的范围。编辑器用。
func apply_scale(id: StringName, ring_count_: int) -> void:
	var p := scale_by_id(id)
	if p == null:
		return
	_build_rings(clampi(ring_count_, p.rings.x, p.rings.y))
	entry_count = clampi(entry_count, p.entries.x, p.entries.y)
	if zone_count >= 0:
		zone_count = clampi(zone_count, p.zones.x, p.zones.y)
	if zone_soft_cap >= 0:
		zone_soft_cap = clampi(zone_soft_cap, p.zone_size.x, p.zone_size.y)


func _build_rings(ring_count_: int) -> void:
	var kinds := [&"outskirts", &"ruins", &"depths", &"core_ring", &"inner"]
	rings = [] as Array[RingSpec]
	for i in ring_count_:
		var spec := RingSpec.new()
		spec.kind = kinds[mini(i, kinds.size() - 1)]
		if ring_template != null:
			spec.quota = ring_template.quota.duplicate(true)
			spec.type_weights = ring_template.type_weights.duplicate(true)
		rings.append(spec)
	# 槽位照半径算，不动 —— 环的长度是几何，不随节点数变。规模模板要的是【节点数】：
	# 每环只填一部分槽位，空的连成空白弧。内环只有 min_slots 个槽位，填满也就那么几个，
	# 减的份额落在外环；二分一个填充系数，让各环 max(min_slots, 槽位 × 系数) 的总和正好是要的
	var p := scale()
	if p != null and p.nodes.y > 0:
		# 节点数仍随环数增长：在这一档规模的范围里按环数插值 —— 6 环取下限、8 环取上限
		var t := 0.0 if p.rings.y <= p.rings.x \
			else clampf(float(ring_count_ - p.rings.x) / float(p.rings.y - p.rings.x), 0.0, 1.0)
		var want := roundi(lerpf(float(p.nodes.x), float(p.nodes.y), t)) - 1     # 减掉核心
		var lo := 0.0
		var hi := 1.0
		for _k in 24:
			var mid := (lo + hi) / 2.0
			var sum := 0
			for i in ring_count_:
				sum += fill_count(slots_for_ring(ring_count_ - i), mid)
			if sum < want:
				lo = mid
			else:
				hi = mid
		for i in ring_count_:
			rings[i].node_count = fill_count(slots_for_ring(ring_count_ - i), hi)
	else:
		# 没有规模模板：每环留一点空位就好（fill_cap 说了内环也不填满）
		for i in ring_count_:
			rings[i].node_count = fill_count(slots_for_ring(ring_count_ - i), 1.0)
	# 把算出来的数写明白。0 的意思是「自动」（槽位按半径算、节点填满），
	# 但编辑器里看到一排 0、图上却是十几个点，只会让人以为数据没对上
	for i in ring_count_:
		var r := ring_count_ - i
		rings[i].slots = slots_for_ring(r)
		if rings[i].node_count <= 0:
			rings[i].node_count = rings[i].slots


## 一个 slots 个槽位的环按 factor 填几个：不少于 min_slots - 1 个（内环的下限），
## 不多于 fill_cap 允许的 —— 严格小于槽位数，环上总有空位。
func fill_count(slots: int, factor: float) -> int:
	var cap := mini(slots - 1, floori(float(slots) * fill_cap))
	return clampi(roundi(float(slots) * factor), mini(cap, min_slots - 1), maxi(1, cap))


## 造一份跑得起来的默认配置。**数值是占位**，等内容定稿；
## 结构才是要紧的。测试与沙盒用它开箱即跑。
static func sample(ring_count_: int = 5) -> RingMapConfig:
	var cfg := RingMapConfig.new()
	cfg.scales = MapScaleProfile.defaults()
	# 类型分配（M3-3c）。数值全是占位，等内容定稿；测试从这里读期望值，不写死
	cfg.ring_template = RingSpec.new()
	cfg.ring_template.type_weights = {"battle": 3, "search": 3, "event": 3, "random": 2, "elite": 1}
	cfg.ring_template.quota = {"shop": [0, 1], "rest": [0, 2], "elite": [0, 2]}
	cfg._build_rings(ring_count_)

	var combat := RouteStyle.new()
	combat.id = &"combat"
	combat.ends_at = &"core"
	combat.mix = {"battle": 5, "elite": 1, "event": 1}
	combat.risk_band = Vector2(1.2, 1.9)
	combat.reward_band = Vector2(1.2, 1.9)
	combat.bailout_every_rings = 4     # 得 ≥ 撤离点间距，不然沿路的出口自己就挤在一起
	var search := RouteStyle.new()
	search.id = &"search"
	search.ends_at = &"extract"
	search.mix = {"search": 4, "event": 1}
	search.min_share = {"search": 0.8}     # 偏搜索的路线，搜索点至少占八成
	# 八成是搜索点的路线，风险只有平均的两三成 —— 档位得跟着 min_share 走
	search.risk_band = Vector2(0.15, 0.6)
	search.reward_band = Vector2(0.15, 0.6)
	var mixed := RouteStyle.new()
	mixed.id = &"mixed"
	mixed.ends_at = &"core"
	mixed.mix = {"battle": 2, "search": 2, "event": 2}
	mixed.risk_band = Vector2(0.8, 1.3)
	mixed.reward_band = Vector2(0.8, 1.3)
	cfg.routes = [combat, search, mixed] as Array[RouteStyle]

	cfg.type_risk = {"battle": 1.0, "elite": 2.2, "event": 0.3, "random": 0.8, "search": 0.4,
		"shop": 0.0, "rest": 0.0, "extract": 0.0, "core": 3.0, "spawn": 0.0}
	# 搜索点每搜一次的收益不能比战斗划算太多：偏搜索的路线八成都是它，
	# 它的性价比就是那条路线的性价比 —— 太高，校准只能把别的路线也换成搜索点去追
	cfg.type_reward = {"battle": 1.0, "elite": 3.0, "event": 0.6, "random": 0.8, "search": 0.6,
		"shop": 0.5, "rest": 0.3, "extract": 0.0, "core": 5.0, "spawn": 0.0}
	cfg.coverage = {"rest": 4, "shop": 6}
	cfg.no_adjacent = [["elite", "elite"], ["shop", "shop"]]
	cfg.ev_tolerance = 0.25
	# 撤离点每 4 环一个：窗口跨度不小于「撤离点之间至少几步」，相邻两个窗口才放得下
	# 两个隔得够远的出口。每 2 环一个的话，内圈只有六个点，只能靠重试碰
	cfg.extract_every_rings = 4

	# 要不要高危区、要几片、多大，由规模模板决定（环太少时没有匹配的规模，也就没有高危区）
	cfg.zone_spec = DangerZoneSpec.new()
	return cfg
