## 深层侵蚀：损坏背包里的一件（5.7：你刚抢到的战利品正在你手里烂掉）。现在的「损坏」= 摧毁（道具没有耐久）
class_name ErodeDamageItem
extends ErosionEffect

enum Pick { RANDOM, MOST_VALUABLE, LEAST_VALUABLE }
enum Target { BOARD, STORAGE, BOTH }

@export var pick: Pick = Pick.MOST_VALUABLE
@export var target: Target = Target.BOARD
## 包也在候选里？默认不：包没了里面的东西全散
@export var include_bags: bool = false


func apply(ctx: ErosionContext) -> void:
	var cands: Array = []
	if target != Target.STORAGE and ctx.run.board != null:
		for inst in ctx.run.board.items():
			if include_bags or not (inst as ItemInstance).def.is_bag:
				cands.append({"inst": inst, "from": ctx.run.board})
	if target != Target.BOARD and ctx.run.storage != null:
		for inst in ctx.run.storage.items():
			cands.append({"inst": inst, "from": ctx.run.storage})
	if cands.is_empty():
		return
	var chosen: Dictionary = cands[0]
	match pick:
		Pick.RANDOM:
			chosen = cands[ctx.rng.randi_range(0, cands.size() - 1)]
		Pick.MOST_VALUABLE:
			for c in cands:
				if ItemValue.of((c["inst"] as ItemInstance).def) > ItemValue.of((chosen["inst"] as ItemInstance).def):
					chosen = c
		Pick.LEAST_VALUABLE:
			for c in cands:
				if ItemValue.of((c["inst"] as ItemInstance).def) < ItemValue.of((chosen["inst"] as ItemInstance).def):
					chosen = c
	var inst := chosen["inst"] as ItemInstance
	if (chosen["from"] as ItemContainer).remove(inst.uid) != null:
		ctx.items_lost.append(inst.def.display_name)


func describe() -> String:
	var how: String = ["随机一件", "最值钱的一件", "最不值钱的一件"][pick]
	var where: String = ["棋盘上", "地上", "棋盘或地上"][target]
	return "损坏%s%s%s" % [where, how, gate_text()]
