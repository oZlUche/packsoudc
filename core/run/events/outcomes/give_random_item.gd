## 后果：按搜索规则抽一件（稀有度随深度与危险上偏，6.2），可以给稀有度上限
class_name GiveRandomItem
extends EventOutcome

## -1 = 不限
@export var rarity_cap: int = -1
@export var count: int = 1


func apply(ctx: EventContext) -> void:
	if ctx.rules == null or ctx.rules.search == null or ctx.items == null or ctx.rng == null:
		return
	var got := SearchSession.draw_items(ctx.rules.search, ctx.items, ctx.depth, ctx.node.danger if ctx.node != null else 0, ctx.rng, rarity_cap)
	for i in mini(maxi(0, count), got.size()):
		ctx.items_given.append(got[i])


func describe() -> String:
	return "随机给 %d 件%s" % [count, "（稀有度 ≤ %d）" % rarity_cap if rarity_cap >= 0 else ""]
