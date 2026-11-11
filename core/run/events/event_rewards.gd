## 事件奖励的冻结（事件方案 2026-11-11 §8.4「结果冻结」）：事件挂起时，选项里每一份 [GivePoolItem] 按它的 key 抽好，
## 写进节点内容 `content["rewards"][key] = {"items": [...], "pool": 池 id, "depth": 深度, "level": 难度档}`，跟着存档走。
##
## 之后选项文字的 `{reward_name}`、选了之后发的东西都读这一份：重进、Esc、读档、换着看选项都不重抽，后来深度 / 难度变了也不改。
## 随机数只由节点的 content_seed 与 key 派生，和战斗、搜索的随机流互不相干。不同的事件实例各抽各的（池子永不抽空）
class_name EventRewards
extends RefCounted

const KEY := "rewards"


## 这一份冻结的道具 id；没冻结过返回空
static func frozen(node: MapNode, key: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if node == null:
		return out
	var all = node.content.get(KEY, {})
	if not (all is Dictionary):
		return out
	var row = (all as Dictionary).get(String(key), {})
	if row is Dictionary:
		for id in (row as Dictionary).get("items", []):
			out.append(StringName(String(id)))
	return out


static func has_frozen(node: MapNode, key: StringName) -> bool:
	return node != null and node.content.get(KEY, {}) is Dictionary and (node.content.get(KEY, {}) as Dictionary).has(String(key))


## 这一份奖励：冻结过就读冻结的，没有就现抽、写进内容再返回
static func ensure(ctx: EventContext, o: GivePoolItem) -> Array[StringName]:
	if ctx == null or ctx.node == null or o == null:
		return [] as Array[StringName]
	var key := o.reward_key()
	if has_frozen(ctx.node, key):
		return frozen(ctx.node, key)
	var got: Array[StringName] = []
	var pool: RewardPool = ctx.reward_pools.get(o.pool, null)
	if pool != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:reward:%s" % [ctx.node.content_seed, key])
		got = pool.draw(ctx.items, ctx.chapter, ctx.depth, ctx.difficulty_level, rng, o.count)
	if pool == null or got.is_empty():
		push_warning("EventRewards: 奖励池 '%s' 在这里没有合格候选（章节 %s，深度 %.2f，难度 %d）" % [o.pool, ctx.chapter, ctx.depth, ctx.difficulty_level])
	var ids: Array = []
	for id in got:
		ids.append(String(id))
	var all: Dictionary = ctx.node.content.get(KEY, {}) if ctx.node.content.get(KEY, {}) is Dictionary else {}
	all[String(key)] = {"items": ids, "pool": String(o.pool), "depth": snappedf(ctx.depth, 0.001), "level": ctx.difficulty_level}
	ctx.node.content[KEY] = all
	return got


## 一个事件里全部的池奖励都冻结好（挂起时调；预览与结算读同一份）
static func freeze_all(ctx: EventContext, def: EventDef) -> void:
	if def == null:
		return
	for opt in def.options:
		for o in (opt as EventOption).outcomes:
			if o is GivePoolItem:
				ensure(ctx, o as GivePoolItem)


## 这个选项的池奖励 → 文字占位符：`{reward_name}`（第一份的第一件，按稀有度上色）、`{reward_names}`（第一份全部）、
## `{reward_price}`（按奖励定价的付钱后果要付多少）。只读冻结的，不抽
static func params(node: MapNode, opt: EventOption, items: ItemDatabase) -> Dictionary:
	var out := {}
	if node == null or opt == null:
		return out
	for o in opt.outcomes:
		var key := &""
		if o is GivePoolItem:
			key = (o as GivePoolItem).reward_key()
		elif o is ChangeMoney and (o as ChangeMoney).reward_key != &"":
			out["reward_price"] = price_of(node, o as ChangeMoney, items)
			key = (o as ChangeMoney).reward_key
		if key == &"" or out.has("reward_name"):
			continue
		var ids := frozen(node, key)
		if ids.is_empty():
			continue
		var names: Array[String] = []
		for id in ids:
			names.append("{item:%s}" % id)
		var ctx := {"_items": items}
		out["reward_name"] = TextTemplate.render(names[0], ctx)
		out["reward_names"] = TextTemplate.render(UiText.t("setup.list_sep").join(names), ctx)
	return out


## 按冻结的奖励定价的那笔钱（[member ChangeMoney.reward_key]）：每件定价（[ItemValue]）× 倍率，合起来取整，至少 1
static func price_of(node: MapNode, o: ChangeMoney, items: ItemDatabase) -> int:
	var total := 0.0
	for id in frozen(node, o.reward_key):
		var d := items.get_def(id) if items != null else null
		if d != null:
			total += float(ItemValue.of(d))
	return maxi(1, roundi(total * o.reward_price_mult)) if total > 0.0 else 0
