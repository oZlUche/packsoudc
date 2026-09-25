## 强度档位表的一行（架构文档 6.0）：这一档背几件、棋盘多大、基线乘多少。
##
## 「强度」在本作里首先是**道具数量**：件数多，DPS 与生命一起上去，掉落也一起肥。
## 基线倍率是补充 —— 不靠道具也能把血堆上去的那一档。
class_name StrengthTier
extends Resource

@export var strength: int = 0

## 件数范围 [min, max]，含招牌道具
@export var item_count: Vector2i = Vector2i(2, 3)

## 棋盘尺寸。放不下的道具会被跳过，所以棋盘该比件数宽裕
@export var board: Vector2i = Vector2i(4, 3)

## 基线倍率：属性键 → 倍数。例：{"max_hp": 1.5}
@export var stat_scale: Dictionary = {}

## 这一档背的包（道具 id，084 作者：敌人和玩家一样，所有道具都依托背包）。先摆包，道具只能摆进包里；
## 包本身计入身上的东西（会掉）、不计入 item_count。空 = 老路，道具直接摆棋盘
@export var bags: Array[StringName] = []

## 这一档背的道具稀有度上限，-1 不限；与组装规则的上限取小。
## 外环的小兵不该背传说品 —— 这是掉落的来源（5.10），也是低档棋盘小、别让 3×3 的重甲把它塞满的原因
@export var rarity_cap: int = -1


func scaled(key: StringName, value: float) -> float:
	return value * float(stat_scale.get(String(key), 1.0))
