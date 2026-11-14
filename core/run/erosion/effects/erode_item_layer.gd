## 320 A9（深层侵蚀）：真正走进（不是待着）够深的被侵蚀点，从随身的合格道具里等权随机挑一件，侵蚀 +1；
## 到上限那一次永久损毁（[ItemErosion]）。没有合格道具什么也不做。旧的「损坏道具」[ErodeDamageItem] 不再用
class_name ErodeItemLayer
extends ErosionEffect

## 第几层损毁（第一次侵蚀时记到道具上）
@export var limit: int = ItemErosion.DEFAULT_LIMIT


func apply(ctx: ErosionContext) -> void:
	if not ctx.entered or ctx.run == null or ctx.run.board == null:
		return
	var cands: Array[ItemInstance] = []
	for inst in ctx.run.board.items():
		if ItemErosion.eligible(inst):
			cands.append(inst)
	if cands.is_empty():
		ctx.log.append(UiText.t("erosion.item_none"))
		return
	var inst := cands[ctx.rng.randi_range(0, cands.size() - 1)]
	var n := ItemErosion.add(inst, limit)
	var name_ := Names.of(inst.def)
	if n >= ItemErosion.limit(inst):
		ctx.run.destroy_item(inst, ctx.run.board)
		ctx.items_eroded.append({"name": name_, "count": n, "limit": ItemErosion.limit(inst), "destroyed": true})
		ctx.log.append(UiText.t("erosion.item_destroyed") % name_)
	else:
		ctx.items_eroded.append({"name": name_, "count": n, "limit": ItemErosion.limit(inst), "destroyed": false})
		ctx.log.append(UiText.t("erosion.item_layer") % [name_, n, ItemErosion.limit(inst)])
