## 敌人池：一张配置表（架构文档 6.0，M4-1）。
##
## 一章挑一个池（`ChapterDef.enemy_pool`）。池里有四样：
## - [member entries]：谁、多重、在什么环种类 / 节点类型 / 危险等级下出现（地图类型的过滤在这里）
## - [member tiers]：档位表 —— 每档背几件、棋盘多大、基线乘多少（强度 = 道具数量）
## - [member strength_rule]：一个节点想要几档（深度、危险、类型、难度、规模）
## - [member loadout]：默认组装规则（通用 + 流派）
##
## 作者数据，走内容管线：`data/authoring/enemy_pools/*.json` → `data/enemy_pools/*.tres`。
## 章节按 id 引用它，好几章可以共用一个池、只改难度。
class_name EnemyPool
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

@export var entries: Array[EnemyPoolEntry] = []
@export var tiers: Array[StrengthTier] = []
@export var strength_rule: StrengthRule = null
@export var loadout: EnemyLoadout = null

## 哪些节点类型里放敌人。random 不在里面：那是踩上去才知道的（5.10）
@export var combat_types: Array[StringName] = [&"battle", &"elite", &"core"]


## 这一档的行。没有正好的就取最近的（并列取低的）；表为空返回 null
func tier_of(strength: int) -> StrengthTier:
	var best: StrengthTier = null
	var best_d := 1 << 30
	for t in tiers:
		if t == null:
			continue
		var d := absi(t.strength - strength)
		if d < best_d or (d == best_d and t.strength < best.strength):
			best = t
			best_d = d
	return best


## 表里有的档位，升序
func strengths() -> Array[int]:
	var out: Array[int] = []
	for t in tiers:
		if t != null and not out.has(t.strength):
			out.append(t.strength)
	out.sort()
	return out


## 想要的档位夹进表的范围 —— 内容里记的就是这个
func clamp_strength(strength: int) -> int:
	var s := strengths()
	if s.is_empty():
		return maxi(0, strength)
	return clampi(strength, s[0], s[s.size() - 1])
