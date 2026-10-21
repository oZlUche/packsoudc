## 仓库扩建（110；163 作者定：不加行，加页）：每升一级仓库多 [member pages] 页，各页独立、一样大（[Warehouse]）；页数由级数算出（120）
class_name TechWarehousePages
extends TechEffect

## 每级加几页
@export_range(1, 10) var pages: int = 1


## 120：页数 = 1 + 每级页数 × 级数。比现在多就在后面加空页；比现在少就只删末尾的空页（[method Warehouse.set_page_count]，
## 碰到有东西的页停下并告警）—— 读档时仓库还是空的，总能缩到位
func derive(meta: MetaState, level: int) -> void:
	if meta == null or meta.warehouse == null:
		return
	meta.warehouse.set_page_count(1 + pages * maxi(0, level))


func describe() -> String:
	return UiText.t("tech.pages_plus") % pages


## 118：到第 k 级一共几页
func describe_level(level: int, _buff_defs: Dictionary = {}) -> String:
	return UiText.t("tech.pages_total") % (1 + pages * level)


## 163：界面列出未解锁的页用 —— {"max": 升满时几页, "per_level": 每级几页, "name": 科技名}；科技里没有仓库扩建 = {}
static func plan_of(defs: Array) -> Dictionary:
	for d in defs:
		var def := d as TechDef
		if def != null and def.effect is TechWarehousePages:
			var per := (def.effect as TechWarehousePages).pages
			return {"max": 1 + per * def.tiers.size(), "per_level": per, "name": Names.of(def)}
	return {}
