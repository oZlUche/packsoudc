## 深层侵蚀：损坏背包里的一件（5.7：你刚抢到的战利品正在你手里烂掉）。现在的「损坏」= 摧毁（道具没有耐久）。挑法见 [ItemPick]
class_name ErodeDamageItem
extends ErosionEffect

## 与 [enum ItemPick.Mode] 对齐
enum Pick { RANDOM, MOST_VALUABLE, LEAST_VALUABLE }
enum Target { BOARD, STORAGE, BOTH }

@export var pick: Pick = Pick.MOST_VALUABLE
@export var target: Target = Target.BOARD
## 包也在候选里？默认不：包没了里面的东西全散
@export var include_bags: bool = false


func apply(ctx: ErosionContext) -> void:
	var cands: Array = []
	if target != Target.STORAGE and ctx.run.board != null:
		cands.append_array(ItemPick.candidates([ctx.run.board], include_bags))
	if target != Target.BOARD and ctx.run.storage != null:
		cands.append_array(ItemPick.candidates([ctx.run.storage], true))     # 地上是列表，包是空的，不用避
	var chosen := ItemPick.choose(cands, pick, ctx.rng)
	if chosen.is_empty():
		return
	var inst := chosen["inst"] as ItemInstance
	if (chosen["from"] as ItemContainer).remove(inst.uid) != null:
		ctx.items_lost.append(Names.of(inst.def))


func describe() -> String:
	var how: String = ["随机一件", "最值钱的一件", "最不值钱的一件"][pick]
	var where: String = ["棋盘上", "地上", "棋盘或地上"][target]
	return "损坏%s%s%s" % [where, how, gate_text()]
