## 仓库扩建（110）：每升一级仓库多 [member rows] 行，仓库里的东西原地不动（[method GridInventory.grow_rows]）；行数由级数算出（120）
class_name TechWarehouseRows
extends TechEffect

## 每级加几行
@export_range(1, 20) var rows: int = 3


## 120：行数 = 规则里的基础行数 + 每级行数 × 级数。比现在多就长；比现在少就从底往上只删空行（[method GridInventory.resize_rows]，
## 碰到有东西的行停下并告警）—— 读档时仓库还是空的，总能缩到位
func derive(meta: MetaState, level: int) -> void:
	if meta == null or meta.warehouse == null:
		return
	meta.warehouse.resize_rows(meta.warehouse_size().y + rows * maxi(0, level))


func describe() -> String:
	return "+%d 行" % rows


## 118：到第 k 级一共加了几行
func describe_level(level: int, _buff_defs: Dictionary = {}) -> String:
	return "仓库共 +%d 行" % (rows * level)
