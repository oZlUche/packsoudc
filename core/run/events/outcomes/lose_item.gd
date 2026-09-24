## 后果：失去身上的道具（8-3）—— 献祭、被偷、交钥匙。挑法与 [ErodeDamageItem] 一样：随机 / 最值钱 / 最不值钱，
## 再加「指定 id」；从棋盘、暂存区或两处拿；一次拿几件。没得拿就什么也不发生（条件层该先用 HasItem 挡住）
class_name LoseItem
extends EventOutcome

enum Pick { RANDOM, MOST_VALUABLE, LEAST_VALUABLE, BY_ID }
enum Where { BOARD, STORAGE, BOTH }

@export var pick: Pick = Pick.BY_ID
## BY_ID 时拿哪个
@export var item: StringName = &""
@export var count: int = 1
@export var where: Where = Where.BOTH
## 包也在候选里？默认不：包没了里面的东西全散
@export var include_bags: bool = false


func apply(ctx: EventContext) -> void:
	for i in maxi(0, count):
		var chosen := _choose(ctx)
		if chosen.is_empty():
			return
		var inst := chosen["inst"] as ItemInstance
		if (chosen["from"] as ItemContainer).remove(inst.uid) != null:
			ctx.items_lost.append(inst.def.display_name)


func _choose(ctx: EventContext) -> Dictionary:
	var cands: Array = []
	for c in ctx.containers(where):
		for inst in (c as ItemContainer).items():
			var def := (inst as ItemInstance).def
			if pick == Pick.BY_ID:
				if def.id == item:
					cands.append({"inst": inst, "from": c})
			elif include_bags or not def.is_bag:
				cands.append({"inst": inst, "from": c})
	if cands.is_empty():
		return {}
	var chosen: Dictionary = cands[0]
	match pick:
		Pick.RANDOM:
			chosen = cands[ctx.rng.randi_range(0, cands.size() - 1)] if ctx.rng != null else cands[0]
		Pick.MOST_VALUABLE:
			for c in cands:
				if ItemValue.of((c["inst"] as ItemInstance).def) > ItemValue.of((chosen["inst"] as ItemInstance).def):
					chosen = c
		Pick.LEAST_VALUABLE:
			for c in cands:
				if ItemValue.of((c["inst"] as ItemInstance).def) < ItemValue.of((chosen["inst"] as ItemInstance).def):
					chosen = c
	return chosen


func describe() -> String:
	var what: String = ["随机一件", "最值钱的一件", "最不值钱的一件", String(item)][pick]
	var from: String = ["棋盘上", "暂存区里", ""][where]
	return "失去%s%s%s" % [from, what, " ×%d" % count if count != 1 else ""]
