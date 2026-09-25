## 掉落规则（架构文档 6.1，M4-2）：敌人的每件道具各自掷一次，稀有度越高基础掉落率越低；
## 另有一次「珍宝」掷骰 —— 掉一件敌人**自身没有**的高稀有度道具。
##
## 作者的设想原话：每件道具都有一定概率掉落，稀有度越高基础掉落率越低，受难度（正面）、幸运值（增益 / 减益）、
## 局外 buff（占位）、地图 buff（占位）修正；每个敌人都有概率掉落自身未持有的最高两级（红、金）珍宝。
##
## 全是数据：概率表按稀有度下标，修正是每一级 / 每一点加多少。局外与地图 buff 走 [DropBonusSource] 的接缝。
## 作者数据，走内容管线：`data/authoring/drop_rules/*.json` → `data/drop_rules/*.tres`，章节按 id 引用。
class_name DropRule
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

## 稀有度 → 基础掉落率（0～1），下标即稀有度。导入器要求**非递增**：越稀有越难掉。
## 稀有度超出表长的按最后一档
@export var base_chance: Array[float] = [0.6, 0.45, 0.3, 0.15, 0.05]

## 难度每 +1，每件道具的掉落率加多少（正面加成）
@export var difficulty_bonus: float = 0.05

## 幸运值每一点加多少。幸运值可正可负 —— 减益就是负的幸运
@export var luck_bonus: float = 0.02

## 每个敌人掉一件自身未持有的珍宝的概率（每次尝试；尝试次数 = LootContext.rolls）
@export var treasure_chance: float = 0.05

## 珍宝的稀有度 → 权重。作者定的是最高两级：红（4）、金（3）。键是稀有度的字符串形式（JSON 的键只能是字符串）
@export var treasure_weights: Dictionary = {"3": 3, "4": 1}

## 珍宝道具的标签。「珍宝」类型作者还没细定，先用标签占位：带这个标签的道具才会当珍宝掉
@export var treasure_tag: StringName = &"treasure"

## 珍宝概率是否也吃难度 / 幸运 / buff 修正
@export var treasure_modified: bool = true

## 至少掉几件身上有的（084 作者定：打赢了至少掉一件敌人拥有的道具）。掷完不够就从没掉的里随机补；身上没那么多就掉光。0 = 不保底。
## **包不算在这个名额里**（作者定：包另有 bags_always_drop）
@export var min_drops: int = 0
## 敌人身上的包必掉（作者定），且不占 min_drops 的名额。false = 包和别的东西一样按稀有度掷
@export var bags_always_drop: bool = true


func base_of(rarity: int) -> float:
	if base_chance.is_empty():
		return 0.0
	return base_chance[clampi(rarity, 0, base_chance.size() - 1)]


## 珍宝的稀有度列表（整数），升序
func treasure_rarities() -> Array[int]:
	var out: Array[int] = []
	for key in treasure_weights:
		var r := int(String(key))
		if not out.has(r):
			out.append(r)
	out.sort()
	return out


func treasure_weight(rarity: int) -> float:
	return float(treasure_weights.get(str(rarity), 0))
