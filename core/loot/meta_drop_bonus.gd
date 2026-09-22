## 局外 buff 对掉落的修正 —— [b]占位[/b]（架构文档 6.1、15 节 meta 成长）。
##
## 局外成长还没有设计，这里只把接缝留好：将来它从 meta 存档里读「掉落率 +x」「珍宝概率 +y」之类的项，
## 在这两个方法里加上去。现在两个都返回 0，[DropResolver] 照样调它 —— 接上时一行不改。
class_name MetaDropBonus
extends DropBonusSource

## 将来装 meta 存档里的加成；现在空着
var entries: Dictionary = {}


func owned_bonus(_ctx: LootContext, _def: ItemDef) -> float:
	return float(entries.get("owned", 0.0))


func treasure_bonus(_ctx: LootContext) -> float:
	return float(entries.get("treasure", 0.0))


func describe() -> String:
	return "局外 buff（占位）"
