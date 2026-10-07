## 一个战斗单位在战场上的完整状态（架构文档 4.5）。
##
## [b]运行时属性 = 编译快照 + 活跃 buff。[/b]
## [member base] 来自 [BattleCompiler]，全程不可变；buff 在其之上叠加。
## 参战属性在进入战斗时只读取一次 —— 战斗中改动背包不影响本场战斗，
## 而且战斗期间背包 UI 本就禁用（4.1），玩家碰不到。
class_name CombatantRuntime
extends RefCounted

var side: int = 0
## 编译产物，全程不可变
var base: StatSet = null
var buffs: Array[BuffInstance] = []
var resources: ResourcePool = null
var rules: Array[RuleRuntime] = []

## uid -> 该物品的编译期属性（不可变）。
## **必须按物品保留粒度** —— 「磨刀石只给旁边那把武器加伤害」是这个品类的核心，
## 全部并成单位级属性表会把它抹平。
var item_base: Dictionary = {}

## uid -> 与它连结的物品 uid 列表（增益／受益格）。[OnItemFired] 的 LINKED 来源查它。
var item_links: Dictionary = {}
## 132：uid → 道具标签（`on_item_fired.source_tags`）
var item_tags: Dictionary = {}

## 标准轴（4.3，103 4e）：axis → [内容层, 系统层]，带符号；结算在 [method _rebuild] 末尾
var axes: Dictionary = {}

var _merged: StatSet = null
var _merged_items: Dictionary = {}
var _dirty: bool = true

## 对 BattleContext 的弱引用。
##
## 必须是弱引用：ctx 持有 sides，若 sides 上的信号回调又强持 ctx，
## 就成了引用环，RefCounted 永远不释放（表现为退出时 "resources still in use"）。
var _ctx_ref: WeakRef = null


static func from_spec(spec: CombatantSpec, p_side: int) -> CombatantRuntime:
	var rt := CombatantRuntime.new()
	rt.side = p_side
	rt.base = spec.baseline.clone() if spec.baseline != null else StatSet.new()
	rt.resources = ResourcePool.new()

	# 把各物品的属性并成一份单位级属性表。
	# 物品级的乘区已在编译期结算完毕，这里只汇总终值，不再二次相乘。
	for item in spec.items:
		var it := item as CompiledItem
		rt.item_base[it.source_uid] = it.stats
		if not it.linked_uids.is_empty():
			rt.item_links[it.source_uid] = it.linked_uids
		if not it.tags.is_empty():
			rt.item_tags[it.source_uid] = it.tags
		for key in it.stats.keys():
			# **乘法单位元类属性不能跨物品累加。** haste 每件都是 1.0，
			# 逐件相加会得出「N 件物品 = N 倍速度」；而且单位级 haste 的含义是
			# 「不属于任何物品的规则（套装、buff）用什么速率」，本就该是 1.0 起。
			if BattleStats.default_base(key) != 0:
				continue
			rt.base.ensure(key).base += it.stats.total_of(key)
	rt.base.ensure(BattleStats.MAX_HP).base = spec.max_hp
	rt.undying_sec = StatMath.from_float(spec.undying_sec)     # 093：蛮神 4 级
	# 105：编译期带来的轴层数种进**系统层**（103 第 6 条：常驻加成不是 buff、不走净化）
	for axis in spec.axes:
		rt.shift_axis(axis, int(spec.axes[axis]), true)

	for item in spec.items:
		var it2 := item as CompiledItem
		for rule in it2.rules:
			rt._register(RuleRuntime.create(rule, it2.source_uid, null, p_side))
	# 套装规则不属于任何物品，来源 uid 为 0
	for rule in spec.set_rules:
		rt._register(RuleRuntime.create(rule, 0, null, p_side))

	rt._rebuild()
	return rt


#region 属性
## 按 4.3 公式把 base 与所有 buff 的 mods 合并后的终值。
func stat(key: StringName, fallback: int = 0) -> int:
	if _dirty:
		_rebuild()
	return _merged.total_of(key, fallback)


func stat_int(key: StringName, fallback: int = 0) -> int:
	return StatMath.to_int(stat(key, fallback))


## buff 增减后必须调用。整表重算而非按键脏标记 ——
## 物品数量在几十这个量级，重算一次远比维护细粒度依赖便宜。
func mark_dirty() -> void:
	_dirty = true


## 某件物品的属性终值 = 它自己的编译期属性 + 单位级 buff。
##
## 与 [method stat] 的区别：伤害、冷却、消耗这类**属于单件物品**的属性走这里；
## 生命上限、护甲这类**属于整个单位**的走 [method stat]。
func item_stat(uid: int, key: StringName, fallback: int = 0) -> int:
	if _dirty:
		_rebuild()
	var merged: StatSet = _merged_items.get(uid, null)
	if merged == null:
		return stat(key, fallback)
	return merged.total_of(key, fallback)


func item_stat_int(uid: int, key: StringName, fallback: int = 0) -> int:
	return StatMath.to_int(item_stat(uid, key, fallback))


func _rebuild() -> void:
	_dirty = false
	_merged = base.clone()
	_merged_items = {}
	for uid in item_base:
		_merged_items[uid] = (item_base[uid] as StatSet).clone()
	for buff in buffs:
		for mod in buff.def.mods:
			(mod as StatModifier).apply_to(_merged, buff.stacks)
			for uid in _merged_items:
				(mod as StatModifier).apply_to(_merged_items[uid], buff.stacks)
	_apply_axes()
	_sync_resource_maxes()


#region 标准轴
## 内容层 / 系统层 / 合计层数
func axis_stacks(axis: StringName) -> int:
	return int((axes.get(axis, [0, 0]) as Array)[0])


func axis_system(axis: StringName) -> int:
	return int((axes.get(axis, [0, 0]) as Array)[1])


func axis_total(axis: StringName) -> int:
	return axis_stacks(axis) + axis_system(axis)


## 百分比轴的当前因子（定点）。受到伤害这条由伤害管线直接读
func axis_factor(axis: StringName) -> int:
	return StatAxes.factor(axis, axis_total(axis))


## 改一条轴。[param system] = 系统层（加时这类；净化不动它）。返回实际改了多少
func shift_axis(axis: StringName, delta: int, system: bool = false) -> int:
	if delta == 0 or not StatAxes.has(axis):
		return 0
	var pair: Array = axes.get(axis, [0, 0])
	pair[1 if system else 0] = int(pair[1 if system else 0]) + delta
	axes[axis] = pair
	mark_dirty()
	return delta


## 4.3 公式的最后一步：按轴表把因子 / 固定值落到单位与每件道具的属性终值上
func _apply_axes() -> void:
	for axis in axes:
		var total := axis_total(axis)
		if total == 0:
			continue
		var key := StatAxes.stat_of(axis)
		if axis == StatAxes.REGEN_HP_PCT:
			# 按生命上限的百分比每秒回血：折进 regen_hp 的速率（只落在单位上）
			var per_sec := StatMath.mul(_merged.total_of(BattleStats.MAX_HP), StatMath.from_float(total * StatAxes.step_of(axis) / 100.0))
			_merged.ensure(BattleStats.REGEN_HP).add_flat(per_sec)
			continue
		if key == &"":
			continue
		if StatAxes.is_factor(axis):     # 105 第十节：连乘轴和百分比轴走同一条路，只是因子算法不同
			var f := StatAxes.factor(axis, total)
			_scale_final(_merged, key, f)
			for uid in _merged_items:
				_scale_final(_merged_items[uid], key, f)
		else:
			var add := StatMath.from_float(total * StatAxes.step_of(axis))
			_merged.ensure(key).add_flat(add)
			if StatAxes.on_items(axis):
				for uid in _merged_items:
					(_merged_items[uid] as StatSet).ensure(key).add_flat(add)


## 把一项属性的终值乘上 [param f]（定点）：差额补进固定值 —— 终值 = 原终值 × f
static func _scale_final(set: StatSet, key: StringName, f: int) -> void:
	if f == StatMath.ONE or (not set.has(key) and BattleStats.default_base(key) == 0):
		return
	var v := set.ensure(key)
	var before := v.total()
	v.add_flat(StatMath.mul(before, f) - before)
#endregion


## 资源由 max_* 属性自动派生：有 max_shield 就有 shield 资源。
func _sync_resource_maxes() -> void:
	for key in _merged.keys():
		var res := BattleStats.resource_of_max(key)
		if res == &"":
			continue
		var cap := _merged.total_of(key)
		if resources.has(res):
			resources.set_max(res, cap)
		else:
			resources.define(res, cap)
#endregion


## 把所有带回复速率的资源补算到 [param now]。
##
## [b]懒结算，没有定时器。[/b] 推进器每到一个时刻调一次，
## 按「距上次结算过了多久 × 当刻速率」补上 —— 事件驱动的模拟里没有「每秒」这回事。
##
## 速率取自 regen_xxx 属性，因此**它自动吃 buff**：
## 「某某 buff 让耐力回得更快」就是一条作用于 regen_stamina 的普通 StatModifier，
## 和增伤走同一条 4.3 公式，不需要任何新机制。
func settle_regen(now: int) -> void:
	for key in resources.keys():
		var rate := stat(BattleStats.regen_of_resource(key), 0)
		if rate > 0:
			resources.settle_regen(key, rate, now)


## 某件物品通过增益／受益格连结到的其他物品 uid
func links_of(uid: int) -> Array[int]:
	return item_links.get(uid, [] as Array[int])


## 132：某件物品的标签（没有 = 空）
func tags_of(uid: int) -> Array[StringName]:
	return item_tags.get(uid, [] as Array[StringName])


#region buff
func stacks_of(buff_id: StringName) -> int:
	for b in buffs:
		if b.def.id == buff_id:
			return b.stacks
	return 0


func find_buff(buff_id: StringName) -> BuffInstance:
	for b in buffs:
		if b.def.id == buff_id:
			return b
	return null


## 施加 buff。已存在则叠层，否则新建。返回实际增加的层数。
##
## [b]会改变规则集[/b]（buff 可携带 rules），调用方必须随后重算事件掩码，
## 否则新规则订阅的事件可能尚未开启，那条规则会静默失效。
func apply_buff(def: BuffDef, stacks: int = 1, now: int = 0) -> int:
	var ctx: BattleContext = _ctx_ref.get_ref() if _ctx_ref != null else null
	if ctx != null and not ctx.seen_buffs.has(def.id):
		ctx.seen_buffs[def.id] = def     # 103 第 6 条：上过身的都登记，回放的 buff 栏靠它认得所有 buff
	var existing := find_buff(def.id)
	var added := 0
	if existing != null:
		added = existing.add_stacks(stacks, now)
	else:
		var inst := BuffInstance.create(def, stacks, now)
		buffs.append(inst)
		added = inst.stacks
		var added_rules: Array[RuleRuntime] = []
		for rule in def.rules:
			var new_rt := RuleRuntime.create(rule, 0, inst, side)
			_register(new_rt)
			added_rules.append(new_rt)
		_notify_rules_changed(added_rules)
	mark_dirty()
	if ctx != null and ctx.trace != null:
		var inst2 := find_buff(def.id)
		_trace_buff(ctx, def.id, added, inst2.stacks if inst2 != null else 0, "apply", inst2.expires_at if inst2 != null else -1)
	return added


## 117：内部日志的一条 buff 变动（叠层、移除、到期），带剩余层数与到期时刻
func _trace_buff(ctx: BattleContext, id: StringName, delta: int, stacks: int, reason: String, expires_at: int = -1) -> void:
	ctx.trace.record(ctx.now, side, BattleTrace.BUFF, {"buff": String(id), "delta": delta, "stacks": stacks,
		"reason": reason, "expires_at": expires_at})


## 移除层数，返回实际移除的层数。层数归零时整条 buff 连同其规则一并移除。
func remove_buff_stacks(buff_id: StringName, count: int) -> int:
	var inst := find_buff(buff_id)
	if inst == null or count <= 0 or inst.def.system:
		return 0     # 103：系统效果（鏖战、衰竭）不可解除
	var removed := mini(count, inst.stacks)
	inst.stacks -= removed
	if inst.stacks <= 0:
		_drop_buff(inst)
	mark_dirty()
	var ctx: BattleContext = _ctx_ref.get_ref() if _ctx_ref != null else null
	if ctx != null and ctx.trace != null:
		_trace_buff(ctx, buff_id, -removed, maxi(0, inst.stacks), "remove", inst.expires_at)
	return removed


func _drop_buff(inst: BuffInstance) -> void:
	buffs.erase(inst)
	var before := rules.size()
	var kept: Array[RuleRuntime] = []
	for rt in rules:
		if rt.buff != inst:
			kept.append(rt)
	rules = kept
	if rules.size() != before:
		_notify_rules_changed()


## 登记一条规则并写入次序键。
func _register(rt: RuleRuntime) -> void:
	rt.order = side * 100000 + rules.size()
	rules.append(rt)


## 规则集一变就重建事件索引，并把新增的自发型规则排进时间轮。
##
## [b]放在这里而不是让调用方各自记得调。[/b] 施加 buff 时漏掉只是少触发，
## 移除 buff 时漏掉却会让已删除的规则继续被派发 —— 后者是真 bug，
## 而且「有时候某个效果还在生效」极难定位。集中在这一处就不可能漏。
##
## 被移除的规则不从堆里摘 —— 堆删任意元素代价高，改由弹出时惰性丢弃。
func _notify_rules_changed(added: Array[RuleRuntime] = [] as Array[RuleRuntime]) -> void:
	var ctx: BattleContext = _ctx_ref.get_ref() if _ctx_ref != null else null
	if ctx == null:
		return
	ctx.refresh_event_index()
	for rt in added:
		ctx.schedule_rule(self, rt)


## 该规则是否仍在本单位的规则表里。时间轮弹出时用它做惰性删除。
func owns_rule(rt: RuleRuntime) -> bool:
	return rules.has(rt)


## 移除所有在 now 已到期的 buff，返回被移除的列表。
func expire_buffs(now: int) -> Array[BuffInstance]:
	var expired: Array[BuffInstance] = []
	for b in buffs:
		if b.is_expired_at(now):
			expired.append(b)
	for b in expired:
		_drop_buff(b)
	if not expired.is_empty():
		mark_dirty()
		var ctx: BattleContext = _ctx_ref.get_ref() if _ctx_ref != null else null
		if ctx != null and ctx.trace != null:
			for b in expired:
				_trace_buff(ctx, b.def.id, -b.stacks, 0, "expired", b.expires_at)
	return expired


## 下一个 buff 到期的时刻；没有限时 buff 则返回 -1。
## 模拟器把它排进时间轮，不需要逐帧扫描。
func next_expiry() -> int:
	var soonest := -1
	for b in buffs:
		if b.is_permanent():
			continue
		if soonest < 0 or b.expires_at < soonest:
			soonest = b.expires_at
	if undying_until >= 0 and (soonest < 0 or undying_until < soonest):
		soonest = undying_until     # 093：坚持期到期也是一个要醒来的时刻
	return soonest
#endregion


## 把资源变动接到事件总线上。由 [method BattleContext.create] 调用。
func bind_context(ctx: BattleContext) -> void:
	_ctx_ref = weakref(ctx)
	if not resources.changed.is_connected(_on_resource_changed):
		resources.changed.connect(_on_resource_changed)


func _on_resource_changed(key: StringName, delta: int, reason: StringName) -> void:
	var ctx: BattleContext = _ctx_ref.get_ref() if _ctx_ref != null else null
	if ctx == null:
		return
	# 带上变化【之后】的当前值与上限：回放层因此不必自己累加增量，
	# 也不会因为漏掉一次上限变动（强壮之类的 buff）而让血条的分母失真。
	# 093（蛮神 4 级）：不死期间耐力无限 —— 花掉多少立刻补回
	if undying_active() and key == BattleStats.RES_STAMINA and delta < 0:
		resources.change(key, -delta, BattleEvent.REASON_REGEN)
	ctx.emit(BattleEvent.RESOURCE_CHANGED, side, {
		"key": String(key), "delta": delta, "reason": String(reason),
		"current": resources.current(key), "max": resources.maximum(key),
	})
	# 103（衰竭）：生命上限掉到把当前血压成 0 也是倒下。走 mark_dead，所以蛮神的不死照常进坚持期
	if key == BattleStats.RES_HP and reason == BattleEvent.REASON_MAX_CHANGED \
			and resources.current(key) <= 0 and mark_dead():
		ctx.emit(BattleEvent.DIED, side, {})


## 087（作者反馈：敌人倒下两次、倒下时血没归零）：**倒下是终局**。血一到 0 就记死，之后的治疗（伤药的「濒死回血」）不再把它救回来，
## 也不再发第二次 DIED。回放里看到的「倒下时血没归零」就是同一时刻先倒下、再被治回来、面板停在治疗后的数
var dead: bool = false
## 093（蛮神 4 级）：血归零后还能坚持几秒（定点；0 = 没有这条），只用一次；不死期间 undying_until 是到期时刻
var undying_sec: int = 0
var undying_until: int = -1
var undying_used: bool = false


func is_alive() -> bool:
	return not dead and (resources.current(BattleStats.RES_HP) > 0 or undying_active())


func undying_active() -> bool:
	return undying_until >= 0 and not dead


## 血到 0 时由伤害管线 / 资源效果调：第一次返回 true（该发 DIED），之后 false。
## 093：有「不死」且还没用过 → 不死、不发 DIED，进入坚持期（发 EFFECT_RESOLVED undying 给回放看），到期由 [method settle_undying] 判
func mark_dead() -> bool:
	if dead:
		return false
	if undying_active():
		return false     # 坚持期里血再归零：还没到时候
	if undying_sec > 0 and not undying_used:
		undying_used = true
		var ctx: BattleContext = _ctx_ref.get_ref() if _ctx_ref != null else null
		var now := ctx.now if ctx != null else 0
		undying_until = now + undying_sec
		if ctx != null:
			ctx.emit(BattleEvent.EFFECT_RESOLVED, side, {"effect": "undying", "uid": 0, "until": undying_until, "seconds": StatMath.to_float(undying_sec)})
		return false
	dead = true
	return true


## 093：坚持期到了没。到了：血还是 0 就真死（返回 true，该发 DIED）；被治回来了就活着继续
func settle_undying(now: int) -> bool:
	if undying_until < 0 or now < undying_until:
		return false
	undying_until = -1
	if resources.current(BattleStats.RES_HP) > 0:
		return false
	dead = true
	return true


func snapshot() -> Dictionary:
	var buff_snap := {}
	for b in buffs:
		buff_snap[String(b.def.id)] = b.stacks
	var axis_snap := {}
	for a in axes:
		if axis_total(a) != 0 or axis_system(a) != 0:
			axis_snap[String(a)] = [axis_stacks(a), axis_system(a)]
	return {"side": side, "resources": resources.snapshot(), "buffs": buff_snap, "axes": axis_snap}
