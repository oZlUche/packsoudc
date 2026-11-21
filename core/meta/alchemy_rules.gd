## 354：炼金术的规矩 —— 哪些要危险确认、折损多少、哪些料不能用尘补。第七节（作者 2026-11-21 11:39「所有东西都可以炼金」）：仓库里每一件都能丢，只有锁定的拒绝
##
## 走内容管线：`data/authoring/base_rules/alchemy.json` → `data/base_rules/alchemy.tres`（[method Alchemy.load_rules]）。数都是初值，作者改 json
class_name AlchemyRules
extends Resource

const ID := &"alchemy"

@export var id: StringName = &""
@export var display_name: String = ""
## 哪一方的声望档决定折损（魔法师协会）
@export var faction: StringName = &"society"
## 折损（下标 = 那一方的声望档 0 初识 … 4 代言，表短按最后一项）：分解得尘 = 尘值 × (1 − 折损)。作者 2026-11-21：在 20% 到 50% 之间
@export var loss_by_tier: Array[float] = [0.4, 0.4, 0.4, 0.4, 0.25]
## 第七节：带其中一个标签的能炼，但手动要危险确认（「这件拿不回来」）、一键炼金跳过（剧情独有、珍宝、信物、铸牌、封存件、委托物、入场券）
@export var guard_tags: Array[StringName] = [&"unique", &"treasure", &"keepsake", &"token", &"sealed", &"commission", &"ticket"]
## 第七节：点名要危险确认、一键跳过的
@export var guard_ids: Array[StringName] = []
## 补料：带其中一个标签的料不能用尘补（魔晶石）
@export var no_dust_tags: Array[StringName] = [&"crystal"]
## 补料：门槛（材料格的最低稀有度 / 点名道具的稀有度）到这一档就不能用尘补（4 = 传说）
@export var no_dust_rarity: int = 4


## 第 [param tier] 档的折损
func loss_at(tier: int) -> float:
	if loss_by_tier.is_empty():
		return 0.0
	return loss_by_tier[clampi(tier, 0, loss_by_tier.size() - 1)]
