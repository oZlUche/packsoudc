## 一局里「别人要调一局的某个能力」的那张表（101 第 3 刀，架构文档 7.5）。
##
## [NodeEvents] 与 [EventContext] 原来各挂十几个裸 `Callable` 字段：谁接、接的签名是什么、没接会怎样，
## 全靠注释说，接错一个参数的表现是运行时静默报错。这里把它们收成**带类型的方法**：
## 调用方写 `hooks.safe_open()`，拿到的一定是 `bool`；没人接就是这里写的那个默认值。
##
## 谁来接：一局的骨架（[RunState]）在 `_wire_events` 里接它自己的那几条（编译玩家、掉落上下文、撤离、传送……），
## 模块与机制在自己的 `install` 里接自己的那几条（[SafeModule] 的 `safe_open`、[BuffModule] 的三条地图 buff、
## [AltarModule] 的 `bless_substitute`、[HunterSystem] 的迎战 / 逃跑）。**[NodeEvents] 不认识任何模块**，只认这张表。
##
## 加一条 hook：[constant NAMES] 加一行 + 这里加一个带类型的方法 —— 名字写错 `register` 当场报错，不会默默不生效。
class_name RunHooks
extends RefCounted

## 认得的 hook 名字 → 这一条由谁接（只为出错时说清楚）
const NAMES := {
	&"player_spec": "RunState：开战那一刻编译玩家的战斗单位",
	&"loot_context": "RunState：掉落上下文（难度、幸运、信仰）",
	&"run_context": "RunState：一局的规则被 buff 改成什么样",
	&"has_buff_tag": "RunState：身上 / 局内有带这个标签的 buff 吗",
	&"grant_map_buff": "BuffModule：给一个地图 buff",
	&"remove_map_buff": "BuffModule：去掉一个地图 buff",
	&"has_map_buff": "BuffModule：有这个地图 buff 吗",
	&"bracket": "HunterSystem / RunState：现在第几段位",
	&"request_extract": "RunState：从这个撤离点撤离（付不起返回 false）",
	&"relocate": "RunState：把人挪到别处（清地上、给猎手一个回合）",
	&"safe_open": "SafeModule：保险箱还能开吗",
	&"belt_use": "BeltModule：用腰带里的一个随身技能（147 / 160：空串 = 用了，否则是原因）",
	&"belt_grant": "BeltModule：往腰带里放几个随身技能（160 补一：事件发的；返回放进了几个）",
	&"faith_tier": "RunState：激活信仰现在第几阶（-1 = 没激活）",
	&"active_faith_id": "RunState：激活信仰的 id（空 = 没激活）",
	&"bless_substitute": "AltarModule：战利品 / 搜索里把道具换成赐福过的",
	&"before_battle": "RunState：开打前改双方的战斗单位（局内技能）",
	&"fight_hunter": "HunterSystem：迎战追上来的猎手",
	&"flee_hunter": "HunterSystem：从猎手那里逃跑",
	&"skill_ready": "RunState：局内技能现在能不能用（136：空串 = 能，否则是原因）",
}

var _fns: Dictionary = {}


## 接一条。名字不在 [constant NAMES] 里就报错 —— 这正是裸 Callable 字段抓不到的那种错
func register(name: StringName, fn: Callable) -> void:
	if not NAMES.has(name):
		push_error("RunHooks：没有名叫 %s 的 hook（认得的见 RunHooks.NAMES）" % name)
		return
	if not fn.is_valid():
		_fns.erase(name)
		return
	_fns[name] = fn


## 这一条有人接吗（用来决定走默认那条路，比如没人接 `relocate` 就直接交给旅程）
func has(name: StringName) -> bool:
	return _fns.has(name) and (_fns[name] as Callable).is_valid()


func _at(name: StringName) -> Callable:
	return _fns.get(name, Callable()) as Callable


#region 一局的骨架接的
func player_spec() -> CombatantSpec:
	if not has(&"player_spec"):
		return null
	return _at(&"player_spec").call() as CombatantSpec


func loot_context() -> LootContext:
	if not has(&"loot_context"):
		return null
	return _at(&"loot_context").call() as LootContext


## 一局的规则被 buff 改成什么样。没人接 = 一份默认的（沙盒、测试）
func run_context() -> RunContext:
	if not has(&"run_context"):
		return RunContext.new()
	return _at(&"run_context").call() as RunContext


func has_buff_tag(tag: StringName) -> bool:
	return bool(_at(&"has_buff_tag").call(tag)) if has(&"has_buff_tag") else false


func bracket() -> int:
	return int(_at(&"bracket").call()) if has(&"bracket") else -1


func request_extract() -> bool:
	return bool(_at(&"request_extract").call()) if has(&"request_extract") else false


func relocate(intent: MoveIntent) -> bool:
	return bool(_at(&"relocate").call(intent)) if has(&"relocate") else false


func faith_tier() -> int:
	return int(_at(&"faith_tier").call()) if has(&"faith_tier") else -1


func active_faith_id() -> StringName:
	if not has(&"active_faith_id"):
		return &""
	return StringName(String(_at(&"active_faith_id").call()))


## 136：局内技能现在能不能用：空串 = 能。没人接 = 不能
func skill_ready(id: StringName) -> String:
	return String(_at(&"skill_ready").call(id)) if has(&"skill_ready") else UiText.t("log.no_skill")


func before_battle(me: CombatantSpec, enemy: CombatantSpec, type: StringName) -> void:
	if has(&"before_battle"):
		_at(&"before_battle").call(me, enemy, type)
#endregion


#region 模块接的
## 保险箱还能开吗。没装保险箱模块 = 能（老路：踩上去就开）
func safe_open() -> bool:
	return bool(_at(&"safe_open").call()) if has(&"safe_open") else true


## 147：用腰带里的一个（160 补一：按随身技能 id）。空串 = 用了
func belt_use(skill_id: StringName) -> String:
	return String(_at(&"belt_use").call(skill_id)) if has(&"belt_use") else UiText.t("log.no_belt")


## 160 补一：往腰带里放 [param count] 个，返回放进了几个（没腰带 / 满了 = 0）
func belt_grant(skill_id: StringName, count: int) -> int:
	return int(_at(&"belt_grant").call(skill_id, count)) if has(&"belt_grant") else 0


func grant_map_buff(id: StringName) -> bool:
	return bool(_at(&"grant_map_buff").call(id)) if has(&"grant_map_buff") else false


func remove_map_buff(id: StringName) -> bool:
	return bool(_at(&"remove_map_buff").call(id)) if has(&"remove_map_buff") else false


func has_map_buff(id: StringName) -> bool:
	return bool(_at(&"has_map_buff").call(id)) if has(&"has_map_buff") else false


## 095：把要掉的 id 换成赐福过的。没装神坛模块 = 原样
func bless_substitute(ids: Array, chance_idle: float, chance_active: float, rng: RandomNumberGenerator) -> Array:
	if not has(&"bless_substitute"):
		return ids
	return _at(&"bless_substitute").call(ids, chance_idle, chance_active, rng) as Array


## 071：迎战 / 逃跑。没装猎手机制 = 这两件事不会发生
func fight_hunter(node: MapNode, uid: int, ctx: EventContext) -> bool:
	return bool(_at(&"fight_hunter").call(node, uid, ctx)) if has(&"fight_hunter") else false


func flee_hunter(node: MapNode, uid: int, ctx: EventContext) -> bool:
	return bool(_at(&"flee_hunter").call(node, uid, ctx)) if has(&"flee_hunter") else false
#endregion
