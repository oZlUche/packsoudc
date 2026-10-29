## 节点里发生什么的规则（架构文档 5.4 / 6.2 / 7.1，M4-3 / M4-4）：随机点变成什么、搜索点怎么搜、
## 战斗输了扣多少体力、休息回多少、常规事件的结果。章节按 id 引用（`ChapterDef.node_rules`）。
##
## 7.1 说得明白：体力自己不知道任何数值，「输一场扣多少」「歇一会儿回多少」由调用方从配置里拿 —— 就是从这里拿。
## 作者数据，走内容管线：`data/authoring/node_rules/*.json` → `data/node_rules/*.tres`。
class_name NodeRules
extends Resource

## 随机点（?）进入时可以变成的类型：**不会**变成精英或 BOSS（5.4）。导入器只认这几个键
const RANDOM_ALLOWED: Array[StringName] = [&"battle", &"search", &"shop", &"rest", &"event", &"chest"]     # 154：随机点能揭出宝箱
## 常规事件的三种结果（占位）：给一件道具 / 回一点体力 / 一段剧情
const EVENT_OUTCOMES: Array[StringName] = [&"item", &"restore", &"story"]

@export var id: StringName = &""
@export var display_name: String = ""

## 随机点：类型 → 权重
@export var random_weights: Dictionary = {"battle": 3, "search": 3, "event": 2, "shop": 1, "rest": 1}

@export var search: SearchRules = null

## 154：宝箱点的规则（稀有度、开锁时长、收获）。空 = 用 [ChestRules] 的默认
@export var chest: ChestRules = null

## 战斗输了扣多少体力：类型 → 数。core 不在这里 —— BOSS 输了直接战败（7.1），那是规则不是数值。
## 搜索点里遭遇的不在这里：固定无代价（091 / 135），进战斗时直接传 0
@export var loss_cost: Dictionary = {"battle": 1, "elite": 2, "hunter": 1}

## 休息区回多少体力。不写死 —— 不同章节可以不一样
@export var rest_restore: int = 1     # 作者 10-27：火堆回 1 点、耗 1 次倒计时；帐篷再耗 1 次、多回 1 点

## 常规事件（Q）的结果权重，占位：item / restore / story
@export var event_weights: Dictionary = {"item": 1, "restore": 1, "story": 1}

## 事件结果是 restore 时回多少体力
@export var event_restore: int = 1

## 事件结果是 item 时给一件什么稀有度以下的道具（-1 不限）；找法与搜索点一样
@export var event_item_rarity_cap: int = 1

## 一场战斗的安全上限（秒，103）：加时与衰竭保证有限时间内必有人倒下，这条只防配置坏了时死循环；到了判平局（按输算）
@export var battle_time_limit: float = 600.0

## 103：加时与衰竭的数值（没填用 [OvertimeRules] 的默认：30 秒起受伤 +20%、每 5 秒再叠；60 秒起每秒掉 5 点生命上限）
@export var overtime: OvertimeRules

## 087（作者定）：击败核心点的 BOSS 之后，收完战利品就直接撤离结算（不用走到撤离点、不付费）
@export var boss_extracts: bool = true

## 248：被缠上了再跑（搜索遭遇、伏击；猎手用它自己定义里的成功率与体力）：`chance` 基础成功率（加 buff 的 flee_bonus，夹在 0～1）、
## `fail_vitality` 失败扣几点体力、`fail_buff` 失败背的地图 buff（空 = 不背）。看见了再躲（战前屏「退回」）不收这份代价
@export var flee: Dictionary = {"chance": 0.5, "fail_vitality": 1, "fail_buff": "weakened"}


## 随机点变成什么。权重全 0 或表空返回 battle —— 一个随机点总得是点什么
## 259：[param exclude] 里的类型按权重 0 算（随机点旁边已有休息，就不揭出休息）
func random_pick(rng: RandomNumberGenerator, exclude: Array = []) -> StringName:
	if exclude.is_empty():
		return _weighted(random_weights, rng, &"battle")
	var table := random_weights.duplicate()
	for t in exclude:
		table.erase(String(t))
		table.erase(StringName(t))
	return _weighted(table, rng, &"battle")


## 常规事件的结果
func event_pick(rng: RandomNumberGenerator) -> StringName:
	return _weighted(event_weights, rng, &"story")


## 248：逃跑的基础成功率（还没加 buff）
func flee_chance() -> float:
	return float(flee.get("chance", 0.5))


func flee_fail_vitality() -> int:
	return int(flee.get("fail_vitality", 1))


func flee_fail_buff() -> StringName:
	return StringName(String(flee.get("fail_buff", "")))


func loss_cost_of(type: StringName) -> int:
	return int(loss_cost.get(String(type), 0))


static func _weighted(table: Dictionary, rng: RandomNumberGenerator, fallback: StringName) -> StringName:
	var keys: Array = table.keys()
	keys.sort()   # 顺序稳定，同种子同结果
	var total := 0.0
	for k in keys:
		total += maxf(0.0, float(table[k]))
	if total <= 0.0:
		return fallback
	var x := rng.randf() * total
	for k in keys:
		x -= maxf(0.0, float(table[k]))
		if x <= 0.0:
			return StringName(String(k))
	return StringName(String(keys[keys.size() - 1]))


## 事件层（063）：节点类型 → {事件 id: 权重}。生成地图时按它给每个点定一个事件（[EventPlacer]），踩上去先过事件屏。
## 没列的类型（多数是战斗）没有事件 = 转场，踩上去直接发生。搜索点的「要不要搜」就是它的事件（选项里 OpenSearch）
@export var events_by_type: Dictionary = {}
## 093（作者定）：**成组限量**的事件 —— 生成时先于 events_by_type 铺：`{"组名": {"max_per_map": 1, "early": true, "chance": 1.0, "events": {"事件 id": 权重}}}`。
## 每张图最多放 max_per_map 个（在事件点里挑）；early = 偏前期（越浅的点权重越高）；chance = 这张图有没有它的概率。「触发信仰」用它：每张图最多一位神
@export var event_groups: Dictionary = {}
## 267 C：材料节点的种类 → `{"tags": [...], "other_share": 0.25}`：只出带任一标签的材料（[method SearchSession.in_kind]），每件有 other_share 的机会从普通池抽。
## 生成时 [RingTypeAssigner] 按环的 `material_nodes` 给搜索点写 `content.search_kind`；本章没配（序章）= 没有材料节点
@export var search_kinds: Dictionary = {}


## 这种类型的点该配哪个事件；没配返回空
## 093：成组事件按权重抽一个
func group_pick(group: String, rng: RandomNumberGenerator) -> StringName:
	var g = event_groups.get(group, null)
	if not (g is Dictionary):
		return &""
	var table = (g as Dictionary).get("events", {})
	return _weighted(table, rng, &"") if table is Dictionary and not (table as Dictionary).is_empty() else &""


func event_pick_for(type: StringName, rng: RandomNumberGenerator) -> StringName:
	var table = events_by_type.get(String(type), null)
	if not (table is Dictionary) or (table as Dictionary).is_empty():
		return &""
	return _weighted(table, rng, &"")
