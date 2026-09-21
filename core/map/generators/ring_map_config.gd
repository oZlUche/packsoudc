## 同心环地图的配置（架构文档 5.4）。
##
## 标了「M3-3c 才用到」的字段属于**类型分配**（谁是战斗、谁是商店），
## 与拓扑无关；[RingMapGenerator] 这一步一个都不读。
class_name RingMapConfig
extends Resource

## 由外向内，下标 0 = 最外环。环数 = rings.size()
@export var rings: Array[RingSpec] = []

@export_group("规模")
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

@export_group("类型分配（M3-3c）")
@export var type_risk: Dictionary = {}
@export var type_reward: Dictionary = {}
## 给路线定档时假设玩家在每个搜索点搜几次。实际搜几次由玩家决定（5.4.2）
@export var reference_searches: int = 1
@export var danger_risk_multiplier: Array[float] = [1.0, 1.3, 1.7]
@export var danger_reward_multiplier: Array[float] = [1.0, 1.4, 2.0]
@export var ev_tolerance: float = 0.2
## 类型 → 每个节点到最近该类型节点的步数上限。例：{"rest": 4, "shop": 6}
@export var coverage: Dictionary = {}
## danger 高于此值的区域里不放休息区与商店
@export var no_haven_in_danger_above: int = 1
## 不许相邻的类型对
@export var no_adjacent: Array = []
@export var extract_every_rings: int = 2

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
		rings.append(spec)
	# 外圈各留一段空白弧 —— 参照示意图，环本来就可以断成几段。
	# 只挖【真比 min_slots 长】的环：内圈本来就已经缩到下限了，
	# 再挖就会比外圈还空，看着不像同心环
	for i in mini(2, ring_count_):
		var r := ring_count_ - i
		var slots := slots_for_ring(r)
		if slots > min_slots:
			rings[i].node_count = maxi(min_slots, slots - 3)
	# 把算出来的数写明白。0 的意思是「自动」（槽位按半径算、节点填满），
	# 但编辑器里看到一排 0、图上却是十几个点，只会让人以为数据没对上
	for i in ring_count_:
		var r := ring_count_ - i
		rings[i].slots = slots_for_ring(r)
		if rings[i].node_count <= 0:
			rings[i].node_count = rings[i].slots


## 造一份跑得起来的默认配置。**数值是占位**，等内容定稿；
## 结构才是要紧的。测试与沙盒用它开箱即跑。
static func sample(ring_count_: int = 5) -> RingMapConfig:
	var cfg := RingMapConfig.new()
	cfg.scales = MapScaleProfile.defaults()
	cfg._build_rings(ring_count_)

	var combat := RouteStyle.new()
	combat.id = &"combat"
	combat.ends_at = &"core"
	var search := RouteStyle.new()
	search.id = &"search"
	search.ends_at = &"extract"
	var mixed := RouteStyle.new()
	mixed.id = &"mixed"
	mixed.ends_at = &"core"
	cfg.routes = [combat, search, mixed] as Array[RouteStyle]

	# 要不要高危区、要几片、多大，由规模模板决定（环太少时没有匹配的规模，也就没有高危区）
	cfg.zone_spec = DangerZoneSpec.new()
	return cfg
