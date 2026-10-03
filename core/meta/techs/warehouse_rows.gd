## 仓库扩建（110）：每升一级仓库多 [member rows] 行，仓库里的东西原地不动（[method GridInventory.grow_rows]）
class_name TechWarehouseRows
extends TechEffect

## 每级加几行
@export_range(1, 20) var rows: int = 3


func apply(meta: MetaState) -> void:
	if meta != null and meta.warehouse != null:
		meta.warehouse.grow_rows(rows)


## 期望行数 = 规则里的基础行数 + 每级行数 × 级数；存档里的仓库比它小（改过基础尺寸、手改存档）就补齐
func heal(meta: MetaState, level: int) -> void:
	if meta == null or meta.warehouse == null:
		return
	var want := meta.warehouse_size().y + rows * level
	var have := meta.warehouse.size.y
	if have < want:
		meta.warehouse.grow_rows(want - have)


func describe() -> String:
	return "+%d 行" % rows
