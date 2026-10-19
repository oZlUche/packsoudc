## 一种敌人（架构文档 5.10 / 6.0，M4-1）。
##
## [b]敌人就是一个背包。[/b] 它不带固定的棋盘 —— 棋盘是按规则**组装**出来的：
## 「通用道具 + 流派道具」（[EnemyLoadout]），件数由强度档位定（[StrengthTier]）。
## 同一种敌人在外环是档位 0 背两件，到了核心附近是档位 3 背七件 —— 定义里只写它的
## **本色档位** [member strength]（用来在池里按想要的档位挑人）与**流派** [member schools]。
##
## 流派是标签，可以有多个：「混伤型」不是一种流派，是同时带两个流派的敌人。
## 道具按 [member ItemDef.tags] 里带没带这个流派名归到流派里 —— 新增一种流派 = 给几件道具打上标签，
## 再写一个带这个标签的敌人，代码一行不改。
##
## 作者数据，走内容管线：`data/authoring/enemies/*.json` → `data/enemies/*.tres`。
class_name EnemyDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 088：别的语言的名字，`{"en": "Knife"}`；界面用 [method Names.of] 取（当前语言没有就用 display_name）
@export var display_names: Dictionary = {}

## 本色档位（0 起）。池按节点算出想要的档位后，在 ± tolerance 内挑本色接近的敌人；
## 实际用哪个档位组装，记在节点内容里（`content.strength`），不一定等于本色
@export var strength: int = 0

## 流派标签，可多个。组装时按它挑流派道具
@export var schools: Array[StringName] = []

## 基线属性覆盖（max_hp、armor…）。没写的键用 [CombatantBaseline] 的默认值；
## 档位表的 [member StrengthTier.stat_scale] 再乘上去
@export var base_stats: Dictionary = {}

## 招牌道具：一定背着的道具 id，计入件数。屠夫总带着刀
@export var signature: Array[StringName] = []

## 087（作者定）：**身份决定能背什么** —— 名字既然叫神射手，背的就只能是弓箭。列出这个身份相关的道具标签，
## 组装时（流派池、通用池、补件、保底武器）**只从带任一这些标签的道具里抽**；空 = 不限（老路）。
## 流派 [member schools] 仍决定「哪几件是它的出手风格」，身份标签是外面那一圈篓子
@export var item_tags: Array[StringName] = []

## 087：按档位换招牌 —— 键是档位（JSON 里是字符串 "0" / "1" / …），值是那一档起必带的道具 id 列表；取 ≤ 实际档位的最高一档，
## 和 [member signature] 一起算招牌。神射手：0 档短弓、1 档长弓、2 档赐福的长弓
@export var signature_by_strength: Dictionary = {}


## 这一档的招牌：signature + signature_by_strength 里 ≤ strength 的最高一档
func signature_at(p_strength: int) -> Array[StringName]:
	var out: Array[StringName] = signature.duplicate()
	var best := -1
	for key in signature_by_strength:
		var k := int(String(key))
		if k <= p_strength and k > best:
			best = k
	if best >= 0:
		for raw in signature_by_strength[str(best)]:
			var id := StringName(String(raw))
			if not out.has(id):
				out.append(id)
	return out


## 这件道具这个身份能不能背（不看流派、稀有度）：没列身份标签 = 都能
func allows_item(def: ItemDef) -> bool:
	if item_tags.is_empty():
		return true
	if def == null:
		return false
	for t in def.tags:
		if item_tags.has(t):
			return true
	return false

## 165（作者定）：**身份固定的相邻组合** —— 每组是几件道具 id（`[["longbow", "arrows"]]`）。挑出来的道具里这几件都在时一定摆成一组、
## 彼此挨着生效（谁给谁加成看道具自己的相邻标记），不参与自动配对、不被拆。没写就全靠 [method EnemyPlacer.auto_groups] 从道具定义里推。
## JSON 里是数组的数组（元素不带类型：GDScript 导出不了 `Array[Array[StringName]]`），读用 [method combo_list]
@export var combos: Array = []


## 165：[member combos] 按 id 列表读出来（坏掉的项跳过）
func combo_list() -> Array[Array]:
	var out: Array[Array] = []
	for raw in combos:
		if not (raw is Array):
			continue
		var ids: Array[StringName] = []
		for id in raw:
			ids.append(StringName(String(id)))
		if ids.size() >= 2:
			out.append(ids)
	return out

## 覆盖池的默认组装规则。null = 用池的
@export var loadout: EnemyLoadout = null

## 覆盖档位表的棋盘尺寸。零 = 用档位表的
@export var board: Vector2i = Vector2i.ZERO

## 覆盖档位表的包（084）。空 = 用档位表的
@export var bags: Array[StringName] = []


## 212：种族。`human`（人，默认）/ `beast`（魔兽）/ `construct`（机关，210）—— 不是人的身上的道具用 [member ItemDef.wild] 那一面，
## 不揣携带品（126）
@export var species: StringName = &"human"
## 212：没有包 —— 不摆包，棋盘不要求包（道具直接摆）；死了不掉包（209）
@export var bagless: bool = false

const SPECIES: Array[StringName] = [&"human", &"beast", &"construct"]


## 212：不是人（魔兽、机关）：编译用 `wild` 面
func is_wild() -> bool:
	return species != &"human"


func is_valid() -> bool:
	return id != &"" and strength >= 0
