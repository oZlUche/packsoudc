## 局外科技的一级要什么（110）：钱在按【升级】时一次扣；材料可以分批上交，交一件记一件
class_name TechTier
extends Resource

## 要多少钱
@export var funds: int = 0
## 319：要多少见识（机制树只花它，钱与材料都是 0；数值树这一项是 0）
@export var insight: int = 0
## 要哪些材料：道具 id → 件数（空 = 只要钱）
@export var items: Dictionary = {}
