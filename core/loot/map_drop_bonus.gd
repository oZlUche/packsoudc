## 地图 buff 对掉落的修正 —— [b]占位[/b]（架构文档 6.1）。
##
## 「这张图上掉落率 +10%」「这片高危区里珍宝概率翻倍」之类的地图级修正还没有设计。
## 接缝留在这里：将来从章节或区域的定义里读，现在两个都返回 0。
class_name MapDropBonus
extends DropBonusSource

## 将来装章节 / 区域给的加成；现在空着
var entries: Dictionary = {}


func owned_bonus(_ctx: LootContext, _def: ItemDef) -> float:
	return float(entries.get("owned", 0.0))


func treasure_bonus(_ctx: LootContext) -> float:
	return float(entries.get("treasure", 0.0))


func describe() -> String:
	return "地图 buff（占位）"
