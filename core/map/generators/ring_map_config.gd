## 同心环地图的配置（架构文档 5.4）。
##
## 标了「M3-3c 才用到」的字段属于**类型分配**（谁是战斗、谁是商店），
## 与拓扑无关；[RingMapGenerator] 这一步一个都不读。
class_name RingMapConfig
extends Resource

## 由外向内，下标 0 = 最外环。环数 = rings.size()
@export var rings: Array[RingSpec] = []

@export_group("路线")
## 每条出生点→尽头的路线各有一种风格；出生点数 = entry_count，风格按本列表轮流分配
@export var routes: Array[RouteStyle] = []
@export var entry_count: int = 3
## 出生点之间在最外环上至少隔几个槽位（环形距离）。
## 放不下（出生点数 × 间隔 > 槽位数）是配置错误，生成器会直说
@export var entry_min_gap: int = 2
## 向内走时，下一环的候选槽位在当前次序比例的 ± 多少个槽位之内。
## 单位是【最外环的槽位】，到内环按环长等比缩小（至少 1）—— 和 entry_min_gap 同一把尺
@export var route_drift: int = 2
## 走过几环之后才允许路线合流。太早合流，风格就没意义了
@export var converge_after_ring: int = 2
## 相邻路线之间每隔几环要有一个换乘点。0 = 不要 ——
## 没有换乘点，风格就成了开局定终身，那不是取舍是抽签
@export var pivot_every_rings: int = 2

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
@export var danger_zones: Array[DangerZoneSpec] = []

@export_group("边与槽位")
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


## 造一份跑得起来的默认配置。**数值是占位**，等内容定稿；
## 结构才是要紧的。测试与沙盒用它开箱即跑。
static func sample(ring_count_: int = 5) -> RingMapConfig:
	var cfg := RingMapConfig.new()
	var kinds := [&"outskirts", &"ruins", &"depths", &"core_ring", &"inner"]
	for i in ring_count_:
		var spec := RingSpec.new()
		spec.kind = kinds[mini(i, kinds.size() - 1)]
		cfg.rings.append(spec)
	# 外圈各留一段空白弧 —— 参照示意图，环本来就可以断成几段。
	# 只挖【真比 min_slots 长】的环：内圈本来就已经缩到下限了，
	# 再挖就会比外圈还空，看着不像同心环
	for i in mini(2, ring_count_):
		var r := ring_count_ - i
		var slots := cfg.slots_for_ring(r)
		if slots > cfg.min_slots:
			cfg.rings[i].node_count = maxi(cfg.min_slots, slots - 3)

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

	# 高危区要避开骨架与换乘弧，而换乘弧会把它所在的那一整环占掉，
	# 所以它得落在两个换乘环【之间】。环太少时它自己会不生效（DangerZoneSpec.min_rings）
	var zone := DangerZoneSpec.new()
	zone.ring_range = Vector2i(2, maxi(2, ring_count_ - 1))
	zone.size = Vector2i(3, 5)
	cfg.danger_zones = [zone] as Array[DangerZoneSpec]
	return cfg
